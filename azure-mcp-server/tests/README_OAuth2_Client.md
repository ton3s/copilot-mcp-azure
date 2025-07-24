# OAuth2 Test Client for MCP Azure

This test client implements the OAuth2 authorization code flow with PKCE (Proof Key for Code Exchange) for secure authentication with Azure AD.

## Features

- **OAuth2 Authorization Code Flow with PKCE**: Secure authentication without exposing client secrets
- **Azure AD Integration**: Uses Microsoft Identity Platform v2.0 endpoints
- **Token Management**: Handles access token acquisition and storage
- **User Information Display**: Shows logged-in user details
- **Error Handling**: Comprehensive error messages and user feedback
- **Session Persistence**: Maintains authentication state across page refreshes

## Configuration

1. **API Base URL**: The URL of your Azure API Management instance or backend API
2. **Tenant ID**: Your Azure AD tenant ID (default: c67773cd-1868-485d-bc21-f36acb61ce1a)
3. **Client ID**: Your Azure AD application client ID (default: c1de1621-a378-469d-8e17-b5c2d3b94bee)
4. **Redirect URI**: The URL Azure AD will redirect to after authentication (defaults to current page)

## Azure AD App Registration Requirements

Your Azure AD app registration must have:

1. **Redirect URI**: Add the test client URL as a redirect URI in your app registration
   - Type: Single-page application (SPA)
   - Example: `http://localhost:8000/test_client.html`

2. **API Permissions**: 
   - `api://{client-id}/.default` - Your API's scope
   - `openid` - For OpenID Connect authentication
   - `profile` - To retrieve user profile information

3. **Authentication Settings**:
   - Platform: Single-page application
   - Allow public client flows: Yes (for PKCE support)

## How It Works

1. **Login Process**:
   - User clicks "Login with Azure AD"
   - Client generates PKCE code verifier and challenge
   - User is redirected to Azure AD login page
   - After successful authentication, Azure AD redirects back with an authorization code

2. **Token Exchange**:
   - Client exchanges the authorization code for access tokens
   - Uses PKCE code verifier to prove the exchange is legitimate
   - Stores access token in session storage

3. **API Calls**:
   - All API calls include the access token in the Authorization header
   - Token is automatically included in SSE connections

4. **Session Management**:
   - Tokens are stored in session storage (cleared when browser tab closes)
   - Configuration is stored in local storage (persists across sessions)

## Security Features

- **PKCE**: Protects against authorization code interception attacks
- **State Parameter**: Prevents CSRF attacks
- **No Client Secret**: Client secret is never exposed in the browser
- **Session Storage**: Tokens are not persisted beyond the browser session

## Usage

1. Open `test_client.html` in a web browser
2. Configure the API URL and verify tenant/client IDs
3. Click "Login with Azure AD"
4. Complete the Azure AD authentication
5. Use the test buttons to interact with the MCP API

## Troubleshooting

- **Invalid Redirect URI**: Ensure the redirect URI is registered in your Azure AD app
- **Token Exchange Failed**: Check that your app registration allows public client flows
- **CORS Errors**: Ensure your API allows requests from the test client origin
- **Authentication Errors**: Verify tenant ID and client ID are correct