# Quick Start Guide

Get the MCP Azure Server running in under 15 minutes!

## Prerequisites Checklist

- [ ] Azure subscription
- [ ] Azure CLI installed
- [ ] OpenTofu installed
- [ ] Python 3.11+
- [ ] VS Code with GitHub Copilot

## 1. Clone and Setup (2 minutes)

```bash
# Clone repository
git clone https://github.com/your-org/copilot-mcp-azure.git
cd copilot-mcp-azure

# Login to Azure
az login
```

## 2. Create Azure AD App (3 minutes)

```bash
# Create app registration
APP_NAME="MCP-Server-QuickStart"
APP_ID=$(az ad app create --display-name $APP_NAME --query appId -o tsv)

echo "Your App ID: $APP_ID"
echo "Save this ID - you'll need it next!"

# Create a client secret (for testing only)
SECRET=$(az ad app credential reset --id $APP_ID --query password -o tsv)
echo "Your Client Secret: $SECRET"
echo "Save this secret securely!"
```

## 3. Deploy Infrastructure (5 minutes)

```bash
cd azure-mcp-server/infrastructure/opentofu

# Run automated deployment
./deploy.sh

# When prompted, enter:
# - Azure AD Client ID: (from step 2)
# - GitHub Organization: (press Enter to skip)
# - Your email: your-email@company.com
# - Organization name: Your Company
```

## 4. Deploy Function Code (3 minutes)

When the deployment script asks "Would you like to deploy the Function App code now?", type `yes`.

The script will automatically:
- Package the Python code
- Deploy to Azure Functions
- Configure all settings

## 5. Test Your Deployment (2 minutes)

### Option A: Web Browser Test

1. Open `azure-mcp-server/tests/test_client.html`
2. Get your values from OpenTofu output:
   ```bash
   tofu output apim_gateway_url
   ```
3. Enter in the web client:
   - API Base URL: (from terraform output)
   - Tenant ID: (from your Azure subscription)
   - Client ID: (from step 2)
   - Client Secret: (from step 2)
4. Click "Connect" - you should see "Status: Connected"

### Option B: Quick cURL Test

```bash
# Get your API URL
API_URL=$(tofu output -raw apim_gateway_url)

# Test the health endpoint
curl -X GET "$API_URL/mcp/health"
```

## 6. Configure VS Code Extension (Optional)

If you want to use with VS Code:

1. Open VS Code settings (Cmd+,)
2. Search for "mcp-azure"
3. Configure:
   ```json
   {
     "mcp-azure.apiBaseUrl": "https://your-apim.azure-api.net",
     "mcp-azure.clientId": "your-app-id",
     "mcp-azure.tenantId": "your-tenant-id"
   }
   ```

## Common Issues & Solutions

### "Unauthorized" Error
- Check that your Azure AD app has the correct API permissions
- Verify the client ID and tenant ID are correct

### "Function App not responding"
- Wait 2-3 minutes after deployment for cold start
- Check Function App logs: `az functionapp logs tail -n YOUR_FUNCTION_APP_NAME -g mcp-server-rg-dev`

### "CORS error in browser"
- This is expected for the test client
- The production setup uses proper authentication flow

## What's Next?

1. **Explore the MCP tools**: Check available tools in the web test client
2. **Add custom tools**: Edit `src/shared/mcp_protocol.py`
3. **Monitor usage**: View Application Insights in Azure Portal
4. **Production setup**: See [Production Guide](./PRODUCTION_GUIDE.md)

## Clean Up (When Done)

To remove all resources:

```bash
cd azure-mcp-server/infrastructure/opentofu
tofu destroy
```

---

**Need Help?** 
- Check the [Complete Setup Guide](./COMPLETE_SETUP_GUIDE.md) for detailed instructions
- Review [Architecture Guide](./ARCHITECTURE_GUIDE.md) for system understanding
- See [Troubleshooting](./COMPLETE_SETUP_GUIDE.md#troubleshooting) for common issues

🎉 **Congratulations!** You now have a working MCP server integrated with Azure!