param dataCollectionEndpointId string
param logAnalyticsWorkspaceId string
@description('Name of the custom log table to create (NOTE: Do not include _CL suffix)')
param customLogName string
@description('Custom Table Retention in days')
param customLogRetentionInDays int = 30
@description('Location for all resources')
param location string = resourceGroup().location
param tags object
param dcrColumns array
param principalId string
param transformKql string

var sanitisedResourceName = toLower(customLogName)

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: last(split(logAnalyticsWorkspaceId, '/'))
}

// Create the log analytics table if it doesn't exist
resource customLogTable 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  name: '${customLogName}_CL'
  parent: logAnalyticsWorkspace
  properties: {
    retentionInDays: customLogRetentionInDays
    schema: {
      name: '${customLogName}_CL'
      columns: dcrColumns
    }
  }
}

resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: '${sanitisedResourceName}-dcr'
  location: location
  tags: tags
  properties: {
    dataCollectionEndpointId: dataCollectionEndpointId
    streamDeclarations: {
      'Custom-${customLogTable.name}': {
        columns: dcrColumns
      }
    }
    dataSources: {}
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id
          name: guid(logAnalyticsWorkspace.id, customLogTable.name)
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Custom-${customLogTable.name}'
        ]
        destinations: [
          guid(logAnalyticsWorkspace.id, customLogTable.name)
        ]
        transformKql: transformKql
        outputStream: 'Custom-${customLogTable.name}'
      }
    ]
  }
}

// Add a role assignment for the Monitoring Metrics Publisher role on the DCR to allow it to write to the Log Analytics workspace
resource roleAssignmentDCR 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, dcr.id, logAnalyticsWorkspace.id, 'Monitoring Metrics Publisher')
  scope: dcr
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '3913510d-42f4-4e42-8a64-420c390055eb'
    )
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output dcrImmutableId string = dcr.properties.immutableId
output customLogTableName string = customLogTable.name
