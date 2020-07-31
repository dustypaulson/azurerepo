<#
param(
[Parameter (Mandatory= $true)]
[String] $attackedVMResourceGroupName,

[Parameter (Mandatory= $true)]
[String] $attackedSubscriptionID,

	[Parameter(Mandatory = $true)]
	[string]$attackedVMName

)
#>

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

$attackedVMResourceGroupName = "Dusty"
$attackedSubscriptionID = "1a0a3f26-c387-4204-891e-be296382e9d2"
$attackedVMName = "attackedvm2"
$forensicsVMName = "forensicsVM"

#Time Stamp
$Timestamp = $(Get-Date -Format "MM-dd-yyyy_hh-mm-ss-ms")

#Creates log path if not present
$logCheck = Test-Path -Path "C:\forensicsLog\memCapture"
if ($logCheck -eq $false) {
	mkdir "C:\forensicsLog\memCapture" -Force
}

#Creates log file name
$logFileName = "C:\forensicsLog\memCapture\memCapture.csv"

#Connect Azure Account and creates log file for account verification
$connectionCheck = Connect-AzAccount

#Forensics Subscription ID
$forensicsSubscriptionID = "ba1f7dcc-89de-4858-9f8b-b2ad61c895b5"

#Forensics VM Name
$forensicsVMName = "forensicsvm"

#Forensics Resource Group Name
$forensicsVMResourceGroup = "Dusty-Forensics"

#Application Id of the SPN that will be used for authentication on the local VM
$userName = "555b6390-ef6f-4568-a5e8-c7dbc04469ec"

#Keyvault information for local VM SPN Password
$keyVaultName = "forensicsKV"
$keyVaultSecretName = "password"

#Provide tenant ID for login
$tenantID = "72f988bf-86f1-41af-91ab-2d7cd011db47"

#Name of the script in the storage account that will run on the local Windows VM to run memCap
$memCapScript = "memCap.ps1"

#Name of the script in the storage account that will run on the local Linux VM to run memCap
$memCapScriptLinux = "ubuntu_forensics.sh"

#Name of memory capture disk
$memCapDiskName = "memcap"

#Name of memory capture disk
$memCapDiskNameLinux = "linuxmemcap"

#Forensics storage account container where script is stored for custom script extension
$forensicsScriptSAContainer = "forensicscript"

#Container for logs
$logContainer = "forensicauditlog"

#Provide Shared Access Signature (SAS) expiry duration in seconds e.g. 86400 Seconds.
#Know more about SAS here: https://docs.microsoft.com/en-us/Az.Storage/storage-dotnet-shared-access-signature-part-1
$sasExpiryDuration = "86400"

#Name of the storage container where the downloaded VHD will be stored
$storageVHDContainerName = "forensicvhdfiles"

#Storage Account prefix to build storage for VHD transfer
$saPrefix = "dustymemcap"

#Forensic storage account name
$forensicSAName = "dustyforensicstest"

#Selects Subscription of Forensics VM
Write-Output "Change subscription to Forensics VM Subscription"
Select-AzSubscription -SubscriptionId $forensicsSubscriptionID

#Gets password for SPN from keyvault
$kvPW = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultSecretName).SecretValueText
$passwd = ConvertTo-SecureString $kvPW -AsPlainText -Force
$pscredential = New-Object System.Management.Automation.PSCredential("$username", $passwd)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

#Selects Subscription of Forensics VM
Write-Output "Change subscription to Forensics VM Subscription"
Select-AzSubscription -SubscriptionId $forensicsSubscriptionID

#Get Forensic VM Object
Write-Output "Getting Forenic VM"
$forensicsVM = Get-AzVM -Name $forensicsVMName -ResourceGroupName $forensicsVMResourceGroup

#Get Forensic Storage Account and key value
$forensicSA = Get-AzStorageAccount -ResourceGroupName $forensicsVM.ResourceGroupName -Name $forensicSAName
$forensicSAKey = (Get-AzStorageAccountKey -ResourceGroupName $forensicsVM.ResourceGroupName -Name $forensicSA.StorageAccountName).Value[0]

#Selects the subscription of the attacked VM
Write-Output "Change subscription to Attacked VM Subscription"
Select-AzSubscription -SubscriptionId $attackedSubscriptionID

#Get the Attacked VM object
Write-Output "Getting Attacked VM information"
$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName

