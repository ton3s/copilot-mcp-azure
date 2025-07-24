import azure.functions as func
import logging
import json
import asyncio
import os
from datetime import datetime
from opencensus.ext.azure.log_exporter import AzureLogHandler

from ..shared.auth import AzureADAuthValidator, TokenManager
from ..shared.mcp_protocol import (
    MCPServer, MCPRequest, MCPResponse, MCPError, MCPSession
)

logger = logging.getLogger(__name__)

# Configure Application Insights
if "APPLICATIONINSIGHTS_CONNECTION_STRING" in os.environ:
    logger.addHandler(AzureLogHandler())

auth_validator = AzureADAuthValidator()
token_manager = TokenManager()
mcp_server = MCPServer()

async def main(req: func.HttpRequest) -> func.HttpResponse:
    """Command endpoint for MCP requests"""
    logger.info("MCP command endpoint called")
    
    # Handle CORS preflight
    if req.method == "OPTIONS":
        return func.HttpResponse(
            "",
            status_code=204,
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Authorization, X-Session-Id, Content-Type",
                "Access-Control-Allow-Methods": "POST, OPTIONS"
            }
        )
    
    # Extract authorization header
    auth_header = req.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return func.HttpResponse(
            json.dumps({"error": "Missing or invalid authorization header"}),
            status_code=401,
            headers={
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            }
        )
    
    token = auth_header.split(" ")[1]
    
    try:
        # Validate token
        token_data = await auth_validator.validate_token(token)
        user_id = token_data.get("sub")
        
        # Get session
        session_id = req.headers.get("X-Session-Id")
        if not session_id:
            return func.HttpResponse(
                json.dumps({"error": "Missing session ID"}),
                status_code=400,
                headers={
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                }
            )
        
        session = mcp_server.get_session(session_id)
        if not session or session.user_id != user_id:
            return func.HttpResponse(
                json.dumps({"error": "Invalid session"}),
                status_code=401,
                headers={
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                }
            )
        
        # Parse request body
        try:
            request_data = req.get_json()
            mcp_request = MCPRequest(**request_data)
        except Exception as e:
            return func.HttpResponse(
                json.dumps({
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {
                        "code": -32700,
                        "message": "Parse error",
                        "data": str(e)
                    }
                }),
                status_code=400,
                headers={
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                }
            )
        
        # Log request
        logger.info(f"MCP request: method={mcp_request.method}, user={user_id}")
        
        # Handle request
        response = await mcp_server.handle_request(mcp_request, session)
        
        # Send response via SSE if needed
        if response.result and "async" in response.result:
            # Queue response for SSE delivery
            await session.send_message(response)
            
            # Return acknowledgment
            return func.HttpResponse(
                json.dumps({
                    "jsonrpc": "2.0",
                    "id": mcp_request.id,
                    "result": {"status": "accepted"}
                }),
                status_code=202,
                headers={
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                }
            )
        else:
            # Return direct response
            return func.HttpResponse(
                json.dumps(response.model_dump(exclude_none=True)),
                status_code=200 if response.error is None else 400,
                headers={
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                }
            )
        
    except ValueError as e:
        logger.error(f"Authentication error: {str(e)}")
        return func.HttpResponse(
            json.dumps({
                "jsonrpc": "2.0",
                "id": None,
                "error": {
                    "code": -32000,
                    "message": "Authentication error",
                    "data": str(e)
                }
            }),
            status_code=401,
            headers={
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            }
        )
    except Exception as e:
        logger.error(f"Command endpoint error: {str(e)}", exc_info=True)
        return func.HttpResponse(
            json.dumps({
                "jsonrpc": "2.0",
                "id": None,
                "error": {
                    "code": -32603,
                    "message": "Internal error",
                    "data": str(e)
                }
            }),
            status_code=500,
            headers={
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            }
        )