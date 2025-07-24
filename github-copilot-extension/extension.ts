import * as vscode from 'vscode';
import { MCPClient } from './mcp-client';

let mcpClient: MCPClient | undefined;

export function activate(context: vscode.ExtensionContext) {
    console.log('MCP Azure Extension activated');

    // Register commands
    const connectCommand = vscode.commands.registerCommand('mcp-azure.connect', async () => {
        await connectToMCPServer();
    });

    const disconnectCommand = vscode.commands.registerCommand('mcp-azure.disconnect', async () => {
        await disconnectFromMCPServer();
    });

    const analyzeCodeCommand = vscode.commands.registerCommand('mcp-azure.analyzeCode', async () => {
        await analyzeCurrentCode();
    });

    const generateCodeCommand = vscode.commands.registerCommand('mcp-azure.generateCode', async () => {
        await generateCode();
    });

    const listToolsCommand = vscode.commands.registerCommand('mcp-azure.listTools', async () => {
        await listAvailableTools();
    });

    // Register Copilot chat participant
    const chatParticipant = vscode.chat.createChatParticipant('mcp-azure', async (request, context, response, token) => {
        if (!mcpClient) {
            response.markdown('Please connect to MCP server first using command: `MCP Azure: Connect`');
            return;
        }

        try {
            // Handle different types of requests
            if (request.prompt.toLowerCase().includes('analyze')) {
                await handleAnalyzeRequest(request, response);
            } else if (request.prompt.toLowerCase().includes('generate')) {
                await handleGenerateRequest(request, response);
            } else {
                await handleGeneralRequest(request, response);
            }
        } catch (error) {
            response.markdown(`Error: ${error}`);
        }
    });

    chatParticipant.iconPath = vscode.Uri.joinPath(context.extensionUri, 'icon.png');
    
    // Add to subscriptions
    context.subscriptions.push(
        connectCommand,
        disconnectCommand,
        analyzeCodeCommand,
        generateCodeCommand,
        listToolsCommand,
        chatParticipant
    );

    // Auto-connect if configured
    const config = vscode.workspace.getConfiguration('mcp-azure');
    if (config.get('autoConnect')) {
        connectToMCPServer();
    }
}

async function connectToMCPServer() {
    try {
        const config = vscode.workspace.getConfiguration('mcp-azure');
        
        mcpClient = new MCPClient({
            apiBaseUrl: config.get('apiBaseUrl') || '',
            clientId: config.get('clientId') || '',
            tenantId: config.get('tenantId') || '',
            scope: config.get('scope') || `api://${config.get('clientId')}/.default`,
        });

        await mcpClient.connect();
        
        // Update status bar
        updateStatusBar(true);
        
    } catch (error) {
        vscode.window.showErrorMessage(`Failed to connect to MCP server: ${error}`);
    }
}

async function disconnectFromMCPServer() {
    if (mcpClient) {
        await mcpClient.disconnect();
        mcpClient = undefined;
        updateStatusBar(false);
        vscode.window.showInformationMessage('Disconnected from MCP server');
    }
}

async function analyzeCurrentCode() {
    if (!mcpClient) {
        vscode.window.showErrorMessage('Not connected to MCP server');
        return;
    }

    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showErrorMessage('No active editor');
        return;
    }

    const code = editor.document.getText();
    const language = editor.document.languageId;

    try {
        const result = await mcpClient.callTool('analyze_code', {
            code,
            language,
            analysis_type: 'all',
        });

        // Show results in output channel
        const outputChannel = vscode.window.createOutputChannel('MCP Analysis');
        outputChannel.appendLine('Code Analysis Results:');
        outputChannel.appendLine(JSON.stringify(result, null, 2));
        outputChannel.show();

    } catch (error) {
        vscode.window.showErrorMessage(`Analysis failed: ${error}`);
    }
}

async function generateCode() {
    if (!mcpClient) {
        vscode.window.showErrorMessage('Not connected to MCP server');
        return;
    }

    const description = await vscode.window.showInputBox({
        prompt: 'Describe the code you want to generate',
        placeHolder: 'e.g., Function to validate email addresses',
    });

    if (!description) {
        return;
    }

    const language = await vscode.window.showQuickPick(
        ['python', 'javascript', 'typescript', 'java', 'csharp', 'go'],
        { placeHolder: 'Select target language' }
    );

    if (!language) {
        return;
    }

    try {
        const result = await mcpClient.callTool('generate_code', {
            description,
            language,
        });

        // Create new document with generated code
        const document = await vscode.workspace.openTextDocument({
            language,
            content: result.code,
        });
        
        await vscode.window.showTextDocument(document);

    } catch (error) {
        vscode.window.showErrorMessage(`Code generation failed: ${error}`);
    }
}

