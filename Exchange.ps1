$Windows2019SourcePath = "\\oct-adc-001\share\WindowsServer2019\sources"
$ExchangePrereqPath = "\\oct-adc-001\share\ExchangePrereqs"
$ExchangePath = "\\oct-adc-001\share\Exchange"
$TargetExchangePath = 'E:\Microsoft\ExchangeServer\V15'
$ExchangeOrgName = "OTC"
$ExchangeMailURL = "mail.otc.lab"
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
###         Download Visual C++ Redistributable for Visual Studio 2012 Update 4: 
###                  https://www.microsoft.com/download/details.aspx?id=30679
###         Download Visual C++ Redistributable Package for Visual Studio 2013
###                  https://aka.ms/highdpimfc2013x64enu 2013, rename to 
###             See https://support.microsoft.com/en-us/topic/update-for-
###         Download URL Rewrite Module 2.1: 
###                  https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi
###             See   https://www.iis.net/downloads/microsoft/url-rewrite#additionalDownloads
###         Download Unified Communications Managed API 4.0 Runtime 
###                  https://www.microsoft.com/en-us/download/details.aspx?id=34992 visual-c-2013-redistributable-package-d8ccd6a5-4e26-c290-517b-8da6cfdf4f10
###         Download Latest Exchange 
###             See   https://docs.microsoft.com/en-us/exchange/new-features/build-numbers-and-release-dates?view=exchserver-2019#exchange-server-2019
###                   Place in Updates Folder under Exchange Server Source
###------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
clear-host

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

