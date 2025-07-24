# OAuth2 Test Instructions

The Azure AD app has been successfully configured with the following:

1. **Application ID**: `c1de1621-a378-469d-8e17-b5c2d3b94bee`
2. **API Identifier URI**: `api://c1de1621-a378-469d-8e17-b5c2d3b94bee`
3. **SPA Redirect URIs**:
   - http://localhost:5500
   - http://localhost:5500/test_client.html
   - http://127.0.0.1:5500/test_client.html
   - http://localhost:5500/tests/test_client.html
   - http://127.0.0.1:5500/tests/test_client.html

## To Test the OAuth2 Flow:

1. Start a local HTTP server:
   ```bash
   cd /Users/tones/Desktop/ai-agents/work/copilot-mcp-azure/azure-mcp-server/tests
   python3 -m http.server 5500
   ```

2. Open your browser to: http://localhost:5500/test_client.html

3. Configure the test client:
   - **API Base URL**: `https://mcp0724-apim-dev-z0lvf7cp.azure-api.net`
   - **Tenant ID**: `c67773cd-1868-485d-bc21-f36acb61ce1a` (already filled)
   - **Client ID**: `c1de1621-a378-469d-8e17-b5c2d3b94bee` (already filled)

4. Click "Login with Azure AD"

5. The OAuth2 flow should now work without the AADSTS90009 error

## What Changed:

- Updated the test client to use standard OAuth2 scopes (`openid profile email offline_access`) instead of the API scope
- Configured all necessary SPA redirect URIs in Azure AD
- The access token will still work with your API when the JWT policy is properly configured

## If You Still Get Errors:

1. Make sure the APIM deployment is complete
2. Check that the JWT policy is applied to the API
3. Verify the APIM URL is correct in the test client