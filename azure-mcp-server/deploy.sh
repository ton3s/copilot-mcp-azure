#!/bin/bash

# Azure MCP Server Deployment Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-mcp-server-rg}"
LOCATION="${LOCATION:-eastus}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

echo -e "${GREEN}Azure MCP Server Deployment${NC}"
echo "=============================="

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v az &> /dev/null; then
    echo -e "${RED}Azure CLI is not installed. Please install it first.${NC}"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python 3 is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo -e "${RED}Not logged in to Azure. Please run 'az login' first.${NC}"
    exit 1
fi

# Get deployment parameters
echo -e "\n${YELLOW}Enter deployment parameters:${NC}"
read -p "Azure AD Tenant ID: " TENANT_ID
read -p "Azure AD Client ID (App Registration): " CLIENT_ID
read -p "GitHub Organization (optional): " GITHUB_ORG

# Create resource group
echo -e "\n${YELLOW}Creating resource group...${NC}"
az group create --name $RESOURCE_GROUP --location $LOCATION

# Deploy infrastructure
echo -e "\n${YELLOW}Deploying infrastructure...${NC}"
DEPLOYMENT_OUTPUT=$(az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --template-file infrastructure/bicep/main.bicep \
    --parameters environment=$ENVIRONMENT \
    --parameters azureAdTenantId=$TENANT_ID \
    --parameters azureAdClientId=$CLIENT_ID \
    --parameters githubOrganization=$GITHUB_ORG \
    --query properties.outputs \
    --output json)

# Extract outputs
FUNCTION_APP_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.functionAppName.value')
APIM_GATEWAY_URL=$(echo $DEPLOYMENT_OUTPUT | jq -r '.apimGatewayUrl.value')
KEY_VAULT_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.keyVaultName.value')

echo -e "${GREEN}Infrastructure deployed successfully!${NC}"

# Generate session secret
echo -e "\n${YELLOW}Generating session secret...${NC}"
SESSION_SECRET=$(openssl rand -hex 32)
az keyvault secret set \
    --vault-name $KEY_VAULT_NAME \
    --name session-secret \
    --value $SESSION_SECRET

# Package and deploy Function App
echo -e "\n${YELLOW}Packaging Function App...${NC}"
cd src
zip -r ../function-app.zip . -x "__pycache__/*" "*.pyc"
cd ..

echo -e "\n${YELLOW}Deploying Function App...${NC}"
az functionapp deployment source config-zip \
    --resource-group $RESOURCE_GROUP \
    --name $FUNCTION_APP_NAME \
    --src function-app.zip

# Apply APIM policies
echo -e "\n${YELLOW}Applying API Management policies...${NC}"

# Update policy files with actual values
sed -i "s/{tenant-id}/$TENANT_ID/g" infrastructure/policies/apim-global-policy.xml
sed -i "s/{client-id}/$CLIENT_ID/g" infrastructure/policies/apim-global-policy.xml
sed -i "s/{function-app-name}/$FUNCTION_APP_NAME/g" infrastructure/policies/mcp-api-policy.xml

# Apply global policy
az apim policy set \
    --resource-group $RESOURCE_GROUP \
    --service-name $(echo $APIM_GATEWAY_URL | sed 's/https:\/\///' | sed 's/.azure-api.net//') \
    --policy-file infrastructure/policies/apim-global-policy.xml

# Apply API policy
az apim api policy set \
    --resource-group $RESOURCE_GROUP \
    --service-name $(echo $APIM_GATEWAY_URL | sed 's/https:\/\///' | sed 's/.azure-api.net//') \
    --api-id mcp-api \
    --policy-file infrastructure/policies/mcp-api-policy.xml

# Clean up
rm -f function-app.zip

echo -e "\n${GREEN}Deployment completed successfully!${NC}"
echo -e "\n${YELLOW}Deployment Information:${NC}"
echo "========================"
echo "Resource Group: $RESOURCE_GROUP"
echo "Function App: $FUNCTION_APP_NAME"
echo "API Gateway URL: $APIM_GATEWAY_URL"
echo "MCP Endpoints:"
echo "  - SSE Stream: ${APIM_GATEWAY_URL}mcp/stream"
echo "  - Command: ${APIM_GATEWAY_URL}mcp/command"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure your Azure AD App Registration redirect URIs"
echo "2. Add required API permissions in Azure AD"
echo "3. Configure GitHub Copilot extension with the API endpoints"
echo "4. Test the endpoints using the provided test scripts"