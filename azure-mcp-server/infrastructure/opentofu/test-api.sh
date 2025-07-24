#!/bin/bash

# Test API endpoints

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get API URL from Terraform output
API_URL=$(tofu output -raw apim_gateway_url)

echo -e "${GREEN}Testing API Endpoints${NC}"
echo "===================="
echo -e "${YELLOW}API URL: ${API_URL}${NC}"

# Test the command endpoint without auth (should return 401)
echo -e "\n${YELLOW}Testing /mcp/command without auth (should return 401):${NC}"
curl -X POST "${API_URL}/mcp/command" \
    -H "Content-Type: application/json" \
    -H "X-Session-Id: test-session" \
    -d '{"jsonrpc":"2.0","id":"1","method":"initialize","params":{}}' \
    -w "\nHTTP Status: %{http_code}\n" \
    -o /dev/null -s

# Test OPTIONS for CORS
echo -e "\n${YELLOW}Testing CORS preflight:${NC}"
curl -X OPTIONS "${API_URL}/mcp/command" \
    -H "Origin: http://127.0.0.1:5500" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: authorization,content-type,x-session-id" \
    -v 2>&1 | grep -E "< HTTP|< Access-Control"

echo -e "\n${GREEN}Note:${NC} To test with authentication, use the test_client.html"