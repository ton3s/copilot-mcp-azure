# Configure Azure AD App Registration

Follow these steps to properly configure your Azure AD App Registration for the MCP Server.

## 1. Expose an API

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to: Azure Active Directory → App registrations
3. Find your app (Client ID: `c1de1621-a378-469d-8e17-b5c2d3b94bee`)
4. Click on "Expose an API" in the left menu
5. Click "Set" next to Application ID URI
6. Accept the default `api://c1de1621-a378-469d-8e17-b5c2d3b94bee` or set a custom one
7. Click "Save"

## 2. Add a Scope

1. Still in "Expose an API", click "+ Add a scope"
2. Create a scope with these details:
   - **Scope name**: `access_as_user`
   - **Who can consent**: Admins and users
   - **Admin consent display name**: Access MCP Server API
   - **Admin consent description**: Allows the app to access MCP Server API on behalf of the signed-in user
   - **User consent display name**: Access MCP Server API
   - **User consent description**: Allows the app to access MCP Server API on your behalf
   - **State**: Enabled
3. Click "Add scope"

## 3. Add Client Application (Optional)

If you want to pre-authorize your client:
1. In "Expose an API", click "+ Add a client application"
2. Enter your app's Client ID: `c1de1621-a378-469d-8e17-b5c2d3b94bee`
3. Check the scope you created
4. Click "Add application"

## 4. Configure Authentication

1. Go to "Authentication" in the left menu
2. Under "Platform configurations", click "+ Add a platform"
3. Select "Single-page application"
4. Add these Redirect URIs:
   - `http://localhost:5500/test_client.html`
   - `http://127.0.0.1:5500/test_client.html`
   - `http://localhost:5500/tests/test_client.html`
   - `http://127.0.0.1:5500/tests/test_client.html`
   - `http://localhost:3000` (if using different ports)
5. Under "Implicit grant and hybrid flows":
   - ✅ Check "Access tokens"
   - ✅ Check "ID tokens"
6. Click "Configure"

## 5. Configure API Permissions

1. Go to "API permissions" in the left menu
2. Click "+ Add a permission"
3. Select "My APIs" tab
4. Select your app (MCP Server API)
5. Select "Delegated permissions"
6. Check `access_as_user` (or the scope you created)
7. Click "Add permissions"
8. Click "Grant admin consent for [Your Tenant]" (if you're an admin)

## 6. Update Your Configuration

After setting up the API, update your OpenTofu variables if the Application ID URI changed:

```bash
cd /Users/tones/Desktop/ai-agents/work/copilot-mcp-azure/azure-mcp-server/infrastructure/opentofu
```

Edit `terraform.tfvars` if needed to match your Application ID URI.

## 7. Test the Configuration

1. Open the test client
2. The scope should now be: `api://c1de1621-a378-469d-8e17-b5c2d3b94bee/access_as_user`
3. Or use `.default` scope: `api://c1de1621-a378-469d-8e17-b5c2d3b94bee/.default`

## Common Issues

### Wrong Tenant
If you see "wrong tenant" errors:
- Make sure you're logged into the correct Azure AD tenant
- Check that the tenant ID in your configuration matches your Azure AD tenant
- Verify the app registration exists in the correct tenant

### Resource Not Found
If the API resource is not found:
- Ensure you've completed step 1 (Expose an API)
- The Application ID URI must be set
- Wait a few minutes for Azure AD to propagate changes

### Permission Errors
If you get permission errors:
- Grant admin consent for the permissions
- Ensure the user has access to the application
- Check that the scope is correctly defined