#Create log files for memcap
$jobvalue = [pscustomobject]@{
	Account = $connectionCheck.Context.Account.id
	AttackedVM = $attackedVM.Name
	AttackedVMSubID = $attackedVM.id.Split("/")[2]
    AttackedVMRG = $attackedVM.ResourceGroupName
    TimeStamp = $Timestamp
}

$jobvalue | Export-Csv $logFileName -Append -NoClobber -NoTypeInformation -Force -Confirm:$false

#Upload Log to Storage Account
Set-AzStorageBlobContent -File $logFileName -Container $logContainer -blob ($($logFileName.Split("\")[2]) + '\' + $($logFileName.Split("\")[3])) -Context $forensicSA.Context -Force

#Selects Subscription of Forensics VM
Write-Output "Change subscription to Forensics VM Subscription"
Select-AzSubscription -SubscriptionId $forensicsSubscriptionID

#Get original memcap disk from Forensics RG
if ($attackedVM.StorageProfile.OsDisk.OsType -eq "Windows")
{
       $memCapDisk = Get-AzDisk -ResourceGroupName $forensicsVMResourceGroup -DiskName $memCapDiskName
              $winDisk = Get-AzDisk -ResourceGroupName $forensicsVMResourceGroup -DiskName $memCapDiskName
       $linDisk = Get-AzDisk -ResourceGroupName $forensicsVMResourceGroup -DiskName $memCapDiskNameLinux
}
if ($attackedVM.StorageProfile.OsDisk.OsType -eq "Linux")
{
       $memCapDisk = Get-AzDisk -ResourceGroupName $forensicsVMResourceGroup -DiskName $memCapDiskNameLinux
       $winDisk = Get-AzDisk -ResourceGroupName $forensicsVMResourceGroup -DiskName $memCapDiskName
              $linDisk = Get-AzDisk -ResourceGroupName $forensicsVMResourceGroup -DiskName $memCapDiskNameLinux
}

#Detach Disk From Forensics VM
Write-Output ("Removing tools disk from Forensics VM if attached")
if ($forensicsVM.StorageProfile.DataDisks.Name -contains $winDisk.Name -or $forensicsVM.StorageProfile.DataDisks.Name -contains $linDisk.Name)
{
    if($winDisk -ne $null){
       Remove-AzVMDataDisk -VM $forensicsVM -Name $winDisk.Name
       Update-AzVM -ResourceGroupName $forensicsVM.ResourceGroupName -VM $forensicsVM
       $forensicsVM = Get-AzVM -ResourceGroupName $forensicsVM.ResourceGroupName -Name $forensicsVM.Name
       }
           if($linDisk -ne $null){
       Remove-AzVMDataDisk -VM $forensicsVM -Name $linDisk.Name
       Update-AzVM -ResourceGroupName $forensicsVM.ResourceGroupName -VM $forensicsVM
       $forensicsVM = Get-AzVM -ResourceGroupName $forensicsVM.ResourceGroupName -Name $forensicsVM.Name
       }
                  if($linDisk -ne $null){

              Remove-Variable -Name linDisk
              }
                  if($winDisk -ne $null){

                     Remove-Variable -Name windisk
                     }
}

#Checks for disks from pervious runs. If disks exist please remove the previous files by saving and removing or deleting the directory
if ($oldCapture = Get-AzDisk | Where-Object { $_.Name -like "*memcap*" -and $_.DiskState -eq "Attached"})
{
               foreach ($capture in $oldCapture) {
        $memCapDrive = (Get-PSDrive | Where-Object Description -EQ MemCap).Root
        if($memCapDrive -eq $null){
        Write-Host "No memCap drive detected"
        break}
        $files = Get-ChildItem -Path $memCapDrive
                              do{
        Write-Host ($capture.Name + " is still attached to the $forensicsVMName. Please either save the files and delete the directory if needed or simply delete the directory. The script will continue when no previous memory capture file directory exists.") -ForegroundColor yellow -BackgroundColor Black
        Start-Sleep 60
        $files = Get-ChildItem -Path $memCapDrive
}until ($files.Name -eq "ftkimager" -or $files.count -eq 0)
                              Remove-AzVMDataDisk -VM $forensicsVM -Name $capture.Name
                              Update-AzVM -ResourceGroupName $forensicsVM.ResourceGroupName -VM $forensicsVM
        Remove-AzDisk -ResourceGroupName $forensicsVMResourceGroup -DiskName $capture.Name -Force -AsJob
                              $forensicsVM = Get-AzVM -ResourceGroupName $forensicsVM.ResourceGroupName -Name $forensicsVM.Name

       }
}

#Generate the SAS for the managed disk memcap in Forensics RG
Revoke-AzDiskAccess -ResourceGroupName $memCapDisk.ResourceGroupName -DiskName $memCapDisk.Name -Confirm:$false
Write-Output "Generating SAS token for managed disk to extract VHD"
$sas = Grant-AzDiskAccess -ResourceGroupName $memCapDisk.ResourceGroupName -DiskName $memCapDisk.Name -DurationInSecond $sasExpiryDuration -Access Read

#Selects the subscription of the attacked VM
Write-Output "Change subscription to Attacked VM Subscription"
Select-AzSubscription -SubscriptionId $attackedSubscriptionID

#Selects the subscription of the attacked VM
Write-Output "Change subscription to Attacked VM Subscription"
$subName = Select-AzSubscription -SubscriptionId $attackedSubscriptionID

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

#Create Storage Account in region of Attacked VM
$saNameTest = Get-AzStorageAccountNameAvailability -Name $saPrefix
$i = 0
do {
       if ($saNameTest.NameAvailable -eq $false) {
             $saName = ($saPrefix + $i++)
             $saNameTest = Get-AzStorageAccountNameAvailability -Name $saName
       }
       else { $saName = $saPrefix }
}
until ($saNameTest.NameAvailable -eq $true)


#Get RG to place newly created items
$rg = Get-AzResourceGroup | where {$_.ResourceGroupName -eq "CDC_Forensics_$($subName.Subscription.Name)"}

#Create new storage account to match the region of the attacked vm
New-AzStorageAccount -ResourceGroupName $rg.ResourceGroupName -Name $saName -SkuName Standard_LRS -Location $attackedVM.Location -Kind StorageV2 -AccessTier Hot

#Gets Attacked VM storage account where VHD wll reside
Write-Output ("Creating Storage Account in region " + $attackedvm.Location + " to match Attacked VM location")
$storageAccount = Get-AzStorageAccount -ResourceGroupName $rg.ResourceGroupName -Name $saName
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $rg.ResourceGroupName -Name $storageAccount.StorageAccountName).Value[0]

#Creating storage container for VHD file
Write-Output "Creating storage container for VHD file"
New-AzStorageContainer -Name $storageVHDContainerName -Context $storageAccount.Context

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

do
{
       $copyStatus = (Get-AzStorageBlobCopyState -Context $destinationContext -Container $storageVHDContainerName -Blob $destinationVHDFileName).status
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
Write-Output "It took the VHD file $vhdruntime to export to the storage account $storageAccountName"

#Remove access to VHD file from managed disk
Select-AzSubscription -SubscriptionId $forensicsSubscriptionID
Write-Output "Revoking access to VHD file on memcap disk"
Revoke-AzDiskAccess -ResourceGroupName $forensicsVM.ResourceGroupName -DiskName $memCapDisk.Name -Confirm:$false
Write-Output "VHD Access Revoked"

$testBlob = Get-AzStorageBlob -Blob $destinationVHDFileName -Container $storageVHDContainerName -Context $storageAccount.Context | Where-Object Name -EQ $destinationVHDFileName
if ($testBlob -eq $null) {
       Write-Output ".VHD file is not available. Please rerun try script again."
       break
}

#Select attacked subscription
Select-AzSubscription -SubscriptionId $attackedSubscriptionID

#Create managed disk from VHD file in Attacked VM RG to attach to Attacked VM to run memory capture
$diskURI = ($destinationContext.BlobEndPoint + $storageVHDContainerName + "/" + $destinationVHDFileName)
$diskConfig = New-AzDiskConfig -AccountType $storageAccount.Sku.Name -Location $attackedVM.Location -CreateOption Import -StorageAccountId $storageAccount.id -SourceUri $diskURI
$checkDisk = Get-AzDisk -ResourceGroupName $rg.ResourceGroupName -DiskName $memCapDisk.Name -ErrorAction SilentlyContinue
$m = 0
if ($checkDisk -ne $null) {
       do {
             $newDiskName = $checkDisk.Name + $m
             $m++
             $checkDisk = Get-AzDisk -ResourceGroupName $rg.ResourceGroupName -DiskName $newDiskName -ErrorAction SilentlyContinue
       }
       until ($checkDisk -eq $null)
}
else
{
       $newDiskName = $memCapDisk.Name
}

#make try catch in case disk is not created
try {
       New-AzDisk -Disk $diskConfig -ResourceGroupName $rg.ResourceGroupName -DiskName $newDiskName -ErrorAction Stop
}
catch
{
       #do loop until disk is created
       do {
             New-AzDisk -Disk $diskConfig -ResourceGroupName $rg.ResourceGroupName -DiskName $newDiskName
             $diskTest = Get-AzDisk -ResourceGroupName $rg.ResourceGroupName -DiskName $newDiskName -ErrorAction SilentlyContinue
       }
       until ($diskTest -ne $null)
}

#Clean up storage account that is no longer needed in Attacked VM RG
Remove-AzStorageAccount -ResourceGroupName $rg.ResourceGroupName -Name $storageAccount.StorageAccountName -Force -Confirm:$false

#Attach memcap disk to AttackedVM
if ($attackedVM.StorageProfile.DataDisks.Name -contains $newDiskName)
{
       Write-Output "Disk already attached"
}
else
{
       $newMemCapDisk = Get-AzDisk -ResourceGroupName $rg.ResourceGroupName -DiskName $newDiskName
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

#Custom script extension to capture memory
if ($attackedVM.StorageProfile.OsDisk.OsType -eq "Windows")
{
       do {
             Write-Output "Starting custom script extension"
             Set-AzVMCustomScriptExtension -ResourceGroupName $attackedVM.ResourceGroupName -VMName $attackedVM.Name -ContainerName $forensicsScriptSAContainer -FileName $memCapScript -StorageAccountName $forensicSA.StorageAccountName -StorageAccountKey $forensicSAKey -Location $attackedVM.Location -Name "memCap" -run $memCapScript -ForceRerun "RerunExtension" -SecureExecution -ErrorAction SilentlyContinue
             $state = (Get-AzVMCustomScriptExtension -ResourceGroupName $attackedVM.ResourceGroupName -VMName $attackedVM.Name -Name memCap).ProvisioningState
             Start-Sleep -Seconds 120
             Write-Host "removing custom script extension"
             Remove-AzVMCustomScriptExtension -ResourceGroupName $attackedvm.ResourceGroupName -VMName $attackedvm.Name -Name memCap -Force
             $state
             Start-Sleep -Seconds 120
       }
       while ($state -ne "Succeeded")
}

#If os is Linux run a template to deploy custom script extension
if ($attackedVM.StorageProfile.OsDisk.OsType -eq "Linux")
{
       #Check for prexisting template file.
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
                    "storageAccountName": "$($forensicSA.StorageAccountName)",
                     "storageAccountKey": "$($forensicSAKey)"                
            }
        }
      }
    ]
}
"@ | Out-File C:\forensicsLog\cseLinux.json -Force -Confirm:$false -NoClobber

       do {
             #Starting custom script extension with template deployment
             Write-Output "Starting custom script extension"
             New-AzResourceGroupDeployment -Name memcap -ResourceGroupName $attackedVM.ResourceGroupName -TemplateFile C:\forensicsLog\cseLinux.json -fileURI "https://$($forensicSA.StorageAccountName).blob.core.windows.net/$($forensicsScriptSAContainer)/$($memCapScriptLinux)" -AsJob

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

#Detach Disk And Move Back To Forensics VM
Write-Output "Removing memCap from AttackedVM"
$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName
Remove-AzVMDataDisk -VM $attackedVM -Name $newDiskName
Update-AzVM -ResourceGroupName $attackedVM.ResourceGroupName -VM $attackedVM
$attackedVM = Get-AzVM -ResourceGroupName $attackedVMResourceGroupName -Name $attackedVMName

#Generate the SAS for the memcap managed disk from Attacked VM
Write-Output "Generating SAS token for managed disk to extract VHD"
$forensicSAS = Grant-AzDiskAccess -ResourceGroupName $rg.ResourceGroupName -DiskName $newDiskName -DurationInSecond $sasExpiryDuration -Access Read

#Create context for Forensics Storage Account
Write-Output "Creating destination context for VHD to be placed in Attacked VM Storage Account"
$forensicDestinationContext = New-AzStorageContext –StorageAccountName $forensicSA.StorageAccountName -StorageAccountKey $forensicSAKey

#Copy the VHD of the managed disk to the storage account. If the BLOB is already in the storage account the script will stop
$vhdStartTime = Get-Date
try
{
       Get-AzStorageBlob -Blob ($attackedVM.Name + "_" + $destinationVHDFileName) -Container $storageVHDContainerName -Context $forensicSA.Context -ErrorAction stop
       Write-Output "The blob " + ($attackedVM.Name + "_" + $destinationVHDFileName) + " is already in " $($forensicSA.StorageAccountName)
       Write-Output "Stopping script. Please investigate why the VHD file " + ($attackedVM.Name + "_" + $destinationVHDFileName) + " already exists"
       break
}
catch
{
       Write-Output "Starting VHD Export from attacked VM" (Get-Date)
       Start-AzStorageBlobCopy -AbsoluteUri $forensicSAS.AccessSAS -DestContainer $storageVHDContainerName -DestContext $forensicDestinationContext -DestBlob ($attackedVM.Name + "_" + $destinationVHDFileName)
}
$copyStatus = (Get-AzStorageBlobCopyState -Context $forensicDestinationContext -Container $storageVHDContainerName -Blob ($attackedVM.Name + "_" + $destinationVHDFileName)).status
do
{
       $copyStatus = (Get-AzStorageBlobCopyState -Context $forensicDestinationContext -Container $storageVHDContainerName -Blob ($attackedVM.Name + "_" + $destinationVHDFileName)).status
       Write-Output "starting sleep"
       Start-Sleep -Seconds 60
       $copyStatus
}
until ($copyStatus -eq "Success")

#Display time taken to transfer VHD file
Write-Output "Completed VHD Export from attacked VM" (Get-Date)
$vhdEndTime = Get-Date
$vhdRunTime = New-TimeSpan -Start $vhdStartTime -End $vhdEndTime
Write-Output "It took the VHD file $vhdruntime to export to the storage account $forensicSAName"

#Remove access to VHD file from managed disk
Select-AzSubscription -SubscriptionId $attackedSubscriptionID
Write-Output "Revoking access to VHD file on memcap disk in attacked vm RG"
Revoke-AzDiskAccess -ResourceGroupName $rg.ResourceGroupName -DiskName $newDiskName -Confirm:$false
Write-Output "VHD Access Revoked"
Remove-AzDisk -ResourceGroupName $rg.ResourceGroupName -DiskName $newDiskName -Force -Confirm:$false

#Selects Forensics Subscription
Select-AzSubscription -SubscriptionId $forensicsSubscriptionID

#Create managed disk from VHD file in Forensics VM RG to attach to Forensics VM to run memory capture
$diskURI = ($forensicSA.PrimaryEndpoints.Blob + $storageVHDContainerName + "/" + ($attackedVM.Name + "_" + $destinationVHDFileName))
$diskConfig = New-AzDiskConfig -AccountType $forensicSA.Sku.Name -Location $forensicsVM.Location -CreateOption Import -StorageAccountId $forensicSA.id -SourceUri $diskURI
New-AzDisk -Disk $diskConfig -ResourceGroupName $forensicsVM.ResourceGroupName -DiskName ($attackedVM.Name + "_" + $newDiskName)
$newMemCapDisk = Get-AzDisk -ResourceGroupName $forensicsVM.ResourceGroupName -DiskName ($attackedVM.Name + "_" + $newDiskName)

Write-Output "New disk name is $($newMemCapDisk.Name)"

#Calculate LUN for data disk to attach to Forensics VM
Write-Output "Calculate the LUN number for attaching data disk"
$forensicsVM = Get-AzVM -ResourceGroupName $forensicsVMResourceGroup -Name $forensicsVMName
$lun = $null
$numberOfDataDisks = $forensicsVM.StorageProfile.DataDisks.Count
if ($numberOfDataDisks -eq 0)
{
       $lun = "1"
}
else
{
       $lunNumber = $forensicsVM.StorageProfile.DataDisks.lun
       $lunMax = ($lunNumber | Measure-Object -Maximum).Maximum
       $lun = $lunMax += 1
}

$forensicsVM = Add-AzVMDataDisk -CreateOption Attach -Lun $lun -VM $forensicsVM -ManagedDiskId $newMemCapDisk.id
Update-AzVM -VM $forensicsVM -ResourceGroupName $forensicsVM.ResourceGroupName
$forensicsVM = Get-AzVM -ResourceGroupName $forensicsVMResourceGroup -Name $forensicsVMName

#Selects Forensics Subscription
Select-AzSubscription -SubscriptionId $attackedSubscriptionID

#Remove VHD file from Forensics RG
Remove-AzStorageBlob -Blob ($attackedVM.Name + "_" + $destinationVHDFileName) -Container $storageVHDContainerName -Context $forensicSA.Context 
