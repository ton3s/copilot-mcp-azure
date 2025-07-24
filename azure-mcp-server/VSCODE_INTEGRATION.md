# VSCode Integration Guide for MCP Azure Server

This guide explains how to integrate your deployed MCP Azure Server with Visual Studio Code and GitHub Copilot.

## Prerequisites

- ✅ MCP Azure Server deployed and running
- ✅ Azure AD authentication configured
- ✅ API Management endpoints working
- Visual Studio Code installed
- GitHub Copilot extension installed

## Server Endpoints

Your MCP server is available at:
- **Base URL**: `https://mcp0724-apim-dev-z0lvf7cp.azure-api.net`
- **Command Endpoint**: `/mcp/command`
- **Stream Endpoint**: `/mcp/stream`

## Available Tools

1. **analyze_code** - Analyze code for complexity, issues, and improvements
2. **generate_code** - Generate code based on descriptions

## Integration Options

### Option 1: GitHub Copilot Extension Settings

1. Open VSCode Settings (Cmd/Ctrl + ,)
2. Search for "GitHub Copilot"
3. Find "GitHub Copilot: Advanced Settings"
4. Add custom MCP server configuration:

```json
{
  "github.copilot.advanced": {
    "mcpServers": {
      "azure-mcp": {
        "url": "https://mcp0724-apim-dev-z0lvf7cp.azure-api.net/mcp",
        "auth": {
          "type": "oauth2",
          "clientId": "c1de1621-a378-469d-8e17-b5c2d3b94bee",
          "tenantId": "c67773cd-1868-485d-bc21-f36acb61ce1a",
          "scope": "openid profile email offline_access"
        }
      }
    }
  }
}
```

### Option 2: Custom VSCode Extension

Create a custom extension that connects to your MCP server:

1. **Create Extension Structure**:
```bash
mkdir vscode-mcp-azure
cd vscode-mcp-azure
npm init -y
npm install vscode axios
```

2. **Create `extension.js`**:
```javascript
const vscode = require('vscode');
const axios = require('axios');

const MCP_BASE_URL = 'https://mcp0724-apim-dev-z0lvf7cp.azure-api.net/mcp';
let accessToken = null;

async function activate(context) {
    // Register commands
    let analyzeCommand = vscode.commands.registerCommand('mcp-azure.analyzeCode', async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor) return;

        const code = editor.document.getText();
        const language = editor.document.languageId;

        try {
            const response = await callMCPTool('analyze_code', {
                code: code,
                language: language,
                analysis_type: 'all'
            });

            // Show results in output panel
            const output = vscode.window.createOutputChannel('MCP Analysis');
            output.appendLine(JSON.stringify(response.analysis, null, 2));
            output.show();
        } catch (error) {
            vscode.window.showErrorMessage(`Analysis failed: ${error.message}`);
        }
    });

    let generateCommand = vscode.commands.registerCommand('mcp-azure.generateCode', async () => {
        const description = await vscode.window.showInputBox({
            prompt: 'Describe the code you want to generate',
            placeHolder: 'e.g., Function to validate email addresses'
        });

        if (!description) return;

        const language = await vscode.window.showQuickPick(
            ['javascript', 'python', 'java', 'csharp', 'go'],
            { placeHolder: 'Select target language' }
        );

        if (!language) return;

        try {
            const response = await callMCPTool('generate_code', {
                description: description,
                language: language
            });

            // Create new document with generated code
            const doc = await vscode.workspace.openTextDocument({
                language: language,
                content: response.code
            });
            await vscode.window.showTextDocument(doc);
        } catch (error) {
            vscode.window.showErrorMessage(`Generation failed: ${error.message}`);
        }
    });

    context.subscriptions.push(analyzeCommand, generateCommand);
}

async function callMCPTool(toolName, args) {
    // Initialize session if needed
    if (!sessionId) {
        await initializeMCPSession();
    }

    const response = await axios.post(
        `${MCP_BASE_URL}/command`,
        {
            jsonrpc: '2.0',
            id: Date.now().toString(),
            method: 'tools/call',
            params: {
                name: toolName,
                arguments: args
            }
        },
        {
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
                'X-Session-Id': sessionId
            }
        }
    );

    return response.data.result;
}

module.exports = { activate };
```

3. **Create `package.json`**:
```json
{
  "name": "vscode-mcp-azure",
  "displayName": "MCP Azure Tools",
  "version": "1.0.0",
  "engines": {
    "vscode": "^1.74.0"
  },
  "activationEvents": [
    "onCommand:mcp-azure.analyzeCode",
    "onCommand:mcp-azure.generateCode"
  ],
  "main": "./extension.js",
  "contributes": {
    "commands": [
      {
        "command": "mcp-azure.analyzeCode",
        "title": "MCP: Analyze Current File"
      },
      {
        "command": "mcp-azure.generateCode",
        "title": "MCP: Generate Code"
      }
    ],
    "keybindings": [
      {
        "command": "mcp-azure.analyzeCode",
        "key": "ctrl+shift+a",
        "mac": "cmd+shift+a"
      },
      {
        "command": "mcp-azure.generateCode",
        "key": "ctrl+shift+g",
        "mac": "cmd+shift+g"
      }
    ]
  }
}
```

### Option 3: Direct API Integration

Use the MCP server directly from VSCode tasks or scripts:

1. **Create `.vscode/tasks.json`**:
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Analyze with MCP",
      "type": "shell",
      "command": "curl",
      "args": [
        "-X", "POST",
        "https://mcp0724-apim-dev-z0lvf7cp.azure-api.net/mcp/command",
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer ${env:MCP_TOKEN}",
        "-H", "X-Session-Id: vscode-session",
        "-d", "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"tools/call\",\"params\":{\"name\":\"analyze_code\",\"arguments\":{\"code\":\"${file}\",\"language\":\"${fileExtname}\",\"analysis_type\":\"all\"}}}"
      ],
      "problemMatcher": []
    }
  ]
}
```

## Authentication Setup

### Getting Access Token

1. Use Azure CLI:
```bash
az account get-access-token --resource api://c1de1621-a378-469d-8e17-b5c2d3b94bee
```

2. Or use the test client to get a token and save it:
```bash
export MCP_TOKEN="your-access-token"
```

## Testing the Integration

1. Open a code file in VSCode
2. Run Command Palette (Cmd/Ctrl + Shift + P)
3. Type "MCP" to see available commands
4. Select "MCP: Analyze Current File" or "MCP: Generate Code"

## Security Best Practices

1. **Token Management**:
   - Store tokens securely in VSCode Secret Storage
   - Implement token refresh logic
   - Never commit tokens to source control

2. **API Keys**:
   - Use environment variables
   - Rotate keys regularly
   - Limit scope to minimum required permissions

## Troubleshooting

### Common Issues

1. **401 Unauthorized**:
   - Check token expiration
   - Verify Azure AD configuration
   - Ensure correct scopes

2. **404 Not Found**:
   - Verify API Management URL
   - Check endpoint paths
   - Ensure policies are applied

3. **CORS Errors**:
   - Only affects browser-based clients
   - VSCode extensions bypass CORS

## Next Steps

1. Implement token refresh logic
2. Add more MCP tools (debugging, testing, documentation)
3. Create code lenses for inline analysis
4. Add support for workspace-wide operations
5. Integrate with VSCode's AI features

## Resources

- [VSCode Extension API](https://code.visualstudio.com/api)
- [MCP Protocol Specification](https://github.com/modelcontextprotocol/specification)
- [Azure AD Authentication](https://docs.microsoft.com/en-us/azure/active-directory/develop/)