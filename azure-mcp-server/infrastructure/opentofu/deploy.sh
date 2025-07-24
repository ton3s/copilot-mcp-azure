#!/bin/bash

# MCP Azure Server Deployment Script
# This script handles the complete deployment process

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    MCP Azure Server Deployment with OpenTofu     ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for required tools
missing_tools=()
command -v tofu >/dev/null 2>&1 || missing_tools+=("tofu (OpenTofu)")
command -v az >/dev/null 2>&1 || missing_tools+=("az (Azure CLI)")
command -v jq >/dev/null 2>&1 || missing_tools+=("jq")

if [ ${#missing_tools[@]} -ne 0 ]; then
    echo -e "${RED}Missing required tools:${NC}"
    for tool in "${missing_tools[@]}"; do
        echo -e "  - $tool"
    done
    echo -e "\n${YELLOW}Installation instructions:${NC}"
    echo -e "  - OpenTofu: https://opentofu.org/docs/intro/install/"
    echo -e "  - Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    echo -e "  - jq: https://stedolan.github.io/jq/download/"
    exit 1
fi

# Check Azure login
if ! az account show >/dev/null 2>&1; then
    echo -e "${RED}Not logged in to Azure CLI${NC}"
    echo -e "${YELLOW}Please run: az login${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}\n"

# Setup configuration
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Setting up configuration...${NC}"
    
    # Get Azure subscription info
    TENANT_ID=$(az account show --query tenantId -o tsv)
    
    # Prompt for required values
    echo -e "\n${YELLOW}Please provide the following information:${NC}"
    read -p "Azure AD App Registration Client ID: " CLIENT_ID
    read -p "Base name for resources (e.g., mcp-server): " BASE_NAME
    read -p "Environment (dev/staging/prod) [dev]: " ENVIRONMENT
    ENVIRONMENT=${ENVIRONMENT:-dev}
    read -p "Azure region (e.g., eastus, westus2) [eastus]: " LOCATION
    LOCATION=${LOCATION:-eastus}
    read -p "Publisher email for APIM: " PUBLISHER_EMAIL
    
    # Create terraform.tfvars
    cat > terraform.tfvars <<EOF
# Azure AD Configuration
azure_ad_tenant_id = "$TENANT_ID"
azure_ad_client_id = "$CLIENT_ID"

# Resource Configuration
base_name           = "$BASE_NAME"
environment         = "$ENVIRONMENT"
location            = "$LOCATION"

# API Management
apim_publisher_name  = "MCP Server Admin"
apim_publisher_email = "$PUBLISHER_EMAIL"

# Tags
tags = {
  Project     = "MCP-Server"
  Environment = "$ENVIRONMENT"
  ManagedBy   = "OpenTofu"
}
EOF
    
    echo -e "${GREEN}✓ Configuration created${NC}\n"
else
    echo -e "${GREEN}✓ Using existing terraform.tfvars${NC}\n"
fi

# Initialize OpenTofu
echo -e "${YELLOW}Initializing OpenTofu...${NC}"
tofu init -upgrade
echo -e "${GREEN}✓ OpenTofu initialized${NC}\n"

# Plan deployment
echo -e "${YELLOW}Planning deployment...${NC}"
tofu plan -out=tfplan

# Confirm deployment
echo -e "\n${YELLOW}Ready to deploy the infrastructure.${NC}"
echo -e "${YELLOW}This will create:${NC}"
echo -e "  - Resource Group"
echo -e "  - Azure Functions (Consumption plan)"
echo -e "  - API Management (Basic tier)"
echo -e "  - Key Vault, Storage, Application Insights"
echo -e "  - All necessary configurations and policies"

read -p "Continue with deployment? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 1
fi

# Apply deployment
echo -e "\n${YELLOW}Deploying infrastructure...${NC}"
tofu apply tfplan

# Get outputs
FUNCTION_APP_NAME=$(tofu output -raw function_app_name)
GATEWAY_URL=$(tofu output -raw apim_gateway_url)

# Display summary
echo -e "\n${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}         Deployment Complete!                      ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "\n${BLUE}API Endpoints:${NC}"
echo -e "  SSE Stream: ${GATEWAY_URL}/mcp/stream"
echo -e "  Command:    ${GATEWAY_URL}/mcp/command"
echo -e "\n${BLUE}Function App:${NC} $FUNCTION_APP_NAME"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "1. Deploy the Function App code:"
echo -e "   ${GREEN}cd ../.. && func azure functionapp publish $FUNCTION_APP_NAME${NC}"
echo -e "\n2. Configure your Azure AD App Registration"
echo -e "\n3. Test with the web client:"
echo -e "   ${GREEN}open ../../tests/test_client.html${NC}"
echo -e "\n${YELLOW}To view all outputs:${NC} tofu output"
echo -e "${YELLOW}To destroy resources:${NC} tofu destroy"