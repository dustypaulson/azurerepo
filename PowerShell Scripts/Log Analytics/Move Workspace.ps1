#If moving VMs to a new workspace and updating Azure Defender's Auto Provisioning workspace change the workspace now in the auto provisioning config then run script

Write-Host "Setting Runtime Variables" -ForegroundColor Yellow -BackgroundColor Black

#Subscription ID Of The Centralized Workspace
$newWorkspaceSubID = ""

#Workspace Centralized Workspace Is In
$newWorkspaceRG = ""

#Log Analytics Workspace ID That VMs Will Be Moved To
$newWorkspaceId = ""

#Name Of Centralized Log Analytics Workspace
$newWorkspaceName = ""

#Subscription ID Where VMs To Move Are Located
$vmSubID = ""

#Log Analytics Workspace ID That VMs Are Currently Attached To
$oldWorkspaceID = ""

#Name Of Windows And Linux Extension
$winExtension = "MicrosoftMonitoringAgent"
$linExtension = "OmsAgentForLinux"
[array]$updateWindowsVMS = @()
[array]$updateLinuxVMs = @()

Write-Host "Select Subscription New Workspace Is In" -ForegroundColor Yellow -BackgroundColor Black
Select-AzSubscription -SubscriptionId $newWorkspaceSubID

Write-Host "Getting New Workspace Key" -ForegroundColor Yellow -BackgroundColor Black
$newWorkspaceKey = (Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $newWorkspaceRG -Name $newWorkspaceName).PrimarySharedKey

Write-Host "Setting Public And Protected Settings" -ForegroundColor Yellow -BackgroundColor Black
$PublicSettings = @{"workspaceId" = $newWorkspaceId;"stopOnMultipleConnections" = $false}
$ProtectedSettings = @{"workspaceKey" = $newWorkspaceKey}

Write-Host "Starting sleep" -ForegroundColor Yellow -BackgroundColor Black
#start-sleep 360

Write-Host "Select Subscription VMs Are In" -ForegroundColor Yellow -BackgroundColor Black
Select-AzSubscription -SubscriptionId $vmSubID

Write-Host "Getting Windows VMs" -ForegroundColor Yellow -BackgroundColor Black
$winvms = Get-AzVM | where {$_.StorageProfile.OsDisk.OsType -eq "Windows"}

foreach($winvm in $winvms){
if((Get-AzVMExtension -ResourceGroupName $winvm.ResourceGroupName -VMName $winvm.Name -Name $winExtension -Status -ErrorAction Ignore).ProvisioningState -ne "Succeeded"){
$updateWindowsVMS += $winvm
}
}

if($updateWindowsVMS.Count -gt 0){
$winvms = $null
foreach ($vm in $updateWindowsVMS){
$winvms = Get-AzVM | where {$_.StorageProfile.OsDisk.OsType -eq "Windows" -and $_.Name -ne $vm.Name}
}
}

Write-Host "Remove Old Connector To Workspace (Windows)" -ForegroundColor Yellow -BackgroundColor Black
foreach($winvm in $winvms){
$winext = (Get-AzVMExtension -ResourceGroupName $winvm.ResourceGroupName -VMName $winvm.Name -Name $winExtension).PublicSettings

Write-Host "If Old Workspace Is Different From New Workspace Then Update (WindowsVM - $($winvm.Name))" -ForegroundColor Yellow -BackgroundColor Black
if(($winext | ConvertFrom-Json | select workspaceId).workspaceId -eq $oldWorkspaceID){
$updateWindowsVMS += $winvm
Write-Host "Removing Old Workspace from Windows VM $($winvm.Name)" -ForegroundColor Red -BackgroundColor Black
Remove-azVMExtension -ResourceGroupName $winvm.ResourceGroupName -VMName $winvm.Name -Name $winExtension -Force 
}
}

Write-Host "Getting Linux VMs" -ForegroundColor Yellow -BackgroundColor Black
$linvms = Get-AzVM | where {$_.StorageProfile.OsDisk.OsType -eq "linux"}

foreach($linvm in $linvms){
if((Get-AzVMExtension -ResourceGroupName $linvm.ResourceGroupName -VMName $linvm.Name -Name $linExtension -Status -ErrorAction Ignore).ProvisioningState -ne "Succeeded"){
$updateLinuxVMs += $linvm
}
}

if($updateLinuxVMs.Count -gt 0){
$linvms = $null
foreach ($vm in $updateLinuxVMs){
$linvms = Get-AzVM | where {$_.StorageProfile.OsDisk.OsType -eq "Linux" -and $_.Name -ne $vm.Name}
}
}

Write-Host "Remove Old Connector To Workspace (Linux)" -ForegroundColor Yellow -BackgroundColor Black
foreach($linvm in $linvms){
$linext = (Get-AzVMExtension -ResourceGroupName $linvm.ResourceGroupName -VMName $linvm.Name -Name $linExtension).PublicSettings

Write-Host "If Old Workspace Is Different From New Workspace Then Update (LinuxVm - $($linvm.Name))" -ForegroundColor Yellow -BackgroundColor Black
if(($linext | ConvertFrom-Json | select workspaceId).workspaceId -eq $oldWorkspaceID){

$updateLinuxVMs += $linvm

Write-Host "Removing Old Workspace from Linux VM $($linvm.Name)" -ForegroundColor Red -BackgroundColor Black

Remove-azVMExtension -ResourceGroupName $linvm.ResourceGroupName -VMName $linvm.Name -Name $linExtension -Force
}
}

Write-Host "Starting sleep" -ForegroundColor Yellow -BackgroundColor Black
Start-Sleep 360
 
Write-Host "Deploying New Workspace (Windows)" -ForegroundColor Yellow -BackgroundColor Black

 foreach($winvm in $updateWindowsVMS){

Write-Host "Deploying $($winvm.Name) To Workspace $newWorkspaceName" -ForegroundColor Yellow -BackgroundColor Black

Set-azVMExtension -ExtensionName $winExtension -ResourceGroupName $winvm.resourcegroupname -VMName $winvm.name `
-Publisher "Microsoft.EnterpriseCloud.Monitoring"`
-ExtensionType $winExtension `
-TypeHandlerVersion 1.0 `
-Settings $PublicSettings `
-ProtectedSettings $ProtectedSettings `
-Location $winvm.Location -AsJob
}

Write-Host "Deploying New Workspace (Linux)" -ForegroundColor Yellow -BackgroundColor Black

 foreach($linvm in $updateLinuxVMs){

Write-Host "Deploying $($linvm.Name) To Workspace $newWorkspaceName" -ForegroundColor Yellow -BackgroundColor Black

Set-azVMExtension -ExtensionName $linExtension -ResourceGroupName $linvm.resourcegroupname -VMName $linvm.name `
-Publisher "Microsoft.EnterpriseCloud.Monitoring"`
-ExtensionType $linExtension `
-TypeHandlerVersion "1.0" `
-Settings $PublicSettings `
-ProtectedSettings $ProtectedSettings `
-Location $linvm.Location -AsJob
}

Get-Job | Wait-Job

Get-Job
