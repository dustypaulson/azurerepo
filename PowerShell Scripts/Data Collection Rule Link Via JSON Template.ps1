param(
$defaultDataCollectionRuleResourceId,
$workspaceID
)

$defaultDcrParams = @"
{
    "properties": {
        "defaultDataCollectionRuleResourceId": "$defaultDataCollectionRuleResourceId"
    }
}
"@
$workspaceString = "$workspaceID" + "?api-version=2021-12-01-preview"
Invoke-AzRestMethod -Path "$workspaceString"  -Method PATCH -payload $defaultDcrParams