<#
NAME
    SKYPE-CONFIG-5.ps1

SYNOPSIS
    Updates Skype for Business

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
$SQLServer2019Path = "$InstallShare\SQLServer2019\Express"
$SQLServer2019CU = "$InstallShare\SQLServer2019\CU"
$SQLServer2019CUVer = "15.0.4249.2" # Patched SQL version with CU; see https://sqlserverbuilds.blogspot.com/#sql2019x
 
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
    
    If ((Get-CsServerPatchVersion | where ComponentName -eq "Skype for Business Server 2019, Core Components").Version -lt "$SkypeForBusinessCUVer") 
    {
        Write-Host "Applying Skype for Business Server Cumulative Update." -ForegroundColor Green
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
        Write-Host "Skype for Business not installed; or Skype for Business Server 2019 Cumulative Updates are already applied." -Foregroundcolor Green
    }
}

Function Upgrade-SQLInstance ($SQLInstance)
{
    Write-Verbose "----- Entering Upgrade-SQLInstance ($SQLInstance) function -----"
    
    If ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$SQLInstance\MSSQLServer\CurrentVersion").CurrentVersion -lt "15.0.2000.5")
    {
        # Check pending reboot; potentially Restart-Computer in middle of MDT TS?
        If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}

        Write-Host "Upgrading SQL instance $SQLInstance to SQL Server 2019" -Foregroundcolor Green
        Test-FilePath ("$SQLServer2019Path\SETUP.EXE")
        Stop-CsWindowsService
        $service = Get-Service | Where-Object {$_.Name -eq "w3svc"}
        If ($service.Status -eq "Running") {Stop-Service w3svc}
        Start-Process "$SQLServer2019Path\SETUP.EXE" -Wait -Argumentlist " /qs /ACTION=Upgrade /IAcceptSQLServerLicenseTerms /INSTANCENAME=$SQLInstance /HIDECONSOLE /ERRORREPORTING=0"
        Start-CsWindowsService
        $service = Get-Service | Where-Object {$_.Name -eq "w3svc"}
        If ($service.Status -eq "Stopped") {Start-Service w3svc}
    }
}

Function Update-SQLInstance ($SQLInstance)
{
    Write-Verbose "----- Entering Update-SQLInstance ($SQLInstance) function -----"
    
    If ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$SQLInstance\MSSQLServer\CurrentVersion").CurrentVersion -lt "$SQLServer2019CUVer")
    {
        # Check pending reboot; potentially Restart-Computer in middle of MDT TS?
        If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}

        Write-Host "Applying CU ($SQLServer2019CUVer) to SQL Server 2019 instance $SQLInstance" -Foregroundcolor Green
        Test-FilePath ("$SQLServer2019CU\SETUP.EXE")
        Stop-CsWindowsService
        $service = Get-Service | Where-Object {$_.Name -eq "w3svc"}
        If ($service.Status -eq "Running") {Stop-Service w3svc}
        Start-Process "$SQLServer2019Path\SETUP.EXE" -Wait -Argumentlist " /qs /ACTION=Patch /IAcceptSQLServerLicenseTerms /AllInstances /ERRORREPORTING=0"
        $service = Get-Service | Where-Object {$_.Name -eq "w3svc"}
        If ($service.Status -eq "Stopped") {Start-Service w3svc}
        Start-CsWindowsService
    }
    Else
    {
        Write-Host "SQL Server 2019 CU ($SQLServer2019CUVer) already applied to instance $SQLInstance" -Foregroundcolor Green
    }
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Check pending reboot
If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}

# Apply Skype for Business Server Cumulative Update
Import-Module "C:\Program Files\Common Files\Skype for Business Server 2019\Modules\SkypeForBusiness\SkypeForBusiness.psd1"
Update-SfB

# Upgrade SQL Server instances to SQL Server 2019
Upgrade-SQLInstance ("RTC")
Upgrade-SQLInstance ("RTCLOCAL")
Upgrade-SQLInstance ("LYNCLOCAL")

# Apply latest Cumulative Update (CU) to SQL Server 2019 instances (currently not working)
#Update-SQLInstance ("RTC")
#Update-SQLInstance ("RTCLOCAL")
#Update-SQLInstance ("LYNCLOCAL")

# Update firewall rule to reflect new SQL Server path
Set-NetFirewallRule -DisplayName 'SQL RTC Access' -Program "C:\Program Files\Microsoft SQL Server\MSSQL15.RTC\MSSQL\Binn\sqlservr.exe" | Out-Null

Stop-Transcript
