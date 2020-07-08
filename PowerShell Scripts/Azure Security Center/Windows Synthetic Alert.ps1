$reg = (Get-Item -Path Registry::"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system\Audit" | Select-Object -ExpandProperty Property)
if($reg -eq $null){
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system\Audit" /f /v "ProcessCreationIncludeCmdLine_Enabled"
}
Set-Location C:\Windows\System32\
$NewEXEName = "ASC_AlertTest_662jfi039N.exe"
$des = [Environment]::GetFolderPath("Desktop")
if((Test-Path "$des\$NewEXEName") -eq "True"){
Remove-Item "$des\$NewEXEName" -Force -Confirm:$false
}
Copy-Item -Path .\calc.exe -Destination $des
Rename-Item -Path $des\calc.exe -NewName $NewEXEName
& "$des\$NewEXEName" -foo
