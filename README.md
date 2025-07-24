# MCP Azure Server for GitHub Copilot

A secure Model Context Protocol (MCP) server implementation using Azure Functions and API Management, designed to integrate with GitHub Copilot via OAuth2 authentication.

## 🚀 Features

- **Secure OAuth2 Authentication**: Azure AD integration with JWT validation
- **Real-time Communication**: Server-Sent Events (SSE) for streaming responses
- **Enterprise-Ready**: Rate limiting, CORS, security headers, and audit logging
- **Fully Managed**: Serverless architecture with Azure Functions
- **Observable**: Built-in Application Insights monitoring
- **Extensible**: Easy to add custom tools and resources

## 📖 Documentation

- **[Quick Start Guide](./docs/QUICK_START.md)** - Get running in 15 minutes
- **[Complete Documentation](./docs/README.md)** - All documentation
- **[Architecture Guide](./docs/ARCHITECTURE_GUIDE.md)** - System design
- **[MCP Protocol Deep Dive](./docs/MCP_PROTOCOL_DEEP_DIVE.md)** - Protocol details

## 🏗️ Architecture

```
GitHub Copilot ←→ Azure API Management ←→ Azure Functions ←→ Azure Services
                        ↓                        ↓
                   Azure AD Auth            Key Vault
                                          App Insights
```

## 🚦 Quick Start

### Prerequisites

- Azure subscription
- Azure CLI
- OpenTofu
- Python 3.11+
- VS Code with GitHub Copilot

### Deploy in 15 Minutes

```bash
# Clone repository
git clone https://github.com/your-org/copilot-mcp-azure.git
cd copilot-mcp-azure

# Login to Azure
az login

# Deploy infrastructure
cd azure-mcp-server/infrastructure/opentofu
./deploy.sh
```

See the [Quick Start Guide](./docs/QUICK_START.md) for detailed instructions.

## 🧪 Testing

Open `azure-mcp-server/tests/test_client.html` in a browser to test your deployment interactively.

## 🛡️ Security

- OAuth2/JWT authentication with Azure AD
- Per-user rate limiting
- Comprehensive audit logging
- Security headers and CORS policies
- Managed identities for Azure resources

See [Security Best Practices](./azure-mcp-server/docs/SECURITY.md) for details.

## 📁 Project Structure

```
copilot-mcp-azure/
├── docs/                          # Comprehensive documentation
├── azure-mcp-server/              # Server implementation
│   ├── src/                       # Python source code
│   ├── infrastructure/            # OpenTofu/Bicep IaC
│   └── tests/                     # Test suites
└── github-copilot-extension/      # VS Code extension
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for GitHub Copilot integration
- Uses the Model Context Protocol (MCP)
- Powered by Azure cloud services

---

**Ready to get started?** Check out the [Quick Start Guide](./docs/QUICK_START.md)!