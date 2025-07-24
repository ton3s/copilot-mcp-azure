import asyncio
import json
import os
import pytest
import aiohttp
from typing import AsyncGenerator
import jwt
from datetime import datetime, timedelta

# Test configuration
API_BASE_URL = os.environ.get("API_BASE_URL", "https://your-apim.azure-api.net")
CLIENT_ID = os.environ.get("CLIENT_ID", "your-client-id")
TENANT_ID = os.environ.get("TENANT_ID", "your-tenant-id")
CLIENT_SECRET = os.environ.get("CLIENT_SECRET", "your-client-secret")

class MCPTestClient:
    def __init__(self):
        self.session = None
        self.token = None
        self.session_id = None
        self.sse_task = None
        
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        await self.authenticate()
        return self
        
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.sse_task:
            self.sse_task.cancel()
        await self.session.close()
        
    async def authenticate(self):
        """Get OAuth2 token from Azure AD"""
        token_url = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"
        
        data = {
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "scope": f"api://{CLIENT_ID}/.default",
            "grant_type": "client_credentials"
        }
        
        async with self.session.post(token_url, data=data) as resp:
            token_data = await resp.json()
            self.token = token_data["access_token"]
            
    def get_headers(self):
        """Get headers with authentication"""
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }
        if self.session_id:
            headers["X-Session-Id"] = self.session_id
        return headers
        
    async def connect_sse(self) -> AsyncGenerator[dict, None]:
        """Connect to SSE stream"""
        url = f"{API_BASE_URL}/mcp/stream"
        
        async with self.session.get(url, headers=self.get_headers()) as resp:
            async for line in resp.content:
                line = line.decode('utf-8').strip()
                if line.startswith('data:'):
                    data = json.loads(line[5:])
                    yield data
                elif line.startswith('event:'):
                    event_type = line[6:].strip()
                    # Handle event type if needed
                    
    async def send_command(self, method: str, params: dict = None) -> dict:
        """Send MCP command"""
        url = f"{API_BASE_URL}/mcp/command"
        
        request_data = {
            "jsonrpc": "2.0",
            "id": f"test-{datetime.utcnow().timestamp()}",
            "method": method,
            "params": params or {}
        }
        
        async with self.session.post(url, json=request_data, headers=self.get_headers()) as resp:
            return await resp.json()

@pytest.mark.asyncio
async def test_mcp_connection():
    """Test basic MCP connection and initialization"""
    async with MCPTestClient() as client:
        # Initialize session
        response = await client.send_command("initialize", {
            "clientInfo": {
                "name": "Test Client",
                "version": "1.0.0"
            },
            "capabilities": {
                "tools": True,
                "resources": True
            }
        })
        
        assert response.get("result") is not None
        assert response["result"]["protocolVersion"] == "1.0"
        assert response["result"]["capabilities"]["tools"] is True
        
        # Connect to SSE stream
        sse_connected = False
        async for event in client.connect_sse():
            if "session_id" in event:
                client.session_id = event["session_id"]
                sse_connected = True
                break
                
        assert sse_connected
        assert client.session_id is not None

@pytest.mark.asyncio
async def test_list_tools():
    """Test listing available tools"""
    async with MCPTestClient() as client:
        # Initialize first
        await client.send_command("initialize", {
            "clientInfo": {"name": "Test Client", "version": "1.0.0"}
        })
        
        # List tools
        response = await client.send_command("tools/list")
        
        assert response.get("result") is not None
        assert "tools" in response["result"]
        assert len(response["result"]["tools"]) > 0
        
        # Verify tool structure
        tool = response["result"]["tools"][0]
        assert "name" in tool
        assert "description" in tool
        assert "inputSchema" in tool

@pytest.mark.asyncio
async def test_analyze_code():
    """Test code analysis tool"""
    async with MCPTestClient() as client:
        # Initialize
        await client.send_command("initialize", {
            "clientInfo": {"name": "Test Client", "version": "1.0.0"}
        })
        
        # Call analyze_code tool
        test_code = """
def calculate_sum(numbers):
    total = 0
    for num in numbers:
        total += num
    return total
"""
        
        response = await client.send_command("tools/call", {
            "name": "analyze_code",
            "arguments": {
                "code": test_code,
                "language": "python",
                "analysis_type": "all"
            }
        })
        
        assert response.get("result") is not None
        assert "toolResult" in response["result"]
        
        result = response["result"]["toolResult"]
        assert result["language"] == "python"
        assert "metrics" in result
        assert result["metrics"]["lines"] == 6

@pytest.mark.asyncio
async def test_generate_code():
    """Test code generation tool"""
    async with MCPTestClient() as client:
        # Initialize
        await client.send_command("initialize", {
            "clientInfo": {"name": "Test Client", "version": "1.0.0"}
        })
        
        # Generate code
        response = await client.send_command("tools/call", {
            "name": "generate_code",
            "arguments": {
                "description": "Function to validate email addresses",
                "language": "python"
            }
        })
        
        assert response.get("result") is not None
        result = response["result"]["toolResult"]
        assert "code" in result
        assert result["language"] == "python"
        assert "def" in result["code"]  # Should contain a function

@pytest.mark.asyncio
async def test_list_resources():
    """Test listing resources"""
    async with MCPTestClient() as client:
        # Initialize
        await client.send_command("initialize", {
            "clientInfo": {"name": "Test Client", "version": "1.0.0"}
        })
        
        # List resources
        response = await client.send_command("resources/list")
        
        assert response.get("result") is not None
        assert "resources" in response["result"]
        assert len(response["result"]["resources"]) > 0
        
        # Verify resource structure
        resource = response["result"]["resources"][0]
        assert "uri" in resource
        assert "name" in resource
        assert "type" in resource

@pytest.mark.asyncio
async def test_error_handling():
    """Test error handling"""
    async with MCPTestClient() as client:
        # Try calling non-existent method
        response = await client.send_command("invalid/method")
        
        assert response.get("error") is not None
        assert response["error"]["code"] == -32601
        assert "not found" in response["error"]["message"].lower()

@pytest.mark.asyncio
async def test_concurrent_requests():
    """Test handling concurrent requests"""
    async with MCPTestClient() as client:
        # Initialize
        await client.send_command("initialize", {
            "clientInfo": {"name": "Test Client", "version": "1.0.0"}
        })
        
        # Send multiple concurrent requests
        tasks = []
        for i in range(5):
            task = client.send_command("tools/list")
            tasks.append(task)
            
        responses = await asyncio.gather(*tasks)
        
        # All should succeed
        for response in responses:
            assert response.get("result") is not None
            assert "tools" in response["result"]

@pytest.mark.asyncio
async def test_session_persistence():
    """Test session persistence across requests"""
    async with MCPTestClient() as client:
        # Initialize and get session
        await client.send_command("initialize", {
            "clientInfo": {"name": "Test Client", "version": "1.0.0"}
        })
        
        # Connect to SSE to get session ID
        async for event in client.connect_sse():
            if "session_id" in event:
                client.session_id = event["session_id"]
                break
        
        # Make multiple requests with same session
        response1 = await client.send_command("tools/list")
        response2 = await client.send_command("resources/list")
        
        assert response1.get("result") is not None
        assert response2.get("result") is not None

if __name__ == "__main__":
    # Run specific test
    asyncio.run(test_mcp_connection())