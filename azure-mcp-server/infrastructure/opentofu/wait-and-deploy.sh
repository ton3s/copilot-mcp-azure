#!/bin/bash

# Wait for APIM to complete and finish deployment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}MCP Azure Server - Waiting for APIM Completion${NC}"
echo -e "${BLUE}===============================================${NC}"

BASE_NAME=$(grep base_name terraform.tfvars | cut -d'"' -f2)
ENVIRONMENT=$(grep environment terraform.tfvars | cut -d'"' -f2 || echo "dev")
RG_NAME="${BASE_NAME}-rg-${ENVIRONMENT}"

echo -e "\n${YELLOW}Monitoring APIM deployment progress...${NC}"
echo -e "${YELLOW}This typically takes 30-45 minutes for Basic tier${NC}\n"

# Monitor APIM status
while true; do
    APIM_STATE=$(az apim list --resource-group "$RG_NAME" --query "[0].provisioningState" -o tsv 2>/dev/null || echo "Unknown")
    TIMESTAMP=$(date '+%H:%M:%S')
    
    case $APIM_STATE in
        "Succeeded")
            echo -e "${GREEN}[$TIMESTAMP] ✓ APIM deployment completed successfully!${NC}"
            break
            ;;
        "Activating"|"Creating")
            echo -e "${YELLOW}[$TIMESTAMP] ⏳ APIM still activating... (state: $APIM_STATE)${NC}"
            ;;
        "Failed")
            echo -e "${RED}[$TIMESTAMP] ❌ APIM deployment failed${NC}"
            echo -e "${YELLOW}Check Azure portal for error details${NC}"
            exit 1
            ;;
        *)
            echo -e "${YELLOW}[$TIMESTAMP] ⚠ Unknown APIM state: $APIM_STATE${NC}"
            ;;
    esac
    
    # Wait 2 minutes before checking again
    if [ "$APIM_STATE" != "Succeeded" ]; then
        sleep 120
    fi
done

echo -e "\n${GREEN}APIM is ready! Completing OpenTofu deployment...${NC}"

# Now complete the deployment
tofu apply -auto-approve

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}         Deployment Complete!                      ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    
    # Get important outputs
    GATEWAY_URL=$(tofu output -raw apim_gateway_url)
    FUNCTION_APP_NAME=$(tofu output -raw function_app_name)
    
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
else
    echo -e "\n${RED}Deployment failed. Check the error messages above.${NC}"
    exit 1
fi