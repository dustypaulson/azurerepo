Install-Module -Name Az.Security -Force
Select-AzSubscription -SubscriptionId "ASC SUB"
Get-AzSecurityTask | Export-Csv "FILEPATH"
