<#
NAME
    Install-CoreFeatures.ps1

SYNOPSIS
    Installs core features on Windows Servers supporting the solution

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
$Features = ($WS | ? {($_.Name -eq "$Server")}).Features.Split(",")
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value
$WS2019Source = "$InstallShare\W2019\sources\sxs"

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

Function Check-Prereqs
{
    Write-Verbose "----- Entering Check-Prereqs function -----"
    
    # Ensure script is run elevated
    If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}
    
    # Ensure sources directory path is valid    
    Test-FilePath ($WS2019Source)
}

Function Install-CoreComponents
{
    Write-Verbose "----- Entering Install-CoreComponents function -----"
    
    # Enable network file and print:
    Set-NetFirewallRule -DisplayGroup "File And Printer Sharing" -Enabled False -Profile Any 

    # Enable WinRM:
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/enable-psremoting?view=powershell-7.1
    Enable-PSRemoting -Force
    winrm quickconfig -Force
    
    # Disable MapsBroker service that is not needed
    Set-Service -Name "MapsBroker" -Status Stopped -StartupType Disabled
    #Get-Service MapsBroker | Select-Object -Property Name, StartType, Status
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

Check-Prereqs
Install-CoreComponents
Install-WindowsFeature -Name $Features -Source $WS2019Source -IncludeManagementTools

Stop-Transcript
