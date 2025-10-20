@description('The unique name of the Azure Monitor workbook resource.')
param workbookName string

@description('The Azure region where the workbook will be deployed.')
param location string

@description('A set of tags to assign to the workbook resource.')
param tags object

@description('The display name for the workbook as shown in the Azure portal.')
param workbookDisplayName string

@description('The serialized JSON data representing the workbook content and configuration.')
param workbookSerializedData string

@description('The category under which the workbook will be listed (e.g., "workbook", "shared", etc.).')
param workbookCategory string

@description('The resource ID of the source resource associated with the workbook.')
param workbookSourceId string

resource insightsWorkbook 'Microsoft.Insights/workbooks@2020-10-20' = {
  name: workbookName
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    serializedData: workbookSerializedData
    version: '1.0'
    category: workbookCategory
    sourceId: workbookSourceId
  }
}
