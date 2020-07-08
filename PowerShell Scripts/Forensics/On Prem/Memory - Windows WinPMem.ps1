$memCapDrive = Get-PSDrive | Where-Object Description -EQ MemCap
$memCapDriveLetter = $memCapDrive.Name + ":\"
$folder = ($memCapDriveLetter + $env:computername + "\" + $env:computername)
$taskName = "memory capture"

if (!(Get-Process -Name winpmem_v3.3.rc3 -ErrorAction SilentlyContinue) -and !(Test-Path ($memCapDriveLetter + $env:computername)))
{
	New-Item -Path ($memCapDriveLetter + $env:computername) -ItemType directory -Force -Confirm:$false
	$logName = 'Microsoft-Windows-TaskScheduler/Operational'
	$log = New-Object System.Diagnostics.Eventing.Reader.EventLogConfiguration $logName
	$log.IsEnabled = $true
	$log.SaveChanges()
	$drive = $memCapDrive.Name + ":"
	@"
    $($memCapDrive.Name):
	cd "$($memCapDrive.Name):\winpmem\"
    mkdir "$($memCapDriveLetter)$($env:computername)"
    winpmem_v3.3.rc3.exe -o $folder.aff4 -dd	
    exit
"@ | Out-File c:\memcap.cmd -Encoding ascii

	$A = New-ScheduledTaskAction -Execute c:\memcap.cmd -WorkingDirectory c:\
	$T = New-ScheduledTaskTrigger -Daily -DaysInterval 30 -At 3am
	$S = New-ScheduledTaskSettingsSet -MultipleInstances Queue
	$P = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
	$D = New-ScheduledTask -Action $A -Trigger $T -Settings $S -Principal $P -Description "Runs memory capture on the VM"
	Register-ScheduledTask -TaskName $taskName -InputObject $D -User "NT AUTHORITY\SYSTEM"

	Start-ScheduledTask -TaskName $taskName
	$taskState = (Get-ScheduledTask -TaskName $taskName).State
	do
	{
		$taskState = (Get-ScheduledTask -TaskName $taskName).State
		Start-Sleep 60
	}
	until ($taskState -eq "Ready")

	if ($taskState -eq "Ready") {
		Remove-Item -Path C:\memcap.cmd -Force -Confirm:$false
		Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
		break
	}
}
else
{
	do
	{
		$taskState = (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue).State
		Start-Sleep 60
	}
	until ($taskState -eq "Ready" -or $taskState -eq $null)
	Remove-Item -Path C:\memcap.cmd -Force -Confirm:$false
	Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
	break
}
