from typing import Dict, Any, List, Optional, Union
from pydantic import BaseModel, Field
from enum import Enum
import json
import asyncio
from datetime import datetime

class MCPMessageType(str, Enum):
    REQUEST = "request"
    RESPONSE = "response"
    NOTIFICATION = "notification"
    ERROR = "error"

class MCPMethod(str, Enum):
    # Session
    INITIALIZE = "initialize"
    INITIALIZED = "initialized"
    SHUTDOWN = "shutdown"
    
    # Resources
    LIST_RESOURCES = "resources/list"
    READ_RESOURCE = "resources/read"
    
    # Tools
    LIST_TOOLS = "tools/list"
    CALL_TOOL = "tools/call"
    
    # Prompts
    LIST_PROMPTS = "prompts/list"
    GET_PROMPT = "prompts/get"
    
    # Sampling
    CREATE_MESSAGE = "sampling/createMessage"

class MCPError(BaseModel):
    code: int
    message: str
    data: Optional[Dict[str, Any]] = None

class MCPMessage(BaseModel):
    jsonrpc: str = "2.0"
    id: Optional[Union[str, int]] = None
    
class MCPRequest(MCPMessage):
    method: str
    params: Optional[Dict[str, Any]] = None
    
class MCPResponse(MCPMessage):
    result: Optional[Any] = None
    error: Optional[MCPError] = None
    
class MCPNotification(MCPMessage):
    method: str
    params: Optional[Dict[str, Any]] = None

class ResourceType(str, Enum):
    TEXT = "text"
    IMAGE = "image"
    CODE = "code"
    DATA = "data"

class Resource(BaseModel):
    uri: str
    name: str
    description: Optional[str] = None
    mimeType: Optional[str] = None
    type: ResourceType = ResourceType.TEXT

class Tool(BaseModel):
    name: str
    description: str
    inputSchema: Dict[str, Any]

class Prompt(BaseModel):
    name: str
    description: str
    arguments: List[Dict[str, Any]] = []

class MCPSession:
    def __init__(self, session_id: str, user_id: str):
        self.session_id = session_id
        self.user_id = user_id
        self.created_at = datetime.utcnow()
        self.last_activity = datetime.utcnow()
        self.client_info: Optional[Dict[str, Any]] = None
        self.capabilities: Dict[str, Any] = {}
        self.active = True
        self._message_queue: asyncio.Queue = asyncio.Queue()
        
    def update_activity(self):
        self.last_activity = datetime.utcnow()
        
    async def send_message(self, message: Union[MCPResponse, MCPNotification]):
        """Queue message for SSE delivery"""
        await self._message_queue.put(message.model_dump())
        
    async def get_message(self) -> Optional[Dict[str, Any]]:
        """Get next message from queue"""
        try:
            return await asyncio.wait_for(self._message_queue.get(), timeout=30)
        except asyncio.TimeoutError:
            return None

