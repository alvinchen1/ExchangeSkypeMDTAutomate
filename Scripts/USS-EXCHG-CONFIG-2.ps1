<#
NAME
    USS-EXCHG-CONFIG-2.ps1

SYNOPSIS
    Installs prerequisite software in support of Exchange Server 2019

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
$ExchangePrereqPath = "$InstallShare\ExchangePrereqs"

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

Function Install-VisualC-2012
{
    $App = "Microsoft Visual C++ 2012 Redistributable (x64)"
    $VisualC2012 = Get-Package | where {$_.Name -like "$App*"}
    If ($VisualC2012.count -gt '0') 
    {
       Write-Host "$App already installed" -ForegroundColor Green
    }
    Else 
    {
        Write-Host "Installing $App" -Foregroundcolor Green
        Test-FilePath ("$ExchangePrereqPath\vcredist_x64.exe")
        Start-Process "$ExchangePrereqPath\vcredist_x64.exe" -Wait -NoNewWindow -Argumentlist "/passive /norestart /log $env:WINDIR\Temp\Install-VisualC-2012.log"

        $VisualC2012 = Get-Package | where {$_.Name -like "$App*"}
        If ($VisualC2012.count -eq '1') 
        {
           Write-Host "$App installed successfully"
        }
        Else 
        {
            Throw {"An issue occurred with installing $App"}
        }
    }
}

Function Install-VisualC-2013
{
    $App = "Microsoft Visual C++ 2013 Redistributable (x64)"
    $VisualC2013 = Get-Package | ? {$_.Name -like "$App*"}
    If ($VisualC2013.count -gt '0') 
    {
        Write-Host "$App already installed" -ForegroundColor Green
    }
    Else 
    {
        Write-Host "Installing $App" -Foregroundcolor Green
        Test-FilePath ("$ExchangePrereqPath\vcredist_x64_2013.exe")
        Start-Process "$ExchangePrereqPath\vcredist_x64_2013.exe" -Wait -NoNewWindow -Argumentlist "/passive /norestart /log $env:WINDIR\Temp\Install-VisualC-2013.log"

        $VisualC2013 = Get-Package | ? {$_.Name -like "$App*"}
        If ($VisualC2013.count -eq '1') 
        {
            Write-Host "$App installed successfully"
        }
        Else 
        {
            Throw {"An issue occurred with installing $App"}
        }
    }
}

Function Install-IISURLRewrite
{
    $App = "IIS URL Rewrite Module"
    $IISURLRewrite = Get-Package | ? {$_.Name -like "$App*"}
    If ($IISURLRewrite.count -eq '1') 
    {
        Write-Host "$App already installed" -ForegroundColor Green
    }
    Else 
    {
        Write-Host "Installing $App" -Foregroundcolor Green
        Test-FilePath ("$ExchangePrereqPath\rewrite_amd64_en-US.msi")
        Start-Process msiexec.exe -Wait -NoNewWindow -Argumentlist " /i $ExchangePrereqPath\rewrite_amd64_en-US.msi /qn /log $env:WINDIR\Temp\Install-IISURLRewrite.log"

        $IISURLRewrite = Get-Package | ? {$_.Name -like "$App*"}
        If ($IISURLRewrite.count -eq '1')
        {
            Write-Host "$App installed successfully"
        }
        Else
        {
            Throw {"An issue occurred with installing $App"}
        }
    }
}

Function Install-UCManagedAPI
{
    $App = "Microsoft Server Speech Platform Runtime (x64)"
    $UCManagedAPI = Get-Package | ? {$_.Name -like "$App*"}
    If ($UCManagedAPI.count -eq '1') 
    {
        Write-Host "$App already installed" -ForegroundColor Green
    }
    Else 
    {
        Write-Host "Installing $App" -Foregroundcolor Green
        Test-FilePath ("$ExchangePrereqPath\UcmaRuntimeSetup.exe")
        Start-Process "$ExchangePrereqPath\UcmaRuntimeSetup.exe" -Wait -NoNewWindow -Argumentlist "/passive /norestart /log $env:WINDIR\Temp\Install-UCManagedAPI.log"

        $UCManagedAPI = Get-Package | ? {$_.Name -like "$App*"}
        If ($UCManagedAPI.count -eq '1') 
        {
            Write-Host "$App installed successfully"
        }
        Else
        {
            Throw {"An issue occurred with installing $App"}
        }
    }
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Check pending reboot
If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}

# Install Exchange prereqs
Install-VisualC-2012
Install-VisualC-2013
Install-IISURLRewrite
Install-UCManagedAPI

Import-Module ActiveDirectory
If ((Get-ADGroup "Web Servers").ObjectClass -eq "group") 
{
    Write-Host "Adding $env:COMPUTERNAME$ computer account to Web Servers security group" -ForegroundColor Green
    Get-ADGroup "Web Servers" | Add-AdGroupMember -Members $env:COMPUTERNAME$
}

Stop-Transcript
