# Terraform Deployment for MCP Azure Server

This directory contains Terraform configuration for deploying the MCP Azure Server infrastructure.

## Prerequisites

1. **Install required tools:**
   - [Terraform](https://www.terraform.io/downloads) (>= 1.5.0)
   - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
   - [jq](https://stedolan.github.io/jq/download/) (for JSON parsing)

2. **Azure setup:**
   - Active Azure subscription
   - Azure AD tenant with permissions to create app registrations
   - Logged in to Azure CLI: `az login`

3. **Azure AD App Registration:**
   - Create an app registration in Azure AD
   - Note the Application (client) ID
   - Configure API permissions if needed

## Quick Start

### 1. Automated Deployment

Use the provided deployment script for an interactive setup:

```bash
./deploy.sh
```

This script will:
- Check prerequisites
- Initialize Terraform
- Create terraform.tfvars from your inputs
- Plan and apply the deployment
- Optionally deploy the Function App code
- Create a test script

### 2. Manual Deployment

If you prefer manual control:

```bash
# 1. Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Initialize Terraform
terraform init

# 3. Plan deployment
terraform plan

# 4. Apply deployment
terraform apply

# 5. View outputs
terraform output
```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `azure_ad_tenant_id` | Your Azure AD tenant ID | `12345678-1234-1234-1234-123456789012` |
| `azure_ad_client_id` | App registration client ID | `87654321-4321-4321-4321-210987654321` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `base_name` | Base name for resources | `mcp-server` |
| `environment` | Environment (dev/staging/prod) | `dev` |
| `location` | Azure region | `eastus` |
| `github_organization` | GitHub org restriction | `""` |
| `function_app_sku` | Function App SKU | `Y1` (Consumption) |

## Resources Created

The Terraform configuration creates:

1. **Core Infrastructure:**
   - Resource Group
   - Storage Account
   - Key Vault
   - Application Insights
   - Log Analytics Workspace

2. **Function App:**
   - Linux Function App (Python 3.11)
   - App Service Plan
   - System-assigned Managed Identity

3. **API Management:**
   - API Management instance
   - MCP API definition
   - OAuth2 authorization server
   - Security policies

4. **Security:**
   - Role assignments for managed identities
   - Key Vault access policies
   - Network security configuration

## Outputs

After deployment, Terraform provides:

- Function App name and URL
- API Management gateway URL
- Key Vault name and URI
- Application Insights connection string
- MCP endpoint URLs

## Testing

After deployment:

1. **Web Client Test:**
   ```bash
   # Open the test client
   open ../../tests/test_client.html
   ```

2. **Python Integration Tests:**
   ```bash
   cd ../..
   export API_BASE_URL=$(terraform -chdir=infrastructure/terraform output -raw apim_gateway_url)
   export CLIENT_ID=$(grep azure_ad_client_id infrastructure/terraform/terraform.tfvars | cut -d'"' -f2)
   export TENANT_ID=$(grep azure_ad_tenant_id infrastructure/terraform/terraform.tfvars | cut -d'"' -f2)
   
   pytest tests/
   ```

3. **VS Code Extension:**
   - Configure extension settings with deployment outputs
   - Use "MCP Azure: Connect" command

## Troubleshooting

### Common Issues

1. **"Resource already exists" error:**
   - Some resource names must be globally unique
   - Try changing `base_name` in terraform.tfvars

2. **Authentication errors:**
   - Ensure Azure AD app registration is configured correctly
   - Check redirect URIs and API permissions

3. **Function App deployment fails:**
   - Verify Python 3.11 is specified
   - Check storage account connectivity

### State Management

Terraform state is stored locally by default. For team deployments:

1. Configure remote state backend:
   ```hcl
   terraform {
     backend "azurerm" {
       resource_group_name  = "terraform-state-rg"
       storage_account_name = "tfstateXXXXX"
       container_name      = "tfstate"
       key                 = "mcp-server.tfstate"
     }
   }
   ```

2. Initialize with backend:
   ```bash
   terraform init -backend-config="storage_account_name=tfstateXXXXX"
   ```

## Cleanup

To remove all resources:

```bash
terraform destroy
```

**Warning:** This will delete all resources including data. Ensure you have backups if needed.

## Advanced Configuration

### High Availability

For production deployments, consider:

1. **Premium Function App:**
   ```hcl
   function_app_sku = "EP1"  # or EP2, EP3
   ```

2. **Multi-region deployment:**
   - Use Terraform workspaces for multiple regions
   - Configure Traffic Manager for global routing

3. **Enhanced security:**
   - Enable Private Endpoints
   - Configure Virtual Network integration
   - Use Azure Firewall

### Custom Policies

Add custom APIM policies by modifying:
- `policies/global-policy.xml` - Global policies
- `policies/api-policy.xml` - API-specific policies

## Support

For issues or questions:
1. Check Terraform logs: `terraform show`
2. Review Azure Activity Log in portal
3. Enable debug logging: `export TF_LOG=DEBUG`

## Next Steps

After successful deployment:
1. Configure Azure AD app registration
2. Set up monitoring alerts
3. Deploy Function App code
4. Test with provided clients
5. Configure GitHub Copilot extension