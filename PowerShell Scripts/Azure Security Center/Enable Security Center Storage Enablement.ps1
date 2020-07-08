#Login-AzAccount
#Install-Module az.security -requiredVersion 0.7.3
Get-AzContext -ListAvailable -PipelineVariable AzSub | Set-AzContext | ForEach-Object {
	$storageAccounts = Get-AzStorageAccount
	foreach ($sa in $storageAccounts)
	{
		Enable-AzSecurityAdvancedThreatProtection -ResourceId $sa.Id
	}
}
