Connect-AzureAD
$users = Get-AzureADUser
foreach ($u in $users) {
	$userUPN = $u.UserPrincipalName
	$licensePlanList = Get-AzureADSubscribedSku
	$userList = Get-AzureADUser -ObjectID $userUPN | Select-Object -ExpandProperty AssignedLicenses | Select-Object SkuID
	if ($userList -ne $null) {
		$u.DisplayName
		$userList | ForEach-Object { $sku = $_.SkuId; $licensePlanList | ForEach-Object { if ($sku -eq $_.ObjectId.substring($_.ObjectId.length - 36,36)) { Write-Host $_.SkuPartNumber } } }
	}
}
