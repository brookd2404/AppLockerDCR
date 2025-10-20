// storageAccount.bicep
// (this file gets called as a module from main.bicep)

@description('Name of the Storage Account')
param resourceName string
@description('Location for all resources')
param location string = resourceGroup().location
@description('Array of container objects to create')
param containers array = []
@description('Allow or disallow anonymous (public) blob/container access')
param allowBlobPublicAccess bool = false
// Optional: SKU, kind, tags—feel free to expose more if you like
param skuName string = 'Standard_LRS'
param kind string = 'StorageV2'
param tags object
param principalId string // <- add this

var sanitisedResourceName = toLower(resourceName)
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageTableDataContributorId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'

module stg 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: 'avmStorage'
  params: {
    name: '${sanitisedResourceName}st'
    location: location
    skuName: skuName
    kind: kind
    tags: tags
    publicNetworkAccess: 'Enabled' // if you’re still using public network
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow' // <— allow all traffic by default
    }
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: true
    allowBlobPublicAccess: allowBlobPublicAccess // <— explicitly set it
    blobServices: {
      containers: [
        for c in containers: {
          name: c.name
          publicAccess: 'None' // <— no anonymous access per-container
          metadata: c.metadata
        }
      ]
    }
    roleAssignments: [
      {
        name: guid(location, principalId, storageBlobDataOwnerRoleId) // Storage Blob Data Owner
        principalId: principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: storageBlobDataOwnerRoleId
      }
      {
        name: guid(location, principalId, storageBlobDataContributorRoleId) // Storage Blob Data Contributor
        principalId: principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: storageBlobDataContributorRoleId
      }
      {
        name: guid(location, principalId, storageTableDataContributorId) // Storage Table Contributor
        principalId: principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: storageTableDataContributorId
      }
    ]
  }
}

// Re-expose what you need for later
output storageAccountName string = stg.outputs.name
output storageAccountId string = stg.outputs.resourceId
output primaryBlobEndpointUri string = stg.outputs.primaryBlobEndpoint
