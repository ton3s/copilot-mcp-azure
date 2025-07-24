output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "function_app_name" {
  description = "Name of the Function App"
  value       = azurerm_linux_function_app.main.name
}

output "function_app_url" {
  description = "URL of the Function App"
  value       = "https://${azurerm_linux_function_app.main.default_hostname}"
}

output "function_app_id" {
  description = "Resource ID of the Function App"
  value       = azurerm_linux_function_app.main.id
}

output "function_app_principal_id" {
  description = "Principal ID of the Function App's managed identity"
  value       = azurerm_linux_function_app.main.identity[0].principal_id
}

output "apim_gateway_url" {
  description = "Gateway URL of API Management"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_developer_portal_url" {
  description = "Developer portal URL of API Management"
  value       = azurerm_api_management.main.developer_portal_url
}

output "apim_id" {
  description = "Resource ID of API Management"
  value       = azurerm_api_management.main.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "app_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "mcp_endpoints" {
  description = "MCP API endpoints"
  value = {
    sse_stream = "${azurerm_api_management.main.gateway_url}/mcp/stream"
    command    = "${azurerm_api_management.main.gateway_url}/mcp/command"
  }
}

output "deployment_instructions" {
  description = "Next steps for deployment"
  value = <<-EOT
    Deployment completed successfully!
    
    Next steps:
    1. Configure your Azure AD App Registration redirect URIs
    2. Add required API permissions in Azure AD
    3. Deploy the Function App code using: cd ../.. && ./deploy.sh
    4. Configure GitHub Copilot extension with:
       - API Base URL: ${azurerm_api_management.main.gateway_url}
       - Client ID: ${var.azure_ad_client_id}
       - Tenant ID: ${var.azure_ad_tenant_id}
    5. Test the endpoints:
       - SSE Stream: ${azurerm_api_management.main.gateway_url}/mcp/stream
       - Command: ${azurerm_api_management.main.gateway_url}/mcp/command
  EOT
}