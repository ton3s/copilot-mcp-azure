# Fix APIM 404 Error

The function is working correctly when accessed directly, but APIM returns 404. This is a routing issue.

## Quick Fix:

In the Azure Portal, on the API operation page you're viewing:

1. Click on the **POST MCP Command** operation in the left sidebar
2. You'll see tabs: **Frontend | Backend | Inbound processing | Outbound processing**
3. Click on **Inbound processing**
4. Click on **+ Add policy**
5. Select **Rewrite URL**
6. Set the backend URL to: `/mcp/command`
7. Click Save

Alternatively, click on the **</>** (Code editor) icon and add this policy:

```xml
<policies>
    <inbound>
        <base />
        <rewrite-uri template="/mcp/command" copy-unmatched-params="true" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

## Why this happens:

- APIM backend URL: `https://mcp0724-func-dev-z0lvf7cp.azurewebsites.net/api`
- Operation URL template: `/command`
- Full URL APIM calls: `.../api/command` ❌
- What Function expects: `.../api/mcp/command` ✅

The rewrite-uri policy fixes this by changing the path before sending to the backend.

## Do the same for SSE Stream:

1. Click on **GET SSE Stream** operation
2. Add the same type of policy but with template: `/mcp/stream`

After applying these policies, your test client should work!