$dotnetFramework48main = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').version.Substring(0,1)
$dotnetFramework48rev = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').version.Substring(2,1)
If ($dotnetFramework48main -eq '4' -and $dotnetFramework48rev -gt 7) {write-host ".net Framework 4.8 already installed" -ForegroundColor Green}
Else {
      write-host "Installing .net Framework 4.8" -Foregroundcolor green
      start-process $ExchangePrereqPath"\ndp48-x86-x64-allos-enu.exe" -Wait -Argumentlist " /q /norestart"
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

$WindowsFeature = Get-WindowsFeature -Name Web* | Where Installed
If ($WindowsFeature.count -gt '45') {write-host "Windows Server prerequisites already installed" -ForegroundColor Green}
Else {
      write-host "Installing Windows Server Prerequisites" -Foregroundcolor green
      Install-WindowsFeature Server-Media-Foundation, NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation, RSAT-ADDS, RSAT-AD-PowerShell -Source $Windows2019SourcePath
     }


####
####  Check is ADPS Module is installed before proceeding with Schema check, currently not working consistently, will attempt to update ####       schema when get-addomain fails
####
get-addomain 2>&1 | out-null
$ADPSModule = get-module | ? {$_.Name -eq "ActiveDirectory"}
IF ($ADPSModule.count -eq '1') 
       {
       $LDAPDomain = (get-addomain).DistinguishedName
       $ExchangeSchemaLocation = 'AD:\CN=ms-Exch-Schema-Version-Pt,CN=Schema,CN=Configuration,'+$LDAPDomain
       $ADSchema = Get-ItemProperty $ExchangeSchemaLocation -Name rangeUpper
       If ($ADSchema.rangeUpper -lt '16999') {
             write-host "Extending Active Directory Schema" -Foregroundcolor green
             start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /ps"
             write-host "Pausing for Schema replication" -Foregroundcolor green
             Start-Sleep -seconds 300
            }
       Else {write-host "Active Directory Schema already extended for Exchange 2019" -ForegroundColor Green}
       }
Else {write-host "Active Directory PowerShell not detected, skipping Schema check" -ForegroundColor Red}

$ADExchangePrepped = "AD:\CN=Microsoft Exchange System Objects," + $LDAPDomain
$ADExchangePreppedobjversion = Get-ItemProperty $ADExchangePrepped -Name objectVersion
If ($ADExchangePreppedobjversion.objectVersion -gt '13230') {write-host "Active Directory already Prepared for Exchange 2019" -ForegroundColor Green}
Else {
      write-host "Preparing Active Directory" -Foregroundcolor green
      start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /PrepareAD       /OrganizationName:$ExchangeOrgName"
      write-host "Pausing for Active Directory replication" -Foregroundcolor green
      Start-Sleep -seconds 300
     }

####$Exchange = Get-Package -Name 'Microsoft Exchange Server' 2>&1 | out-null
####$Exchange = Get-Package -Name 'Microsoft Exchange Server' 
$Exchange = Get-Package  | ? {$_.Name -like "Microsoft Exchange Server"}
If ($Exchange.count -eq '1') {write-host "Microsoft Exchange Server already installed" -ForegroundColor Green}
Else {
      write-host "Installing Exchange 2019" -Foregroundcolor green
      start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /TargetDir:$TargetExchangePath /CustomerFeedbackEnabled:False /Mode:install /Roles:mb"
     }

#####$TargetExchangePath = 'E:\Program,Files\Microsoft\Exchange,Server\v15'
#####Fix for first bad servers

$TargetExchangePSPath = $TargetExchangePath + "\bin\RemoteExchange.ps1"
Write-Host $TargetExchangePSPath 
Import-Module $TargetExchangePSPath
Connect-ExchangeServer -auto -ClientApplication:ManagementShell

####Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn
####Connect-ExchangeServer -auto -ClientApplication:ManagementShell
####Obtain Certificate

Write-Host 'Getting OWA Virtual Directories' -ForegroundColor Green
Get-OwaVirtualDirectory | fl InternalURL,ExternalURL
Write-Host 'Setting OWA Virtual Directories' -ForegroundColor Yellow
Get-OwaVirtualDirectory | set-OwaVirtualDirectory -InternalURL https://$ExchangeMailURL/owa  -ExternalURL https://$ExchangeMailURL/owa
Write-Host 'New OWA Virtual Directories' -ForegroundColor Red
Get-OwaVirtualDirectory | fl InternalURL,ExternalURL

Write-Host 'Getting ECP Virtual Directories' -ForegroundColor Green
Get-EcpVirtualDirectory | fl InternalURL,ExternalURL
Write-Host 'Setting ECP Virtual Directories' -ForegroundColor Yellow
Get-EcpVirtualDirectory | Set-EcpVirtualDirectory -InternalURL https://$ExchangeMailURL/ecp  -ExternalURL https://$ExchangeMailURL/ecp
Write-Host 'New ECP Virtual Directories' -ForegroundColor Red
Get-EcpVirtualDirectory | fl InternalURL,ExternalURL

Write-Host 'Getting ActiveSync Virtual Directories' -ForegroundColor Green
Get-ActiveSyncVirtualDirectory | fl InternalURL,ExternalURL
Write-Host 'Setting AciveSync Virtual Directories' -ForegroundColor Yellow
Get-ActiveSyncVirtualDirectory | set-ActiveSyncVirtualDirectory -InternalURL https://$ExchangeMailURL/Microsoft-Server-ActiveSync  -ExternalURL https://$ExchangeMailURL/Microsoft-Server-ActiveSync
Write-Host 'New ActiveSync Virtual Directories' -ForegroundColor Red
Get-ActiveSyncVirtualDirectory | fl InternalURL,ExternalURL

Write-Host 'Getting OAB Virtual Directories' -ForegroundColor Green
Get-OabVirtualDirectory | fl InternalURL,ExternalURL
Write-Host 'Setting OAB Virtual Directories' -ForegroundColor Yellow
Get-OabVirtualDirectory | Set-OabVirtualDirectory -InternalURL https://$ExchangeMailURL/OAB  -ExternalURL https://$ExchangeMailURL/OAB
Write-Host 'New OAB Virtual Directories' -ForegroundColor Red
Get-OabVirtualDirectory | fl InternalURL,ExternalURL

Write-Host 'Getting WebServices Virtual Directories' -ForegroundColor Green
Get-WebServicesVirtualDirectory | fl InternalURL,ExternalURL
Write-Host 'Setting WebServices Virtual Directories' -ForegroundColor Yellow
Get-WebServicesVirtualDirectory | Set-WebServicesVirtualDirectory -InternalURL https://$ExchangeMailURL/EWS/Exchange.asmx -ExternalURL https://$ExchangeMailURL/EWS/Exchange.asmx -force
Write-Host 'New WebServices Virtual Directories' -ForegroundColor Red
Get-WebServicesVirtualDirectory | fl InternalURL,ExternalURL

Write-Host 'Getting OutlookAnywhere Host Name' -ForegroundColor Green
Get-OutlookAnywhere | fl Internalhostname,Externalhostname
Write-Host 'Setting OutlookAnywhere Host Name' -ForegroundColor Yellow
Get-OutlookAnywhere | Set-OutlookAnywhere -Internalhostname $ExchangeMailURL -Externalhostname $ExchangeMailURL -InternalClientsRequireSsl $true -ExternalClientsRequireSsl $true -DefaultAuthenticationMethod NTLM
Write-Host 'New OutlookAnywhere Host Name' -ForegroundColor Red
Get-OutlookAnywhere | fl Internalhostname,Externalhostname

####No longer needed?
####Write-Host 'Getting PowerShell Virtual Directories' -ForegroundColor Green
####Get-PowerShellVirtualDirectory | fl InternalURL,ExternalURL
####Write-Host 'Setting PowerShell Virtual Directories' -ForegroundColor Yellow
####Get-PowerShellVirtualDirectory | Set-EcpVirtualDirectory -InternalURL https://$ExchangeMailURL/powershell -ExternalURL https://####$ExchangeMailURL/powershell
####Write-Host 'New PowerShell Virtual Directories' -ForegroundColor Red
####Get-PowerShellVirtualDirectory | fl InternalURL,ExternalURL

####No longer needed?
####Write-Host 'Getting Client Access Array' -ForegroundColor Green
####Get-ClientAccessService | fl ClientAccessArray
####Write-Host 'Setting Client Access Array' -ForegroundColor Yellow
####Get-ClientAccessService | Set-ClientAccessService -ClientAccessArray $ExchangeMailURL
####Write-Host 'New Client Access Array' -ForegroundColor Red
####Get-ClientAccessService | fl ClientAccessArray

Write-Host 'Getting MAPI Virtual Directories' -ForegroundColor Green
Get-MapiVirtualDirectory | fl InternalURL,ExternalURL
Write-Host 'Setting MAPI Virtual Directories' -ForegroundColor Yellow
Get-MapiVirtualDirectory | Set-MapiVirtualDirectory -InternalURL https://$ExchangeMailURL/mapi  -ExternalURL https://$ExchangeMailURL/mapi
Write-Host 'New MAPI Virtual Directories' -ForegroundColor Red
Get-MapiVirtualDirectory | fl InternalURL,ExternalURL






