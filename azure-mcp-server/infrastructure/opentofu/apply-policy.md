# Apply CORS Policy to API Management

To fix the CORS error, you need to apply the policy manually in the Azure Portal:

## Quick Steps:

1. **Open Azure Portal**: https://portal.azure.com

2. **Navigate to your API Management instance**:
   - Resource Group: `mcp0724-rg-dev`
   - API Management: `mcp0724-apim-dev-z0lvf7cp`

3. **Go to APIs**:
   - Click on "APIs" in the left menu
   - Select "MCP Server API"

4. **Apply the Policy**:
   - Click on "All operations"
   - Click on the "</>" (Code editor) icon in the Inbound processing section
   - Delete all existing content
   - Copy and paste the entire content from one of these files:
     - **For testing only (no auth)**: `policies/cors-only-policy.xml`
     - **For production (with JWT validation)**: `policies/simple-jwt-policy-filled.xml`
   - Click "Save"

## Testing:

After applying the policy, test again:
1. Refresh your test client page
2. Try logging in again
3. The CORS error should be resolved

## Note:

If you use the CORS-only policy for testing, remember to switch to the JWT validation policy for production use to ensure proper authentication.