# Azure AD Application Configuration
# This file manages the Azure AD app registration for OAuth2 authentication

# NOTE: Since we're using an existing Azure AD application (created outside Terraform),
# we'll use a null_resource with local-exec provisioner to configure it properly.
# This approach avoids conflicts with existing app management while ensuring proper configuration.

# Data source to get existing Azure AD application
data "azuread_application" "mcp_server" {
  application_id = var.azure_ad_client_id
}

# Local values for redirect URIs and configuration
locals {
  spa_redirect_uris = [
    "http://localhost:5500",
    "http://localhost:5500/test_client.html",
    "http://127.0.0.1:5500/test_client.html",
    "http://localhost:5500/tests/test_client.html",
    "http://127.0.0.1:5500/tests/test_client.html",
    "http://localhost:5500/azure-mcp-server/tests/test_client.html",
    "http://127.0.0.1:5500/azure-mcp-server/tests/test_client.html",
    "http://localhost:3000",
    "http://localhost:8000",
    "http://localhost:8080"
  ]
}

# Configure the existing Azure AD application using Azure CLI
resource "null_resource" "configure_azure_ad_app" {
  # Trigger reconfiguration when any of these values change
  triggers = {
    client_id      = var.azure_ad_client_id
    redirect_uris  = jsonencode(local.spa_redirect_uris)
    api_scope      = "api://${var.azure_ad_client_id}"
  }

  # Configure SPA redirect URIs
  provisioner "local-exec" {
    command = <<-EOT
      echo "Configuring Azure AD application..."
      
      # Get the application object ID
      APP_OBJECT_ID=$(az ad app show --id ${var.azure_ad_client_id} --query id -o tsv)
      
      # Update SPA redirect URIs using Microsoft Graph API
      az rest --method PATCH --uri "https://graph.microsoft.com/v1.0/applications/$APP_OBJECT_ID" \
        --headers "Content-Type=application/json" \
        --body '${jsonencode({
          spa = {
            redirectUris = local.spa_redirect_uris
          }
        })}'
      
      echo "Azure AD application configured successfully."
    EOT
  }
}

# Output the application details
output "azure_ad_app_id" {
  value       = data.azuread_application.mcp_server.client_id
  description = "The Application (client) ID"
}

output "azure_ad_identifier_uris" {
  value       = data.azuread_application.mcp_server.identifier_uris
  description = "The Application ID URIs for API access"
}

output "azure_ad_spa_redirect_uris" {
  value       = local.spa_redirect_uris
  description = "List of configured SPA redirect URIs"
}

output "oauth2_test_instructions" {
  value = <<-EOT
    OAuth2 Authentication Test Instructions:
    ========================================
    
    1. Start a local HTTP server:
       cd ${path.module}/../../tests
       python3 -m http.server 5500
    
    2. Open your browser to one of these URLs:
       - http://localhost:5500/test_client.html
       - http://127.0.0.1:5500/test_client.html
    
    3. Configure the test client with:
       - API Base URL: ${var.base_name}-apim-${var.environment}-*.azure-api.net
       - Tenant ID: ${var.azure_ad_tenant_id}
       - Client ID: ${var.azure_ad_client_id}
    
    4. Click "Login with Azure AD" to test the OAuth2 flow
    
    The test client uses standard OAuth2 scopes (openid, profile, email, offline_access)
    to avoid self-referencing token errors.
  EOT
  description = "Instructions for testing OAuth2 authentication"
}