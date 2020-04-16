$connectionName = "AzureRunAsConnection"
try
{
       # Get the connection "AzureRunAsConnection "
       $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

       "Logging in to Azure..."
       Add-AzAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
}
catch {
       if (!$servicePrincipalConnection)
       {
             $ErrorMessage = "Connection $connectionName not found."
             throw $ErrorMessage
       } else {
             Write-Error -Message $_.Exception
             throw $_.Exception
       }
}

#Variables for script to run. Diagnostic extension will be set on all VM's in same region as storage account
$subID = "ba1f7dcc-89de-4858-9f8b-b2ad61c895b5"
$storageAccountName = "vhdcapture8788"
$storageAccountResourceGroup = "Dusty-Forensics"
$blobSinkName = "MyJSONBlob"
$expiryTime = (Get-Date).AddDays(25)

#Select subscription
Select-AzSubscription -SubscriptionId $subID

#Gets storage account information
$sa = Get-AzStorageAccount -ResourceGroupName $storageAccountResourceGroup -Name $storageAccountName

#Configures storage account location
$storageLocation = $sa.Location

#Gets VM Object information in the same region as the storage account
$VMs = Get-AzVM | Where-Object { $_.Location -eq $storageLocation }
foreach ($vm in $vms) {
       #Nulls the variables used to check if Windows or Linux
       $linuxExtensionCheck = $null

       #Checks if diagnostic extension is currently installed
       $linuxExtensionCheck = Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name | Where-Object { $_.ExtensionType -eq "LinuxDiagnostic" }

       #Gets power status for VM
       $status = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status

       #Checks for Linux VM that does not contain the diagnostic extension and that it is turned on 
       if ($vm.StorageProfile.OsDisk.OsType -eq "Linux" -and $linuxExtensionCheck -eq $null -and $status.Statuses.displaystatus -contains "VM Running") {

             #Create SAS token for storage account 
             $sasToken = New-AzStorageAccountSASToken -Service Blob,Table -ResourceType Service,Container,Object -Permission "racwdlup" -ExpiryTime $expiryTime -Context (Get-AzStorageAccount -ResourceGroupName $storageAccountResourceGroup -AccountName $storageAccountName).Context

             # Build the protected settings (storage account SAS token)
             $protectedSettings = "{'storageAccountName': '$storageAccountName', 'sinksConfig': {
        'sink': [{
                'name': '$($blobSinkName)',
                'type': 'JsonBlob',
                'sasURL': '$sasToken'
            }
        ]
    }, 'storageAccountSasToken': '$sasToken'}"

             #Finally tell Azure to install and enable the extension
             Set-AzVMExtension -ResourceGroupName $VM.ResourceGroupName -VMName $vm.Name -Location $vm.Location -ExtensionType LinuxDiagnostic -Publisher Microsoft.Azure.Diagnostics -Name LinuxDiagnostic -SettingString $linuxExtensionCheck.PublicSettings -ProtectedSettingString $protectedSettings -TypeHandlerVersion 3.0 -asjob
       }
} 
