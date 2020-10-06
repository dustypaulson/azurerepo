#Remove custom script extension
Remove-AzVMCustomScriptExtension -ResourceGroupName password_spray_demo -VMName $attackVM -Name DownloadPasswordSprayFiles -Force -Confirm:$false