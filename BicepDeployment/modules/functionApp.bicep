@description('Location for all resources')
param location string

@description('Base name for all resources')
param resourceName string

@description('Function runtime name (e.g. powershell)')
param functionAppRuntimeName string

@description('Function runtime version (e.g. ~4)')
param functionAppRuntimeVersion string

@description('User-Assigned Identity resource ID')
param identityResourceId string

@description('User-Assigned Identity client ID')
param identityClientId string

@description('Storage account name')
param storageAccountName string

@description('Name of the blob container holding Sponsors.png')
param deploymentContainerName string

@description('Connection string for the same App Insights component')
param applicationInsightsConnectionString string

@description('Application Insights resource ID')
param applicationInsightsId string

@description('Application Insights instrumentation key')
param applicationInsightsInstrumentationKey string

@description('Log Ingestion Endpoint for the Data Collection Rule')
param dcrUri string

@description('DCR Mapping for multiple tables')
param dcrContentTableVar string

param tags object

var sanitisedResourceName = toLower(resourceName)
var appName = '${sanitisedResourceName}-fa'
var blobContainerUrl = 'https://${storageAccountName}.blob.core.windows.net/'
var tableStorageUrl = 'https://${storageAccountName}.table.core.windows.net/'

//––– App Service Plan –––
resource appServicePlan 'Microsoft.Web/serverfarms@2018-11-01' = {
  name: '${sanitisedResourceName}-asp'
  location: location
  tags: tags
  kind: ''
  properties: {
    name: '${sanitisedResourceName}-asp'
    workerSize: 0
    workerSizeId: 0
    numberOfWorkers: 1
  }
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

//––– Function App –––
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: appName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityResourceId}': {}
    }
  }
  tags: {
    ...tags
    'hidden-link: /app-insights-resource-id': applicationInsightsId
    'hidden-link: /app-insights-instrumentation-key': applicationInsightsInstrumentationKey
    'hidden-link: /app-insights-conn-string': applicationInsightsConnectionString
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: [
          '*'
        ]
      }
      use32BitWorkerProcess: false
      alwaysOn: false
      publicNetworkAccess: 'Enabled'
      ftpsState: 'Disabled'
      powerShellVersion: string(functionAppRuntimeVersion)
      netFrameworkVersion: 'v8.0'
      appSettings: [
        // These runtime settings are critical
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: string(functionAppRuntimeName)
        }
        // Identity-based storage configuration - no keys needed
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: identityClientId
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: blobContainerUrl
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: tableStorageUrl
        }
        // App Insights settings
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'APPLICATIONINSIGHTS_AUTHENTICATION_STRING'
          value: 'ClientId=${identityClientId};Authorization=AAD'
        }
        // Deployment configuration
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: 'https://${storageAccountName}.blob.core.windows.net/packages/package.zip'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_RESOURCE_ID'
          value: identityResourceId
        }
        // Your custom settings
        {
          name: 'SPONSORS_BLOB_NAME'
          value: 'Sponsors.png'
        }
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'AZURE_RESOURCE_GROUP_NAME'
          value: resourceGroup().name
        }
        {
          name: 'CONFIG_CONTAINER_NAME'
          value: deploymentContainerName
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: identityClientId
        }
        {
          name: 'DCR_URI'
          value: dcrUri
        }
        {
          name: 'DCR_TABLE'
          value: dcrContentTableVar
        }
      ]
    }
  }
}
