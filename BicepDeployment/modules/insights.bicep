param location string
param resourceName string
param principalId string
param tags object

var monitoringMetricsPublisherId = '3913510d-42f4-4e42-8a64-420c390055eb'
var sanitisedResourceName = toLower(resourceName)

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${sanitisedResourceName}-la'
  tags: tags
  location: location
  properties: {
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${sanitisedResourceName}-insights'
  tags: tags
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    DisableLocalAuth: true
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource roleAssignmentAppInsights 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, applicationInsights.id, principalId, 'Monitoring Metrics Publisher')
  scope: applicationInsights
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.id
output applicationInsightsId string = applicationInsights.id
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
