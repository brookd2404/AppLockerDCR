param location string = resourceGroup().location
param functionAppRuntime string = 'powershell'
param functionAppRuntimeVersion string = '7.4'
param resourceName string = 'dcrMMSMusicTest'
param tags object = {}
@description('Define one or more blob containers')
param storageContainers array = [
  {
    name: 'packages'
    publicAccess: 'Container'
    metadata: tags
  }
]
param workbookName string = 'MMS Music 2025 AppLocker Workbook'
param workbookSerializedData string = loadTextContent('Assets/Workbooks/MMSMusicAppLocker.json')

module identity 'modules/identity.bicep' = {
  name: 'identityModule'
  params: {
    location: location
    resourceName: resourceName
    tags: tags
  }
}

module storage 'modules/storageAccount.bicep' = {
  name: 'storageModule'
  params: {
    location: location
    resourceName: resourceName
    principalId: identity.outputs.identityPrincipalId
    containers: storageContainers
    tags: tags
  }
}

module insights 'modules/insights.bicep' = {
  name: 'insightsModule'
  params: {
    location: location
    resourceName: resourceName
    principalId: identity.outputs.identityPrincipalId
    tags: tags
  }
}

module dataCollectionEndpoint 'modules/dataCollectionEndpoint.bicep' = {
  name: 'dataCollectionEndpointModule'
  params: {
    location: location
    resourceName: resourceName
    enablePublicNetworkAccess: true
    tags: tags
  }
}

module dataCollectionRule_AppLocker 'modules/dataCollectionRules.bicep' = {
  name: 'dataCollectionRule_AppLocker'
  params: {
    principalId: identity.outputs.identityPrincipalId
    location: location
    customLogName: '${resourceName}_AppLocker'
    dataCollectionEndpointId: dataCollectionEndpoint.outputs.dataCollectionEndpointId
    logAnalyticsWorkspaceId: insights.outputs.logAnalyticsWorkspaceId
    tags: tags
    dcrColumns: [
      {
        name: 'TimeGenerated'
        type: 'datetime'
      }
      {
        name: 'Computer'
        type: 'string'
      }
      {
        name: 'ManagedDeviceID'
        type: 'string'
      }
      {
        name: 'FileDescription'
        type: 'string'
      }
      {
        name: 'FileVersion'
        type: 'string'
      }
      {
        name: 'ProductName'
        type: 'string'
      }
      {
        name: 'FileHash'
        type: 'dynamic'
      }
      {
        name: 'Publisher'
        type: 'string'
      }
      {
        name: 'FullPublisherName'
        type: 'dynamic'
      }
      {
        name: 'FileUseCount'
        type: 'int'
      }
      {
        name: 'EntraDeviceID'
        type: 'string'
      }
      {
        name: 'ConnectingIP'
        type: 'string'
      }
    ]
    transformKql: 'source | extend TimeGenerated = iff(isempty(TimeGenerated), now(), TimeGenerated)'
  }
}

module workbook 'modules/insightsWorkbook.bicep' = {
  name: 'workbookModule'
  params: {
    location: location
    tags: tags
    workbookName: guid(workbookName, insights.outputs.logAnalyticsWorkspaceId)
    workbookDisplayName: workbookName
    workbookSerializedData: workbookSerializedData
    workbookCategory: 'workbook'
    workbookSourceId: insights.outputs.logAnalyticsWorkspaceId
  }
}

module functionApp 'modules/functionApp.bicep' = {
  name: 'functionAppModule'
  params: {
    location: location
    tags: tags
    resourceName: resourceName
    functionAppRuntimeName: functionAppRuntime
    functionAppRuntimeVersion: functionAppRuntimeVersion
    identityResourceId: identity.outputs.identityResourceId
    identityClientId: identity.outputs.identityClientId
    storageAccountName: storage.outputs.storageAccountName
    deploymentContainerName: storageContainers[0].name
    applicationInsightsConnectionString: insights.outputs.applicationInsightsConnectionString
    applicationInsightsId: insights.outputs.applicationInsightsId
    applicationInsightsInstrumentationKey: insights.outputs.applicationInsightsInstrumentationKey
    dcrUri: dataCollectionEndpoint.outputs.logIngestionUri
    dcrContentTableVar: '[{"id":"${dataCollectionRule_AppLocker.outputs.dcrImmutableId}","table":"${dataCollectionRule_AppLocker.outputs.customLogTableName}"}]'
  }
}
