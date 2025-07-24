terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}

# Data sources
data "azurerm_client_config" "current" {}

# Random suffix for unique naming
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.base_name}-rg-${var.environment}"
  location = var.location

  tags = var.tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.base_name}-logs-${var.environment}-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.base_name}-insights-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = var.tags
}

# Storage Account for Function App
resource "azurerm_storage_account" "main" {
  name                     = "${replace(var.base_name, "-", "")}${var.environment}${random_string.unique.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version         = "TLS1_2"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                        = "${var.base_name}-kv-${var.environment}-${random_string.unique.result}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = false
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  sku_name                    = "standard"

  enable_rbac_authorization = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = var.tags
}

# Generate session secret
resource "random_password" "session_secret" {
  length  = 64
  special = true
}

# Store session secret in Key Vault
resource "azurerm_key_vault_secret" "session_secret" {
  name         = "session-secret"
  value        = random_password.session_secret.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_role_assignment.current_user_key_vault
  ]
}

# App Service Plan for Function App
resource "azurerm_service_plan" "main" {
  name                = "${var.base_name}-plan-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.function_app_sku

  tags = var.tags
}

# Function App
resource "azurerm_linux_function_app" "main" {
  name                = "${var.base_name}-func-${var.environment}-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key

  https_only = true

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"               = "python"
    "FUNCTIONS_EXTENSION_VERSION"            = "~4"
    "APPLICATIONINSIGHTS_CONNECTION_STRING"  = azurerm_application_insights.main.connection_string
    "AZURE_TENANT_ID"                       = var.azure_ad_tenant_id
    "AZURE_CLIENT_ID"                       = var.azure_ad_client_id
    "KEY_VAULT_URL"                         = azurerm_key_vault.main.vault_uri
    "SESSION_SECRET"                        = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault.main.vault_uri}secrets/session-secret/)"
    "GITHUB_ORGANIZATION"                   = var.github_organization
    "WEBSITE_RUN_FROM_PACKAGE"              = "1"
    "PYTHON_ENABLE_WORKER_EXTENSIONS"       = "1"
    "PYTHON_ISOLATE_WORKER_DEPENDENCIES"    = "1"
  }

  site_config {
    python_version = "3.11"
    
    application_insights_key               = azurerm_application_insights.main.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.main.connection_string

    cors {
      allowed_origins = [
        "https://github.com",
        "https://copilot.github.com",
        "vscode://*",
        "vscode-insiders://*"
      ]
      support_credentials = true
    }

    application_stack {
      python_version = "3.11"
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"]
    ]
  }
}

# API Management
resource "azurerm_api_management" "main" {
  name                = "${var.base_name}-apim-${var.environment}-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.environment == "prod" ? "Standard_1" : "Developer_1"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# API Management Logger
resource "azurerm_api_management_logger" "app_insights" {
  name                = "applicationinsights"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  application_insights {
    instrumentation_key = azurerm_application_insights.main.instrumentation_key
  }
}

# OAuth2 Authorization Server in APIM
resource "azurerm_api_management_authorization_server" "azure_ad" {
  name                         = "azuread"
  api_management_name          = azurerm_api_management.main.name
  resource_group_name          = azurerm_resource_group.main.name
  display_name                 = "Azure AD"
  client_registration_endpoint = "https://portal.azure.com"
  authorization_endpoint       = "https://login.microsoftonline.com/${var.azure_ad_tenant_id}/oauth2/v2.0/authorize"
  token_endpoint              = "https://login.microsoftonline.com/${var.azure_ad_tenant_id}/oauth2/v2.0/token"
  default_scope               = "api://${var.azure_ad_client_id}/.default"
  client_id                   = var.azure_ad_client_id
  grant_types                 = ["authorizationCode", "clientCredentials"]
  authorization_methods       = ["GET", "POST"]
  bearer_token_sending_methods = ["authorizationHeader"]
}

# API in API Management
resource "azurerm_api_management_api" "mcp" {
  name                = "mcp-api"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "MCP Server API"
  path                = "mcp"
  protocols           = ["https"]
  service_url         = "https://${azurerm_linux_function_app.main.default_hostname}/api"

  subscription_required = false

  import {
    content_format = "openapi"
    content_value  = file("${path.module}/api-spec.yaml")
  }
}

# API Management Named Values
resource "azurerm_api_management_named_value" "function_key" {
  name                = "AzureFunctionKey"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "AzureFunctionKey"
  secret              = true
  value               = data.azurerm_function_app_host_keys.main.default_function_key

  depends_on = [
    azurerm_linux_function_app.main
  ]
}

# Get Function App host keys
data "azurerm_function_app_host_keys" "main" {
  name                = azurerm_linux_function_app.main.name
  resource_group_name = azurerm_resource_group.main.name

  depends_on = [
    azurerm_linux_function_app.main
  ]
}

# Global API Management Policy
resource "azurerm_api_management_policy" "global" {
  api_management_id = azurerm_api_management.main.id
  xml_content       = templatefile("${path.module}/policies/global-policy.xml", {
    tenant_id = var.azure_ad_tenant_id
    client_id = var.azure_ad_client_id
  })
}

# API Policy
resource "azurerm_api_management_api_policy" "mcp" {
  api_name            = azurerm_api_management_api.mcp.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  xml_content        = templatefile("${path.module}/policies/api-policy.xml", {
    function_app_name = azurerm_linux_function_app.main.name
  })
}

# API Operations
resource "azurerm_api_management_api_operation" "stream" {
  operation_id        = "stream"
  api_name            = azurerm_api_management_api.mcp.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "SSE Stream"
  method              = "GET"
  url_template        = "/stream"
  description         = "Server-Sent Events stream for MCP communication"

  response {
    status_code = 200
    description = "SSE stream"
    header {
      name   = "Content-Type"
      type   = "string"
      values = ["text/event-stream"]
    }
  }
}

resource "azurerm_api_management_api_operation" "command" {
  operation_id        = "command"
  api_name            = azurerm_api_management_api.mcp.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "MCP Command"
  method              = "POST"
  url_template        = "/command"
  description         = "Execute MCP commands"

  request {
    header {
      name     = "Content-Type"
      type     = "string"
      values   = ["application/json"]
      required = true
    }
    header {
      name     = "X-Session-Id"
      type     = "string"
      required = true
    }
  }

  response {
    status_code = 200
    description = "Command executed successfully"
  }
}

# Role Assignments
resource "azurerm_role_assignment" "function_app_key_vault" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "apim_key_vault" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_api_management.main.identity[0].principal_id
}

# Grant current user access to Key Vault for deployment
resource "azurerm_role_assignment" "current_user_key_vault" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}