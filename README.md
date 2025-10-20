# Introduction

This repository contains the solution files for a Session Maurice Daly and I presented at MMS Music City Edition 2025, titled [**"Building Your Own Intune Reporting Destiny with Log Analytics and KQL"**](https://mms2025music.sched.com/event/27LYz/building-your-own-intune-reporting-destiny-with-log-analytics-and-kql).

# Prerequisites

> **NOTE:** No matter which deployment method you choose, you will need to have the Asset Folder within the same directory as the Bicep file, as the Bicep file references files within this folder for deployment.

## DevOps Pipeline

> **NOTE:** If you are using DevOps, please ensure all of the files and folders are in the root of your repository, as the pipeline references files and folders based on this structure.

To deploy using Azure DevOps, with the yaml file provided, you will need to create a service connection, and [environment](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/environments?view=azure-devops) with both Contributor, Storage Blob Data Contributor and User Access Administrator permissions to deploy resources to your Resource Group.

You must also configure the variables in the pipeline to match your environment:

- serviceConnectionName: The name of the service connection you created
- subscriptionId: The Subscription ID where the resources will be deployed
- resourceGroupName: The name of the Resource Group where the resources will be deployed
- location: The Azure region where the resources will be deployed (e.g "UK Sourth")
- environmentName: The name of the DevOps environment you created
- bicepFilePath: The path to the Bicep file to be deployed (default is "main.bicep" in the root of the repository)
- resourceName: The base name for the resources to be deployed, make sure this matches the name used in the Bicep parameter file.

Once these are configured, you can run the pipeline to deploy the resources.

> **NOTE:** You may need to grant permissions for the Pipeline to run, depending on the governance policies in place within your Azure DevOps organization.

## PowerShell Deployment

The first step is to ensure you have Bicep installed on your local machine. You can follow the instructions [here](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install).

You also need to ensure you have updated the parameter values in the Bicep parameter file to match your environment.

You will need at least Contributor, Storage Blob Data Contributor and User Access Administrator permissions on the Resource Group where you will be deploying the resources.

You can then use the ['Invoke-DeployBicep.ps1'](/BicepDeployment/Invoke-DeployBicep.ps1) script provided in the BicepModules folder. This script will deploy the Bicep file to your Resource Group.

To execute the script, you will need to provide the following parameters:

- subscriptionId: The Subscription ID where the resources will be deployed
- resourceGroupName: The name of the Resource Group where the resources will be deployed
- location: The Azure region where the resources will be deployed (e.g "UK South")
- bicepFilePath: The path to the Bicep file to be deployed
- resourceName: The base name for the resources to be deployed, make sure this matches the name used in the Bicep parameter file.

# Deployment Example

## PowerShell Deployment

An example of how to run the script is as follows:

```powershell
.\Invoke-DeployBicep.ps1 -subscriptionId "your-subscription-id" -resourceGroupName "your-resource-group-name" -location "your-location" -bicepFilePath "path-to-your-bicep-file" -resourceName "your-resource-base-name"
```

## DevOps Pipeline

You can run the Azure DevOps pipeline provided in the Pipeline folder. Ensure you have configured the variables as mentioned in the Prerequisites section before running the pipeline.

For more information on setting up and running Azure DevOps pipelines, you can refer to the official documentation [here](https://learn.microsoft.com/en-us/azure/devops/pipelines/get-started-yaml?view=azure-devops).

# Making Changes

If you make any changes to the Function App code within the Assets folder, ensure you redeploy the Bicep file using either the PowerShell script or the DevOps pipeline to update the deployed resources with your changes, as these are idempotent deployments, it will only update the resources that have changed.

# Intune Remediation Script

The Intune Remediation Script used to create the Log Analytics custom logs and data sources can be found in the Remediation folder. You will need to add your DCR Immutable ID and the Function App URL to the script before deploying it via Intune.

### Credits

Thank you to Maurice Daly for collaborating on this session and thank you to the MSEndpointMgr Team for their initial blog post on AppLocker and Log Analytics, which inspired this solution for the new method for Log Analytics ingestion using Data Collection Rules.

[Log Analytics & AppLocker – Better Together](https://msendpointmgr.com/2021/08/13/log-analytics-applocker-better-together/)
