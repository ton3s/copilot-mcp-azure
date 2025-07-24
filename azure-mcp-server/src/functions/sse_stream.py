import azure.functions as func
import logging
import json
import asyncio
from typing import AsyncGenerator
import os
from datetime import datetime

from ..shared.auth import AzureADAuthValidator, TokenManager
from ..shared.mcp_protocol import MCPServer, MCPSession, MCPNotification

logger = logging.getLogger(__name__)
auth_validator = AzureADAuthValidator()
token_manager = TokenManager()
mcp_server = MCPServer()

async def generate_sse_events(session: MCPSession) -> AsyncGenerator[str, None]:
    """Generate SSE events for the session"""
    # Send initial connection event
    yield f"event: connected\ndata: {json.dumps({'session_id': session.session_id})}\n\n"
    
    # Send heartbeat every 30 seconds to keep connection alive
    heartbeat_task = asyncio.create_task(send_heartbeats(session))
    
    try:
        while session.active:
            # Get next message from session queue
            message = await session.get_message()
            
            if message:
                yield f"event: message\ndata: {json.dumps(message)}\n\n"
            else:
                # Send heartbeat if no message
                yield f"event: heartbeat\ndata: {json.dumps({'timestamp': datetime.utcnow().isoformat()})}\n\n"
                
    except Exception as e:
        logger.error(f"SSE stream error: {str(e)}")
        yield f"event: error\ndata: {json.dumps({'error': str(e)})}\n\n"
    finally:
        heartbeat_task.cancel()
        session.active = False

async def send_heartbeats(session: MCPSession):
    """Send periodic heartbeats"""
    while session.active:
        await asyncio.sleep(30)
        if session.active:
            await session.send_message(MCPNotification(
                method="heartbeat",
                params={"timestamp": datetime.utcnow().isoformat()}
            ))

async def main(req: func.HttpRequest) -> func.HttpResponse:
    """SSE endpoint for MCP communication"""
    logger.info("SSE stream endpoint called")
    
    # Extract authorization header
    auth_header = req.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return func.HttpResponse(
            json.dumps({"error": "Missing or invalid authorization header"}),
            status_code=401,
            headers={"Content-Type": "application/json"}
        )
    
    token = auth_header.split(" ")[1]
    
    try:
        # Validate token
        token_data = await auth_validator.validate_token(token)
        user_id = token_data.get("sub")
        
        # Create or get session
        session_id = req.headers.get("X-Session-Id")
        
        if session_id:
            session = mcp_server.get_session(session_id)
            if not session or session.user_id != user_id:
                return func.HttpResponse(
                    json.dumps({"error": "Invalid session"}),
                    status_code=401,
                    headers={"Content-Type": "application/json"}
                )
        else:
            # Create new session
            session_id = token_manager.create_session(user_id, token_data)
            session = mcp_server.create_session(session_id, user_id)
        
        # Set up SSE response headers
        headers = {
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Session-Id": session_id,
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Authorization, X-Session-Id, Content-Type",
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS"
        }
        
        # Generate SSE stream
        async def stream_generator():
            async for event in generate_sse_events(session):
                yield event.encode('utf-8')
        
        return func.HttpResponse(
            stream_generator(),
            status_code=200,
            headers=headers
        )
        
    except ValueError as e:
        logger.error(f"Authentication error: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=401,
            headers={"Content-Type": "application/json"}
        )
    except Exception as e:
        logger.error(f"SSE endpoint error: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )