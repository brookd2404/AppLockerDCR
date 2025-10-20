param location string
param principalId string // <- add this
param resourceName string
@allowed([false, true])
param allowSharedKeyAccess bool = false
param tags object

var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageTableDataContributorId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
var sanitisedResourceName = toLower(resourceName)
var appName = '${sanitisedResourceName}-fa'
var deploymentContainerName = 'app-package-${take(appName, 32)}-${take(sanitisedResourceName, 7)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: '${sanitisedResourceName}st'
  tags: tags
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: allowSharedKeyAccess
    dnsEndpointType: 'Standard'
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
  }
  resource blobServices 'blobServices' = {
    name: 'default'
    properties: {
      deleteRetentionPolicy: {}
    }
    resource deploymentContainer 'containers' = {
      name: deploymentContainerName
      properties: {
        publicAccess: 'None'
      }
    }
  }
}

resource roleAssignmentBlobDataOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storageAccount.id, principalId, 'Storage Blob Data Owner')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storageAccount.id, principalId, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleId
    )
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentTableContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storageAccount.id, principalId, 'Storage Table Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageTableDataContributorId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output deploymentContainerName string = deploymentContainerName
output storageAccountConnectionString string = listKeys(storageAccount.id, '2021-04-01').keys[0].value
