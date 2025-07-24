variable "base_name" {
  description = "Base name for all resources"
  type        = string
  default     = "mcp-server"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "azure_ad_tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "azure_ad_client_id" {
  description = "Azure AD client ID for the application"
  type        = string
}

variable "github_organization" {
  description = "GitHub organization allowed to access the API"
  type        = string
  default     = ""
}

variable "apim_publisher_name" {
  description = "API Management publisher name"
  type        = string
  default     = "MCP Server Admin"
}

variable "apim_publisher_email" {
  description = "API Management publisher email"
  type        = string
  default     = "admin@example.com"
}

variable "function_app_sku" {
  description = "SKU for Function App service plan"
  type        = string
  default     = "Y1"

  validation {
    condition     = contains(["Y1", "EP1", "EP2", "EP3"], var.function_app_sku)
    error_message = "Function App SKU must be Y1 (Consumption), EP1, EP2, or EP3 (Premium)."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "MCP-Server"
    ManagedBy   = "Terraform"
  }
}