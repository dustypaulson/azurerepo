$myWorkspaceId = "79ad538e-3106-43ed-b614-e66c7da35923"
$myWorkspaceKey = "eha3mBH2SesJGoYYwysmfqw5UL49ciNCLTEuCcKbmzP86BN/QIS4TiJnplo6W+yQaC0tlej+DYcBvpotwrsI3A=="
$PublicSettings = @{ "workspaceId" = "$($myWorkspaceId)" }
$ProtectedSettings = @{ "workspaceKey" = "$($myWorkspaceKey)" }
$RGs = Get-AzResourceGroup
foreach ($rg in $RGs) {
	$VMs = Get-AzVM -ResourceGroupName $rg.ResourceGroupName
	foreach ($vm in $VMs) {
		if ($vm.StorageProfile.OsDisk.OsType -eq "Linux") {
			$ext = Get-AzVMExtension -ResourceGroupName $rg.ResourceGroupName -VMName $vm.Name | Where-Object { $_.ExtensionType -eq "MicrosoftMonitoringAgent" }
			if ($ext -eq $null) {
				Write-Output "install on linux vm $($vm.Name) in RG $($vm.ResourceGroupName)"

				Set-AzVMExtension -ExtensionName "OmsAgentForLinux" `
 					-ResourceGroupName "$($vm.ResourceGroupName)" `
 					-VMName "$($vm.Name)" `
 					-Publisher "Microsoft.EnterpriseCloud.Monitoring" `
 					-ExtensionType "OmsAgentForLinux" `
 					-TypeHandlerVersion 1.0 `
 					-Settings $PublicSettings `
 					-ProtectedSettings $ProtectedSettings `
 					-Location $vm.Location
			}

		}

	}
}
