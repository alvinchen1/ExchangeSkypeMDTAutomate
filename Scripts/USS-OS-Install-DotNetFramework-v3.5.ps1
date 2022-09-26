<#
NAME
    Install-DotNetFramework-v3.5.ps1

SYNOPSIS
    Installs Microsoft .NET Framework v3.5

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
$WS2019Source = "$InstallShare\W2019\sources\sxs"

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

Function Install-DotNetFramework-v3.5
{
    Test-FilePath ($WS2019Source)

    If ((Get-WindowsFeature -Name NET-Framework-Core).InstallState -eq "Removed")
    {
        Write-Host "Installing Microsoft .NET Framework v3.5"
        Start-Process "dism.exe" -Wait -Argumentlist " /Online /Enable-Feature /FeatureName:netFX3 /All /LimitAccess /source:$WS2019Source"
    }
    Else
    {
        Write-Host "`nMicrosoft .NET Framework v3.5 is already installed."
    }
}

Function Set-TlsForDotNet-v3.5
{
    # Transport Layer Security (TLS) best practices with the .NET Framework
    # https://docs.microsoft.com/en-us/dotnet/framework/network-programming/tls

    # Enable TLS 1.2 for .NET v3.5
    # x64
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727' -Name 'SystemDefaultTlsVersions' -Value '1' -Type DWord
    # x86
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v2.0.50727' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v2.0.50727' -Name 'SystemDefaultTlsVersions' -Value '1' -Type DWord

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "TLS for .NET set to:" -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Check pending reboot
If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}

Install-DotNetFramework-v3.5
Set-TlsForDotNet-v3.5

Stop-Transcript
