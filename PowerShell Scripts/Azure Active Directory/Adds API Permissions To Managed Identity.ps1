# Install the module (You need admin on the machine)
Install-Module AzureAD

# Your tenant id (in Azure Portal, under Azure Active Directory -> Overview )
$TenantID="TENANTID"
# Name of the manage identity (same as the Logic App name)
$DisplayNameOfMSI="LOGICAPPNAME" 
# Check the Microsoft Graph documentation for the permission you need for the operation
$PermissionName = "ThreatIndicators.ReadWrite.OwnedBy" 

# Microsoft Graph App ID (DON'T CHANGE)
$GraphAppId = "00000003-0000-0000-c000-000000000000"

Connect-AzureAD -TenantId $TenantID

#Gets Managed Identity based on logic app name
$MSI = Get-AzADServicePrincipal -DisplayName $DisplayNameOfMSI
Start-Sleep -Seconds 10
$MSI

#Get Microsoft Graph Add ID
$GraphServicePrincipal = Get-AzADServicePrincipal -ApplicationId $GraphAppId
$GraphServicePrincipal

#Sets permissions to add to Managed Identity
$AppRole = $GraphServicePrincipal.AppRoles | `
Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
$AppRole

#Adds permissions to Managed Identity
New-AzServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId `
-ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id
