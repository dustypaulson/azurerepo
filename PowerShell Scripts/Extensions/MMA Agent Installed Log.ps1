$RGs = Get-AzResourceGroup
foreach ($rg in $RGs) {
	$VMs = Get-AzVM -ResourceGroupName $rg.ResourceGroupName
	foreach ($vm in $VMs) {
		if ($vm.StorageProfile.OsDisk.OsType -eq "Linux") {
			$ext = Get-AzVMExtension -ResourceGroupName $rg.ResourceGroupName -VMName $vm.Name | Where-Object { $_.ExtensionType -eq "MicrosoftMonitoringAgent" }
			if ($ext -eq $null) {
				$text = "install on linux vm $($vm.Name) in RG $($vm.ResourceGroupName)" | Out-File "C:\Users\dusty\Desktop\Extension Installed.txt" -Append ascii -NoClobber -Force
			}
			if ($ext -ne $null) {
				$text = "extension exists on linux vm $($vm.Name) in RG $($vm.ResourceGroupName)" | Out-File "C:\Users\dusty\Desktop\Extension Installed.txt" -Append ascii -NoClobber -Force
			}

		}
		if ($vm.StorageProfile.OsDisk.OsType -eq "Windows") {
			$ext = Get-AzVMExtension -ResourceGroupName $rg.ResourceGroupName -VMName $vm.Name | Where-Object { $_.ExtensionType -eq "MicrosoftMonitoringAgent" }
			if ($ext -eq $null) {
				$text = "install on windows vm $($vm.Name) in RG $($vm.ResourceGroupName)" | Out-File "C:\Users\dusty\Desktop\Extension Installed.txt" -Append ascii -NoClobber -Force
			}
			if ($ext -ne $null) {
				$text = "extension exists on windows vm $($vm.Name) in RG $($vm.ResourceGroupName)" | Out-File "C:\Users\dusty\Desktop\Extension Installed.txt" -Append ascii -NoClobber -Force
			}
		}
	}
}
