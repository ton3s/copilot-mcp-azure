# Complete Setup Guide for MCP Azure Server

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Azure Setup](#azure-setup)
3. [Azure AD Configuration](#azure-ad-configuration)
4. [Infrastructure Deployment](#infrastructure-deployment)
5. [Function App Deployment](#function-app-deployment)
6. [Testing the Deployment](#testing-the-deployment)
7. [VS Code Extension Setup](#vs-code-extension-setup)
8. [Troubleshooting](#troubleshooting)
9. [Production Considerations](#production-considerations)

## Prerequisites

### Required Tools

1. **Azure CLI** (v2.50.0 or later)
   ```bash
   # macOS
   brew install azure-cli
   
   # Windows
   winget install Microsoft.AzureCLI
   
   # Linux
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

2. **OpenTofu** (v1.5.0 or later)
   ```bash
   # macOS
   brew install opentofu
   
   # Windows
   choco install opentofu
   
   # Linux
   # Install via snap
   snap install --classic opentofu
   
   # Or via installer script
   curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh | sh
   ```

3. **Python** (3.11 or later)
   ```bash
   # Verify Python version
   python3 --version
   
   # Install pip if needed
   python3 -m ensurepip --upgrade
   ```

4. **Node.js** (18 or later) - for VS Code extension
   ```bash
   # Using nvm
   nvm install 18
   nvm use 18
   ```

5. **VS Code** with GitHub Copilot
   - Install from: https://code.visualstudio.com/
   - Install GitHub Copilot extension

### Azure Requirements

- Active Azure subscription
- Permissions to create:
  - Resource Groups
  - Azure AD App Registrations
  - API Management instances
  - Function Apps
  - Key Vaults

## Azure Setup

### 1. Login to Azure

```bash
# Login to Azure
az login

# Verify subscription
az account show

# Set subscription if multiple
az account set --subscription "Your Subscription Name"
```

### 2. Create Service Principal (Optional - for CI/CD)

```bash
# Create service principal
az ad sp create-for-rbac --name "mcp-server-sp" --role Contributor \
  --scopes /subscriptions/{subscription-id}

# Save the output - you'll need:
# - appId (client ID)
# - password (client secret)
# - tenant (tenant ID)
```

## Azure AD Configuration

### 1. Create App Registration

```bash
# Create app registration
APP_NAME="MCP-Server-App"
APP_ID=$(az ad app create --display-name $APP_NAME --query appId -o tsv)

echo "App ID: $APP_ID"
```

### 2. Configure App Registration

#### Via Azure Portal:

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to Azure Active Directory → App registrations
3. Find your app "MCP-Server-App"
4. Configure the following:

**Authentication:**
- Platform: Single-page application
- Redirect URIs:
  ```
  https://localhost
  vscode://vscode.github-authentication/did-authenticate
  ```

**API Permissions:**
- Microsoft Graph → User.Read (Delegated)
- Add any custom permissions needed

**Expose an API:**
1. Set Application ID URI: `api://{APP_ID}`
2. Add a scope:
   - Scope name: `access_as_user`
   - Who can consent: Admins and users
   - Admin consent display name: Access MCP Server
   - Admin consent description: Allow access to MCP Server APIs

**Certificates & secrets:**
- Create a new client secret (save it securely)
- Note: Only needed for testing, not for production

### 3. Grant Admin Consent

```bash
# Grant admin consent
az ad app permission admin-consent --id $APP_ID
```

## Infrastructure Deployment

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/copilot-mcp-azure.git
cd copilot-mcp-azure/azure-mcp-server
```

### 2. Deploy with OpenTofu

```bash
cd infrastructure/opentofu

# Run the automated deployment script
./deploy.sh
```

The script will prompt for:
- Azure AD Client ID (from previous step)
- GitHub Organization (optional)
- APIM publisher email
- Organization name

#### Manual OpenTofu Deployment (Alternative)

```bash
# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
vim terraform.tfvars
```

Example `terraform.tfvars`:
```hcl
base_name   = "mcp-server"
environment = "dev"
location    = "eastus"

azure_ad_tenant_id = "12345678-1234-1234-1234-123456789012"
azure_ad_client_id = "87654321-4321-4321-4321-210987654321"

github_organization = "your-github-org"

apim_publisher_name  = "Your Company"
apim_publisher_email = "admin@company.com"

tags = {
  Project     = "MCP-Server"
  Environment = "dev"
  Owner       = "Engineering Team"
}
```

Deploy:
```bash
# Initialize OpenTofu
tofu init

# Review plan
tofu plan

# Apply configuration
tofu apply
```

### 3. Save Deployment Outputs

```bash
# Save outputs to file
tofu output -json > deployment-outputs.json

# View key outputs
tofu output -raw apim_gateway_url
tofu output -raw function_app_name
```

## Function App Deployment

### 1. Prepare Function App Code

```bash
cd ../../src

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r ../requirements.txt
```

### 2. Configure Local Settings (for testing)

Create `local.settings.json`:
```json
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "AZURE_TENANT_ID": "your-tenant-id",
    "AZURE_CLIENT_ID": "your-client-id",
    "KEY_VAULT_URL": "https://your-keyvault.vault.azure.net/",
    "SESSION_SECRET": "local-dev-secret"
  }
}
```

### 3. Deploy to Azure

```bash
# Get deployment parameters
FUNCTION_APP_NAME=$(cd ../infrastructure/opentofu && tofu output -raw function_app_name)
RESOURCE_GROUP=$(cd ../infrastructure/opentofu && tofu output -raw resource_group_name)

# Create deployment package
zip -r ../function-app.zip . -x "venv/*" "__pycache__/*" "*.pyc" "local.settings.json" ".env"

# Deploy to Azure
az functionapp deployment source config-zip \
  --resource-group $RESOURCE_GROUP \
  --name $FUNCTION_APP_NAME \
  --src ../function-app.zip

# Verify deployment
az functionapp show --resource-group $RESOURCE_GROUP --name $FUNCTION_APP_NAME --query state -o tsv
```

### 4. Configure Function App Settings

```bash
# Update Function App settings if needed
az functionapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $FUNCTION_APP_NAME \
  --settings "NEW_SETTING=value"
```

## Testing the Deployment

### 1. Test with Web Client

1. Open `azure-mcp-server/tests/test_client.html` in a browser
2. Configure with your deployment values:
   - API Base URL: `https://your-apim.azure-api.net`
   - Tenant ID: Your Azure AD tenant ID
   - Client ID: Your app registration client ID
   - Client Secret: (for testing only)

3. Click "Connect" and verify:
   - Authentication succeeds
   - SSE connection establishes
   - Tools list properly

### 2. Test with Python Script

```bash
cd tests

# Set environment variables
export API_BASE_URL="https://your-apim.azure-api.net"
export CLIENT_ID="your-client-id"
export TENANT_ID="your-tenant-id"
export CLIENT_SECRET="your-client-secret"  # For testing only

# Run tests
python -m pytest test_mcp_integration.py -v
```

### 3. Test with cURL

```bash
# Get access token
TOKEN=$(curl -X POST \
  "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=api://$CLIENT_ID/.default" \
  -d "grant_type=client_credentials" \
  | jq -r .access_token)

# Test command endpoint
curl -X POST \
  "$API_BASE_URL/mcp/command" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "X-Session-Id: test-session" \
  -d '{
    "jsonrpc": "2.0",
    "id": "1",
    "method": "tools/list",
    "params": {}
  }'
```

## VS Code Extension Setup

### 1. Install Dependencies

```bash
cd github-copilot-extension
npm install
```

### 2. Configure Extension

Create `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Run Extension",
      "type": "extensionHost",
      "request": "launch",
      "args": [
        "--extensionDevelopmentPath=${workspaceFolder}"
      ]
    }
  ]
}
```

### 3. Build Extension

```bash
# Compile TypeScript
npm run compile

# Package extension
npm install -g vsce
vsce package
```

### 4. Install Extension

1. In VS Code: `Cmd+Shift+P` → "Extensions: Install from VSIX"
2. Select the generated `.vsix` file

### 5. Configure Extension Settings

VS Code settings.json:
```json
{
  "mcp-azure.apiBaseUrl": "https://your-apim.azure-api.net",
  "mcp-azure.clientId": "your-client-id",
  "mcp-azure.tenantId": "your-tenant-id",
  "mcp-azure.autoConnect": true
}
```

### 6. Use the Extension

1. Open Command Palette: `Cmd+Shift+P`
2. Run: "MCP Azure: Connect"
3. Authenticate with Azure AD
4. In Copilot chat: `@mcp analyze this code`

## Troubleshooting

### Common Issues

#### 1. Authentication Failures

**Symptom**: 401 Unauthorized errors

**Solutions**:
- Verify Azure AD app registration configuration
- Check token audience and issuer
- Ensure correct scopes are requested
- Validate redirect URIs match exactly

```bash
# Decode JWT token to inspect
echo $TOKEN | cut -d. -f2 | base64 -d | jq
```

#### 2. SSE Connection Issues

**Symptom**: EventSource connection fails

**Solutions**:
- Check CORS configuration in APIM
- Verify Function App timeout settings
- Ensure proper headers are set
- Check browser console for errors

```javascript
// Debug SSE in browser console
const eventSource = new EventSource(url, {
  withCredentials: true
});
eventSource.onerror = (e) => console.error('SSE Error:', e);
```

#### 3. Function App Not Responding

**Symptom**: 500 errors or timeouts

**Solutions**:
- Check Function App logs:
  ```bash
  az functionapp logs tail --resource-group $RG --name $FUNC_APP
  ```
- Verify app settings are correct
- Check Application Insights for errors
- Ensure Python dependencies are installed

#### 4. APIM Policy Errors

**Symptom**: Requests blocked at gateway

**Solutions**:
- Test policies in APIM test console
- Check policy syntax
- Verify named values are set
- Review APIM diagnostics logs

### Debugging Tools

#### 1. Application Insights Queries

```kusto
// Failed requests
requests
| where success == false
| order by timestamp desc
| take 100

// Authentication failures
customEvents
| where name == "SecurityEvent"
| where customDimensions.Type == "AuthenticationFailed"
| order by timestamp desc
```

#### 2. Function App Streaming Logs

```bash
# Stream live logs
func azure functionapp logstream $FUNCTION_APP_NAME

# Or use Azure CLI
az webapp log tail --resource-group $RG --name $FUNCTION_APP_NAME
```

#### 3. APIM Trace

Enable tracing in APIM test console:
1. Go to APIM in Azure Portal
2. Select API → Test tab
3. Enable "Trace" option
4. Send request and review trace

## Production Considerations

### 1. Security Hardening

- [ ] Remove test client secrets
- [ ] Enable Managed Identity everywhere
- [ ] Configure Private Endpoints
- [ ] Enable Azure DDoS Protection
- [ ] Implement IP restrictions
- [ ] Regular security scans

### 2. High Availability

- [ ] Deploy to multiple regions
- [ ] Configure Traffic Manager
- [ ] Enable geo-replication
- [ ] Set up automated backups
- [ ] Test disaster recovery

### 3. Performance Optimization

- [ ] Enable Function App Always On (Premium)
- [ ] Configure autoscaling rules
- [ ] Implement caching strategy
- [ ] Optimize cold starts
- [ ] Monitor performance metrics

### 4. Monitoring Setup

- [ ] Configure comprehensive alerts
- [ ] Set up dashboards
- [ ] Enable diagnostic logs
- [ ] Configure log retention
- [ ] Set up on-call rotation

### 5. Cost Management

- [ ] Set up cost alerts
- [ ] Review resource sizing
- [ ] Implement auto-shutdown for dev
- [ ] Use reserved instances
- [ ] Regular cost reviews

---

## Next Steps

1. **Customize MCP Tools**: Add your own tools in `mcp_protocol.py`
2. **Enhance Security**: Implement additional authorization checks
3. **Add Features**: Extend the protocol with custom capabilities
4. **Scale Testing**: Perform load testing before production
5. **Documentation**: Keep docs updated with changes

For support, refer to:
- [Azure Documentation](https://docs.microsoft.com/azure)
- [MCP Protocol Spec](https://github.com/anthropics/mcp)
- [GitHub Copilot Docs](https://docs.github.com/copilot)

---

*This guide is maintained by the Engineering Team. Last updated: January 2024*