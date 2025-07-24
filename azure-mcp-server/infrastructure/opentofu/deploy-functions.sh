#!/bin/bash

# Deploy Function App Code to Existing Infrastructure

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Deploying Function App Code${NC}"
echo "============================"

# Get function app name from Terraform output
FUNCTION_APP_NAME=$(tofu output -raw function_app_name)
RESOURCE_GROUP=$(tofu output -raw resource_group_name)

echo -e "${YELLOW}Function App: ${FUNCTION_APP_NAME}${NC}"
echo -e "${YELLOW}Resource Group: ${RESOURCE_GROUP}${NC}"

# Navigate to project root
cd ../..

# Check if requirements.txt exists
if [ ! -f "requirements.txt" ]; then
    echo -e "${RED}requirements.txt not found in project root${NC}"
    exit 1
fi

# Create a zip package
echo -e "\n${YELLOW}Creating deployment package...${NC}"
# Include all necessary files for Azure Functions
zip -r function-app-package.zip \
    src/ \
    host.json \
    requirements.txt \
    -x "*.pyc" \
    -x "*__pycache__/*" \
    -x "*.git/*" \
    -x "*.venv/*" \
    -x "local.settings.json" \
    -x "tests/*" \
    -x "infrastructure/*" \
    -x "docs/*"

# Deploy to Azure
echo -e "\n${YELLOW}Deploying to Azure Function App...${NC}"
az functionapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP" \
    --name "$FUNCTION_APP_NAME" \
    --src function-app-package.zip

# Clean up
rm -f function-app-package.zip

echo -e "\n${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}Function App URL: https://${FUNCTION_APP_NAME}.azurewebsites.net${NC}"

# List deployed functions
echo -e "\n${YELLOW}Deployed functions:${NC}"
az functionapp function list \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query '[].{name:name, language:language}' \
    -o table

echo -e "\n${GREEN}You can now test the API endpoints through API Management${NC}"