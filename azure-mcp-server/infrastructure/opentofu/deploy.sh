#!/bin/bash

# OpenTofu Deployment Script for MCP Azure Server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}MCP Azure Server OpenTofu Deploy${NC}"
echo -e "${BLUE}=================================${NC}"

# Function to check prerequisites
check_prerequisites() {
    echo -e "\n${YELLOW}Checking prerequisites...${NC}"
    
    # Check OpenTofu
    if ! command -v tofu &> /dev/null; then
        echo -e "${RED}❌ OpenTofu is not installed. Please install it first.${NC}"
        echo "Visit: https://opentofu.org/docs/intro/install/"
        exit 1
    fi
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        echo -e "${RED}❌ Azure CLI is not installed. Please install it first.${NC}"
        echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        echo -e "${RED}❌ Not logged in to Azure. Please run 'az login' first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites met${NC}"
}

# Function to initialize OpenTofu
init_opentofu() {
    echo -e "\n${YELLOW}Initializing OpenTofu...${NC}"
    tofu init
    echo -e "${GREEN}✓ OpenTofu initialized${NC}"
}

# Function to create terraform.tfvars if it doesn't exist
create_tfvars() {
    if [ ! -f "terraform.tfvars" ]; then
        echo -e "\n${YELLOW}terraform.tfvars not found. Creating from template...${NC}"
        
        # Get Azure account info
        CURRENT_SUB=$(az account show --query id -o tsv)
        CURRENT_TENANT=$(az account show --query tenantId -o tsv)
        
        echo -e "\n${YELLOW}Please provide the following information:${NC}"
        read -p "Azure AD Client ID (App Registration): " CLIENT_ID
        read -p "GitHub Organization (optional, press Enter to skip): " GITHUB_ORG
        read -p "Your email for APIM: " APIM_EMAIL
        read -p "Your organization name: " ORG_NAME
        
        cat > terraform.tfvars <<EOF
# Auto-generated terraform.tfvars for OpenTofu
# Generated on $(date)

# Base configuration
base_name   = "mcp-server"
environment = "dev"
location    = "eastus"

# Azure AD configuration
azure_ad_tenant_id = "${CURRENT_TENANT}"
azure_ad_client_id = "${CLIENT_ID}"

# Optional: GitHub organization restriction
github_organization = "${GITHUB_ORG}"

# API Management configuration
apim_publisher_name  = "${ORG_NAME}"
apim_publisher_email = "${APIM_EMAIL}"

# Function App SKU (Y1 = Consumption, EP1-EP3 = Premium)
function_app_sku = "Y1"

# Resource tags
tags = {
  Project     = "MCP-Server"
  Environment = "dev"
  ManagedBy   = "OpenTofu"
  Owner       = "${ORG_NAME}"
}
EOF
        
        echo -e "${GREEN}✓ terraform.tfvars created${NC}"
    else
        echo -e "${GREEN}✓ terraform.tfvars already exists${NC}"
    fi
}

# Function to validate configuration
validate_config() {
    echo -e "\n${YELLOW}Validating OpenTofu configuration...${NC}"
    tofu validate
    echo -e "${GREEN}✓ Configuration is valid${NC}"
}

# Function to plan deployment
plan_deployment() {
    echo -e "\n${YELLOW}Planning deployment...${NC}"
    tofu plan -out=tfplan
    echo -e "${GREEN}✓ Deployment plan created${NC}"
}

# Function to apply deployment
apply_deployment() {
    echo -e "\n${YELLOW}Applying deployment...${NC}"
    
    # Confirm deployment
    echo -e "\n${YELLOW}This will create resources in Azure. Continue? (yes/no)${NC}"
    read -p "> " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${RED}Deployment cancelled.${NC}"
        exit 0
    fi
    
    tofu apply tfplan
    echo -e "${GREEN}✓ Deployment completed${NC}"
}

# Function to show outputs
show_outputs() {
    echo -e "\n${BLUE}=================================${NC}"
    echo -e "${BLUE}Deployment Outputs${NC}"
    echo -e "${BLUE}=================================${NC}"
    
    tofu output -json | jq -r '
        to_entries[] | 
        "\(.key): \(.value.value)"
    '
}

# Function to deploy function code
deploy_function_code() {
    echo -e "\n${YELLOW}Would you like to deploy the Function App code now? (yes/no)${NC}"
    read -p "> " DEPLOY_CODE
    
    if [ "$DEPLOY_CODE" == "yes" ]; then
        echo -e "\n${YELLOW}Deploying Function App code...${NC}"
        
        # Get function app name from opentofu output
        FUNCTION_APP_NAME=$(tofu output -raw function_app_name)
        RESOURCE_GROUP=$(tofu output -raw resource_group_name)
        
        # Navigate to source directory
        cd ../../src
        
        # Create deployment package
        echo -e "${YELLOW}Creating deployment package...${NC}"
        zip -r ../function-app.zip . -x "__pycache__/*" "*.pyc" ".env" "local.settings.json"
        
        # Deploy to Azure
        echo -e "${YELLOW}Deploying to Azure...${NC}"
        az functionapp deployment source config-zip \
            --resource-group $RESOURCE_GROUP \
            --name $FUNCTION_APP_NAME \
            --src ../function-app.zip
        
        # Clean up
        rm ../function-app.zip
        cd ../infrastructure/opentofu
        
        echo -e "${GREEN}✓ Function App code deployed${NC}"
    fi
}

# Function to create test script
create_test_script() {
    echo -e "\n${YELLOW}Creating test script...${NC}"
    
    # Get outputs
    APIM_URL=$(tofu output -raw apim_gateway_url)
    CLIENT_ID=$(tofu output -json | jq -r '.azure_ad_client_id.value // empty' || grep azure_ad_client_id terraform.tfvars | cut -d'"' -f2)
    TENANT_ID=$(tofu output -json | jq -r '.azure_ad_tenant_id.value // empty' || grep azure_ad_tenant_id terraform.tfvars | cut -d'"' -f2)
    
    cat > test-deployment.sh <<EOF
#!/bin/bash
# Test script for MCP Azure deployment

echo "Testing MCP Azure deployment..."
echo "API Gateway URL: ${APIM_URL}"
echo ""
echo "To test the deployment:"
echo "1. Open azure-mcp-server/tests/test_client.html in a browser"
echo "2. Enter the following configuration:"
echo "   - API Base URL: ${APIM_URL}"
echo "   - Tenant ID: ${TENANT_ID}"
echo "   - Client ID: ${CLIENT_ID}"
echo "3. Create a client secret in your Azure AD App Registration"
echo "4. Use the client secret to authenticate and test"
echo ""
echo "For VS Code extension testing:"
echo "1. Configure the extension with the above values"
echo "2. Use 'MCP Azure: Connect' command"
EOF
    
    chmod +x test-deployment.sh
    echo -e "${GREEN}✓ Test script created: test-deployment.sh${NC}"
}

# Main deployment flow
main() {
    check_prerequisites
    init_opentofu
    create_tfvars
    validate_config
    plan_deployment
    apply_deployment
    show_outputs
    deploy_function_code
    create_test_script
    
    echo -e "\n${GREEN}=================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Configure your Azure AD App Registration"
    echo "2. Run ./test-deployment.sh for testing instructions"
    echo "3. Configure GitHub Copilot extension in VS Code"
}

# Run main function
main