import * as vscode from 'vscode';
import { EventSource } from 'eventsource';
import axios, { AxiosInstance } from 'axios';

interface MCPConfig {
  apiBaseUrl: string;
  clientId: string;
  tenantId: string;
  scope: string;
}

interface MCPSession {
  sessionId: string;
  accessToken: string;
  eventSource?: EventSource;
}

export class MCPClient {
  private config: MCPConfig;
  private session?: MCPSession;
  private axiosInstance: AxiosInstance;
  private messageHandlers: Map<string, (data: any) => void> = new Map();

  constructor(config: MCPConfig) {
    this.config = config;
    this.axiosInstance = axios.create({
      baseURL: config.apiBaseUrl,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Add request interceptor for authentication
    this.axiosInstance.interceptors.request.use(
      (config) => {
        if (this.session?.accessToken) {
          config.headers.Authorization = `Bearer ${this.session.accessToken}`;
          config.headers['X-Session-Id'] = this.session.sessionId;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Add response interceptor for token refresh
    this.axiosInstance.interceptors.response.use(
      (response) => response,
      async (error) => {
        if (error.response?.status === 401) {
          await this.refreshToken();
          return this.axiosInstance.request(error.config);
        }
        return Promise.reject(error);
      }
    );
  }

  /**
   * Initialize MCP connection with OAuth2 authentication
   */
  async connect(): Promise<void> {
    try {
      // Get access token using VS Code authentication provider
      const session = await vscode.authentication.getSession(
        'microsoft',
        [this.config.scope],
        { createIfNone: true }
      );

      if (!session) {
        throw new Error('Failed to authenticate with Azure AD');
      }

      this.session = {
        sessionId: '',
        accessToken: session.accessToken,
      };

      // Initialize MCP session
      const initResponse = await this.sendRequest('initialize', {
        clientInfo: {
          name: 'GitHub Copilot',
          version: vscode.version,
        },
        capabilities: {
          tools: true,
          resources: true,
          prompts: true,
          sampling: true,
        },
      });

      // Connect to SSE stream
      await this.connectSSE();

      vscode.window.showInformationMessage('Connected to MCP server');
    } catch (error) {
      vscode.window.showErrorMessage(`Failed to connect: ${error}`);
      throw error;
    }
  }

  /**
   * Connect to Server-Sent Events stream
   */
  private async connectSSE(): Promise<void> {
    if (!this.session) {
      throw new Error('No active session');
    }

    const eventSourceUrl = `${this.config.apiBaseUrl}/mcp/stream`;
    
    this.session.eventSource = new EventSource(eventSourceUrl, {
      headers: {
        'Authorization': `Bearer ${this.session.accessToken}`,
        'X-Session-Id': this.session.sessionId,
      },
    });

    this.session.eventSource.onopen = () => {
      console.log('SSE connection established');
    };

    this.session.eventSource.onmessage = (event) => {
      this.handleSSEMessage(event);
    };

    this.session.eventSource.onerror = (error) => {
      console.error('SSE error:', error);
      this.reconnectSSE();
    };

    // Handle specific event types
    this.session.eventSource.addEventListener('connected', (event: any) => {
      const data = JSON.parse(event.data);
      this.session!.sessionId = data.session_id;
      console.log('Session established:', this.session!.sessionId);
    });

    this.session.eventSource.addEventListener('message', (event: any) => {
      const message = JSON.parse(event.data);
      this.handleMCPMessage(message);
    });

    this.session.eventSource.addEventListener('heartbeat', (event: any) => {
      // Handle heartbeat to keep connection alive
    });
  }

  /**
   * Reconnect SSE stream
   */
  private async reconnectSSE(): Promise<void> {
    if (this.session?.eventSource) {
      this.session.eventSource.close();
    }

    // Wait before reconnecting
    await new Promise(resolve => setTimeout(resolve, 5000));

    try {
      await this.connectSSE();
    } catch (error) {
      console.error('Failed to reconnect SSE:', error);
    }
  }

  /**
   * Handle SSE messages
   */
  private handleSSEMessage(event: MessageEvent): void {
    try {
      const data = JSON.parse(event.data);
      console.log('SSE message:', data);
    } catch (error) {
      console.error('Failed to parse SSE message:', error);
    }
  }

  /**
   * Handle MCP protocol messages
   */
  private handleMCPMessage(message: any): void {
    if (message.id && this.messageHandlers.has(message.id)) {
      const handler = this.messageHandlers.get(message.id)!;
      handler(message);
      this.messageHandlers.delete(message.id);
    }

    // Handle notifications
    if (!message.id && message.method) {
      this.handleNotification(message);
    }
  }

  /**
   * Handle MCP notifications
   */
  private handleNotification(notification: any): void {
    console.log('MCP notification:', notification);
    // Handle specific notification types
  }

  /**
   * Send MCP request
   */
  async sendRequest(method: string, params?: any): Promise<any> {
    const requestId = this.generateRequestId();
    
    const request = {
      jsonrpc: '2.0',
      id: requestId,
      method,
      params,
    };

    // Create promise for response
    const responsePromise = new Promise((resolve, reject) => {
      this.messageHandlers.set(requestId, (response) => {
        if (response.error) {
          reject(new Error(response.error.message));
        } else {
          resolve(response.result);
        }
      });

      // Timeout after 30 seconds
      setTimeout(() => {
        if (this.messageHandlers.has(requestId)) {
          this.messageHandlers.delete(requestId);
          reject(new Error('Request timeout'));
        }
      }, 30000);
    });

    // Send request
    await this.axiosInstance.post('/mcp/command', request);

    return responsePromise;
  }

  /**
   * List available tools
   */
  async listTools(): Promise<any[]> {
    const response = await this.sendRequest('tools/list');
    return response.tools || [];
  }

  /**
   * Call a tool
   */
  async callTool(name: string, args: any): Promise<any> {
    const response = await this.sendRequest('tools/call', {
      name,
      arguments: args,
    });
    return response.toolResult;
  }

  /**
   * List available resources
   */
  async listResources(): Promise<any[]> {
    const response = await this.sendRequest('resources/list');
    return response.resources || [];
  }

  /**
   * Read a resource
   */
  async readResource(uri: string): Promise<any> {
    const response = await this.sendRequest('resources/read', { uri });
    return response.contents;
  }

  /**
   * Refresh access token
   */
  private async refreshToken(): Promise<void> {
    const session = await vscode.authentication.getSession(
      'microsoft',
      [this.config.scope],
      { forceNewSession: true }
    );

    if (session && this.session) {
      this.session.accessToken = session.accessToken;
    }
  }

  /**
   * Generate unique request ID
   */
  private generateRequestId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Disconnect from MCP server
   */
  async disconnect(): Promise<void> {
    if (this.session?.eventSource) {
      this.session.eventSource.close();
    }

    await this.sendRequest('shutdown').catch(() => {});
    
    this.session = undefined;
    this.messageHandlers.clear();
  }
}