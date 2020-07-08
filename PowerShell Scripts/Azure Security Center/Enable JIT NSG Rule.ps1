#Login-AzureRmAccount
$ip = Invoke-RestMethod http://ipinfo.io/json | Select-Object -exp ip
$VM = Get-AzureRmVM | Out-GridView -PassThru
$date = Get-Date
$endDate = $date.AddHours(3)
[array]$portNumbers = '22 - SSH','3389 - Windows RDP','5986 - PSRemoting'
$portInUse = $portNumbers | Out-GridView -PassThru
$portInUse = $portInUse.split(' ')[0]
$JitPolicyVm1 = (@{
		Id = $vm.Id
		ports = (@{
				number = $portInUse;
				endTimeUtc = $endDate;
				allowedSourceAddressPrefix = @($ip) }) })

$JitPolicyArr = @($JitPolicyVm1)
$jitID = Get-AzureRmJitNetworkAccessPolicy -Name Default -ResourceGroupName $vm.ResourceGroupName -Location $vm.Location
Start-AzureRmJitNetworkAccessPolicy -ResourceId $jitID.Id -VirtualMachine $JitPolicyArr
