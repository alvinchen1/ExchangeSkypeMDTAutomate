<#
NAME
    USS-EXCHG-CONFIG-2.ps1

SYNOPSIS
    Installs core features and prerequisite software in support of Exchange Server 2019

SYNTAX
    .\$ScriptName
 #>

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path -Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RootDir = Split-Path $ScriptDir -Parent
$ConfigFile = "$RootDir\config.xml"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) {Throw "ERROR: Unable to locate $ConfigFile Exiting..."}
$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value 
$Windows2019SourcePath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\W2019\sources"
$ExchangePrereqPath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\ExchangePrereqs"
$DOTNETFRAMEWORKPath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\DOTNETFRAMEWORK_4.8"
$ExchangePath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\Exchange"

Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\$ScriptName.log
Start-Transcript -Path $RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log


###------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
###
###    Alvin Chen
###    Install Exchange 2019
###    Prerequisites, a file share, AD joined, IP addressed, Schema Admins, Enterprise Admins, Exchange Drive, all variables above set, 
###         DNS name resolution for ExchangeMailURL
###
###    Prerequisties as of 7/15/2022
###         https://docs.microsoft.com/en-us/exchange/plan-and-deploy/prerequisites?view=exchserver-2019
###         Download .net Framework 4.8:  
###                  https://go.microsoft.com/fwlink/?linkid=2088631
###             See   https://support.microsoft.com/en-us/topic/microsoft-net-framework-4-8-offline-installer-for-windows-9d23f658-3b97-68ab-d013-aa3c3e7495e0
###                   Place in DOTNETFRAMEWORK_4.8
###         Download Visual C++ Redistributable for Visual Studio 2012 Update 4: 
###                  https://www.microsoft.com/download/details.aspx?id=30679
###                   Place in ExchangePrereqs
###         Download Visual C++ Redistributable Package for Visual Studio 2013
###                  https://aka.ms/highdpimfc2013x64enu, rename to vcredist_x64_2013.exe
###             See https://support.microsoft.com/en-us/topic/update-for-visual-c-2013-redistributable-package-d8ccd6a5-4e26-c290-517b-8da6cfdf4f10
###                   Place in ExchangePrereqs
###         Download URL Rewrite Module 2.1: 
###                  https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi
###             See   https://www.iis.net/downloads/microsoft/url-rewrite#additionalDownloads
###                   Place in ExchangePrereqs
###         Download Unified Communications Managed API 4.0 Runtime 
###                  https://www.microsoft.com/en-us/download/details.aspx?id=34992 
###                   Place in ExchangePrereqs
###         Download Latest Exchange 
###             See   https://docs.microsoft.com/en-us/exchange/new-features/updates?view=exchserver-2019
###                   Find the latest blog post
###                        Under Release Details, find the latest ISO Download
###                        Mount and copy into Exchange Path Folder 
###
###     Known post steps as of 8/10/2022
###         Add Computer Account to Web Services Group (after Certificate Authority has been installed)
###         Add product key Set-ExchangeServer <ServerName> -ProductKey <ProductKey>
###------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
clear-host

# =============================================================================
# MAIN ROUTINE
# =============================================================================

Write-Host "Installing Windows Server Prerequisites" -Foregroundcolor Green
Install-WindowsFeature Server-Media-Foundation, NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation, RSAT-ADDS, RSAT-AD-PowerShell, GPMC, RSAT-DNS-Server -IncludeManagementTools -Source $Windows2019SourcePath

$dotnetFramework48main = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').version.Substring(0,1)
$dotnetFramework48rev = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').version.Substring(2,1)
If ($dotnetFramework48main -eq '4' -and $dotnetFramework48rev -gt 7) {Write-Host ".Net Framework 4.8 already installed" -ForegroundColor Green}
Else {
     Write-Host "Installing .Net Framework 4.8" -Foregroundcolor Green
     Start-Process $DOTNETFRAMEWORKPath"\ndp48-x86-x64-allos-enu.exe" -Wait -Argumentlist " /q /norestart"
}

####$VisualC2012 = Get-Package -Name 'Microsoft Visual C++ 2012 Redistributable (x64)*' 2>&1 | out-null
#####$VisualC2012 = Get-Package -Name 'Microsoft Visual C++ 2012 Redistributable (x64)*'
$VisualC2012 = Get-Package | where {$_.Name -like "Microsoft Visual C++ 2012 Redistributable (x64)*"}
If ($VisualC2012.count -eq '1') {write-host "Microsoft Visual C++ 2012 Redistributable (x64) already installed" -ForegroundColor Green}
Else {
      write-host "Installing Visual C++ Redistributable for Visual Studio 2012 Update 4" -Foregroundcolor green
      start-process $ExchangePrereqPath"\vcredist_x64.exe" -Wait -Argumentlist "-silent"
}

####$VisualC2013 = Get-Package -Name 'Microsoft Visual C++ 2013 Redistributable (x64)*' 2>&1 | out-null
####$VisualC2013 = Get-Package -Name 'Microsoft Visual C++ 2013 Redistributable (x64)*' 
$VisualC2013 = Get-Package | ? {$_.Name -like "Microsoft Visual C++ 2013 Redistributable (x64)*"}
If ($VisualC2013.count -eq '1') {write-host "Microsoft Visual C++ 2013 Redistributable (x64) already installed" -ForegroundColor Green}
Else {
      write-host "Installing Visual C++ Redistributable Package for Visual Studio 2013" -Foregroundcolor green
      start-process $ExchangePrereqPath"\vcredist_x64_2013.exe" -Wait -Argumentlist "-silent"
}

####$IISURLRewrite = Get-Package -Name 'IIS URL Rewrite Module*' 2>&1 | out-null
####$IISURLRewrite = Get-Package -Name 'IIS URL Rewrite Module*' 
$IISURLRewrite = Get-Package | ? {$_.Name -like "IIS URL Rewrite Module*"}
If ($IISURLRewrite.count -eq '1') {write-host "IIS URL Rewrite Module already installed" -ForegroundColor Green}
Else {
      write-host "Installing URL Rewrite Module 2.1" -Foregroundcolor green
      start-process msiexec.exe -Wait -Argumentlist " /i $ExchangePrereqPath\rewrite_amd64_en-US.msi /qn"
}

####$UCManagedAPI = Get-Package -Name 'Microsoft Server Speech Platform Runtime (x64)*' 2>&1 | out-null
####$UCManagedAPI = Get-Package -Name 'Microsoft Server Speech Platform Runtime (x64)*' 
$UCManagedAPI = Get-Package | ? {$_.Name -like "Microsoft Server Speech Platform Runtime (x64)*"}
If ($IISURLRewrite.count -eq '1') {write-host "Unified Communications Managed API 4.0 Runtime already installed" -ForegroundColor Green}
Else {
      write-host "Installing Unified Communications Managed API 4.0 Runtime" -Foregroundcolor green
      start-process $ExchangePrereqPath"\UcmaRuntimeSetup.exe" -Wait -Argumentlist "/passive /norestart"
}


Stop-Transcript

######################################### REBOOT SERVER ###########################################
