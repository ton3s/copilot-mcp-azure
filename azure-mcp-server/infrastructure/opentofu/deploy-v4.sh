#!/bin/bash

# Deploy using Azure Functions V4 Python model

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Deploying Function App (V4 Model)${NC}"
echo "================================="

# Get function app details
FUNCTION_APP_NAME=$(tofu output -raw function_app_name)
RESOURCE_GROUP=$(tofu output -raw resource_group_name)

echo -e "${YELLOW}Function App: ${FUNCTION_APP_NAME}${NC}"
echo -e "${YELLOW}Resource Group: ${RESOURCE_GROUP}${NC}"

# Navigate to project root
cd ../..

# Create deployment package
echo -e "\n${YELLOW}Creating deployment package...${NC}"
zip -r function-deployment.zip \
    function_app.py \
    host.json \
    requirements.txt \
    src/ \
    -x "*.pyc" \
    -x "*__pycache__/*" \
    -x "*.git/*" \
    -x "tests/*" \
    -x "infrastructure/*" \
    -x "docs/*" \
    -x "*.md"

# Deploy
echo -e "\n${YELLOW}Deploying to Azure...${NC}"
az functionapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP" \
    --name "$FUNCTION_APP_NAME" \
    --src function-deployment.zip

# Clean up
rm -f function-deployment.zip

# Restart the app
echo -e "\n${YELLOW}Restarting Function App...${NC}"
az functionapp restart --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP"

echo -e "\n${GREEN}Deployment complete!${NC}"
echo -e "${YELLOW}Waiting 60 seconds for functions to initialize...${NC}"
sleep 60

# Test direct access
echo -e "\n${YELLOW}Testing direct function access:${NC}"
FUNCTION_URL="https://${FUNCTION_APP_NAME}.azurewebsites.net/api/mcp/command"
echo "URL: $FUNCTION_URL"
curl -X POST "$FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":"1","method":"ping"}' \
    -w "\nStatus: %{http_code}\n" \
    -m 10 || echo "Direct test failed"

echo -e "\n${GREEN}Check the test client or Azure Portal for function status${NC}"