async function listAvailableTools() {
    if (!mcpClient) {
        vscode.window.showErrorMessage('Not connected to MCP server');
        return;
    }

    try {
        const tools = await mcpClient.listTools();
        
        const quickPickItems = tools.map(tool => ({
            label: tool.name,
            description: tool.description,
            detail: JSON.stringify(tool.inputSchema, null, 2),
        }));

        const selected = await vscode.window.showQuickPick(quickPickItems, {
            placeHolder: 'Available MCP Tools',
            matchOnDescription: true,
        });

        if (selected) {
            // Show tool details
            const outputChannel = vscode.window.createOutputChannel('MCP Tool Details');
            outputChannel.appendLine(`Tool: ${selected.label}`);
            outputChannel.appendLine(`Description: ${selected.description}`);
            outputChannel.appendLine('Input Schema:');
            outputChannel.appendLine(selected.detail);
            outputChannel.show();
        }

    } catch (error) {
        vscode.window.showErrorMessage(`Failed to list tools: ${error}`);
    }
}

async function handleAnalyzeRequest(request: vscode.ChatRequest, response: vscode.ChatResponseStream) {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        response.markdown('No active editor found. Please open a file to analyze.');
        return;
    }

    response.progress('Analyzing code...');

    const result = await mcpClient!.callTool('analyze_code', {
        code: editor.document.getText(),
        language: editor.document.languageId,
        analysis_type: 'all',
    });

    response.markdown(`## Code Analysis Results\n\n`);
    response.markdown(`**Language:** ${result.language}\n`);
    response.markdown(`**Lines:** ${result.metrics.lines}\n`);
    response.markdown(`**Complexity:** ${result.metrics.complexity}\n\n`);

    if (result.issues.length > 0) {
        response.markdown(`### Issues Found\n`);
        result.issues.forEach((issue: any) => {
            response.markdown(`- ${issue}\n`);
        });
    }

    if (result.suggestions.length > 0) {
        response.markdown(`\n### Suggestions\n`);
        result.suggestions.forEach((suggestion: any) => {
            response.markdown(`- ${suggestion}\n`);
        });
    }
}

async function handleGenerateRequest(request: vscode.ChatRequest, response: vscode.ChatResponseStream) {
    const match = request.prompt.match(/generate\s+(.+)\s+in\s+(\w+)/i);
    
    if (!match) {
        response.markdown('Please specify what to generate and the language. Example: "generate a function to validate email in python"');
        return;
    }

    const description = match[1];
    const language = match[2].toLowerCase();

    response.progress('Generating code...');

    const result = await mcpClient!.callTool('generate_code', {
        description,
        language,
    });

    response.markdown(`## Generated ${language} Code\n\n`);
    response.markdown(`\`\`\`${language}\n${result.code}\n\`\`\``);
    
    // Add button to insert code
    response.button({
        command: 'mcp-azure.insertCode',
        title: 'Insert Code',
        arguments: [result.code],
    });
}

async function handleGeneralRequest(request: vscode.ChatRequest, response: vscode.ChatResponseStream) {
    // List available tools and resources
    const tools = await mcpClient!.listTools();
    const resources = await mcpClient!.listResources();

    response.markdown(`## MCP Server Capabilities\n\n`);
    
    response.markdown(`### Available Tools\n`);
    tools.forEach(tool => {
        response.markdown(`- **${tool.name}**: ${tool.description}\n`);
    });

    response.markdown(`\n### Available Resources\n`);
    resources.forEach(resource => {
        response.markdown(`- **${resource.name}**: ${resource.description}\n`);
    });

    response.markdown(`\n### Commands\n`);
    response.markdown(`- Ask me to "analyze" the current code\n`);
    response.markdown(`- Ask me to "generate" code with a description\n`);
}

let statusBarItem: vscode.StatusBarItem;

function updateStatusBar(connected: boolean) {
    if (!statusBarItem) {
        statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    }

    statusBarItem.text = connected ? '$(cloud) MCP Connected' : '$(cloud-offline) MCP Disconnected';
    statusBarItem.command = connected ? 'mcp-azure.disconnect' : 'mcp-azure.connect';
    statusBarItem.show();
}

export function deactivate() {
    if (mcpClient) {
        mcpClient.disconnect();
    }
    
    if (statusBarItem) {
        statusBarItem.dispose();
    }
}