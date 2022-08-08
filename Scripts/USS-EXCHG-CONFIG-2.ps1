<#
NAME
    USS-EXCHG-CONFIG-2.ps1

SYNOPSIS
    Installs Exchange Server 2019 in the AD domain

SYNTAX
    .\$ScriptName
 #>


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
$Exchange = ($XML.Component | ? {($_.Name -eq "Exchange")}).Settings.Configuration
$TargetExchangePath = ($Exchange | ? {($_.Name -eq "TargetExchangePath")}).Value
$ExchangeOrgName = ($Exchange | ? {($_.Name -eq "ExchangeOrgName")}).Value
$ExchangeMailURL = ($Exchange | ? {($_.Name -eq "ExchangeMailURL")}).Value
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value 
$Windows2019SourcePath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\W2019\sources"
$ExchangePrereqPath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\ExchangePrereqs"
$DOTNETFRAMEWORKPath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\DOTNETFRAMEWORK_4.8"
$ExchangePath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\Exchange"
$LDAPDomain = ($WS | ? {($_.Name -eq "DomainDistinguishedName")}).Value
$CertTemplate = ($WS | ? {($_.Name -eq "DomainName")}).Value + "WebServer"
$OWAVirtualDirectory = "https://" + $ExchangeMailURL + "/owa"
$ECPVirtualDirectory = "https://" + $ExchangeMailURL + "/ecp"
$OABVirtualDirectory = "https://" + $ExchangeMailURL + "/OAB"
$MAPIVirtualDirectory = "https://" + $ExchangeMailURL + "/mapi"
$ActiveSyncVirtualDirectory = "https://" + $ExchangeMailURL + "/Microsoft-Server-ActiveSync"
$WebServicesVirtualDirectory = "https://" + $ExchangeMailURL + "/EWS/Exchange.asmx"

###################################################################################################
### Start-Transcript
### Stop-Transcript
### Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\$ScriptName.log
Start-Transcript -Path $InstallShare\LOGS\$env:COMPUTERNAME\$ScriptName.log


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
###     Known post steps as of 7/26/2022
###         Request and obtain certificate from certificate authority Get-Certificate,New-ExchangeCertificate, Enable-ExchangeCertificate
###         Add product key Set-ExchangeServer <ServerName> -ProductKey <ProductKey>
###------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
clear-host

# =============================================================================
# FUNCTIONS
# =============================================================================

#Adapted from https://gist.github.com/altrive/5329377
#Based on <https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542>
function Test-PendingReboot
{
 if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
 if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
 if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
 try { 
   $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
   $status = $util.DetermineIfRebootPending()
   if(($status -ne $null) -and $status.RebootPending){
     return $true
   }
 }catch{}

 return $false
}


# =============================================================================
# MAIN ROUTINE
# =============================================================================

$WindowsFeature = Get-WindowsFeature -Name Web* | Where Installed
If ($WindowsFeature.count -gt '33') {write-host "Windows Server prerequisites already installed" -ForegroundColor Green}
Else {
      write-host "Installing Windows Server Prerequisites" -Foregroundcolor green
      Install-WindowsFeature Server-Media-Foundation, NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation, RSAT-ADDS, RSAT-AD-PowerShell -Source $Windows2019SourcePath
     }

