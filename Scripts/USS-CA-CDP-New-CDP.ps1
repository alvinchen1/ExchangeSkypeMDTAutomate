<#
NAME
    New-CDP.ps1

SYNOPSIS
    Installs a CRL Distribution Point (CDP) on the IIS web server

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
$DomainName = ($WS | ? {($_.Name -eq "DomainName")}).Value
$PkiFolder ="C:\inetpub\PKI"
$CrlFolder = "$PkiFolder\crl"
$CpFolder = "$PkiFolder\cp"

$CAStatementContent = @"
This is our CA Policy File
"@

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

If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

# Create PKI share 
If (!(Test-Path $PkiFolder)) {New-Item $PkiFolder -ItemType Directory}
If (!(Test-Path $CrlFolder)) {New-Item $CrlFolder -ItemType Directory}
If (!(Test-Path $CpFolder)) {New-Item $CpFolder -ItemType Directory}
$CAStatementContent | Out-File "$CpFolder\Root CA.htm" -Force
New-SmbShare -Name 'CRL' -Path $CrlFolder -Description "Share for PKI CRLs and Certs"

# Stop the default website
Import-Module WebAdministration
Get-Website 'Default Web Site' | Stop-Website

# Create and start PKI website
If (!(Get-Website 'pki')) {New-WebSite -Name "pki" -Port 80 -HostHeader "pki" -PhysicalPath $PkiFolder}
Get-Website

# Config PKI site in IIS
If (!(Get-WebConfigurationProperty -filter /system.webServer/directoryBrowse -name enabled -PSPath 'IIS:\Sites\pki').Value)
{
    Set-WebConfigurationProperty -filter /system.webServer/directoryBrowse -name enabled -value true -PSPath 'IIS:\Sites\pki'
}
If (!(Get-WebConfigurationProperty -filter /system.webServer/security/requestFiltering -name allowDoubleEscaping -PSPath 'IIS:\Sites\pki').Value) 
{
    Set-WebConfigurationProperty -filter /system.webServer/security/requestFiltering -name allowDoubleEscaping -value true -PSPath 'IIS:\Sites\pki'
}

#Set-WebConfigurationProperty -PSPath 'IIS:\Sites\pki' -Filter 'system.webServer/security/requestFiltering' -Value @{VERB="OPTIONS";allowed="False"} -Name Verbs -AtIndex 0
#Get-WebConfiguration -filter 'system.webServer/security/requestFiltering/verbs/add' -PSPath 'IIS:\Sites\pki' | ft verb,allowed

# Test CDP URLs
Write-Host "`nTesting http://pki"
(Invoke-WebRequest http://pki -UseBasicParsing).StatusDescription

Write-Host "`nTesting http://pki/cp"
(Invoke-WebRequest http://pki/cp -UseBasicParsing).StatusDescription

Write-Host "`nTesting http://pki/crl"
(Invoke-WebRequest http://pki/crl -UseBasicParsing).StatusDescription

# Server Ready: Writes a text file to MDT Deployment Share notifying dependent servers that they can continue their builds
New-Item -Path "$RootDir\LOGS\$env:COMPUTERNAME-READY.txt" -Force

Stop-Transcript
