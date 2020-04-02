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
       $windowsExtensionCheck = $null

       #Checks if diagnostic extension is currently installed
       $linuxExtensionCheck = Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name | Where-Object { $_.ExtensionType -eq "LinuxDiagnostic" }
       $windowsExtensionCheck = Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name | Where-Object { $_.ExtensionType -eq "IaaSDiagnostics" }

       #Gets power status for VM
       $status = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status

       #Checks for Windows VM that does not contain the diagnostic extension and that it is turned on 
       if ($vm.OSProfile.LinuxConfiguration -eq $null -and $windowsExtensionCheck -eq $null -and $status.Statuses.displaystatus -contains "VM Running") {

             #Settings to enable for diagnostics
             $publicSettings = '{
  "storageAccount": "__DIAGNOSTIC_STORAGE_ACCOUNT__",
  "WadCfg": {
    "DiagnosticMonitorConfiguration": {
      "overallQuotaInMB": 5120,
      "Metrics": {
        "resourceId": "__VM_RESOURCE_ID__",
        "MetricAggregation": [
          {
            "scheduledTransferPeriod": "PT1H"
          },
          {
            "scheduledTransferPeriod": "PT1M"
          }
        ]
      },
      "DiagnosticInfrastructureLogs": {
        "scheduledTransferLogLevelFilter": "Error"
      },
      "PerformanceCounters": {
        "scheduledTransferPeriod": "PT1M",
        "PerformanceCounterConfiguration": [
          {
            "counterSpecifier": "\\Processor Information(_Total)\\% Processor Time",
            "unit": "Percent",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Processor Information(_Total)\\% Privileged Time",
            "unit": "Percent",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Processor Information(_Total)\\% User Time",
            "unit": "Percent",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Processor Information(_Total)\\Processor Frequency",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\System\\Processes",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Process(_Total)\\Thread Count",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Process(_Total)\\Handle Count",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\System\\System Up Time",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\System\\Context Switches/sec",
            "unit": "CountPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\System\\Processor Queue Length",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Memory\\% Committed Bytes In Use",
            "unit": "Percent",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Memory\\Available Bytes",
            "unit": "Bytes",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Memory\\Committed Bytes",
            "unit": "Bytes",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Memory\\Cache Bytes",
            "unit": "Bytes",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Memory\\Pool Paged Bytes",
            "unit": "Bytes",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Memory\\Pool Nonpaged Bytes",
            "unit": "Bytes",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Memory\\Pages/sec",
            "unit": "CountPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Memory\\Page Faults/sec",
            "unit": "CountPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Process(_Total)\\Working Set",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Process(_Total)\\Working Set - Private",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\% Disk Time",
            "unit": "Percent",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\% Disk Read Time",
            "unit": "Percent",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\% Disk Write Time",
            "unit": "Percent",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\% Idle Time",
            "unit": "Percent",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Disk Bytes/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Disk Read Bytes/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Disk Write Bytes/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Disk Transfers/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Disk Reads/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Disk Writes/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Avg. Disk sec/Transfer",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Avg. Disk sec/Read",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Avg. Disk sec/Write",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Avg. Disk Queue Length",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Avg. Disk Read Queue Length",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Avg. Disk Write Queue Length",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\% Free Space",
            "unit": "Percent",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\LogicalDisk(_Total)\\Free Megabytes",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Network Interface(*)\\Bytes Total/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Network Interface(*)\\Bytes Sent/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Network Interface(*)\\Bytes Received/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Network Interface(*)\\Packets/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Network Interface(*)\\Packets Sent/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Network Interface(*)\\Packets Received/sec",
            "unit": "BytesPerSecond",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Network Interface(*)\\Packets Outbound Errors",
            "unit": "Count",
            "sampleRate": "PT60S"
          },
          {
            "counterSpecifier": "\\Network Interface(*)\\Packets Received Errors",
            "unit": "Count",
            "sampleRate": "PT60S"
          }
        ]
      },
      "WindowsEventLog": {
        "scheduledTransferPeriod": "PT1M",
        "DataSource": [
          {
            "name": "Application!*[System[(Level = 1 or Level = 2 or Level = 3)]]"
          },
          {
            "name": "Security!*[System[band(Keywords,4503599627370496)]]"
          },
          {
            "name": "System!*[System[(Level = 1 or Level = 2 or Level = 3)]]"
          }
        ]
      }
    }
  }
}'

             #Replaces the default config with the storage account and VM resource ID in the public settings information
             $publicSettings = $publicSettings.Replace('__DIAGNOSTIC_STORAGE_ACCOUNT__',$storageAccountName)
             $publicSettings = $publicSettings.Replace('__VM_RESOURCE_ID__',$vm.Id)

             #Outputs an xml file that will be used to set the diagnostics
             $publicSettings | Out-File c:\Metric_Template_Windows.xml

             #Starts running diagnostic extension
             Set-AzVMDiagnosticsExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name -DiagnosticsConfigurationPath c:\Metric_Template_Windows.xml

             #Removes XML files when done
             Remove-Item -Path c:\Metric_Template_Windows.xml -Force -Confirm:$false

       }

       #Checks for Linux VM that does not contain the diagnostic extension and that it is turned on 
       if ($vm.OSProfile.WindowsConfiguration -eq $null -and $linuxExtensionCheck -eq $null -and $status.Statuses.displaystatus -contains "VM Running") {

             #Builds public settings information for metric onboarding 
             $publicSettings = "{
  'StorageAccount': '__DIAGNOSTIC_STORAGE_ACCOUNT__',
  'ladCfg': {
    'diagnosticMonitorConfiguration': {
      'eventVolume': 'Medium', 
      'metrics': {
        'metricAggregation': [
          {
            'scheduledTransferPeriod': 'PT1H'
          }, 
          {
            'scheduledTransferPeriod': 'PT1M'
          }
        ], 
        'resourceId': '__VM_RESOURCE_ID__'
      }, 
      'performanceCounters': {
        'performanceCounterConfiguration': [
          {
            'annotation': [
              {
                'displayName': 'Disk read guest OS', 
                'locale': 'en-us'
              }
            ], 
            'class': 'disk', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'readbytespersecond', 
            'counterSpecifier': '/builtin/disk/readbytespersecond', 
            'type': 'builtin', 
            'unit': 'BytesPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Disk writes', 
                'locale': 'en-us'
              }
            ], 
            'class': 'disk', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'writespersecond', 
            'counterSpecifier': '/builtin/disk/writespersecond', 
            'type': 'builtin', 
            'unit': 'CountPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Disk transfer time', 
                'locale': 'en-us'
              }
            ], 
            'class': 'disk', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'averagetransfertime', 
            'counterSpecifier': '/builtin/disk/averagetransfertime', 
            'type': 'builtin', 
            'unit': 'Seconds'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Disk transfers', 
                'locale': 'en-us'
              }
            ], 
            'class': 'disk', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'transferspersecond', 
            'counterSpecifier': '/builtin/disk/transferspersecond', 
            'type': 'builtin', 
            'unit': 'CountPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Disk write guest OS', 
                'locale': 'en-us'
              }
            ], 
            'class': 'disk', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'writebytespersecond', 
            'counterSpecifier': '/builtin/disk/writebytespersecond', 
            'type': 'builtin', 
            'unit': 'BytesPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Disk read time', 
                'locale': 'en-us'
              }
            ], 
            'class': 'disk', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'averagereadtime', 
            'counterSpecifier': '/builtin/disk/averagereadtime', 
            'type': 'builtin', 
            'unit': 'Seconds'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Disk write time', 
                'locale': 'en-us'
              }
            ], 
            'class': 'disk', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'averagewritetime', 
            'counterSpecifier': '/builtin/disk/averagewritetime', 
            'type': 'builtin', 
            'unit': 'Seconds'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Disk total bytes', 
                'locale': 'en-us'
              }
            ], 
            'class': 'disk', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'bytespersecond', 
            'counterSpecifier': '/builtin/disk/bytespersecond', 
            'type': 'builtin', 
            'unit': 'BytesPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Disk reads', 
                'locale': 'en-us'
              }
            ], 
            'class': 'disk', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'readspersecond', 
            'counterSpecifier': '/builtin/disk/readspersecond', 
            'type': 'builtin', 
            'unit': 'CountPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Disk queue length', 
                'locale': 'en-us'
              }
            ], 
            'class': 'disk', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'averagediskqueuelength', 
            'counterSpecifier': '/builtin/disk/averagediskqueuelength', 
            'type': 'builtin', 
            'unit': 'Count'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Network in guest OS', 
                'locale': 'en-us'
              }
            ], 
            'class': 'network', 
            'counter': 'bytesreceived', 
            'counterSpecifier': '/builtin/network/bytesreceived', 
            'type': 'builtin', 
            'unit': 'Bytes'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Network total bytes', 
                'locale': 'en-us'
              }
            ], 
            'class': 'network', 
            'counter': 'bytestotal', 
            'counterSpecifier': '/builtin/network/bytestotal', 
            'type': 'builtin', 
            'unit': 'Bytes'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Network out guest OS', 
                'locale': 'en-us'
              }
            ], 
            'class': 'network', 
            'counter': 'bytestransmitted', 
            'counterSpecifier': '/builtin/network/bytestransmitted', 
            'type': 'builtin', 
            'unit': 'Bytes'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Network collisions', 
                'locale': 'en-us'
              }
            ], 
            'class': 'network', 
            'counter': 'totalcollisions', 
            'counterSpecifier': '/builtin/network/totalcollisions', 
            'type': 'builtin', 
            'unit': 'Count'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Packets received errors', 
                'locale': 'en-us'
              }
            ], 
            'class': 'network', 
            'counter': 'totalrxerrors', 
            'counterSpecifier': '/builtin/network/totalrxerrors', 
            'type': 'builtin', 
            'unit': 'Count'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Packets sent', 
                'locale': 'en-us'
              }
            ], 
            'class': 'network', 
            'counter': 'packetstransmitted', 
            'counterSpecifier': '/builtin/network/packetstransmitted', 
            'type': 'builtin', 
            'unit': 'Count'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Packets received', 
                'locale': 'en-us'
              }
            ], 
            'class': 'network', 
            'counter': 'packetsreceived', 
            'counterSpecifier': '/builtin/network/packetsreceived', 
            'type': 'builtin', 
            'unit': 'Count'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Packets sent errors', 
                'locale': 'en-us'
              }
            ], 
            'class': 'network', 
            'counter': 'totaltxerrors', 
            'counterSpecifier': '/builtin/network/totaltxerrors', 
            'type': 'builtin', 
            'unit': 'Count'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem transfers/sec', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'transferspersecond', 
            'counterSpecifier': '/builtin/filesystem/transferspersecond', 
            'type': 'builtin', 
            'unit': 'CountPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem % free space', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'percentfreespace', 
            'counterSpecifier': '/builtin/filesystem/percentfreespace', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem % used space', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'percentusedspace', 
            'counterSpecifier': '/builtin/filesystem/percentusedspace', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem used space', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'usedspace', 
            'counterSpecifier': '/builtin/filesystem/usedspace', 
            'type': 'builtin', 
            'unit': 'Bytes'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem read bytes/sec', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'bytesreadpersecond', 
            'counterSpecifier': '/builtin/filesystem/bytesreadpersecond', 
            'type': 'builtin', 
            'unit': 'CountPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem free space', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'freespace', 
            'counterSpecifier': '/builtin/filesystem/freespace', 
            'type': 'builtin', 
            'unit': 'Bytes'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem % free inodes', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'percentfreeinodes', 
            'counterSpecifier': '/builtin/filesystem/percentfreeinodes', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem bytes/sec', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'bytespersecond', 
            'counterSpecifier': '/builtin/filesystem/bytespersecond', 
            'type': 'builtin', 
            'unit': 'BytesPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem reads/sec', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'readspersecond', 
            'counterSpecifier': '/builtin/filesystem/readspersecond', 
            'type': 'builtin', 
            'unit': 'CountPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem write bytes/sec', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'byteswrittenpersecond', 
            'counterSpecifier': '/builtin/filesystem/byteswrittenpersecond', 
            'type': 'builtin', 
            'unit': 'CountPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem writes/sec', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'writespersecond', 
            'counterSpecifier': '/builtin/filesystem/writespersecond', 
            'type': 'builtin', 
            'unit': 'CountPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Filesystem % used inodes', 
                'locale': 'en-us'
              }
            ], 
            'class': 'filesystem', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'percentusedinodes', 
            'counterSpecifier': '/builtin/filesystem/percentusedinodes', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'CPU IO wait time', 
                'locale': 'en-us'
              }
            ], 
            'class': 'processor', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'percentiowaittime', 
            'counterSpecifier': '/builtin/processor/percentiowaittime', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'CPU user time', 
                'locale': 'en-us'
              }
            ], 
            'class': 'processor', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'percentusertime', 
            'counterSpecifier': '/builtin/processor/percentusertime', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'CPU nice time', 
                'locale': 'en-us'
              }
            ], 
            'class': 'processor', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'percentnicetime', 
            'counterSpecifier': '/builtin/processor/percentnicetime', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'CPU percentage guest OS', 
                'locale': 'en-us'
              }
            ], 
            'class': 'processor', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'percentprocessortime', 
            'counterSpecifier': '/builtin/processor/percentprocessortime', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'CPU interrupt time', 
                'locale': 'en-us'
              }
            ], 
            'class': 'processor', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'percentinterrupttime', 
            'counterSpecifier': '/builtin/processor/percentinterrupttime', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'CPU idle time', 
                'locale': 'en-us'
              }
            ], 
            'class': 'processor', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'percentidletime', 
            'counterSpecifier': '/builtin/processor/percentidletime', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'CPU privileged time', 
                'locale': 'en-us'
              }
            ], 
            'class': 'processor', 
            'condition': 'IsAggregate=TRUE', 
            'counter': 'percentprivilegedtime', 
            'counterSpecifier': '/builtin/processor/percentprivilegedtime', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Memory available', 
                'locale': 'en-us'
              }
            ], 
            'class': 'memory', 
            'counter': 'availablememory', 
            'counterSpecifier': '/builtin/memory/availablememory', 
            'type': 'builtin', 
            'unit': 'Bytes'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Swap percent used', 
                'locale': 'en-us'
              }
            ], 
            'class': 'memory', 
            'counter': 'percentusedswap', 
            'counterSpecifier': '/builtin/memory/percentusedswap', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Memory used', 
                'locale': 'en-us'
              }
            ], 
            'class': 'memory', 
            'counter': 'usedmemory', 
            'counterSpecifier': '/builtin/memory/usedmemory', 
            'type': 'builtin', 
            'unit': 'Bytes'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Page reads', 
                'locale': 'en-us'
              }
            ], 
            'class': 'memory', 
            'counter': 'pagesreadpersec', 
            'counterSpecifier': '/builtin/memory/pagesreadpersec', 
            'type': 'builtin', 
            'unit': 'CountPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Swap available', 
                'locale': 'en-us'
              }
            ], 
            'class': 'memory', 
            'counter': 'availableswap', 
            'counterSpecifier': '/builtin/memory/availableswap', 
            'type': 'builtin', 
            'unit': 'Bytes'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Swap percent available', 
                'locale': 'en-us'
             }
            ], 
            'class': 'memory', 
            'counter': 'percentavailableswap', 
            'counterSpecifier': '/builtin/memory/percentavailableswap', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Mem. percent available', 
                'locale': 'en-us'
              }
            ], 
            'class': 'memory', 
            'counter': 'percentavailablememory', 
            'counterSpecifier': '/builtin/memory/percentavailablememory', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Pages', 
                'locale': 'en-us'
              }
            ], 
            'class': 'memory', 
            'counter': 'pagespersec', 
            'counterSpecifier': '/builtin/memory/pagespersec', 
            'type': 'builtin', 
            'unit': 'CountPerSecond'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Swap used', 
                'locale': 'en-us'
              }
            ], 
            'class': 'memory', 
            'counter': 'usedswap', 
            'counterSpecifier': '/builtin/memory/usedswap', 
            'type': 'builtin', 
            'unit': 'Bytes'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Memory percentage', 
                'locale': 'en-us'
              }
            ], 
            'class': 'memory', 
            'counter': 'percentusedmemory', 
            'counterSpecifier': '/builtin/memory/percentusedmemory', 
            'type': 'builtin', 
            'unit': 'Percent'
          }, 
          {
            'annotation': [
              {
                'displayName': 'Page writes', 
                'locale': 'en-us'
              }
            ], 
            'class': 'memory', 
            'counter': 'pageswrittenpersec', 
            'counterSpecifier': '/builtin/memory/pageswrittenpersec', 
            'type': 'builtin', 
            'unit': 'CountPerSecond'
          }
        ]
      }, 
      'syslogEvents': {
      'sinks' : '$($blobSinkName)',
        'syslogEventConfiguration': {
          'LOG_AUTH': 'LOG_DEBUG', 
          'LOG_AUTHPRIV': 'LOG_DEBUG', 
          'LOG_CRON': 'LOG_DEBUG', 
          'LOG_DAEMON': 'LOG_DEBUG', 
          'LOG_FTP': 'LOG_DEBUG', 
          'LOG_KERN': 'LOG_DEBUG', 
          'LOG_LOCAL0': 'LOG_DEBUG', 
          'LOG_LOCAL1': 'LOG_DEBUG', 
          'LOG_LOCAL2': 'LOG_DEBUG', 
          'LOG_LOCAL3': 'LOG_DEBUG', 
          'LOG_LOCAL4': 'LOG_DEBUG', 
          'LOG_LOCAL5': 'LOG_DEBUG', 
          'LOG_LOCAL6': 'LOG_DEBUG', 
          'LOG_LOCAL7': 'LOG_DEBUG', 
          'LOG_LPR': 'LOG_DEBUG', 
          'LOG_MAIL': 'LOG_DEBUG', 
          'LOG_NEWS': 'LOG_DEBUG', 
          'LOG_SYSLOG': 'LOG_DEBUG', 
          'LOG_USER': 'LOG_DEBUG', 
          'LOG_UUCP': 'LOG_DEBUG'
        }
      }
    }, 
    'sampleRateInSeconds': 15
  }
}"

             #Replaces the default config with the storage account and VM resource ID in the public settings information
             $publicSettings = $publicSettings.Replace('__DIAGNOSTIC_STORAGE_ACCOUNT__',$storageAccountName)
             $publicSettings = $publicSettings.Replace('__VM_RESOURCE_ID__',$vm.Id)

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
             Set-AzVMExtension -ResourceGroupName $VM.ResourceGroupName -VMName $vm.Name -Location $vm.Location -ExtensionType LinuxDiagnostic -Publisher Microsoft.Azure.Diagnostics -Name LinuxDiagnostic -SettingString $publicSettings -ProtectedSettingString $protectedSettings -TypeHandlerVersion 3.0
       }
} 