$dotnetFramework48main = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').version.Substring(0,1)
$dotnetFramework48rev = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').version.Substring(2,1)
If ($dotnetFramework48main -eq '4' -and $dotnetFramework48rev -gt 7) {write-host ".net Framework 4.8 already installed" -ForegroundColor Green}
Else {
      write-host "Installing .net Framework 4.8" -Foregroundcolor green
      start-process $DOTNETFRAMEWORKPath"\ndp48-x86-x64-allos-enu.exe" -Wait -Argumentlist " /q /norestart"
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

####
####  Check is ADPS Module is installed before proceeding with Schema check, currently not working consistently, will attempt to update ####       schema when get-addomain fails
####
###get-addomain 2>&1 | out-null
import-module ActiveDirectory 2>&1 | out-null
$ADPSModule = get-module | ? {$_.Name -eq "ActiveDirectory"}
IF ($ADPSModule.count -eq '1') {
       ####$LDAPDomain = (get-addomain).DistinguishedName
       ###get-adobject -SearchBase "CN=Schema,CN=Configuration,DC=USS,DC=LOCAL" -filter * | Where {$_.DistinguishedName -like "CN=ms-exch-schema*"}
       $ADOSchemaLocation = 'CN=Schema,CN=Configuration,'+$LDAPDomain
       IF (get-adobject -SearchBase $ADOSchemaLocation -filter * | Where {$_.DistinguishedName -like "CN=ms-exch-schema*"} -eq 0) {
           $ADSchemaLocation = 'AD:\CN=Schema,CN=Configuration,'+$LDAPDomain
           $ExchangeSchemaLocation = 'AD:\CN=ms-Exch-Schema-Version-Pt,CN=Schema,CN=Configuration,'+$LDAPDomain
           $ADSchema = Get-ItemProperty $ExchangeSchemaLocation -Name rangeUpper
           If ($ADSchema.rangeUpper -lt '16999') {
               write-host "Extending Active Directory Schema" -Foregroundcolor green
               start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /ps"
               write-host "Pausing for Schema replication" -Foregroundcolor green
               Start-Sleep -seconds 300
            }
       }
       Else {write-host "Active Directory Schema already extended for Exchange 2019" -ForegroundColor Green}
}
Else {write-host "Active Directory PowerShell not detected, skipping Schema check" -ForegroundColor Red}

####
####   Check Active Directory Prep
####

import-module ActiveDirectory 2>&1 | out-null
$ADPSModule = get-module | ? {$_.Name -eq "ActiveDirectory"}
IF ($ADPSModule.count -eq '1') {
       ####$LDAPDomain = (get-addomain).DistinguishedName
       ###get-adobject -SearchBase "CN=Schema,CN=Configuration,DC=USS,DC=LOCAL" -filter * | Where {$_.DistinguishedName -like "CN=ms-exch-schema*"}
       $ADOSchemaLocation = 'CN=Schema,CN=Configuration,'+$LDAPDomain
       IF (get-adobject -SearchBase $ADOSchemaLocation -filter * | Where {$_.DistinguishedName -like "CN=ms-exch-schema*"} -eq 0) {
           $ADSchemaLocation = 'AD:\CN=Schema,CN=Configuration,'+$LDAPDomain
           $ExchangeSchemaLocation = 'AD:\CN=ms-Exch-Schema-Version-Pt,CN=Schema,CN=Configuration,'+$LDAPDomain
           $ADSchema = Get-ItemProperty $ExchangeSchemaLocation -Name rangeUpper
           If ($ADSchema.rangeUpper -lt '16999') {
                 $ADExchangePrepped = "AD:\CN=Microsoft Exchange System Objects," + $LDAPDomain
                 $ADExchangePreppedobjversion = Get-ItemProperty $ADExchangePrepped -Name objectVersion
                 If ($ADExchangePreppedobjversion.objectVersion -gt '13230') {write-host "Active Directory already Prepared for Exchange 2019" -ForegroundColor Green}
                 Else {
                       start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /PrepareAD /OrganizationName:$ExchangeOrgName"
                       write-host "Pausing for Active Directory replication" -Foregroundcolor green
                       Start-Sleep -seconds 300
                      }
                 }

           }
       Else {write-host "Active Directory prepped already for Exchange 2019" -ForegroundColor Green}
       }
Else {write-host "Active Directory PowerShell not detected, skipping Active Directory prep" -ForegroundColor Red}

####$Exchange = Get-Package -Name 'Microsoft Exchange Server' 2>&1 | out-null
####$Exchange = Get-Package -Name 'Microsoft Exchange Server' 
$Exchange = Get-Package  | ? {$_.Name -like "Microsoft Exchange Server"}
If ($Exchange.count -eq '0' -and (Test-PendingReboot) -eq $false) {
     write-host "Installing Exchange 2019" -Foregroundcolor green
     start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /TargetDir:$TargetExchangePath /CustomerFeedbackEnabled:False /Mode:install /Roles:mb /OrganizationName:$ExchangeOrgName"
     }
Else {
     write-host "Microsoft Exchange Server already installed or reboot needed" -ForegroundColor Green
     }

$Exchange = Get-Package  | ? {$_.Name -like "Microsoft Exchange Server*"}
If ($Exchange.count -gt '0') {
     write-host "Checking for Exchange" -ForegroundColor Green
     
     $TargetExchangePSPath = $TargetExchangePath + "\bin\RemoteExchange.ps1"
     Import-Module $TargetExchangePSPath
     Connect-ExchangeServer -auto -ClientApplication:ManagementShell

     ####Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn
     ####Connect-ExchangeServer -auto -ClientApplication:ManagementShell
     ####Obtain Certificate
     Write-Host 'Checking OWA Virtual Directories InternalURL' -ForegroundColor Green
     If ((Get-OwaVirtualDirectory | ? {$_.InternalURL -notlike $OWAVirtualDirectory}).count -gt 0) {
          Get-OwaVirtualDirectory | ? {$_.InternalURL -notlike $OWAVirtualDirectory} | fl InternalURL
          Write-Host 'Setting OWA Virtual Directories InternalURL' -ForegroundColor Yellow
          Get-OwaVirtualDirectory | ? {$_.InternalURL -notlike $OWAVirtualDirectory} | set-OwaVirtualDirectory -InternalURL $OWAVirtualDirectory
          Write-Host 'New OWA Virtual Directories InternalURL' -ForegroundColor Red
          Get-OwaVirtualDirectory | fl InternalURL
     }
     Write-Host 'Checking OWA Virtual Directories ExternalURL' -ForegroundColor Green
     If ((Get-OwaVirtualDirectory | ? {$_.ExternalURL -notlike $OWAVirtualDirectory}).count -gt 0) {
          Get-OwaVirtualDirectory | ? {$_.ExternalURL -notlike $OWAVirtualDirectory} | fl ExternalURL
          Write-Host 'Setting OWA Virtual Directories ExternalURL' -ForegroundColor Yellow
          Get-OwaVirtualDirectory | ? {$_.ExternalURL -notlike $OWAVirtualDirectory} | set-OwaVirtualDirectory -ExternalURL $OWAVirtualDirectory
          Write-Host 'New OWA Virtual Directories ExternalURL' -ForegroundColor Red
          Get-OwaVirtualDirectory | fl ExternalURL
     }
     Write-Host 'Checking ECP Virtual Directories InternalURL' -ForegroundColor Green
     If ((Get-ECPVirtualDirectory | ? {$_.InternalURL -notlike $ECPVirtualDirectory}).count -gt 0) {
          Get-ECPVirtualDirectory | ? {$_.InternalURL -notlike $ECPVirtualDirectory} | fl InternalURL
          Write-Host 'Setting ECP Virtual Directories InternalURL' -ForegroundColor Yellow
          Get-ECPVirtualDirectory | ? {$_.InternalURL -notlike $ECPVirtualDirectory} | set-ECPVirtualDirectory -InternalURL $ECPVirtualDirectory
          Write-Host 'New ECP Virtual Directories InternalURL' -ForegroundColor Red
          Get-ECPVirtualDirectory | fl InternalURL
     }
     Write-Host 'Checking ECP Virtual Directories ExternalURL' -ForegroundColor Green
     If ((Get-ECPVirtualDirectory | ? {$_.ExternalURL -notlike $ECPVirtualDirectory}).count -gt 0) {
          Get-ECPVirtualDirectory | ? {$_.ExternalURL -notlike $ECPVirtualDirectory} | fl ExternalURL
          Write-Host 'Setting ECP Virtual Directories ExternalURL' -ForegroundColor Yellow
          Get-ECPVirtualDirectory | ? {$_.ExternalURL -notlike $ECPVirtualDirectory} | set-ECPVirtualDirectory -ExternalURL $ECPVirtualDirectory
          Write-Host 'New ECP Virtual Directories ExternalURL' -ForegroundColor Red
          Get-ECPVirtualDirectory | fl ExternalURL
     }
     Write-Host 'Checking OAB Virtual Directories InternalURL' -ForegroundColor Green
     If ((Get-OABVirtualDirectory | ? {$_.InternalURL -notlike $OABVirtualDirectory}).count -gt 0) {
          Get-OABVirtualDirectory | ? {$_.InternalURL -notlike $OABVirtualDirectory} | fl InternalURL
          Write-Host 'Setting OAB Virtual Directories InternalURL' -ForegroundColor Yellow
          Get-OABVirtualDirectory | ? {$_.InternalURL -notlike $OABVirtualDirectory} | set-OABVirtualDirectory -InternalURL $OABVirtualDirectory
          Write-Host 'New OAB Virtual Directories InternalURL' -ForegroundColor Red
          Get-OABVirtualDirectory | fl InternalURL
     }
     Write-Host 'Checking OAB Virtual Directories ExternalURL' -ForegroundColor Green
     If ((Get-OABVirtualDirectory | ? {$_.ExternalURL -notlike $OABVirtualDirectory}).count -gt 0) {
          Get-OABVirtualDirectory | ? {$_.ExternalURL -notlike $OABVirtualDirectory} | fl ExternalURL
          Write-Host 'Setting OAB Virtual Directories ExternalURL' -ForegroundColor Yellow
          Get-OABVirtualDirectory | ? {$_.ExternalURL -notlike $OABVirtualDirectory} | set-OABVirtualDirectory -ExternalURL $OABVirtualDirectory
          Write-Host 'New OAB Virtual Directories ExternalURL' -ForegroundColor Red
          Get-OABVirtualDirectory | fl ExternalURL
     }
     Write-Host 'Checking MAPI Virtual Directories InternalURL' -ForegroundColor Green
     If ((Get-MAPIVirtualDirectory | ? {$_.InternalURL -notlike $MAPIVirtualDirectory}).count -gt 0) {
          Get-MAPIVirtualDirectory | ? {$_.InternalURL -notlike $MAPIVirtualDirectory} | fl InternalURL
          Write-Host 'Setting MAPI Virtual Directories InternalURL' -ForegroundColor Yellow
          Get-MAPIVirtualDirectory | ? {$_.InternalURL -notlike $MAPIVirtualDirectory} | set-MAPIVirtualDirectory -InternalURL $MAPIVirtualDirectory
          Write-Host 'New MAPI Virtual Directories InternalURL' -ForegroundColor Red
          Get-MAPIVirtualDirectory | fl InternalURL
     }
     Write-Host 'Checking MAPI Virtual Directories ExternalURL' -ForegroundColor Green
     If ((Get-MAPIVirtualDirectory | ? {$_.ExternalURL -notlike $MAPIVirtualDirectory}).count -gt 0) {
          Get-MAPIVirtualDirectory | ? {$_.ExternalURL -notlike $MAPIVirtualDirectory} | fl ExternalURL
          Write-Host 'Setting MAPI Virtual Directories ExternalURL' -ForegroundColor Yellow
          Get-MAPIVirtualDirectory | ? {$_.ExternalURL -notlike $MAPIVirtualDirectory} | set-MAPIVirtualDirectory -ExternalURL $MAPIVirtualDirectory
          Write-Host 'New MAPI Virtual Directories ExternalURL' -ForegroundColor Red
          Get-MAPIVirtualDirectory | fl ExternalURL
     }
          Write-Host 'Checking ActiveSync Virtual Directories InternalURL' -ForegroundColor Green
     If ((Get-ActiveSyncVirtualDirectory | ? {$_.InternalURL -notlike $ActiveSyncVirtualDirectory}).count -gt 0) {
          Get-ActiveSyncVirtualDirectory | ? {$_.InternalURL -notlike $ActiveSyncVirtualDirectory} | fl InternalURL
          Write-Host 'Setting ActiveSync Virtual Directories InternalURL' -ForegroundColor Yellow
          Get-ActiveSyncVirtualDirectory | ? {$_.InternalURL -notlike $ActiveSyncVirtualDirectory} | set-ActiveSyncVirtualDirectory -InternalURL $ActiveSyncVirtualDirectory
          Write-Host 'New ActiveSync Virtual Directories InternalURL' -ForegroundColor Red
          Get-ActiveSyncVirtualDirectory | fl InternalURL
     }
     Write-Host 'Checking ActiveSync Virtual Directories ExternalURL' -ForegroundColor Green
     If ((Get-ActiveSyncVirtualDirectory | ? {$_.ExternalURL -notlike $ActiveSyncVirtualDirectory}).count -gt 0) {
          Get-ActiveSyncVirtualDirectory | ? {$_.ExternalURL -notlike $ActiveSyncVirtualDirectory} | fl ExternalURL
          Write-Host 'Setting ActiveSync Virtual Directories ExternalURL' -ForegroundColor Yellow
          Get-ActiveSyncVirtualDirectory | ? {$_.ExternalURL -notlike $ActiveSyncVirtualDirectory} | set-ActiveSyncVirtualDirectory -ExternalURL $ActiveSyncVirtualDirectory
          Write-Host 'New ActiveSync Virtual Directories ExternalURL' -ForegroundColor Red
          Get-ActiveSyncVirtualDirectory | fl ExternalURL
     }
     Write-Host 'Checking WebServices Virtual Directories InternalURL' -ForegroundColor Green
     If ((Get-WebServicesVirtualDirectory | ? {$_.InternalURL -notlike $WebServicesVirtualDirectory}).count -gt 0) {
          Get-WebServicesVirtualDirectory | ? {$_.InternalURL -notlike $WebServicesVirtualDirectory} | fl InternalURL
          Write-Host 'Setting WebServices Virtual Directories InternalURL' -ForegroundColor Yellow
          Get-WebServicesVirtualDirectory | ? {$_.InternalURL -notlike $WebServicesVirtualDirectory} | set-WebServicesVirtualDirectory -InternalURL $WebServicesVirtualDirectory -force
          Write-Host 'New WebServices Virtual Directories InternalURL' -ForegroundColor Red
          Get-WebServicesVirtualDirectory | fl InternalURL
     }
     Write-Host 'Checking WebServices Virtual Directories ExternalURL' -ForegroundColor Green
     If ((Get-WebServicesVirtualDirectory | ? {$_.ExternalURL -notlike $WebServicesVirtualDirectory}).count -gt 0) {
          Get-WebServicesVirtualDirectory | ? {$_.ExternalURL -notlike $WebServicesVirtualDirectory} | fl ExternalURL
          Write-Host 'Setting WebServices Virtual Directories ExternalURL' -ForegroundColor Yellow
          Get-WebServicesVirtualDirectory | ? {$_.ExternalURL -notlike $WebServicesVirtualDirectory} | set-WebServicesVirtualDirectory -ExternalURL $WebServicesVirtualDirectory -force
          Write-Host 'New WebServices Virtual Directories ExternalURL' -ForegroundColor Red
          Get-WebServicesVirtualDirectory | fl ExternalURL
     }
     Write-Host 'Checking Outlook Anywhere Internal Host Name' -ForegroundColor Green
     If ((Get-OutlookAnywhere | ? {$_.Internalhostname -notlike $ExchangeMailURL}).count -gt 0) {
          Get-OutlookAnywhere | ? {$_.Internalhostname -notlike $ExchangeMailURL} | fl Internalhostname
          Write-Host 'Setting Outlook Anywhere Internal Host Name' -ForegroundColor Yellow
          Get-OutlookAnywhere | ? {$_.Internalhostname -notlike $ExchangeMailURL} | Set-OutlookAnywhere -Internalhostname $ExchangeMailURL -InternalClientsRequireSsl $true -DefaultAuthenticationMethod NTLM
          Write-Host 'New Outlook Anywhere Internal Host Name' -ForegroundColor Red
          Get-OutlookAnywhere | fl InternalURL
     }
     Write-Host 'Checking Outlook Anywhere External Host Name' -ForegroundColor Green
     If ((Get-OutlookAnywhere | ? {$_.Externalhostname -notlike $ExchangeMailURL}).count -gt 0) {
          Get-OutlookAnywhere | ? {$_.Externalhostname -notlike $ExchangeMailURL} | fl Externalhostname
          Write-Host 'Setting Outlook Anywhere External Host Name' -ForegroundColor Yellow
          Get-OutlookAnywhere | ? {$_.Externalhostname -notlike $ExchangeMailURL} | Set-OutlookAnywhere -Externalhostname $ExchangeMailURL -ExternalClientsRequireSsl $true -DefaultAuthenticationMethod NTLM
          Write-Host 'New Outlook Anywhere External Host Name' -ForegroundColor Red
          Get-OutlookAnywhere | fl ExternalURL
     }
     #### Add to Web Servers Group
     #### Reboot Exchange Server
     Write-Host 'Obtaining New Certificate' -ForegroundColor Green
     $Certificate = Get-Certificate -Template $CertTemplate -DNSName $ExchangeMailURL -CertStoreLocation cert:\LocalMachine\My
     $Certificate | FL
     Write-Host 'Binding Certificate to Exchange Services' -ForegroundColor Green
     Enable-ExchangeCertificate -thumbprint $Certificate.certificate.thumbprint -Services IIS,POP,IMAP,SMTP -confirm:$false -force
     Get-ExchangeCertificate
     }
Else {
      write-host "Exchange Not Installed" -Foregroundcolor green
     }


###################################################################################################
Stop-Transcript

######################################### REBOOT SERVER ###########################################
