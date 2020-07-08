<#
param(
  [Parameter (Mandatory= $true)]
  [String] $attackedVMResourceGroupName,

  [Parameter (Mandatory= $true)]
  [String] $attackedSubscriptionID,

  [Parameter (Mandatory= $true)]
  [String] $attackedVMName
)
#>

$attackedVMResourceGroupName = "Dusty"
$attackedSubscriptionID = "1a0a3f26-c387-4204-891e-be296382e9d2"
$attackedVMName = "attackedvm"

#Installs AZ Cmdlets if not installed
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

#Creates log file name
$logFileName = "C:\forensicsLog\memCapture\memCapture_$(Get-Date -Format "MM-dd-yyyy_hh-mm-ss-ms").csv"

#Use to get complete script runtime at the end of script
$startScript = Get-Date

#Drive name that the VHD file will be downloaded to
$vhdDestinationDriveName = "OSDisk"

#Subscription ID where memory capture script and key vault is located
$kvSubscriptionID = "ba1f7dcc-89de-4858-9f8b-b2ad61c895b5"

#Application Id of the SPN that will be used for authentication
$userName = "555b6390-ef6f-4568-a5e8-c7dbc04469ec"

#Provide tenant ID for login
$tenantID = "72f988bf-86f1-41af-91ab-2d7cd011db47"

#Provide storage account name where you want to copy the underlying VHD of the managed disk. 
$storageAccountName = "dustyattacked"

#Provide storage account name where you want to copy the underlying VHD of the managed disk. 
$storageAccountRGName = "Dusty"

#Name of the storage container where the downloaded VHD will be stored
$storageVHDContainerName = "vhd"

#Keyvault information for SPN password retrieval
$keyVaultName = "forensicsKV"
$keyVaultSecretName = "password"

#Provide Shared Access Signature (SAS) expiry duration in seconds e.g. 86400 Seconds.
#Know more about SAS here: https://docs.microsoft.com/en-us/Az.Storage/storage-dotnet-shared-access-signature-part-1
$sasExpiryDuration = "86400"

#Selects Subscription that contains key vault
Select-AzSubscription -SubscriptionId $kvSubscriptionID

#Gets password for SPN from keyvault
$kv = Get-AzKeyVault -VaultName $keyVaultName
$kvPW = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultSecretName).SecretValueText
$passwd = ConvertTo-SecureString $kvPW -AsPlainText -Force
$kvpw = $null

#Logs in with new credential
$pscredential = New-Object System.Management.Automation.PSCredential("$username", $passwd)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

#Selects the subscription of the attacked VM
Write-Output "Change subscription to Attacked VM Subscription"
Select-AzSubscription -SubscriptionId $attackedSubscriptionID

#Get the Attacked VM object
Write-Output "Getting Attacked VM information"
$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName

$jobvalue = [pscustomobject]@{
	Account = $connectionCheck.Context.Account.id
	AttackedVM = $attackedVM.Name
	AttackedVMSubID = $attackedVM.id.Split("/")[2]
    AttackedVMRG = $attackedVM.ResourceGroupName
}

$jobvalue | Export-Csv $logFileName -Append -NoClobber -NoTypeInformation -Force -Confirm:$false

#Get the Storage Account in attacked VM sub
Write-Output "Getting Forensics Storage account for VHD file and forensic scripts"
$storageAccount = Get-AzStorageAccount -ResourceGroupName $storageAccountRGName -Name $storageAccountName

#Gets the key of the storage account where you want to copy the VHD of the managed disk. 
Write-Output "Getting storage account key"
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName).Value[0]

#Get the Attacked VM object
Write-Output "Getting Attacked VM information"
$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName -Status

#If attacked VM is off stop script and alert user with message
Write-Output "Starting Attacked VM if stopped"
if ($attackedVM.Statuses.DisplayStatus -contains "VM deallocated" -or $attackedVM.Statuses.DisplayStatus -contains "VM stopped")
{
	Write-Host "The VM $attackedVMName is currently deallocated. No memory capture possible"
	break
}
else { Write-Host "$attackedVMName is currently running" }

#Gets attacked VM information without power allocation status
$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName

#Create the managed disk name
Write-Output "Getting Attacked OS disk information"
$attackedDiskName = $attackedVM.StorageProfile.OsDisk.Name

#Provide the name of the destination VHD file to which the VHD of the managed disk will be copied.
Write-Output "Creating VHD file name"
$destinationVHDFileName = $attackedVM.StorageProfile.OsDisk.Name + ".vhd"

#Create Snapshot of OS Disk that is being attacked
Write-Output "Creating snapshot of Attacked VM for VHD extraction"
$snapshotname = $attackedVM.Name + "snapshot"
$snapshot = New-AzSnapshotConfig -SourceUri $attackedVM.StorageProfile.OsDisk.ManagedDisk.Id -Location $attackedVM.Location -CreateOption Copy
New-AzSnapshot -SnapshotName $snapshotname -ResourceGroupName $attackedVM.ResourceGroupName -Snapshot $snapshot

#Generate the SAS for the snapshot vhd 
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

#Remove access to VHD file from managed disk
Write-Output "Revoking access to VHD file on managed disk"
Revoke-AzSnapshotAccess -ResourceGroupName $attackedVM.ResourceGroupName -SnapshotName $snapshotname -Confirm:$false
Write-Output "VHD Access Revoked"

#Display time taken to transfer VHD file
Write-Output "Completed VHD Export from attacked VM" (Get-Date)
$vhdEndTime = Get-Date
$vhdRunTime = New-TimeSpan -Start $vhdStartTime -End $vhdEndTime
Write-Output "It took the VHD file $vhdruntime to export to the storage account $storageAccountName"

#Copy blob to vhd disk. Creates a new directory if the vhd file already exists. Will not save two copies.
$driveLetter = (Get-Volume | Where-Object { $_.FileSystemLabel -eq "$vhdDestinationDriveName" }).DriveLetter + ":/"
$fileCheck = Test-Path ($driveLetter + $destinationVHDFileName)
if ($fileCheck -eq "True") {
	mkdir ($driveLetter + $destinationVHDFileName.Trim(".vhd"))
	Move-Item -Path ($driveLetter + $destinationVHDFileName) -Destination ($driveLetter + $destinationVHDFileName.Trim(".vhd")) -Force -Confirm:$false
	Get-AzStorageBlobContent -Container $storageVHDContainerName -Blob $destinationVHDFileName -Destination $driveLetter -Context $destinationContext
}
else {
	Get-AzStorageBlobContent -Container $storageVHDContainerName -Blob $destinationVHDFileName -Destination $driveLetter -Context $destinationContext
}

#Remove snapshot. If disk still has SAS access this will disable it
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

#Cleanup resources no longer needed
Write-Output "Cleaning up unnecessary resources"
Select-AzSubscription -SubscriptionId $attackedSubscriptionID
Remove-AzStorageBlob -Blob $destinationVHDFileName -Container $storageVHDContainerName -Context $storageAccount.Context -Force

#Sets context of account to allow for AD updates
Set-AzContext -Context $connectionCheck.Context

#Removes old SPN Password
$app = Get-AzADApplication -ApplicationId $userName 
$app | Remove-AzADAppCredential -Force

#Creates new password with numbers, characters, and letters
$minLength = 16 ## characters
$maxLength = 26 ## characters
$length = Get-Random -Minimum $minLength -Maximum $maxLength
$nonAlphaChars = 5
$password = [System.Web.Security.Membership]::GeneratePassword($length, $nonAlphaChars)

#If password does not contain numbers try until it does
if ($password -match '\d' -eq $false){
do{
$password = [System.Web.Security.Membership]::GeneratePassword($length, $nonAlphaChars)
}
until($password -match '\d' -eq $true)
}

#Converts password to secure password and nulls the clear text variable
$secPw = ConvertTo-SecureString -String $password -AsPlainText -Force
$password = $null

#Creates new app credential
try{
New-AzADAppCredential -StartDate (Get-Date) -EndDate ((Get-Date).AddDays(365)) -ApplicationId $app.ApplicationId -Password $secPw -ErrorAction stop
}
catch{
write-host "New app credential did not successfully set. Please create new app credential and add to keyvault: $keyVaultName in resource group: $($kv.ResourceGroupName) in subscription $scriptSubscriptionID"
write-host "The error message provided is contained in the "'$Error'" variable."
break
}

#Disables old version of keyvault secret
$version = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultSecretName).Version
Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultSecretName | where {$_.Version -eq $version} | Set-AzKeyVaultSecretAttribute -Enable $false

#Sets new keyvault secret
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultSecretName -SecretValue $secPw

#Display time for entire script to run
Write-Output "Finish script at" (Get-Date)
$finishScript = Get-Date
$scriptDuration = New-TimeSpan -Start $startScript -End $finishScript
Write-Output "Time difference is: $scriptDuration"