class MCPServer:
    def __init__(self):
        self.resources: List[Resource] = []
        self.tools: List[Tool] = []
        self.prompts: List[Prompt] = []
        self.sessions: Dict[str, MCPSession] = {}
        self._initialize_default_capabilities()
        
    def _initialize_default_capabilities(self):
        """Initialize default MCP server capabilities"""
        # Code analysis tool
        self.tools.append(Tool(
            name="analyze_code",
            description="Analyze code for patterns, issues, and improvements",
            inputSchema={
                "type": "object",
                "properties": {
                    "code": {"type": "string", "description": "Code to analyze"},
                    "language": {"type": "string", "description": "Programming language"},
                    "analysis_type": {
                        "type": "string",
                        "enum": ["security", "performance", "quality", "all"],
                        "description": "Type of analysis to perform"
                    }
                },
                "required": ["code", "language"]
            }
        ))
        
        # Code generation tool
        self.tools.append(Tool(
            name="generate_code",
            description="Generate code based on specifications",
            inputSchema={
                "type": "object",
                "properties": {
                    "description": {"type": "string", "description": "Description of code to generate"},
                    "language": {"type": "string", "description": "Target programming language"},
                    "framework": {"type": "string", "description": "Framework to use (optional)"}
                },
                "required": ["description", "language"]
            }
        ))
        
        # Documentation resource
        self.resources.append(Resource(
            uri="resource://docs/api",
            name="API Documentation",
            description="Complete API documentation for the MCP server",
            type=ResourceType.TEXT
        ))
        
    def create_session(self, session_id: str, user_id: str) -> MCPSession:
        """Create new MCP session"""
        session = MCPSession(session_id, user_id)
        self.sessions[session_id] = session
        return session
        
    def get_session(self, session_id: str) -> Optional[MCPSession]:
        """Get existing session"""
        return self.sessions.get(session_id)
        
    def remove_session(self, session_id: str):
        """Remove session"""
        if session_id in self.sessions:
            self.sessions[session_id].active = False
            del self.sessions[session_id]
            
    async def handle_request(self, request: MCPRequest, session: MCPSession) -> MCPResponse:
        """Handle incoming MCP request"""
        session.update_activity()
        
        try:
            if request.method == MCPMethod.INITIALIZE:
                return await self._handle_initialize(request, session)
            elif request.method == MCPMethod.LIST_TOOLS:
                return await self._handle_list_tools(request)
            elif request.method == MCPMethod.CALL_TOOL:
                return await self._handle_call_tool(request, session)
            elif request.method == MCPMethod.LIST_RESOURCES:
                return await self._handle_list_resources(request)
            elif request.method == MCPMethod.READ_RESOURCE:
                return await self._handle_read_resource(request, session)
            else:
                return MCPResponse(
                    id=request.id,
                    error=MCPError(
                        code=-32601,
                        message=f"Method not found: {request.method}"
                    )
                )
        except Exception as e:
            return MCPResponse(
                id=request.id,
                error=MCPError(
                    code=-32603,
                    message=f"Internal error: {str(e)}"
                )
            )
            
    async def _handle_initialize(self, request: MCPRequest, session: MCPSession) -> MCPResponse:
        """Handle initialize request"""
        params = request.params or {}
        session.client_info = params.get("clientInfo", {})
        session.capabilities = params.get("capabilities", {})
        
        return MCPResponse(
            id=request.id,
            result={
                "protocolVersion": "1.0",
                "capabilities": {
                    "tools": True,
                    "resources": True,
                    "prompts": True,
                    "sampling": True
                },
                "serverInfo": {
                    "name": "Azure MCP Server",
                    "version": "1.0.0"
                }
            }
        )
        
    async def _handle_list_tools(self, request: MCPRequest) -> MCPResponse:
        """Handle list tools request"""
        return MCPResponse(
            id=request.id,
            result={
                "tools": [tool.model_dump() for tool in self.tools]
            }
        )
        
    async def _handle_call_tool(self, request: MCPRequest, session: MCPSession) -> MCPResponse:
        """Handle tool call request"""
        params = request.params or {}
        tool_name = params.get("name")
        arguments = params.get("arguments", {})
        
        # Find tool
        tool = next((t for t in self.tools if t.name == tool_name), None)
        if not tool:
            return MCPResponse(
                id=request.id,
                error=MCPError(
                    code=-32602,
                    message=f"Tool not found: {tool_name}"
                )
            )
            
        # Execute tool (simplified - in production, implement actual tool logic)
        if tool_name == "analyze_code":
            result = await self._analyze_code(arguments)
        elif tool_name == "generate_code":
            result = await self._generate_code(arguments)
        else:
            result = {"error": "Tool not implemented"}
            
        return MCPResponse(
            id=request.id,
            result={"toolResult": result}
        )
        
    async def _handle_list_resources(self, request: MCPRequest) -> MCPResponse:
        """Handle list resources request"""
        return MCPResponse(
            id=request.id,
            result={
                "resources": [resource.model_dump() for resource in self.resources]
            }
        )
        
    async def _handle_read_resource(self, request: MCPRequest, session: MCPSession) -> MCPResponse:
        """Handle read resource request"""
        params = request.params or {}
        uri = params.get("uri")
        
        # Find resource
        resource = next((r for r in self.resources if r.uri == uri), None)
        if not resource:
            return MCPResponse(
                id=request.id,
                error=MCPError(
                    code=-32602,
                    message=f"Resource not found: {uri}"
                )
            )
            
        # Read resource content (simplified)
        content = await self._read_resource_content(resource)
        
        return MCPResponse(
            id=request.id,
            result={
                "contents": [{
                    "uri": resource.uri,
                    "mimeType": resource.mimeType or "text/plain",
                    "text": content
                }]
            }
        )
        
    async def _analyze_code(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze code implementation"""
        # Simplified implementation - in production, use actual analysis tools
        code = arguments.get("code", "")
        language = arguments.get("language", "")
        analysis_type = arguments.get("analysis_type", "all")
        
        return {
            "language": language,
            "analysis_type": analysis_type,
            "issues": [],
            "suggestions": ["Code analysis completed successfully"],
            "metrics": {
                "lines": len(code.split("\n")),
                "complexity": "low"
            }
        }
        
    async def _generate_code(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Generate code implementation"""
        # Simplified implementation - in production, use actual generation logic
        description = arguments.get("description", "")
        language = arguments.get("language", "")
        
        return {
            "code": f"# Generated {language} code\n# Description: {description}\n\ndef generated_function():\n    pass",
            "language": language,
            "description": "Code generated successfully"
        }
        
    async def _read_resource_content(self, resource: Resource) -> str:
        """Read resource content"""
        # Simplified implementation - in production, read from actual storage
        if resource.uri == "resource://docs/api":
            return "# API Documentation\n\nThis is the complete API documentation for the MCP server."
        return "Resource content"