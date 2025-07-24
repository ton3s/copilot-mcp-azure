#!/bin/bash

# Alternative deployment approach for Function App

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Deploying Function App Code (Alternative Method)${NC}"
echo "==============================================="

# Get function app details
FUNCTION_APP_NAME=$(tofu output -raw function_app_name)
RESOURCE_GROUP=$(tofu output -raw resource_group_name)

echo -e "${YELLOW}Function App: ${FUNCTION_APP_NAME}${NC}"
echo -e "${YELLOW}Resource Group: ${RESOURCE_GROUP}${NC}"

# Navigate to project root
cd ../..

# Create a temporary deployment directory
DEPLOY_DIR="deployment_temp"
rm -rf $DEPLOY_DIR
mkdir -p $DEPLOY_DIR

echo -e "\n${YELLOW}Preparing deployment files...${NC}"

# Copy necessary files
cp -r src/* $DEPLOY_DIR/
cp host.json $DEPLOY_DIR/
cp requirements.txt $DEPLOY_DIR/

# Rename function files to match Azure Functions Python model
cd $DEPLOY_DIR

# Create proper function structure
echo -e "\n${YELLOW}Restructuring functions...${NC}"

# For mcp_command
mkdir -p mcp_command
cp functions/mcp_command/function.json mcp_command/
echo "import sys
sys.path.insert(0, '..')
from functions.mcp_command import main" > mcp_command/__init__.py

# For sse_stream  
mkdir -p sse_stream
cp functions/sse_stream/function.json sse_stream/
echo "import sys
sys.path.insert(0, '..')
from functions.sse_stream import main" > sse_stream/__init__.py

# Create deployment package
cd ..
echo -e "\n${YELLOW}Creating deployment package...${NC}"
cd $DEPLOY_DIR
zip -r ../function-app-v2.zip . -x "*.pyc" -x "*__pycache__/*"

cd ..

# Deploy using REST API
echo -e "\n${YELLOW}Deploying to Azure...${NC}"
az functionapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP" \
    --name "$FUNCTION_APP_NAME" \
    --src function-app-v2.zip \
    --verbose

# Cleanup
rm -rf $DEPLOY_DIR
rm -f function-app-v2.zip

echo -e "\n${YELLOW}Restarting Function App...${NC}"
az functionapp restart --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP"

echo -e "\n${GREEN}Deployment complete! Waiting for functions to initialize...${NC}"
sleep 30

# Check deployed functions
echo -e "\n${YELLOW}Checking deployed functions:${NC}"
az rest --method GET \
    --uri "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${FUNCTION_APP_NAME}/functions?api-version=2022-03-01" \
    --query "value[].{name:name, language:properties.language}" \
    -o table

echo -e "\n${GREEN}Test the endpoints:${NC}"
echo -e "  - Command: https://$(tofu output -raw apim_gateway_url)/mcp/command"
echo -e "  - Stream: https://$(tofu output -raw apim_gateway_url)/mcp/stream"