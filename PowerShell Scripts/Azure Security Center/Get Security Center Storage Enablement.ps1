#$creds = Get-Credential
#Connect-AzAccount -Credential $creds

$path = "C:\users\v-dupau\desktop\storageASCenabled.csv"
$SA = Get-AzStorageAccount
foreach ($s in $sa)
{
	$ASCEnabled = Get-AzSecurityAdvancedThreatProtection -ResourceId $s.Id
	$jobValue = [pscustomobject]@{
		StorageAccountName = $s.StorageAccountName
		IsSecurityCenterEnabled = $ASCEnabled.IsEnabled
	}
	$jobValue | Export-Csv -Path $path -NoClobber -NoTypeInformation -Append
}
