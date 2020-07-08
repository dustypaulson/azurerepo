<#Will need to remove static variables and run through runbook. Should prettify the script before running again

param(
  [Parameter (Mandatory= $true)]
  [String] $attackedVMResourceGroupName,

  [Parameter (Mandatory= $true)]
  [String] $attackedSubscriptionID,

  [Parameter (Mandatory= $true)]
  [String] $attackedVMName,

  [Parameter (Mandatory= $true)]
  [String] $forensicsVMName
)
#>
############################################################################################################
#When running a scenario where the attacked vm is in another resource group/subscription 
#Then uncomment Move-AzResource -DestinationResourceGroupName $attackedVMResourceGroupName -DestinationSubscriptionId $attackedSubscriptionID -ResourceId $memCapDisk.Id -Force
############################################################################################################

#Use to get complete script runtime at the end of script
$startScript = Get-Date

#Sets TLS version to 1.2 - this is needed to install the below modules
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Installs AZ CMDlets if not installed
if (Get-InstalledModule -Name AZ) {
	Write-Host "Module exists"
}
else {
	Install-PackageProvider Nuget -Force
	Install-Module AZ -Force -AllowClobber
}

#Creates log path if not present
$logCheck = Test-Path -Path "C:\forensicsLog\vhdCapture"
if ($logCheck -eq $false){
mkdir "C:\forensicsLog\vhdCapture" -Force
}

#Connect Azure Account
$connectionCheck = Connect-AzAccount

#Creates log file for account verification
$connectionCheck | Out-File "C:\forensicsLog\vhdCapture\vhdCapture_$(Get-Date -Format "MM-dd-yyyy_hh-mm-ss-ms").log"

$attackedVMResourceGroupName = "Dusty-AD"
$attackedSubscriptionID = "269534e1-06c0-4ee8-a816-0d41a7dee672"
$attackedVMName = "adVM"
$forensicsVMName = "forensicsVM"

#Forensics Resource Group Name
$forensicsVMResourceGroup = "Dusty"

#Forensics Subscription ID
$forensicsSubscriptionID = "269534e1-06c0-4ee8-a816-0d41a7dee672"

#Provide storage account name where you want to copy the underlying VHD of the managed disk. 
$storageAccountName = "dustytest123"

#Name of the storage container where the downloaded VHD will be stored
$storageVHDContainerName = "forensicvhdfiles"

#Provide Shared Access Signature (SAS) expiry duration in seconds e.g. 86400 Seconds.
#Know more about SAS here: https://docs.microsoft.com/en-us/Az.Storage/storage-dotnet-shared-access-signature-part-1
$sasExpiryDuration = "86400"

#Selects Subscription of Forensics VM
Select-AzSubscription -SubscriptionId $forensicsSubscriptionID

#Get Forensic VM Object - Because of the -status switch at the end of get-azvm I call the cmdlet again without to get the full object without the power allocation
Write-Output "Getting Forenic VM"
$forensicsVM = Get-AzVM -Name $forensicsVMName -ResourceGroupName $forensicsVMResourceGroup

#Get the Forensics Storage Account
Write-Output "Getting Forenics Storage account for VHD file and forensic scripts"
$storageAccount = Get-AzStorageAccount -ResourceGroupName $forensicsVM.ResourceGroupName -Name $storageAccountName

#Provide the key of the storage account where you want to copy the VHD of the managed disk. 
Write-Output "Getting storage account key"
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName).Value[0]

#Selects the subscription of the attacked VM
Write-Output "Change subscription to Attacked VM Subscription"
Select-AzSubscription -SubscriptionId $attackedSubscriptionID

#Get the Attacked VM object
Write-Output "Getting Attacked VM information"
$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName -Status

#Output log file with data below
$jobvalue = [pscustomobject]@{
	Account = $connectionCheck.Context.Account.id
	AttackedVM = $attackedVM.Name
	AttackedVMSubID = $attackedVM.id.Split("/")[2]
    AttackedVMRG = $attackedVM.ResourceGroupName
}

#Starts Attacked VM if not started
Write-Output "Starting Attacked VM if stopped"
#If attacked VM is off stop script and alert user with message
Write-Output "Starting Attacked VM if stopped"
if ($attackedVM.Statuses.DisplayStatus -contains "VM deallocated" -or $attackedVM.Statuses.DisplayStatus -contains "VM stopped")
{
	Write-Host "The VM $attackedVMName is currently deallocated. No memory capture possible"
	break
}
else { Write-Host "$attackedVMName is currently running" }

$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName

#Provide the managed disk name 
Write-Output "Getting Attacked OS disk information"
$attackedDiskName = $attackedVM.StorageProfile.OsDisk.Name

#Provide the name of the destination VHD file to which the VHD of the managed disk will be copied.
Write-Output "Creating VHD file name"
$destinationVHDFileName = $attackedVM.StorageProfile.OsDisk.Name + ".vhd"

