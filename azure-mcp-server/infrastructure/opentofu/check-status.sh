#!/bin/bash

# Check deployment status script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}MCP Azure Server - Deployment Status Check${NC}"
echo -e "${YELLOW}===========================================${NC}"

# Get resource group name
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}terraform.tfvars not found${NC}"
    exit 1
fi

BASE_NAME=$(grep base_name terraform.tfvars | cut -d'"' -f2)
ENVIRONMENT=$(grep environment terraform.tfvars | cut -d'"' -f2 || echo "dev")
RG_NAME="${BASE_NAME}-rg-${ENVIRONMENT}"

echo -e "\n${YELLOW}Resource Group: ${RG_NAME}${NC}\n"

# Check if resource group exists
if ! az group show --name "$RG_NAME" >/dev/null 2>&1; then
    echo -e "${RED}Resource group not found. Deployment may not have started.${NC}"
    exit 1
fi

# Check APIM status
echo -e "${YELLOW}API Management Status:${NC}"
APIM_STATUS=$(az apim list --resource-group "$RG_NAME" --query "[0].{name:name,state:provisioningState,sku:sku.name,location:location}" -o table 2>/dev/null || echo "Not found")
echo "$APIM_STATUS"

# Check other resources
echo -e "\n${YELLOW}Other Resources:${NC}"
az resource list --resource-group "$RG_NAME" --query "[?type!='Microsoft.ApiManagement/service'].{name:name,type:type,state:properties.provisioningState}" -o table 2>/dev/null || echo "No other resources found"

# Check if deployment is complete
APIM_STATE=$(az apim list --resource-group "$RG_NAME" --query "[0].provisioningState" -o tsv 2>/dev/null || echo "Unknown")

echo -e "\n${YELLOW}Status Summary:${NC}"
case $APIM_STATE in
    "Succeeded")
        echo -e "${GREEN}✓ Deployment complete! APIM is ready.${NC}"
        echo -e "${GREEN}You can now continue with OpenTofu apply.${NC}"
        ;;
    "Activating"|"Creating")
        echo -e "${YELLOW}⏳ APIM is still deploying (this can take 30-45 minutes)${NC}"
        echo -e "${YELLOW}Current state: $APIM_STATE${NC}"
        echo -e "${YELLOW}Run this script again to check progress.${NC}"
        ;;
    "Failed")
        echo -e "${RED}❌ APIM deployment failed${NC}"
        echo -e "${YELLOW}Check Azure portal for error details${NC}"
        ;;
    *)
        echo -e "${YELLOW}⚠ Unknown state: $APIM_STATE${NC}"
        ;;
esac

echo -e "\n${YELLOW}To monitor in real-time, run:${NC}"
echo -e "watch -n 30 './check-status.sh'"