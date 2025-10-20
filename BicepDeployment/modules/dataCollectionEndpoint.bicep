@description('Name of the Data Collection Endpoint')
param resourceName string
@description('Location for all resources')
param location string = resourceGroup().location
param tags object = {}
param enablePublicNetworkAccess bool

var sanitisedResourceName = toLower(resourceName)

resource dce 'Microsoft.Insights/dataCollectionEndpoints@2023-03-11' = {
  name: '${sanitisedResourceName}dce'
  location: location
  tags: tags
  properties: {
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
  }
}

output dataCollectionEndpointId string = dce.id
output logIngestionUri string = dce.properties.logsIngestion.endpoint
