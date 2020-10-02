$subID = ""
$keyVaultName = ""
$keyVaultSecretName = ""
$username = ""
$tenantId = ""

#Connect Azure Account
Connect-AzAccount

#Selects Subscription
Write-Output "Change subscription to correnct Subscription"
Select-AzSubscription -SubscriptionId $subID

#Gets password for SPN from keyvault
$kvPW = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultSecretName).SecretValueText
$passwd = ConvertTo-SecureString $kvPW -AsPlainText -Force
$pscredential = New-Object System.Management.Automation.PSCredential("$username", $passwd)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId
