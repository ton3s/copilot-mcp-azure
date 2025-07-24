#!/bin/bash

# Fix APIM routing

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Fixing APIM Routing${NC}"
echo "==================="

# Update the APIM backend
echo -e "${YELLOW}Please follow these steps in Azure Portal:${NC}"
echo ""
echo "1. Go to Azure Portal → API Management → mcp0724-apim-dev-z0lvf7cp"
echo "2. Click on 'APIs' → 'MCP Server API'"
echo "3. Click on 'Settings' tab"
echo "4. In 'Web service URL', ensure it shows: https://mcp0724-func-dev-z0lvf7cp.azurewebsites.net/api"
echo "5. Make sure 'API URL suffix' is set to: mcp"
echo "6. Save the changes"
echo ""
echo "7. Click on 'Test' tab"
echo "8. Select 'POST command' operation"
echo "9. Add header: X-Session-Id = test"
echo "10. Add request body: {\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"test\"}"
echo "11. Click 'Send' to test"
echo ""
echo -e "${GREEN}The test should return the JSON response from the function${NC}"