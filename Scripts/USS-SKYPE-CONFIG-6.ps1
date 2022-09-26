<#
NAME
    SKYPE-CONFIG-6.ps1

SYNOPSIS
    Upgrades SQL Express 2016 to 2019 and applies latest SQL CU in support of SfB
    (requires reboot after each SQL instance)

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
$SQLServer2019Path = "$InstallShare\SQLServer2019"
$SQLServer2019CU = "$InstallShare\SQLServer2019\CU"
$SQLServer2019CUVer = "15.0.4249.2" # Patched SQL version with CU; see https://support.microsoft.com/help/4518398
 
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

Function Upgrade-SQLInstance ($SQLInstance)
{
    Write-Verbose "----- Entering Upgrade-SQLInstance ($SQLInstance) function -----"
    
    $SQLVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$SQLInstance\MSSQLServer\CurrentVersion").CurrentVersion
    If (!($SQLVersion))  {Throw "Unable to determine SQL CurrentVersion for $SQLInstance"}
    If ($SQLVersion -lt "$SQLServer2019CUVer") # SQL Server 2019 RTM
    {
        If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}
        Write-Host "Upgrading SQL instance $SQLInstance to SQL Server 2019" -Foregroundcolor Green
        Test-FilePath ("$SQLServer2019Path\Express\SETUP.EXE")
        Stop-CsWindowsService
        $service = Get-Service | Where-Object {$_.Name -eq "w3svc"}
        If ($service.Status -eq "Running") {Stop-Service w3svc}
 
        $FilePath = "$SQLServer2019Path\Express\SETUP.EXE"
        $Args = @(
        "/QS"
        "/IACCEPTSQLSERVERLICENSETERMS"
        "/ERRORREPORTING=0"
        "/ACTION=Upgrade"
        "/INSTANCENAME=`"$SQLInstance`""
        "/UPDATEENABLED=True"
        "/UpdateSource=`"$SQLServer2019Path`""
        )
        Start-Process -FilePath $FilePath -ArgumentList $Args -Wait
    }
    Else
    {
        Write-Host "SQL instance $SQLInstance already upgraded to SQL Server 2019" -Foregroundcolor Green
    }
}

Function Update-SQLInstance ($SQLInstance)
{
    Write-Verbose "----- Entering Update-SQLInstance ($SQLInstance) function -----"

    $SQLPatchLevel = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL15.$SQLInstance\Setup" -ErrorAction "SilentlyContinue").PatchLevel
    If (!($SQLPatchLevel))  {Throw "Unable to determine SQL PatchLevel for $SQLInstance"}
    If ($SQLPatchLevel -lt "$SQLServer2019CUVer") 
    {
        If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}
        Write-Host "Applying CU ($SQLServer2019CUVer) to SQL Server 2019 instance $SQLInstance" -Foregroundcolor Green
        Test-FilePath ("$SQLServer2019CU\SETUP.EXE")
        Stop-CsWindowsService
        $service = Get-Service | Where-Object {$_.Name -eq "w3svc"}
        If ($service.Status -eq "Running") {Stop-Service w3svc}
        Start-Process "$SQLServer2019CU\SETUP.EXE" -Wait -Argumentlist " /QS /ACTION=Patch /IACCEPTSQLSERVERLICENSETERMS /ALLINSTANCES /ERRORREPORTING=0"
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

# Upgrade SQL Server 2016 instances to SQL Server 2019 and apply latest CU to instance (reboots required)
#Upgrade-SQLInstance ("RTC")
Upgrade-SQLInstance ("RTCLOCAL")
#Upgrade-SQLInstance ("LYNCLOCAL")

Stop-Transcript
