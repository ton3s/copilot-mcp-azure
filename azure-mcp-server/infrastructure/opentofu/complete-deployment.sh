#!/bin/bash

# Complete the deployment after APIM is ready

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}MCP Azure Server - Complete Deployment${NC}"
echo -e "${YELLOW}=====================================${NC}"

# Check if APIM is ready
./check-status.sh

BASE_NAME=$(grep base_name terraform.tfvars | cut -d'"' -f2)
ENVIRONMENT=$(grep environment terraform.tfvars | cut -d'"' -f2 || echo "dev")
RG_NAME="${BASE_NAME}-rg-${ENVIRONMENT}"

APIM_STATE=$(az apim list --resource-group "$RG_NAME" --query "[0].provisioningState" -o tsv 2>/dev/null || echo "Unknown")

if [ "$APIM_STATE" != "Succeeded" ]; then
    echo -e "\n${RED}APIM is not ready yet. Current state: $APIM_STATE${NC}"
    echo -e "${YELLOW}Please wait for APIM to complete deployment and try again.${NC}"
    exit 1
fi

echo -e "\n${GREEN}APIM is ready! Completing OpenTofu deployment...${NC}"

# Continue with OpenTofu apply
tofu apply -auto-approve

echo -e "\n${GREEN}Deployment completed successfully!${NC}"

# Display outputs
echo -e "\n${YELLOW}Deployment Outputs:${NC}"
tofu output

echo -e "\n${GREEN}Next Steps:${NC}"
echo -e "1. Deploy Function App code:"
FUNCTION_APP_NAME=$(tofu output -raw function_app_name)
echo -e "   ${GREEN}cd ../.. && func azure functionapp publish $FUNCTION_APP_NAME${NC}"
echo -e "\n2. Configure Azure AD App Registration"
echo -e "\n3. Test the deployment"