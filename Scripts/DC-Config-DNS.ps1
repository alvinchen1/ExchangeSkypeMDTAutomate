<#
NAME
    Config-DNS.ps1

SYNOPSIS
    Creates OUs in AD for the solution

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
$DomainDnsName = ($WS | ? {($_.Name -eq "DomainDnsName")}).Value
$PKI = ($XML.Component | ? {($_.Name -eq "PKI")}).Settings.Configuration
$CDP = ($PKI | ? {($_.Name -eq "CDP")}).Value
$CDPFQDN = $CDP + '.' + $DomainDnsName

# =============================================================================
# FUNCTIONS
# =============================================================================

Function Check-Role()
{
   param (
    [Parameter(Mandatory=$false, HelpMessage = "Enter what role you want to check for. Default check is for 'Administrator'")]
    [System.Security.Principal.WindowsBuiltInRole]$role = [System.Security.Principal.WindowsBuiltInRole]::Administrator
   )

    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object 'System.Security.Principal.WindowsPrincipal' $windowsIdentity

    return $windowsPrincipal.IsInRole($role)
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Ensure script is run elevated
If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

# Create CNAME for CDP
$TestDNS = Get-DnsServerResourceRecord -ZoneName $DomainDnsName -Name "pki" -RRType CName -ErrorAction "SilentlyContinue"
If(!($TestDNS)) {Add-DnsServerResourceRecordCName -Name "pki" -HostNameAlias $CDPFQDN -ZoneName $DomainDnsName}

Stop-Transcript
