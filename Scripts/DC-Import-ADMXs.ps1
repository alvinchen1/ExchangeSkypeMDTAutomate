<#
NAME
    Import-ADMXs.ps1

SYNOPSIS
    Copies ADMX and ADML files to DC policy storage

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
$PkgDir = "$InstallShare\Applications\Import-ADMX"

# =============================================================================
# MAIN ROUTINE
# =============================================================================

If (!(Test-Path -Path "$PkgDir\admx")) {Throw "Unable to locate $PkgDir\admx"}
If (!(Test-Path -Path "$PkgDir\admls")) {Throw "Unable to locate $PkgDir\admls"}

$files = Get-ChildItem -Path "$PkgDir" -File -Recurse -ErrorAction SilentlyContinue
foreach ($file in $files) 
{
    if (!$file) {continue}

    if (($file.Extension -ieq '.admx') -or ($file.Extension -ieq '.adm')) 
    {Copy-Item -Path $file.FullName -Destination 'C:\Windows\PolicyDefinitions' -Force} 
    
    elseif ($file.Extension -ieq '.adml') 
    {Copy-Item -Path $file.FullName -Destination 'C:\Windows\PolicyDefinitions\en-us' -Force}
}

Stop-Transcript