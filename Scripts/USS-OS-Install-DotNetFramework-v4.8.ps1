<#
NAME
    Install-DotNetFramework-v4.8.ps1

SYNOPSIS
    Installs Microsoft .NET Framework v4.8

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
$DotNetPkgDir = "$InstallShare\DOTNETFRAMEWORK_4.8"

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

Function Install-DotNetFramework-v4.8
{
    $DotNetRegVersion = "4.8"
    $LogFile = "$env:WINDIR\Temp\DotNetFramework-v$DotNetRegVersion.log"
    $Manifest = "$DotNetPkgDir\ndp48-x86-x64-allos-enu.exe"
    foreach ($File in $Manifest) {Test-FilePath ($File)}
  
    $DotNetReg = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction "SilentlyContinue")
    If ($DotNetReg.Release -lt 528040)
    {
        Write-Progress -Activity "Installing Microsoft .NET Framework v$DotNetRegVersion" -Status "Install log location: $LogFile" -PercentComplete -1
        
        $FilePath = "$DotNetPkgDir\ndp48-x86-x64-allos-enu.exe"
        $Args = @(
        '/q'
        '/norestart'
        '/log'
        "$LogFile"
        )
        Start-Process -FilePath $FilePath -ArgumentList $Args -Wait
        
        Write-Progress -Activity "Installing Microsoft .NET Framework v$DotNetRegVersion" -Completed -Status "Completed"
    }
    Else
    {
        Write-Host "`nMicrosoft .NET Framework "$DotNetReg.Version" is already installed."
    }
}

Function Set-TlsForDotNet-v4.x
{
    # Transport Layer Security (TLS) best practices with the .NET Framework
    # https://docs.microsoft.com/en-us/dotnet/framework/network-programming/tls

    # Enable TLS 1.2 for .NET v4.x
    # x64
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Value '1' -Type DWord
    # x86
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Value '1' -Type DWord

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "TLS for .NET set to:" -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Check pending reboot
If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}

Install-DotNetFramework-v4.8
Set-TlsForDotNet-v4.x

Stop-Transcript
