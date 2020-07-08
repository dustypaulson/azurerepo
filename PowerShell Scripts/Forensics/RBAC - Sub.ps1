<#
If we want to add the custom role to additional subscriptions under the same Azure AD Directory we will need to come up with a role naming
convention as only one role name is allowed in the scope of the Azure AD Directory
#>

$subId = "1a0a3f26-c387-4204-891e-be296382e9d2"
$spnName = "forensicsSPN"
$scope = "/subscriptions/$subId"
$ObjectIdAssignment = (Get-AzADServicePrincipal -DisplayName $spnName).Id
$roleName = "Forensics Role"

#Login to Azure
#Login-AzAccount

#Selects subscription to add role to
Select-AzSubscription -SubscriptionId $subId

#Builds the role to add based on the Reader role
$role = Get-AzRoleDefinition "Reader"
$role.Id = $null
$role.Name = $roleName
$role.Description = "This role is used to deploy the automation scripts for memory capture and vhd extraction"
#Add storage role actions
$role.Actions.Add("Microsoft.Storage/storageAccounts/read")
$role.Actions.Add("Microsoft.Storage/storageAccounts/write")
$role.Actions.Add("Microsoft.Storage/storageAccounts/delete")
$role.Actions.Add("Microsoft.Storage/storageAccounts/listkeys/action")
$role.Actions.Add("Microsoft.Storage/storageAccounts/blobServices/write")
$role.Actions.Add("Microsoft.Storage/storageAccounts/blobServices/containers/write")
#Add Compute permissions
$role.Actions.Add("Microsoft.Compute/snapshots/*")
$role.Actions.Add("Microsoft.Compute/virtualMachines/read")
$role.Actions.Add("Microsoft.Compute/virtualMachines/write")
$role.Actions.Add("Microsoft.Compute/virtualMachines/extensions/*")
$role.Actions.Add("Microsoft.Compute/disks/*")
#Add Network Permissions
$role.Actions.Add("Microsoft.Network/networkInterfaces/join/action")
#Add template deployment permissions for linux custom script extension template deployment
$role.Actions.Add("Microsoft.Resources/deployments/validate/action")
$role.Actions.Add("Microsoft.Resources/deployments/write")
#Clears current scope and sets the scope as the current subscription
$role.AssignableScopes.Clear()
$role.AssignableScopes.Add("$scope")

#Creates the Role
New-AzRoleDefinition -Role $role

#Waitings for 15 seconds for role to become available for assignment    
Start-Sleep 15

#Assigns the role to the correct group/user. Once this has completed it can take a bit of time for PowerShell to recognize the permissions
#I would recommend waiting 15 minutes or so before running any permissive heavy scripts
New-AzRoleAssignment -ObjectId $ObjectIdAssignment -RoleDefinitionName $roleName -Scope $scope
