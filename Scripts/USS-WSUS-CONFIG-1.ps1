<#
NAME
    Config-OS.ps1

SYNOPSIS
    Configures network adapter(s) and hard drive(s)

SYNTAX
    .\$ScriptName
 #>

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path –Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path –Parent
$DTG = Get-Date -Format yyyyMMddTHHmm
$RootDir = Split-Path $ScriptDir –Parent
$ConfigFile = "$RootDir\config.xml"

Start-Transcript -Path "$RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log"
Start-Transcript -Path "$env:WINDIR\Temp\$env:COMPUTERNAME-$DTG-$ScriptName.log"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) {Throw "ERROR: Unable to locate $ConfigFile Exiting..."} 
$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$Server = $Env:COMPUTERNAME
$MgmtIP = ($WS | ? {($_.Name -eq "$Server")}).Value
$DNS1 = ($WS | ? {($_.Role -eq "DC1")}).Value
$DNS2 = ($WS | ? {($_.Role -eq "DC2")}).Value
$DefaultGW = ($WS | ? {($_.Name -eq "DefaultGateway")}).Value
$PrefixLen = ($WS | ? {($_.Name -eq "SubnetMaskBitLength")}).Value
$MgmtNICName = "NIC_MGMT1_1GB"
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Configure the MGMT NIC
Write-Host -ForegroundColor Green "Configuring NIC(s)"
If (Get-NetAdapter "Ethernet" -ErrorAction SilentlyContinue) {Rename-NetAdapter –Name "Ethernet" –NewName "$MgmtNICName"}
Get-NetAdapter "$MgmtNICName" | Get-NetIPAddress -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false
Get-NetAdapter "$MgmtNICName" | New-NetIPAddress -IPAddress $MgmtIP -AddressFamily IPv4 -PrefixLength $PrefixLen -DefaultGateway $DefaultGW -Confirm:$false
$MgmtNICIP = (Get-NetAdapter "$MgmtNICName" | Get-NetIPAddress -AddressFamily IPv4).IPAddress
If ($MgmtNICIP -eq $DNS1) {Get-NetAdapter "$MgmtNICName" | Set-DnsClientServerAddress -ServerAddresses "127.0.0.1",$DNS2}
ElseIf ($MgmtNICIP -eq $DNS2) {Get-NetAdapter "$MgmtNICName" | Set-DnsClientServerAddress -ServerAddresses "127.0.0.1",$DNS1}
Else {Get-NetAdapter "$MgmtNICName" | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2}
Disable-NetAdapterBinding "$MgmtNICName" -ComponentID ms_tcpip6

# Copy WSUS binaries to local drive
Write-Host -foregroundcolor green "Copying WSUS_STAGING/SCRIPTS folders to C:\"
Copy-Item $InstallShare\WSUS_STAGING -Destination C:\ -Recurse
Copy-Item C:\WSUS_STAGING\WSUSScripts -Destination C:\ -Recurse
Copy-Item C:\WSUS_STAGING\WSUSMaint -Destination C:\ -Recurse

# Install .NET Framework 3.5.1
Write-Host -foregroundcolor green "Installing .NET Framework 3.5.1"
Dism /online /enable-feature /featurename:NetFx3 /All /Source:C:\WSUS_STAGING\W2019\Sources\Sxs /LimitAccess

# Install Microsoft System CLR Types for Microsoft SQL Server 2012
Write-Host -foregroundcolor green "Install Microsoft System CLR Types..."
Start-Process msiexec -Wait -ArgumentList '/I C:\WSUS_STAGING\REPORT_VIEWER_2012\SQLSysCLRTypes.msi /passive /norestart'
Start-Process msiexec -Wait -ArgumentList '/I C:\WSUS_STAGING\REPORT_VIEWER_2012\ReportViewer.msi /passive /norestart'

# Install features
Write-Host -foregroundcolor green "Installing WSUS"
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools

# Configure disks
Write-Host -foregroundcolor green "Configuring Disk for WSUS"
Write-Host -foregroundcolor green "Setting Disk to Online..."
Set-disk 1 -isOffline $false
Set-disk 2 -isOffline $false

Write-Host -foregroundcolor green "Initilizing, Partitioning, Create/Formating Disk/Volumes for WSUS..."
Stop-Service -Name ShellHWDetection
Get-disk 1| Initialize-Disk -PartitionStyle GPT -PassThru|New-Partition -DriveLetter D -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "MECMShare" -Confirm:$false
Get-disk 2| Initialize-Disk -PartitionStyle GPT -PassThru|New-Partition -DriveLetter E -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "WSUS" -Confirm:$false
Start-Service -Name ShellHWDetection

Stop-Transcript
