@description('The name of the environment (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('The Azure region for resources')
param location string = resourceGroup().location

@description('The base name for resources')
param baseName string = 'mcp-server'

@description('Azure AD tenant ID')
param azureAdTenantId string

@description('Azure AD client ID for the application')
param azureAdClientId string

@description('GitHub organization allowed to access the API')
param githubOrganization string = ''

var uniqueSuffix = uniqueString(resourceGroup().id)
var functionAppName = '${baseName}-func-${environment}-${uniqueSuffix}'
var appServicePlanName = '${baseName}-plan-${environment}'
var storageAccountName = replace('${baseName}${environment}${uniqueSuffix}', '-', '')
var appInsightsName = '${baseName}-insights-${environment}'
var keyVaultName = '${baseName}-kv-${environment}-${uniqueSuffix}'
var apimName = '${baseName}-apim-${environment}'
var logAnalyticsName = '${baseName}-logs-${environment}'

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      pythonVersion: '3.11'
      linuxFxVersion: 'Python|3.11'
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: functionAppName
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AZURE_TENANT_ID'
          value: azureAdTenantId
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: azureAdClientId
        }
        {
          name: 'KEY_VAULT_URL'
          value: keyVault.properties.vaultUri
        }
        {
          name: 'SESSION_SECRET'
          value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/session-secret/)'
        }
        {
          name: 'GITHUB_ORGANIZATION'
          value: githubOrganization
        }
      ]
      cors: {
        allowedOrigins: [
          'https://github.com'
          'https://copilot.github.com'
          'vscode://*'
          'vscode-insiders://*'
        ]
      }
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

// API Management
resource apim 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apimName
  location: location
  sku: {
    name: environment == 'prod' ? 'Standard' : 'Developer'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: 'admin@example.com'
    publisherName: 'MCP Server Admin'
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
    }
  }
}

// API Management Logger
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2022-08-01' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsights.properties.InstrumentationKey
    }
  }
}

// API in API Management
resource mcpApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  parent: apim
  name: 'mcp-api'
  properties: {
    displayName: 'MCP Server API'
    description: 'Model Context Protocol server for GitHub Copilot'
    path: 'mcp'
    protocols: ['https']
    serviceUrl: 'https://${functionApp.properties.defaultHostName}/api'
    subscriptionRequired: false
    authenticationSettings: {
      oAuth2AuthenticationSettings: [
        {
          authorizationServerId: 'azuread'
        }
      ]
    }
  }
}

// OAuth2 Authorization Server
resource oauth2Server 'Microsoft.ApiManagement/service/authorizationServers@2022-08-01' = {
  parent: apim
  name: 'azuread'
  properties: {
    displayName: 'Azure AD'
    clientRegistrationEndpoint: 'https://portal.azure.com'
    authorizationEndpoint: 'https://login.microsoftonline.com/${azureAdTenantId}/oauth2/v2.0/authorize'
    tokenEndpoint: 'https://login.microsoftonline.com/${azureAdTenantId}/oauth2/v2.0/token'
    defaultScope: 'api://${azureAdClientId}/.default'
    clientId: azureAdClientId
    grantTypes: ['authorizationCode', 'clientCredentials']
    authorizationMethods: ['GET', 'POST']
    bearerTokenSendingMethods: ['authorizationHeader']
  }
}

// API Operations
resource streamOperation 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: mcpApi
  name: 'stream'
  properties: {
    displayName: 'SSE Stream'
    method: 'GET'
    urlTemplate: '/stream'
    description: 'Server-Sent Events stream for MCP communication'
    responses: [
      {
        statusCode: 200
        description: 'SSE stream'
        headers: [
          {
            name: 'Content-Type'
            type: 'string'
            values: ['text/event-stream']
          }
        ]
      }
    ]
  }
}

resource commandOperation 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: mcpApi
  name: 'command'
  properties: {
    displayName: 'MCP Command'
    method: 'POST'
    urlTemplate: '/command'
    description: 'Execute MCP commands'
    request: {
      headers: [
        {
          name: 'Content-Type'
          type: 'string'
          values: ['application/json']
          required: true
        }
        {
          name: 'X-Session-Id'
          type: 'string'
          required: true
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Command executed successfully'
      }
    ]
  }
}

// Role Assignments
resource functionAppKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, functionApp.id, 'Key Vault Secrets User')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource apimKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, apim.id, 'Key Vault Secrets User')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: apim.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimDeveloperPortalUrl string = apim.properties.developerPortalUrl
output keyVaultName string = keyVault.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString