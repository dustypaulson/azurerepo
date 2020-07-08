<#"
To get helpful information on the mandatory parameters down below type !? as the value of the parameter during run time to see 
help message.
#>
<#
param (
    [Parameter(Mandatory=$true,
    HelpMessage="Enter the Subscription ID the attacked VM resides in.")]
    [String] $attackedSubscriptionID,

[Parameter(Mandatory=$true,
    HelpMessage="Enter the resource group the attacked VM resides in.")]
    [String] $attackedVMResourceGroupName,

        [Parameter(Mandatory=$true,
    HelpMessage="Enter the name of the VM that has been attacked.")]
    [String] $attackedVMName,

            [Parameter(Mandatory=$true,
    HelpMessage="Storage Account name that is in the attacked VM's subscription. This is used to region match the disk for the memory tools and the attacked VM so the disk can be attached.")]
    [String] $forensicsStorageAccount,

                [Parameter(Mandatory=$true,
    HelpMessage="Storage Account container used to store VHD files while creating disks and downloading memory data")]
    [String] $forensicsVHDStorageContainer,

                    [Parameter(Mandatory=$true,
    HelpMessage="Name given to the drive where vhd files will be downloaded to.")]
    [String] $vhdDestinationDriveName
)
#>

#Installs Azure modules if not present
if (Get-InstalledModule -Name AZ -ErrorAction SilentlyContinue) {
	Write-Host "Module exists"
}
else {
	Install-PackageProvider Nuget -Force
	Install-Module AZ -Force -AllowClobber
}

$attackedVMResourceGroupName = "Dusty"
$attackedSubscriptionID = "1a0a3f26-c387-4204-891e-be296382e9d2"
$attackedVMName = "attackedvm"
$forensicsStorageAccount = "dustyattacked"
$forensicsToolsStorageContainer = "toolsdisks"
$forensicsVHDStorageContainer = "vhd"
$vhdDestinationDriveName = "OSDisk"

#Creates log path if not present
$logCheck = Test-Path -Path "C:\forensicsLog\memCapture"
if ($logCheck -eq $false) {
	mkdir "C:\forensicsLog\memCapture" -Force
}

#Creates log file name
$logFileName = "C:\forensicsLog\memCapture\memCapture_$(Get-Date -Format "MM-dd-yyyy_hh-mm-ss-ms").csv"

#Use to get complete script runtime at the end of script
$startScript = Get-Date

#Connect Azure Account and gathers necessary information from log file and context switching for spn password updates
$connectionCheck = Connect-AzAccount

#Subscription ID where memory capture script and key vault is located
$scriptSubscriptionID = "ba1f7dcc-89de-4858-9f8b-b2ad61c895b5"

#Application Id of the SPN that will be used for authentication
$userName = "555b6390-ef6f-4568-a5e8-c7dbc04469ec"

#Keyvault information for SPN password retrieval
$keyVaultName = "forensicsKV"
$keyVaultSecretName = "password"

#Provide tenant ID for login
$tenantID = "72f988bf-86f1-41af-91ab-2d7cd011db47"

#Name of the script in the storage account that will run on the local Windows VM to run memCap
$memCapScript = "winpmemcap.ps1"

#Name of the script in the storage account that will run on the local Linux VM to run memCap
$memCapScriptLinux = "redhat_forensics.sh"

#Name of Windows memory capture disk
$memCapDiskName = "memcap"

#Name of Linux memory capture disk
$memCapDiskNameLinux = "linuxmemcap"

#Storage account name where memory capture scripts are located
$scriptsSAName = "dustyforensicstest"

#Storage account resource group where scripts are located
$scriptSARG = "Dusty-Forensics"

#Storage account container where scripts are stored for custom script extension
$ScriptSAContainer = "forensicscript"

#Provide Shared Access Signature (SAS) expiry duration in seconds e.g. 86400 Seconds.
#Know more about SAS here: https://docs.microsoft.com/en-us/Az.Storage/storage-dotnet-shared-access-signature-part-1
$sasExpiryDuration = "86400"

#Selects Subscription that contains key vault and script storage account
Write-Output "Change subscription to subscription that contains key vault and script storage account"
Select-AzSubscription -SubscriptionId $scriptSubscriptionID

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

#Selects Subscription that contains key vault and script storage account
Write-Output "Change subscription to subscription that contains key vault and script storage account"
Select-AzSubscription -SubscriptionId $scriptSubscriptionID

#Get Forensic Storage Account and key value
$scriptSA = Get-AzStorageAccount -ResourceGroupName $scriptSARG -Name $scriptsSAName
$scriptSAKey = (Get-AzStorageAccountKey -ResourceGroupName $scriptSARG -Name $scriptSA.StorageAccountName).Value[0]

#Get original memcap disk from Forensics RG
if ($attackedVM.StorageProfile.OsDisk.OsType -eq "Windows")
{
	$memCapDisk = Get-AzDisk -ResourceGroupName $forensicsVMResourceGroup -DiskName $memCapDiskName
}
if ($attackedVM.StorageProfile.OsDisk.OsType -eq "Linux")
{
	$memCapDisk = Get-AzDisk -ResourceGroupName $forensicsVMResourceGroup -DiskName $memCapDiskNameLinux
}

#Generate the SAS for the disk that contains memory capture tool
Revoke-AzDiskAccess -ResourceGroupName $memCapDisk.ResourceGroupName -DiskName $memCapDisk.Name -Confirm:$false
Write-Output "Generating SAS token for managed disk to extract VHD"
$sas = Grant-AzDiskAccess -ResourceGroupName $memCapDisk.ResourceGroupName -DiskName $memCapDisk.Name -DurationInSecond $sasExpiryDuration -Access Read

#Selects the subscription of the attacked VM
Write-Output "Change subscription to Attacked VM Subscription"
Select-AzSubscription -SubscriptionId $attackedSubscriptionID

#Calculate LUN for data disk to attach to attacked VM
Write-Output "Calculate the LUN number for attaching data disk"
$numberOfDataDisks = $attackedVM.StorageProfile.DataDisks.Count
if ($numberOfDataDisks -eq "0")
{
	$lun = "1"
}
else
{
	$lunNumber = $attackedVM.StorageProfile.DataDisks.lun
	$lunMax = ($lunNumber | Measure-Object -Maximum).Maximum
	$lun = $lunMax += 1
}

#Gets storage account in Attacked VM subscription where VHD will reside for region matching
Write-Output ("Gets Storage Account in region " + $attackedvm.Location + " to match Attacked VM location")
$storageAccount = Get-AzStorageAccount | where {$_.StorageAccountName -eq $forensicsStorageAccount}
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName).Value[0]

#Create Storage Context for Attacked VM storage account for VHD file
Write-Output "Creating destination context for VHD to be placed in Attacked VM Storage Account"
$destinationContext = New-AzStorageContext –StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storageAccountKey

#Provide the name of the destination VHD file to which the VHD of the managed disk will be copied.
Write-Output "Creating VHD file name"
$destinationVHDFileName = $memCapDisk.Name + ".vhd"

#Copy the VHD of the managed disk to the storage account. If the BLOB is already in the storage account the script will stop
$vhdStartTime = Get-Date
try
{
	Get-AzStorageBlob -Blob $destinationVHDFileName -Container $forensicsToolsStorageContainer -Context $storageAccount.Context -ErrorAction stop
	Write-Output "The blob $destinationVHDFileName is already in $($storageAccount.StorageAccountName)"
	Write-Output "Stopping script. Please investigate why the VHD file $destinationVHDFileName already exists"
	break
}
catch
{
	Write-Output "Starting VHD Export from attacked VM" (Get-Date)
	Start-AzStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer $forensicsToolsStorageContainer -DestContext $destinationContext -DestBlob $destinationVHDFileName
}

do
{
	$copyStatus = (Get-AzStorageBlobCopyState -Context $destinationContext -Container $forensicsToolsStorageContainer -Blob $destinationVHDFileName).status
	Write-Output "starting sleep"
	Start-Sleep -Seconds 60
	$copyStatus
	if ($copyStatus -eq "Failed") {
		Write-Host "VHD copy failed. Please investigate why and start again."
		break
	}
}
until ($copyStatus -eq "Success")

#Display time taken to transfer VHD file
Write-Output "Completed VHD Export from attacked VM" (Get-Date)
$vhdEndTime = Get-Date
$vhdRunTime = New-TimeSpan -Start $vhdStartTime -End $vhdEndTime
Write-Output "It took the VHD file $vhdruntime to export to the storage account $($storageAccount.StorageAccountName)"

#Selects Subscription that contains key vault and script storage account
Write-Output "Change subscription to subscription that contains key vault and script storage account"
Select-AzSubscription -SubscriptionId $scriptSubscriptionID

#Remove access to VHD file from managed disk
Write-Output "Revoking access to VHD file on memcap disk"
Revoke-AzDiskAccess -ResourceGroupName $scriptSARG -DiskName $memCapDisk.Name -Confirm:$false
Write-Output "VHD Access Revoked"

#Select attacked subscription
Select-AzSubscription -SubscriptionId $attackedSubscriptionID

#Checks if BLOB is available
$testBlob = Get-AzStorageBlob -Blob $destinationVHDFileName -Container $forensicsToolsStorageContainer -Context $storageAccount.Context | Where-Object Name -EQ $destinationVHDFileName
if ($testBlob -eq $null) {
	Write-Output ".VHD file is not available. Please rerun try script again."
	break
}

#Create managed disk from VHD file in Attacked VM RG to attach to Attacked VM to run memory capture
$diskURI = ($destinationContext.BlobEndPoint + $forensicsToolsStorageContainer + "/" + $destinationVHDFileName)
$diskConfig = New-AzDiskConfig -AccountType $storageAccount.Sku.Name -Location $attackedVM.Location -CreateOption Import -StorageAccountId $storageAccount.id -SourceUri $diskURI
$checkDisk = Get-AzDisk -ResourceGroupName $attackedVM.ResourceGroupName -DiskName $memCapDisk.Name -ErrorAction SilentlyContinue
$m = 0
if ($checkDisk -ne $null) {
	do {
		$newDiskName = $checkDisk.Name + $m
		$m++
		$checkDisk = Get-AzDisk -ResourceGroupName $attackedVM.ResourceGroupName -DiskName $newDiskName -ErrorAction SilentlyContinue
	}
	until ($checkDisk -eq $null)
}
else
{
	$newDiskName = $memCapDisk.Name
}

#Verifies disk has been created
try {
	New-AzDisk -Disk $diskConfig -ResourceGroupName $attackedVM.ResourceGroupName -DiskName $newDiskName -ErrorAction Stop
}
catch
{
	#Do loop until disk is created
	do {
		New-AzDisk -Disk $diskConfig -ResourceGroupName $attackedVM.ResourceGroupName -DiskName $newDiskName
		$diskTest = Get-AzDisk -ResourceGroupName $attackedVM.ResourceGroupName -DiskName $newDiskName -ErrorAction SilentlyContinue
	}
	until ($diskTest -ne $null)
}

#Deletes VHD file that is no longer needed
Remove-AzStorageBlob -Blob $destinationVHDFileName -Container $forensicsToolsStorageContainer -Context $storageAccount.Context -force

#Attach memcap disk to AttackedVM
if ($attackedVM.StorageProfile.DataDisks.Name -contains $newDiskName)
{
	Write-Output "Disk already attached"
}
else
{
	$newMemCapDisk = Get-AzDisk -ResourceGroupName $attackedVM.ResourceGroupName -DiskName $newDiskName
	$attackedVM = Add-AzVMDataDisk -CreateOption Attach -Lun $lun -VM $attackedVM -ManagedDiskId $newMemCapDisk.id
	Update-AzVM -VM $attackedVM -ResourceGroupName $attackedVM.ResourceGroupName
	$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName
}

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

#Get the Attacked VM object
Write-Output "Getting Attacked VM information"
$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName

#Remove Custom Script Extension if one is present
$customScriptExtensionCheck = (Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName).Extensions | Where-Object { $_.VirtualMachineExtensionType -eq "CustomScriptExtension" -or $_.VirtualMachineExtensionType -eq "CustomScript" }
if ($customScriptExtensionCheck -ne $null) {
	Remove-AzVMCustomScriptExtension -ResourceGroupName $attackedvm.ResourceGroupName -VMName $attackedvm.Name -Name $customScriptExtensionCheck.Name -Force
}

#Deploys Custom script extension to capture memory. Checks state and continues when state has succeeded
if ($attackedVM.StorageProfile.OsDisk.OsType -eq "Windows")
{
	do {
		Write-Output "Starting custom script extension. This will start running Winpmem memory capture."
		Set-AzVMCustomScriptExtension -ResourceGroupName $attackedVM.ResourceGroupName -VMName $attackedVM.Name -ContainerName $ScriptSAContainer -FileName $memCapScript -StorageAccountName $scriptSA.StorageAccountName -StorageAccountKey $scriptSAKey -Location $attackedVM.Location -Name "memCap" -run $memCapScript -ForceRerun "RerunExtension" -SecureExecution -ErrorAction SilentlyContinue
		$state = (Get-AzVMCustomScriptExtension -ResourceGroupName $attackedVM.ResourceGroupName -VMName $attackedVM.Name -Name memCap).ProvisioningState
		Start-Sleep -Seconds 120
		Write-Host "Winpmem is still running. Custom script extension hit its max run time. Restarting Custom Script Extension"
		Remove-AzVMCustomScriptExtension -ResourceGroupName $attackedvm.ResourceGroupName -VMName $attackedvm.Name -Name memCap -Force
		$state
		Start-Sleep -Seconds 120
	}
	while ($state -ne "Succeeded")
}

#If os is Linux run a template to deploy custom script extension
if ($attackedVM.StorageProfile.OsDisk.OsType -eq "Linux")
{
	#Check for preexisting template file.
	$templateFile = Test-Path C:\forensicsLog\cseLinux.json
	if ($templateFile -eq "True") {
		Remove-Item C:\forensicsLog\cseLinux.json -Force -Confirm:$false
	}

	#Create template file for Linux Custom Script Extension. This is more repeatable than the ps command for custom script extension for Linux
	$template = @"
{
    "`$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "fileURI": {
            "type": "Array"
        }
    },
    "resources": [
        {
            "type": "Microsoft.Compute/virtualMachines/extensions",
            "apiVersion": "2015-06-15",
            "name": "[concat('$($attackedVM.Name)','/memcap')]",
            "location": "$($attackedvm.Location)",
            "properties": {
                "publisher": "Microsoft.Azure.Extensions",
                "type": "CustomScript",
                "typeHandlerVersion": "2.0",
                "autoUpgradeMinorVersion": true,
                "settings": {
                    "fileUris": "[parameters('fileURI')]"
                },
                "protectedSettings": {
                    "commandToExecute": "sh $($memCapScriptLinux)",
                    "storageAccountName": "$($scriptSA.StorageAccountName)",
                     "storageAccountKey": "$($scriptSAKey)"                
            }
        }
      }
    ]
}
"@ | Out-File C:\forensicsLog\cseLinux.json -Force -Confirm:$false -NoClobber

	do {
		#Starting custom script extension with template deployment
		Write-Output "Starting custom script extension"
		New-AzResourceGroupDeployment -Name memcap -ResourceGroupName $attackedVM.ResourceGroupName -TemplateFile C:\forensicsLog\cseLinux.json -fileURI "https://$($scriptSA.StorageAccountName).blob.core.windows.net/$($ScriptSAContainer)/$($memCapScriptLinux)" -AsJob

		#Checking state of custom script extension
		$state = ((Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName).Extensions | Where-Object { $_.VirtualMachineExtensionType -eq "CustomScriptExtension" -or $_.VirtualMachineExtensionType -eq "CustomScript" }).ProvisioningState
		do {
			$state = ((Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName).Extensions | Where-Object { $_.VirtualMachineExtensionType -eq "CustomScriptExtension" -or $_.VirtualMachineExtensionType -eq "CustomScript" }).ProvisioningState
			Start-Sleep -Seconds 120
		}
		until ($state -eq "Failed" -or $state -eq "Succeeded")
		if ($state -eq "Failed") {
			#Removing custom script extension to start again
			Write-Host "FTK is still running. Removing custom script extension and start again. If this loops 10 times login to VM and see if FTK is running or if and issue is present"
			Remove-AzVMCustomScriptExtension -ResourceGroupName $attackedvm.ResourceGroupName -VMName $attackedvm.Name -Name memCap -Force
		}
	}
	while ($state -ne "Succeeded")

	#Removes template created as it is no longer needed
	Remove-Item -Path C:\forensicsLog\cseLinux.json -Force -Confirm:$false
}

#Detach Disk from Attacked VM
Write-Output "Removing memCap from AttackedVM"
$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName
Remove-AzVMDataDisk -VM $attackedVM -Name $newDiskName
Update-AzVM -ResourceGroupName $attackedVM.ResourceGroupName -VM $attackedVM
$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName

#Generate the SAS for the memory capture managed disk from Attacked VM
Write-Output "Generating SAS token for managed disk to extract VHD"
$diskSAS = Grant-AzDiskAccess -ResourceGroupName $attackedVM.ResourceGroupName -DiskName $newDiskName -DurationInSecond $sasExpiryDuration -Access Read

#Copy the VHD of the managed disk to the storage account. If the BLOB is already in the storage account the script will stop
$vhdStartTime = Get-Date
try
{
	Get-AzStorageBlob -Blob ($attackedVM.Name + "_" + $destinationVHDFileName) -Container $forensicsVHDStorageContainer -Context $destinationContext.Context -ErrorAction stop
	Write-Output "The blob " + ($attackedVM.Name + "_" + $destinationVHDFileName) + " is already in " $($scriptSA.StorageAccountName)
	Write-Output "Stopping script. Please investigate why the VHD file " + ($attackedVM.Name + "_" + $destinationVHDFileName) + " already exists"
	break
}
catch
{
	Write-Output "Starting VHD Export from attacked VM" (Get-Date)
	Start-AzStorageBlobCopy -AbsoluteUri $diskSAS.AccessSAS -DestContainer $forensicsVHDStorageContainer -DestContext $destinationContext.Context -DestBlob ($attackedVM.Name + "_" + $destinationVHDFileName)
}
$copyStatus = (Get-AzStorageBlobCopyState -Context $destinationContext.Context -Container $forensicsVHDStorageContainer -Blob ($attackedVM.Name + "_" + $destinationVHDFileName)).status
do
{
	$copyStatus = (Get-AzStorageBlobCopyState -Context $destinationContext.Context -Container $forensicsVHDStorageContainer -Blob ($attackedVM.Name + "_" + $destinationVHDFileName)).status
	Write-Output "starting sleep"
	Start-Sleep -Seconds 60
	$copyStatus
}
until ($copyStatus -eq "Success")

#Remove access to VHD file from managed disk
Write-Output "Revoking access to VHD file on memcap disk in Attacked VM RG"
Revoke-AzDiskAccess -ResourceGroupName $attackedVM.ResourceGroupName -DiskName $newDiskName -Confirm:$false
Write-Output "VHD Access Revoked"
Remove-AzDisk -ResourceGroupName $attackedVM.ResourceGroupName -DiskName $newDiskName -Force -Confirm:$false

#Display time taken to transfer VHD file
Write-Output "Completed VHD Export from attacked VM" (Get-Date)
$vhdEndTime = Get-Date
$vhdRunTime = New-TimeSpan -Start $vhdStartTime -End $vhdEndTime
Write-Output "It took the VHD file $vhdruntime to export to the storage account $scriptsSAName"

#Download vhd file from storage account - need to download from vhd container
$driveLetter = (Get-Volume | Where-Object { $_.FileSystemLabel -eq "$vhdDestinationDriveName" }).DriveLetter + ":/"
$fileCheck = Test-Path ($driveLetter + $attackedVM.Name + "_" + $destinationVHDFileName)
if ($fileCheck -eq "True") {
	mkdir ($driveLetter + $attackedVM.Name)
	Move-Item -Path ($driveLetter + $attackedVM.Name + ".vhd") -Destination ($driveLetter + $attackedVM.Name) -Force -Confirm:$false
	Get-AzStorageBlobContent -Container $forensicsVHDStorageContainer -Blob ($attackedVM.Name + "_" + $destinationVHDFileName) -Destination $driveLetter -Context $destinationContext
}
else {
	Get-AzStorageBlobContent -Container $forensicsVHDStorageContainer -Blob ($attackedVM.Name + "_" + $destinationVHDFileName) -Destination $driveLetter -Context $destinationContext
}

#Deletes VHD file that contains memory capture from storage account
Remove-AzStorageBlob -Container $forensicsVHDStorageContainer -Blob ($attackedVM.Name + "_" + $destinationVHDFileName) -Context $storageAccount.Context -Force

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
