#Connect-AzAccount

#Path to export file
$path = "C:\Users\v-dupau\Desktop\sqlstatus.csv"

#Gathers all subs
$subs = Get-AzSubscription

#Loops through each sub
foreach ($sub in $subs)
{
	#Selects the subscription
	Select-AzSubscription -SubscriptionId $sub.Id | Out-Null

	#Gathers all PaaS SQL Servers in this subscription
	$dbsvr = Get-AzSqlServer

	if ($dbsvr.Count -eq 0) { Write-Host "No SQL Servers in this environment. Please verify in the portal this is correct." }

	else
	{
		Write-Host "How Many PaaS SQL servers are in the subscription - " $sub.Name
		$dbsvr.Count

		#Loops through each server in the subscription
		foreach ($svr in $dbsvr)
		{

			#Gets the status of the SQL servers integration with asc. Either enabled or disabled
			$status = Get-AzSqlServerAdvancedThreatProtectionPolicy -ServerName $svr.ServerName -ResourceGroupName $svr.ResourceGroupName

			#Creates job to export data
			$jobvalue = [pscustomobject]@{
				SQLServerName = $svr.ServerName
				ResourceGroup = $svr.ResourceGroupName
				SubscriptionID = $svr.ResourceId.split("/")[2]
				Enabled = $status.IsEnabled
			}
			#Exports $jobvalue data to csv file
			$jobvalue | Export-Csv -Path $path -Append -Force -NoClobber -NoTypeInformation
		}
	}
}
