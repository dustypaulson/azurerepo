param(
$defaultDataCollectionRuleResourceId,
$workspaceID,
$subID,
$tenantID,
$userName,
$SecurePassword
)

$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $SecurePassword

Connect-AzAccount -Subscription $subID -Tenant $tenantID -Credential $cred

Select-AzSubscription -SubscriptionId $subID

$defaultDcrParams = @"
{
    "properties": {
        "defaultDataCollectionRuleResourceId": "$defaultDataCollectionRuleResourceId"
    }
}
"@
$workspaceString = "$workspaceID" + "?api-version=2021-12-01-preview"
Invoke-AzRestMethod -Path "$workspaceString"  -Method PATCH -payload $defaultDcrParams
