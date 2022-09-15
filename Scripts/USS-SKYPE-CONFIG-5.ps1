<#
NAME
    SKYPE-CONFIG-5.ps1

SYNOPSIS
    Applies latest Cumulative Update to Skype for Business 2019

SYNTAX
    .\$ScriptName
 #>

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path -Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$DTG = Get-Date -Format yyyyMMddTHHmm
$RootDir = Split-Path $ScriptDir -Parent
$ConfigFile = "$RootDir\config.xml"

Start-Transcript -Path "$RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log"
Start-Transcript -Path "$env:WINDIR\Temp\$env:COMPUTERNAME-$DTG-$ScriptName.log"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) {Throw "ERROR: Unable to locate $ConfigFile Exiting..."}
$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value
$SkypeForBusinessCUPath = "$InstallShare\Skype4BusinessCU"
$SkypeForBusinessCUVer = "7.0.2046.404" # See https://docs.microsoft.com/en-us/skypeforbusiness/sfb-server-updates
 
# =============================================================================
# FUNCTIONS
# =============================================================================

Function Test-FilePath ($File)
{
    If (!(Test-Path -Path $File)) {Throw "ERROR: Unable to locate $File"} 
}

Function Check-PendingReboot
{
    If (!(Get-Module -ListAvailable -Name PendingReboot)) 
    {
        Test-FilePath ("$InstallShare\Install-PendingReboot\PendingReboot")
        Copy-Item -Path "$InstallShare\Install-PendingReboot\PendingReboot" -Destination "C:\Program Files\WindowsPowerShell\Modules" -Recurse -Force
    }

    Import-Module PendingReboot
    [bool] (Test-PendingReboot -SkipConfigurationManagerClientCheck).IsRebootPending
}

Function Update-SfB
{
    Write-Verbose "----- Entering Update-SfB function -----"
    
    $SfBPatchLevel = (Get-CsServerPatchVersion | where ComponentName -eq "Skype for Business Server 2019, Core Components" -ErrorAction "SilentlyContinue").Version
    If (!($SfBPatchLevel))  {Throw "Unable to determine Skype for Business Server 2019 PatchLevel"}
    If ($SfBPatchLevel -lt "$SkypeForBusinessCUVer") 
    {
        Write-Host "Applying Skype for Business Server 2019 Cumulative Update." -ForegroundColor Green
        Import-Module "C:\Program Files\Common Files\Skype for Business Server 2019\Modules\SkypeForBusiness\SkypeForBusiness.psd1"
        Test-FilePath ("$SkypeForBusinessCUPath\SkypeServerUpdateInstaller.exe")
        Stop-CsWindowsService
        $service = Get-Service | Where-Object {$_.Name -eq "w3svc"}
        If ($service.Status -eq "Running") {Stop-Service w3svc}
        Start-Process "$SkypeForBusinessCUPath\SkypeServerUpdateInstaller.exe" -Wait -Argumentlist "/silentmode"
        Start-CsWindowsService
        $service = Get-Service | Where-Object {$_.Name -eq "w3svc"}
        If ($service.Status -eq "Stopped") {Start-Service w3svc}
        Install-CsDatabase -Update -LocalDatabases
    }
    Else 
    {
        Write-Host "Skype for Business Server 2019 Cumulative Update already applied." -Foregroundcolor Green
    }
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Check pending reboot
If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}

# Apply Skype for Business Server Cumulative Update
Update-SfB

Stop-Transcript
