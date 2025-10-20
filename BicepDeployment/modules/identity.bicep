param location string
param resourceName string
param tags object

var sanitisedResourceName = toLower(resourceName)

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${sanitisedResourceName}-uai'
  tags: tags
  location: location
}

output identityResourceId string = userAssignedIdentity.id
output identityPrincipalId string = userAssignedIdentity.properties.principalId
output identityClientId string = userAssignedIdentity.properties.clientId