#Create Snapshot of OS Disk
Write-Output "Creating snapshot of Attacked VM for VHD extraction"
$snapshotname = $attackedVM.Name + "snapshot"
$snapshot = New-AzSnapshotConfig -SourceUri $attackedVM.StorageProfile.OsDisk.ManagedDisk.Id -Location $attackedVM.Location -CreateOption Copy
New-AzSnapshot -SnapshotName $snapshotname -ResourceGroupName $attackedVM.ResourceGroupName -Snapshot $snapshot

#Generate the SAS for the managed disk 
Write-Output "Generating SAS token for managed disk to extract VHD"
$sas = Grant-AzSnapshotAccess -ResourceGroupName $attackedVM.ResourceGroupName -SnapshotName $snapshotname -Access Read -DurationInSecond $sasExpiryDuration

#Create the context of the storage account where the underlying VHD of the managed disk will be copied
Write-Output "Creating destination context for VHD to be placed in Forensics Storage Account"
$destinationContext = New-AzStorageContext –StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storageAccountKey

#Copy the VHD of the managed disk to the storage account. If the BLOB is already in the storage account the script will stop
$vhdStartTime = Get-Date
try
{
	Get-AzStorageBlob -Blob $destinationVHDFileName -Container $storageVHDContainerName -Context $storageAccount.Context -ErrorAction stop
	Write-Output "The blob $destinationVHDFileName is already in $($storageAccount.StorageAccountName)"
	Write-Output "Stopping script. Please investigate why the VHD file $destinationVHDFileName already exists"
	break
}
catch
{
	Write-Output "Starting VHD Export from attacked VM" (Get-Date)
	Start-AzStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer $storageVHDContainerName -DestContext $destinationContext -DestBlob $destinationVHDFileName
}

#Get the status of the VHD file copy to storage account
$copyStatus = (Get-AzStorageBlobCopyState -Context $destinationContext -Container $storageVHDContainerName -Blob $destinationVHDFileName).status

#Check the status of the VHD file copy to storage account until succeeded
do
{
	$copyStatus = (Get-AzStorageBlobCopyState -Context $destinationContext -Container $storageVHDContainerName -Blob $destinationVHDFileName).status
	Write-Output "starting sleep"
	Start-Sleep -Seconds 60
	$copyStatus
}
until ($copyStatus -ne "pending")

#Give stats for VHD copy
Write-Output "Completed VHD Export from attacked VM" (Get-Date)
$vhdEndTime = Get-Date
$vhdRunTime = New-TimeSpan -Start $vhdStartTime -End $vhdEndTime
Write-Output "It took the VHD file $vhdruntime to export to the storage account $storageAccountName"

#Remove access to VHD file from managed disk
Write-Output "Revoking access to VHD file on managed disk"
Revoke-AzSnapshotAccess -ResourceGroupName $attackedVM.ResourceGroupName -SnapshotName $snapshotname -Confirm:$false
Write-Output "VHD Access Revoked"

#Copy blob to vhd file disk. Creates a new directory if the chd file already exists. Will not save two copies.
$driveLetter = (Get-Volume | Where-Object { $_.FileSystemLabel -eq "vhdFiles" }).DriveLetter + ":/"
$fileCheck = Test-Path ($driveLetter + $destinationVHDFileName)
if ($fileCheck -eq "True") {
	mkdir ($driveLetter + $destinationVHDFileName.Trim(".vhd"))
	Move-Item -Path ($driveLetter + $destinationVHDFileName) -Destination ($driveLetter + $destinationVHDFileName.Trim(".vhd")) -Force -Confirm:$false
	Get-AzStorageBlobContent -Container $storageVHDContainerName -Blob $destinationVHDFileName -Destination $driveLetter -Context $destinationContext
}
else {
	Get-AzStorageBlobContent -Container $storageVHDContainerName -Blob $destinationVHDFileName -Destination $driveLetter -Context $destinationContext
}

#Cleanup resources no longer needed
#If Disk access has not been revoked disk will not remove. This will catch the error and revoke disk access and remove the disk.
Write-Output "Cleaning up unnecessary resources"
Select-AzSubscription -SubscriptionId $attackedSubscriptionID
Remove-AzStorageBlob -Blob $destinationVHDFileName -Container $storageVHDContainerName -Context $storageAccount.Context -Force

try
{
	Remove-AzSnapshot -ResourceGroupName $attackedVM.ResourceGroupName -SnapshotName $snapshotname -Force -ErrorAction Stop
}
catch
{
	Write-Output "Disk still has sas access"
	Revoke-AzSnapshotAccess -ResourceGroupName $attackedVM.ResourceGroupName -SnapshotName $snapshotname -Confirm:$false
	Remove-AzSnapshot -ResourceGroupName $attackedVM.ResourceGroupName -SnapshotName $snapshotname -Force -ErrorAction Stop
}

#Script admin tasks
Write-Output "Finish script at" (Get-Date)
$finishScript = Get-Date
$scriptDuration = New-TimeSpan -Start $startScript -End $finishScript
Write-Output "Time difference is: $scriptDuration"
