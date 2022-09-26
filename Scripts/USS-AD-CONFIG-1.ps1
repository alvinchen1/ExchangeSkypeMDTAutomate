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

# Add RSAT-AD-Tools to support Active Directory forest
Add-WindowsFeature "RSAT-AD-Tools"

Stop-Transcript
