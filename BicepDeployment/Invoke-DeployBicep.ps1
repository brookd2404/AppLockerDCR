<#
.SYNOPSIS
    This script is used to deploy the Bicep Resources for the App Locker DCR Solution
.DESCRIPTION
    This script deploys the necessary Bicep resources to set up the App Locker DCR Solution in your Azure environment. It requires the Bicep CLI and appropriate permissions to deploy resources.
.NOTES
    This script requires the Azure PowerShell module and the Bicep CLI to be installed.

    There MUST BE a bicepparam file with the same name as the bicep file in the same directory.
.LINK
    https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview
.EXAMPLE
    Invoke-DeployBicep.ps1 -bicepFilePath "C:\Path\To\Your\File.bicep" -resourceGroupName "MyResourceGroup" -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $subscriptionId,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { 
            Test-Path $_
        } )]
    [string]
    $bicepFilePath,
    [Parameter(Mandatory = $true)]
    [string]
    $resourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]
    $resourceName
)

#Connect to Azure Account
Write-Verbose "Connecting to Azure Account"
Connect-AzAccount -Subscription $subscriptionId

#Check if the resource group exists, if not exit with error
$rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Error "Resource Group '$resourceGroupName' does not exist. Please create it before deploying the Bicep file."
    return
} else {
    Write-Verbose "Resource Group '$resourceGroupName' found."
}

#Deploy the Bicep file
Write-Verbose "Deploying Bicep file: $bicepFilePath to Resource Group: $resourceGroupName"
try {
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $bicepFilePath -Verbose
    Write-Verbose "Bicep deployment completed successfully."
} catch {
    Write-Error "Bicep deployment failed: $_"
}

#Zip and upload the Function App Assets
try {
    $assetFolder = $(Get-Location).Path + "\Assets\FunctionApp"
    $zipFilePath = "$env:TEMP\package.zip"
    $storageAccountName = "$($resourceName.ToLower())st"
    if (-not (Test-Path -Path $assetFolder)) {
        Write-Error "Asset folder not found at path: $assetFolder"
        return
    }
    Write-Verbose "Zipping Function App assets from $assetFolder to $zipFilePath"
    Compress-Archive -Path "$assetFolder\*" -DestinationPath $zipFilePath -Force
    Write-Verbose "Uploading Function App assets to Azure Function App"

    $stCTX = New-AzStorageContext -StorageAccountName $storageAccountName
    $uploadBlob = Set-AzStorageBlobContent -File $zipFilePath -Container 'packages' -Blob 'package.zip' -Context $stCTX -Force
    Write-Verbose "Function App assets uploaded successfully."

} catch {
    Write-Error "Failed to zip and upload Function App assets: $_"
}
