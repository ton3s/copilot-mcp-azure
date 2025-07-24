import azure.functions as func
import logging
import json
import datetime
import os
import uuid

app = func.FunctionApp()

# In-memory session storage (for demo purposes)
sessions = {}

@app.function_name(name="mcp_command")
@app.route(route="mcp/command", methods=["POST", "OPTIONS"], auth_level=func.AuthLevel.ANONYMOUS)
def mcp_command(req: func.HttpRequest) -> func.HttpResponse:
    """Handle MCP command requests"""
    logging.info('MCP command endpoint called')
    
    # Handle CORS preflight
    if req.method == "OPTIONS":
        return func.HttpResponse(
            "",
            status_code=200,
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Session-Id"
            }
        )
    
    try:
        # Get session ID
        session_id = req.headers.get('X-Session-Id', str(uuid.uuid4()))
        
        # Parse request
        req_body = req.get_json()
        method = req_body.get('method')
        params = req_body.get('params', {})
        request_id = req_body.get('id')
        
        # Handle different methods
        if method == "initialize":
            result = {
                "protocolVersion": "1.0",
                "capabilities": {
                    "tools": True,
                    "resources": False,
                    "prompts": False,
                    "sampling": False
                },
                "serverInfo": {
                    "name": "MCP Azure Server",
                    "version": "1.0.0"
                }
            }
            sessions[session_id] = {"initialized": True, "client": params.get("clientInfo")}
            
        elif method == "tools/list":
            result = {
                "tools": [
                    {
                        "name": "analyze_code",
                        "description": "Analyze code for complexity, issues, and improvements",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "code": {"type": "string", "description": "The code to analyze"},
                                "language": {"type": "string", "description": "Programming language"},
                                "analysis_type": {
                                    "type": "string",
                                    "enum": ["complexity", "security", "performance", "all"],
                                    "default": "all"
                                }
                            },
                            "required": ["code", "language"]
                        }
                    },
                    {
                        "name": "generate_code",
                        "description": "Generate code based on description",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "description": {"type": "string", "description": "What the code should do"},
                                "language": {"type": "string", "description": "Target programming language"},
                                "style": {"type": "string", "description": "Coding style preferences"}
                            },
                            "required": ["description", "language"]
                        }
                    }
                ]
            }
            
        elif method == "tools/call":
            tool_name = params.get("name")
            tool_args = params.get("arguments", {})
            
            if tool_name == "analyze_code":
                # Simple mock analysis
                result = {
                    "analysis": {
                        "complexity": "Medium",
                        "issues": ["Consider adding error handling", "Add type hints"],
                        "score": 7.5,
                        "summary": "Code is functional but could benefit from error handling"
                    }
                }
            elif tool_name == "generate_code":
                # Simple mock generation
                lang = tool_args.get("language", "python")
                if lang == "javascript":
                    code = """function validateCreditCard(number) {
    const digits = number.replace(/\\s/g, '');
    let sum = 0;
    let isEven = false;
    
    for (let i = digits.length - 1; i >= 0; i--) {
        let digit = parseInt(digits[i]);
        if (isEven) {
            digit *= 2;
            if (digit > 9) digit -= 9;
        }
        sum += digit;
        isEven = !isEven;
    }
    
    return sum % 10 === 0;
}"""
                else:
                    code = """def validate_credit_card(number):
    digits = number.replace(' ', '')
    total = 0
    is_even = False
    
    for digit in reversed(digits):
        n = int(digit)
        if is_even:
            n *= 2
            if n > 9:
                n -= 9
        total += n
        is_even = not is_even
    
    return total % 10 == 0"""
                
                result = {
                    "code": code,
                    "language": lang,
                    "explanation": "Luhn algorithm implementation for credit card validation"
                }
            else:
                result = {"error": f"Unknown tool: {tool_name}"}
                
        elif method == "resources/list":
            result = {"resources": []}
            
        else:
            result = {"error": f"Unknown method: {method}"}
        
        # Build response
        response = {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": result
        }
        
        return func.HttpResponse(
            json.dumps(response),
            mimetype="application/json",
            status_code=200,
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Credentials": "true"
            }
        )
        
    except Exception as e:
        logging.error(f"Error processing request: {str(e)}")
        error_response = {
            "jsonrpc": "2.0",
            "id": req_body.get("id") if req_body else None,
            "error": {
                "code": -32603,
                "message": "Internal error",
                "data": str(e)
            }
        }
        return func.HttpResponse(
            json.dumps(error_response),
            mimetype="application/json",
            status_code=500
        )

@app.function_name(name="sse_stream")
@app.route(route="mcp/stream", methods=["GET", "OPTIONS"], auth_level=func.AuthLevel.ANONYMOUS)
def sse_stream(req: func.HttpRequest) -> func.HttpResponse:
    """Handle SSE stream requests"""
    logging.info('SSE stream endpoint called')
    
    # Handle CORS preflight
    if req.method == "OPTIONS":
        return func.HttpResponse(
            "",
            status_code=200,
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Session-Id"
            }
        )
    
    # Return a complete SSE response and close
    # In production, use Azure SignalR or WebSockets for real-time communication
    session_id = req.headers.get('X-Session-Id', str(uuid.uuid4()))
    
    # Send initial connection event and close
    sse_data = f"data: {{\"type\": \"connected\", \"session_id\": \"{session_id}\"}}\n\n"
    sse_data += "data: {\"type\": \"end\", \"reason\": \"SSE not supported in consumption plan\"}\n\n"
    
    return func.HttpResponse(
        sse_data,
        mimetype="text/event-stream",
        status_code=200,
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Credentials": "true"
        }
    )