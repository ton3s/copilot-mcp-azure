# MCP Azure Server - OpenTofu Deployment

This directory contains the Infrastructure as Code (IaC) for deploying the MCP Azure Server using [OpenTofu](https://opentofu.org).

## Quick Start

```bash
# Deploy everything with one command
./deploy.sh
```

That's it! The script will guide you through the entire process.

## Prerequisites

1. **Install required tools:**
   - [OpenTofu](https://opentofu.org/docs/intro/install/) (>= 1.5.0)
   - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
   - [jq](https://stedolan.github.io/jq/download/)

2. **Azure setup:**
   - Active Azure subscription
   - Azure AD App Registration created
   - Logged in to Azure CLI: `az login`

## What Gets Deployed

- **Resource Group**: Container for all resources
- **Azure Functions**: Python 3.11 on Consumption plan (serverless)
- **API Management**: Basic tier with OAuth2 and policies configured
- **Key Vault**: For secure secret storage
- **Storage Account**: Required by Functions
- **Application Insights**: For monitoring and logging
- **Log Analytics Workspace**: For centralized logging

## Configuration

The deployment script will prompt you for:
- Azure AD App Registration Client ID
- Base name for resources (e.g., `mcp-server`)
- Environment (dev/staging/prod)
- Azure region
- Publisher email for APIM

These values are saved to `terraform.tfvars`.

## Manual Deployment

If you prefer to run commands manually:

```bash
# 1. Initialize OpenTofu
tofu init

# 2. Create terraform.tfvars (see terraform.tfvars.example)
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Plan deployment
tofu plan

# 4. Apply deployment
tofu apply

# 5. Deploy Function App code
cd ../..
func azure functionapp publish $(tofu -chdir=infrastructure/opentofu output -raw function_app_name)
```

## Outputs

After deployment, get important values:

```bash
# View all outputs
tofu output

# Get specific values
tofu output -raw apim_gateway_url
tofu output -raw function_app_name
```

## API Endpoints

Once deployed, your MCP endpoints will be:
- **SSE Stream**: `https://<apim-name>.azure-api.net/mcp/stream`
- **Command**: `https://<apim-name>.azure-api.net/mcp/command`

## Cost Information

**Estimated monthly cost**: ~$50-60
- API Management Basic tier: ~$50/month
- Other services: <$10/month with light usage

For testing only, you can modify `main.tf` to use:
- API Management Developer tier (free for 30 days)
- Or remove APIM and use Functions directly

## Cleanup

To remove all deployed resources:

```bash
tofu destroy
```

To completely clean up (including soft-deleted Key Vaults):

```bash
./cleanup.sh
```

## Troubleshooting

### "Resource already exists" error
- Change the `base_name` in terraform.tfvars
- Or run `./cleanup.sh` to remove existing resources

### Authentication errors
1. Ensure Azure AD App Registration is configured correctly
2. Add redirect URIs for your application
3. Configure API permissions as needed

### Deployment failures
1. Check Azure Activity Log in the portal
2. Review terraform output for specific errors
3. Ensure your subscription has required quotas

## Files

- `main.tf` - Main infrastructure configuration
- `variables.tf` - Input variable definitions
- `outputs.tf` - Output definitions
- `api-spec.yaml` - OpenAPI specification for APIM
- `policies/` - APIM policy XML files
- `deploy.sh` - Automated deployment script
- `cleanup.sh` - Resource cleanup script