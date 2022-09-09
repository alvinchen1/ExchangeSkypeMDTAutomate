<#
NAME
    Install-LAPS-AD.ps1

SYNOPSIS
    Installs Local Administrator Password Solution (LAPS) for AD

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
$PkgDir = "$InstallShare\Install-LAPS"
$LAPSFile = "LAPS.x64.msi"
$LogFile = "$Env:WINDIR\Temp\LAPS.x64.log"

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

Function Test-FilePath ($File)
{
    If (!(Test-Path -Path $File))
    {
		Write-Host "ERROR: Unable to locate $File Exiting...`n" -ForeGround "yellow" -back "red"
        Exit 1
    } 
}

Function Install-LAPS-AD
{
    Write-Verbose "----- Entering Install-LAPS-AD function -----"

    # Check if LAPS is already installed
    If ((Get-Module -ListAvailable -Name AdmPwd.PS) -and (Test-Path -Path "C:\Program Files\LAPS\AdmPwd.UI.exe"))
    {
        Write-Host "`nLAPS is already installed"
    }
    Else
    {
        $Manifest = "$PkgDir\$LAPSFile"
        foreach ($File in $Manifest) {Test-FilePath ($File)}

        # Install LAPS
        Write-Progress -Activity "Installing LAPS" -Status "Install log location: $LogFile" -PercentComplete -1

        $FilePath = "$PkgDir\$LAPSFile"
        $Args = @(
        'ADDLOCAL=Management.UI,Management.PS,Management.ADMX'
        '/quiet'
        '/norestart'
        '/log'
        "$LogFile"
        )
        Start-Process -FilePath $FilePath -ArgumentList $Args -Wait

        Write-Progress -Activity "Installing LAPS" -Completed -Status "Completed"    
    }
}


# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Ensure script is run elevated
If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

Install-LAPS-AD

Stop-Transcript
