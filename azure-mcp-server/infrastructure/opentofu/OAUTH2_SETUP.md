# OAuth2 Setup and Configuration

This document explains the OAuth2 authentication setup for the MCP Azure Server.

## Overview

The MCP server uses Azure AD OAuth2 authentication with the Authorization Code Flow + PKCE (Proof Key for Code Exchange) for secure authentication without exposing client secrets in the browser.

## Changes Made

### 1. Azure AD Application Configuration (`azure-ad.tf`)

A new Terraform configuration file was created to manage Azure AD app settings:

- **SPA Redirect URIs**: Configured multiple redirect URIs to support different development scenarios
- **Automatic Configuration**: Uses Azure CLI to update the existing Azure AD app during deployment
- **Flexible URIs**: Supports various localhost ports and path combinations

### 2. Test Client Updates (`test_client.html`)

The test client was updated to:
- Use OAuth2 Authorization Code Flow with PKCE
- Use standard OAuth2 scopes (`openid profile email offline_access`) instead of API-specific scopes
- Handle token exchange securely without client secrets
- Store tokens in session storage for security

### 3. API Management Policy (`simple-jwt-policy.xml`)

Created a simplified JWT validation policy that:
- Accepts both client ID and `api://` format as valid audiences
- Validates tokens from Azure AD v2.0 endpoints
- Adds CORS headers for local development
- Includes the Function App key for backend authentication

### 4. Main Terraform Configuration

Updated `main.tf` to:
- Apply the simplified JWT policy to the API
- Remove complex policy configurations that caused deployment issues

## Deployment

To deploy these changes:

```bash
cd /Users/tones/Desktop/ai-agents/work/copilot-mcp-azure/azure-mcp-server/infrastructure/opentofu
tofu init
tofu apply
```

The deployment will:
1. Create/update all Azure resources
2. Configure the Azure AD app with proper redirect URIs
3. Apply the JWT validation policy to API Management (Note: If policy application fails, apply it manually in Azure Portal)

### Manual Policy Application (if needed)

If the automated policy application fails:

1. Go to Azure Portal → API Management → APIs → MCP Server API
2. Click on "All operations" → "Policies" → "Code editor"
3. Replace the content with the policy from `policies/simple-jwt-policy.xml`
4. Replace `${tenant_id}` with your tenant ID: `c67773cd-1868-485d-bc21-f36acb61ce1a`
5. Replace `${client_id}` with your client ID: `c1de1621-a378-469d-8e17-b5c2d3b94bee`
6. Save the policy

## Testing OAuth2 Flow

After deployment:

1. Start a local HTTP server:
   ```bash
   cd /Users/tones/Desktop/ai-agents/work/copilot-mcp-azure/azure-mcp-server/tests
   python3 -m http.server 5500
   ```

2. Open browser to: http://localhost:5500/test_client.html

3. Configure the test client:
   - API Base URL: Get from `tofu output apim_gateway_url`
   - Tenant ID and Client ID are pre-filled

4. Click "Login with Azure AD"

## Redirect URI Patterns

The following redirect URIs are configured to support various development scenarios:

- `http://localhost:5500` - Base URL
- `http://localhost:5500/test_client.html` - Direct file access
- `http://127.0.0.1:5500/test_client.html` - IP-based access
- `http://localhost:5500/tests/test_client.html` - Tests directory
- `http://localhost:5500/azure-mcp-server/tests/test_client.html` - Full path access
- Additional ports: 3000, 8000, 8080

## Troubleshooting

### AADSTS50011: Redirect URI mismatch
- Check the exact URL in your browser
- Ensure it matches one of the configured redirect URIs
- The Azure AD configuration will be updated automatically during deployment

### AADSTS90009: Application requesting token for itself
- This has been fixed by using standard OAuth2 scopes
- The test client no longer requests `api://` scopes directly

### CORS Errors
- The simplified JWT policy includes CORS headers
- Ensure you're using one of the allowed origins (localhost:5500, 127.0.0.1:5500)

## Security Considerations

1. **No Client Secrets**: The implementation uses PKCE, eliminating the need for client secrets in the browser
2. **Session Storage**: Tokens are stored in session storage and cleared when the browser tab closes
3. **JWT Validation**: All API calls are validated against Azure AD
4. **CORS Protection**: Only specific origins are allowed to access the API