<#
NAME
    Install-PSPKI.ps1

SYNOPSIS
    Installs PSPKI PowerShell module

SYNTAX
    .\$ScriptName
 #>

Start-Transcript

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path –Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path –Parent
$RootDir = Split-Path $ScriptDir –Parent
$ConfigFile = "$RootDir\config.xml"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) 
{
    Write-Host "Missing configuration file $ConfigFile" -ForegroundColor Red
    Stop-Transcript
    Exit
}
$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value
$PkgDir = "$InstallShare\Applications\Install-PSPKI"

# =============================================================================
# MAIN ROUTINE
# =============================================================================

If (!(Test-Path "$PkgDir\PSPKI")) {Throw "Unable to locate $PkgDir\PSPKI"}
Else 
{
    Copy-Item -Path "$PkgDir\PSPKI" -Destination "C:\program files\WindowsPowerShell\Modules" -Recurse -Force
}

Stop-Transcript