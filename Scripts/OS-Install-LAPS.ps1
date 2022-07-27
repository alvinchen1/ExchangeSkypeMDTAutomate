<#
NAME
    Install-LAPS.ps1

SYNOPSIS
    Installs Local Administrator Password Solution (LAPS) on a managed machine

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
$PkgDir = "$InstallShare\Applications\Install-LAPS"
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
    If (!(Test-Path -Path $File)) {Throw "ERROR: Unable to locate $File"} 
}

Function Install-LAPS
{
    Write-Verbose "----- Entering Install-LAPS function -----"

    # Check if LAPS is already installed
    If (Test-Path -Path "$Env:ProgramFiles\LAPS\CSE\AdmPwd.dll")
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

Install-LAPS
