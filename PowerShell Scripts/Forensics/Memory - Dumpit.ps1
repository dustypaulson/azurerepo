Out-File -FilePath c:\test.
<#
if ((gwmi win32_operatingsystem | select osarchitecture).osarchitecture -eq "64-bit")
{
    #64 bit logic here
    Out-File -FilePath c:\64bit.txt
    Write "64-bit OS"
    cd Z:\Comae-Toolkit-3.0.20190124.1\x64
    mkdir z:\dumpit\$env:COMPUTERNAME\memory\x64
    Start-Process "./DumpIt.exe" -WorkingDirectory z:\dumpit\$env:COMPUTERNAME\memory\x64 /q
}
else
{
    #32 bit logic here
    Write "32-bit OS"
    cd Z:\Comae-Toolkit-3.0.20190124.1\x86
    mkdir z:\dumpit\$env:COMPUTERNAME\memory\x86
    Start-Process "./DumpIt.exe" -WorkingDirectory z:\dumpit\$env:COMPUTERNAME\memory\x86 /q

}
#>
