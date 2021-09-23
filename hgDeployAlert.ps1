<#=======================================================================================================================
Required - Powershell Version 5.1, Powershell Azure module 5.0.0
=========================================================================================================================
AUTHOR:  Harika Gadiyakari 
DATE:    21-09-2021
Version: 1.0
=========================================================================================================================
.SYNOPSIS
    Creates ITSM connector. Deploys ActionGroups with ITSM Actions and/or Email Actions. Deploys Alerts.
.DESCRIPTION
    .PARAMETER  SubscriptionID
		Specifies the Subscription ID of Susbcription hosting the Log Analytics Workspace.
    .PARAMETER  LogAnalyticsWorkspaceName
		Specifies the name Log Analytics Workspace used for connecting to Silva instance
=======================================================================================================================#>

[CmdletBinding(SupportsShouldProcess=$true)]
Param
    (
    [Parameter(Mandatory=$true)]  [String]$SubscriptionID,
    [Parameter(Mandatory=$true)]  [String]$LogAnalyticsWorkspaceName,
    [Parameter(Mandatory=$true)]  [String]$LogicAppName
    )
#========================================================================================================================
# VARIABLE SECTION
#========================================================================================================================
$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

[String]$EventProcessingSchema = "1.0"
[String]$AlertVersion = "1.0"
$ITSMAG = $PSScriptRoot + '\deployITSMActionGroup.json'
$LogicAppRID = (Get-AzResource -Name $LogicAppName).ResourceId
#=======================================================================================================================
#Login Section
#=======================================================================================================================

Write-Host "Please connect to Azure Account"
Connect-AzAccount -Subscription $SubscriptionID


# Collect Maintenance ResourceGroup and OMS Workspace Details.
$ObjWorkspace = Get-AzOperationalInsightsWorkspace | Where-Object { $_.Name -Match $LogAnalyticsWorkspaceName }
If ($ObjWorkspace)
    {
    [String]$LogAnalyticsWorkspaceName = $ObjWorkspace.Name
    [String]$ResourceGroup = $ObjWorkspace.ResourceGroupName
    [String]$WorkspaceRegion = (($ObjWorkspace.location).ToLower()) -replace '\s',''
    $WorkspaceId = $ObjWorkspace.CustomerId.Guid

    }
else
    {
    Write-Host "WARNING:     Loganalytics Workspace not found. Please enter correct workspace name while running the script." -ForegroundColor Yellow
    Read-Host "`nPress 'ENTER'to exit the script........"
    exit
    }

#Creating Action Group 

$callbackurl = (Get-AzLogicAppTriggerCallbackUrl -ResourceGroupName $ResourceGroup -Name $LogicAppName -TriggerName manual).Value

$ActionGroupReceiver = New-AzActionGroupReceiver -Name $LogicAppName -UseCommonAlertSchema -LogicAppReceiver -ResourceId $LogicAppRID -CallbackUrl $callbackurl

Set-AzActionGroup -ResourceGroupName $ResourceGroup -Name AG-Major -ShortName MajorLApp -Receiver $ActionGroupReceiver

if ($error) 
            { 
            Write-Host "WARNING: Failed to deploy the Action Group. Script will exit now"
            Read-Host "`nPress 'ENTER'to exit the script........"
            exit
            }
 else {Write-Host "INFORMATION: ActionGroup deployed successfully." }

 #Getting the list of alerts from json templates
 $AlertFileList = (get-childitem ($PSScriptRoot + '\alerts-*.json') |select FullName)

 # Deploy the arm templates one by one
ForEach ($AlertFileName in $AlertFileList)
    {
	$ThisAlertFileName = $AlertFileName.FullName
    $ThisAlertDeploymentFile = ($ThisAlertFileName.Split("\"))[($ThisAlertFileName.Split("\")).Count -1]

    Write-Host "INFORMATION: Calling Alert Deployment ARM Template to Deploy Alerts."
    [String]$ThisAlertDeploymentName = ($ThisAlertDeploymentFile.Split("."))[0]

    $Error.Clear() 	
    New-AzResourceGroupDeployment -Name $ThisAlertDeploymentName -ResourceGroupName $ResourceGroup -TemplateFile $ThisAlertFileName -omsWorkspaceName $LogAnalyticsWorkspaceName -omsWorkspaceLocation $WorkspaceRegion -eventProcessingSchema  $EventProcessingSchema -alertVersion $AlertVersion
	
    if ($Error) { Write-Host "WARNING:     Alert Deployment failed. For detailed error message, please check deployment error in the Resource Group from Azure Portal." -ForegroundColor yellow }      
    }

Write-Host "`n####################### END OF SCRIPT EXECUTION ###################################"

        
