# MCP Azure Server Architecture Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Understanding MCP Protocol](#understanding-mcp-protocol)
4. [Server-Sent Events (SSE) Implementation](#server-sent-events-sse-implementation)
5. [Security Architecture](#security-architecture)
6. [Component Deep Dive](#component-deep-dive)
7. [Data Flow](#data-flow)
8. [Deployment Architecture](#deployment-architecture)
9. [Monitoring and Observability](#monitoring-and-observability)
10. [Scalability Considerations](#scalability-considerations)

## Introduction

The MCP (Model Context Protocol) Azure Server is a secure, scalable implementation that enables GitHub Copilot to interact with custom AI tools and resources through Azure's enterprise-grade infrastructure. This architecture leverages Azure Functions for serverless compute, API Management for gateway capabilities, and Azure AD for OAuth2 authentication.

### Key Benefits

- **Enterprise Security**: OAuth2/JWT authentication with Azure AD
- **Real-time Communication**: SSE for efficient streaming
- **Scalability**: Serverless architecture with auto-scaling
- **Monitoring**: Built-in observability with Application Insights
- **Cost-Effective**: Pay-per-use model with consumption-based pricing

## Architecture Overview

```
┌─────────────────────┐
│   GitHub Copilot    │
│    (VS Code)        │
└──────────┬──────────┘
           │ HTTPS + OAuth2
           ▼
┌─────────────────────┐
│  Azure API          │
│  Management         │────────► Azure AD
│  (Gateway)          │         (OAuth2 Provider)
└──────────┬──────────┘
           │ Validated Requests
           ▼
┌─────────────────────┐
│  Azure Functions    │
│  (MCP Server)       │
├─────────────────────┤
│ • SSE Endpoint      │
│ • Command Endpoint  │
└──────────┬──────────┘
           │ Managed Identity
           ▼
┌─────────────────────┐
│  Azure Resources    │
├─────────────────────┤
│ • Key Vault         │
│ • Storage           │
│ • App Insights      │
└─────────────────────┘
```

### Core Components

1. **Client Layer**: GitHub Copilot extension in VS Code
2. **Gateway Layer**: Azure API Management with security policies
3. **Application Layer**: Azure Functions hosting MCP server
4. **Data Layer**: Azure Key Vault, Storage, and monitoring

## Understanding MCP Protocol

### What is MCP?

The Model Context Protocol (MCP) is a standardized protocol for communication between AI assistants (like GitHub Copilot) and external tools/resources. It provides:

- **Tools**: Executable functions (e.g., code analysis, generation)
- **Resources**: Accessible data (e.g., documentation, templates)
- **Prompts**: Reusable prompt templates
- **Sampling**: AI model interaction capabilities

### MCP Message Structure

MCP uses JSON-RPC 2.0 format:

```json
{
  "jsonrpc": "2.0",
  "id": "unique-request-id",
  "method": "tools/call",
  "params": {
    "name": "analyze_code",
    "arguments": {
      "code": "def hello(): pass",
      "language": "python"
    }
  }
}
```

### MCP Lifecycle

1. **Initialization**
   ```
   Client → Server: initialize
   Server → Client: capabilities
   ```

2. **Discovery**
   ```
   Client → Server: tools/list
   Server → Client: available tools
   ```

3. **Execution**
   ```
   Client → Server: tools/call
   Server → Client: tool results
   ```

4. **Termination**
   ```
   Client → Server: shutdown
   Server → Client: acknowledgment
   ```

## Server-Sent Events (SSE) Implementation

### Why SSE for MCP?

SSE provides real-time, unidirectional communication from server to client, perfect for:
- Streaming AI responses
- Progress updates
- Asynchronous notifications
- Low-latency communication

### SSE Architecture

```
┌─────────────┐         ┌─────────────┐
│   Client    │         │   Server    │
│             │ ──GET─> │             │
│  EventSource│         │ SSE Stream  │
│             │ <────── │  Endpoint   │
│             │  Events │             │
└─────────────┘         └─────────────┘
```

### SSE Event Types

1. **Connection Events**
   ```
   event: connected
   data: {"session_id": "abc123"}
   ```

2. **Message Events**
   ```
   event: message
   data: {"jsonrpc": "2.0", "result": {...}}
   ```

3. **Heartbeat Events**
   ```
   event: heartbeat
   data: {"timestamp": "2024-01-01T12:00:00Z"}
   ```

### SSE Implementation Details

```python
# Server-side SSE generator
async def generate_sse_events(session):
    # Send connection confirmation
    yield f"event: connected\ndata: {json.dumps({'session_id': session.id})}\n\n"
    
    # Keep connection alive with heartbeats
    while session.active:
        message = await session.get_message()
        if message:
            yield f"event: message\ndata: {json.dumps(message)}\n\n"
        else:
            # Send heartbeat every 30 seconds
            yield f"event: heartbeat\ndata: {json.dumps({'timestamp': datetime.utcnow().isoformat()})}\n\n"
```

### Client-side SSE Handling

```typescript
const eventSource = new EventSource(sseUrl, {
    headers: {
        'Authorization': `Bearer ${token}`,
        'X-Session-Id': sessionId
    }
});

eventSource.addEventListener('message', (event) => {
    const data = JSON.parse(event.data);
    handleMCPMessage(data);
});

eventSource.addEventListener('heartbeat', (event) => {
    // Keep-alive received
    updateLastHeartbeat();
});
```

## Security Architecture

### OAuth2 Flow

```
┌──────────┐       ┌──────────┐       ┌──────────┐
│  Client  │       │ Azure AD │       │   API    │
└────┬─────┘       └────┬─────┘       └────┬─────┘
     │                  │                   │
     │ 1. Request Token │                   │
     │─────────────────>│                   │
     │                  │                   │
     │ 2. Return Token  │                   │
     │<─────────────────│                   │
     │                  │                   │
     │ 3. API Request + Bearer Token        │
     │─────────────────────────────────────>│
     │                  │                   │
     │                  │ 4. Validate Token │
     │                  │<──────────────────│
     │                  │                   │
     │                  │ 5. Token Valid    │
     │                  │──────────────────>│
     │                  │                   │
     │ 6. API Response  │                   │
     │<─────────────────────────────────────│
```

### Security Layers

1. **Network Security**
   - TLS 1.2+ encryption
   - API Management firewall
   - DDoS protection

2. **Authentication**
   - Azure AD OAuth2
   - JWT token validation
   - Token expiration handling

3. **Authorization**
   - Scope-based permissions
   - Role-based access control
   - Resource-level security

4. **Application Security**
   - Input validation
   - Rate limiting
   - CORS policies
   - Security headers

## Component Deep Dive

### Azure API Management

**Purpose**: Gateway for all API traffic

**Key Features**:
- OAuth2 token validation
- Rate limiting (100 req/min per user)
- Request/response transformation
- CORS handling
- Monitoring and analytics

**Policy Example**:
```xml
<validate-jwt header-name="Authorization">
    <openid-config url="https://login.microsoftonline.com/{tenant}/v2.0/.well-known/openid-configuration" />
    <audiences>
        <audience>api://{client-id}</audience>
    </audiences>
</validate-jwt>
```

### Azure Functions

**Purpose**: Serverless MCP protocol implementation

**Endpoints**:
1. **SSE Stream** (`/api/mcp/stream`)
   - Long-lived connections
   - Event streaming
   - Session management

2. **Command** (`/api/mcp/command`)
   - JSON-RPC processing
   - Tool execution
   - Synchronous responses

**Configuration**:
```python
# Function App Settings
FUNCTIONS_WORKER_RUNTIME = "python"
AZURE_TENANT_ID = "your-tenant-id"
AZURE_CLIENT_ID = "your-client-id"
KEY_VAULT_URL = "https://vault.azure.net"
```

### Azure Key Vault

**Purpose**: Secure secret storage

**Stored Secrets**:
- Session encryption keys
- API keys
- Connection strings
- Certificates

**Access Pattern**:
```python
# Using Managed Identity
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
secret = client.get_secret("session-secret")
```

## Data Flow

### Request Flow

1. **Client Authentication**
   ```
   VS Code → Azure AD → Token
   ```

2. **API Request**
   ```
   VS Code → APIM → Validation → Function App
   ```

3. **MCP Processing**
   ```
   Function App → Parse Request → Execute Tool → Generate Response
   ```

4. **Response Delivery**
   ```
   Function App → APIM → VS Code
   ```

### Session Management

```python
# Session creation
session = MCPSession(
    session_id=generate_id(),
    user_id=token_data["sub"],
    capabilities=client_capabilities
)

# Session state
sessions[session_id] = {
    "user_id": user_id,
    "created_at": datetime.utcnow(),
    "last_activity": datetime.utcnow(),
    "sse_connection": active_connection
}
```

## Deployment Architecture

### Infrastructure Components

```yaml
Resources:
  - Resource Group
    - API Management (Standard/Developer SKU)
    - Function App (Consumption/Premium)
    - Storage Account (Function state)
    - Key Vault (Secrets)
    - Application Insights (Monitoring)
    - Log Analytics Workspace (Logs)
```

### Network Architecture

```
Internet ──> API Management ──> Function App
              │                    │
              └── Public IP        └── Private/Public
                  + Firewall           + Managed Identity
```

### High Availability

- **Multi-region**: Deploy to multiple Azure regions
- **Load balancing**: Use Traffic Manager
- **Auto-scaling**: Function App scales automatically
- **Redundancy**: Geo-redundant storage

## Monitoring and Observability

### Application Insights Integration

```python
# Custom telemetry
from opencensus.ext.azure import metrics_exporter

def track_mcp_event(event_type, properties):
    telemetry_client.track_event(
        "MCPEvent",
        properties={
            "Type": event_type,
            "UserId": session.user_id,
            "SessionId": session.session_id
        },
        measurements={
            "Duration": execution_time
        }
    )
```

### Key Metrics

1. **Performance Metrics**
   - Request latency
   - SSE connection duration
   - Tool execution time

2. **Business Metrics**
   - Active sessions
   - Tool usage frequency
   - Error rates

3. **Security Metrics**
   - Authentication failures
   - Rate limit violations
   - Suspicious activities

### Alerts Configuration

```json
{
  "name": "High Error Rate",
  "condition": "customMetrics/ErrorRate > 5%",
  "window": "5 minutes",
  "severity": "Warning",
  "action": "Email + SMS"
}
```

## Scalability Considerations

### Horizontal Scaling

- **Function App**: Auto-scales based on load
- **API Management**: Scale units can be added
- **Storage**: Automatically scales

### Performance Optimization

1. **Caching**
   ```python
   # In-memory cache for frequently accessed data
   @lru_cache(maxsize=1000)
   def get_tool_definition(tool_name):
       return tool_registry[tool_name]
   ```

2. **Connection Pooling**
   ```python
   # Reuse HTTP connections
   session = aiohttp.ClientSession(
       connector=aiohttp.TCPConnector(limit=100)
   )
   ```

3. **Async Processing**
   ```python
   # Parallel tool execution
   results = await asyncio.gather(*[
       execute_tool(tool) for tool in tools
   ])
   ```

### Load Testing

```bash
# Example load test with K6
k6 run --vus 100 --duration 30s load-test.js
```

### Capacity Planning

| Component | Metric | Recommended |
|-----------|--------|-------------|
| Function App | Concurrent Executions | 200 (Consumption) |
| API Management | Requests/sec | 1000 (Standard) |
| SSE Connections | Concurrent | 5000 per instance |

---

This architecture provides a robust, secure, and scalable foundation for MCP protocol implementation with Azure services. The combination of serverless computing, managed services, and enterprise security features makes it suitable for production deployments at any scale.