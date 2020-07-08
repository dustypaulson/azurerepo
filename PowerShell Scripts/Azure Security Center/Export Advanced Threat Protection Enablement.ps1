$path = "C:\Users\v-dupau\Desktop\atpenabled.csv"
$tenantID = "72f988bf-86f1-41af-91ab-2d7cd011db47"
$type = "WDATP"
$context = Get-AzContext
$profile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($profile)
$token = $profileClient.AcquireAccessToken($context.Subscription.TenantId)
$authHeader = @{
	'Content-Type' = 'application/json'
	'Authorization' = 'Bearer ' + $token.AccessToken
}

$subs = Get-AzSubscription | Where-Object { $_.TenantId -eq "$tenantID" }
foreach ($sub in $subs) {
	Select-AzSubscription -SubscriptionId $sub.id
	$web = (Invoke-WebRequest -Method GET -Headers $authHeader -Uri https://management.azure.com/subscriptions/$($Sub.id)/providers/Microsoft.Security/settings?api-version=2019-01-01)
	if ($web -ne $null) {
		$value = ($web.Content | ConvertFrom-Json).value
		$value = $value | Where-Object { $_.Name -eq "$type" }
		if ($value -ne $null) {
			$jobValue = [pscustomobject]@{
				SubscriptionID = $value.id.Split("/")[2]
				Enabled = $value.properties.Enabled
			}
			$jobValue | Export-Csv -Path $path -NoClobber -NoTypeInformation -Append
		}
		$value = $null
		$web = $null
	}
}
