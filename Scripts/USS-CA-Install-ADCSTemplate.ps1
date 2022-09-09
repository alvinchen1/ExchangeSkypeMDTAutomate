<#
NAME
    Install-PSPKI.ps1

SYNOPSIS
    Installs PSPKI PowerShell module

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
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value
$PkgDir = "$InstallShare\Install-ADCSTemplate"

# =============================================================================
# MAIN ROUTINE
# =============================================================================

If (!(Test-Path "$PkgDir\ADCSTemplate")) {Throw "Unable to locate $PkgDir\ADCSTemplate"}
Else 
{
    Add-WindowsFeature RSAT-AD-PowerShell
    Copy-Item -Path "$PkgDir\ADCSTemplate" -Destination "C:\program files\WindowsPowerShell\Modules" -Recurse -Force
}

Stop-Transcript