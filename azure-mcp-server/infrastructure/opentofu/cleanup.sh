#!/bin/bash

# Cleanup script for MCP Azure Server deployment
# This script performs a complete cleanup including soft-deleted resources

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}MCP Azure Server - Complete Cleanup${NC}"
echo -e "${YELLOW}====================================${NC}"

# Check if terraform.tfvars exists to get resource names
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}terraform.tfvars not found. Cannot determine resource names.${NC}"
    echo -e "${YELLOW}If you want to clean up manually, check Azure portal for resources with your base name.${NC}"
    exit 1
fi

# Extract values from terraform.tfvars
BASE_NAME=$(grep base_name terraform.tfvars | cut -d'"' -f2)
ENVIRONMENT=$(grep environment terraform.tfvars | cut -d'"' -f2 || echo "dev")
RG_NAME="${BASE_NAME}-rg-${ENVIRONMENT}"

echo -e "\n${YELLOW}Configuration:${NC}"
echo -e "  Base name: $BASE_NAME"
echo -e "  Environment: $ENVIRONMENT"  
echo -e "  Resource Group: $RG_NAME"

# Confirm cleanup
echo -e "\n${RED}WARNING: This will permanently delete all resources!${NC}"
read -p "Are you sure you want to continue? Type 'yes' to confirm: " -r
if [[ ! $REPLY == "yes" ]]; then
    echo -e "${GREEN}Cleanup cancelled.${NC}"
    exit 0
fi

# Step 1: Standard OpenTofu destroy
echo -e "\n${YELLOW}Step 1: Running OpenTofu destroy...${NC}"
if [ -f "terraform.tfstate" ]; then
    tofu destroy -auto-approve
    echo -e "${GREEN}✓ OpenTofu destroy completed${NC}"
else
    echo -e "${YELLOW}⚠ No terraform.tfstate found, skipping OpenTofu destroy${NC}"
fi

# Step 2: Delete resource group (in case some resources weren't managed by OpenTofu)
echo -e "\n${YELLOW}Step 2: Deleting resource group...${NC}"
if az group show --name "$RG_NAME" >/dev/null 2>&1; then
    az group delete --name "$RG_NAME" --yes --no-wait
    echo -e "${GREEN}✓ Resource group deletion initiated${NC}"
else
    echo -e "${YELLOW}⚠ Resource group $RG_NAME not found${NC}"
fi

# Step 3: Clean up soft-deleted Key Vaults
echo -e "\n${YELLOW}Step 3: Cleaning up soft-deleted Key Vaults...${NC}"

DELETED_VAULTS=$(az keyvault list-deleted --query "[?contains(name, '$BASE_NAME')].name" -o tsv 2>/dev/null || echo "")

if [ ! -z "$DELETED_VAULTS" ]; then
    echo -e "${YELLOW}Found soft-deleted Key Vaults to purge:${NC}"
    echo "$DELETED_VAULTS"
    
    for vault in $DELETED_VAULTS; do
        echo -e "  Purging: $vault"
        az keyvault purge --name "$vault" --no-wait 2>/dev/null || echo -e "    ${YELLOW}⚠ Could not purge $vault${NC}"
    done
    echo -e "${GREEN}✓ Key Vault purge initiated${NC}"
else
    echo -e "${GREEN}✓ No soft-deleted Key Vaults found${NC}"
fi

# Step 4: Clean up local state files
echo -e "\n${YELLOW}Step 4: Cleaning up local files...${NC}"
rm -f terraform.tfstate*
rm -f tfplan*
rm -f .terraform.lock.hcl
rm -rf .terraform/
echo -e "${GREEN}✓ Local state files cleaned${NC}"

echo -e "\n${GREEN}Cleanup Complete!${NC}"