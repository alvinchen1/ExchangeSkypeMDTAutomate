$Windows2019SourcePath = "\\oct-adc-001\share\WindowsServer2019\sources"
$Skype4BusinessPrereqPath = "\\oct-adc-001\share\Skype4BusinessPrereqs"
$Skype4BusinessPath = "\\oct-adc-001\share\Skype4Business"
$Skype4BusinessCU = "\\oct-adc-001\share\Skype4BusinessCU"
$ExchangeOrgName = "OTC"
$ExchangeMailURL = "mail.otc.lab"
###------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
###
###    Alvin Chen
###    Install Skype For Business 2019
###    Prerequisites, a file share, AD joined, IP addressed, Schema Admins, Enterprise Admins, all variables above set
###
###    Prerequisties as of 7/26/2022
###         https://docs.microsoft.com/en-us/exchange/plan-and-deploy/prerequisites?view=exchserver-2019
###         Download .net Framework 4.8:  
###                  https://go.microsoft.com/fwlink/?linkid=2088631
###             See   https://support.microsoft.com/en-us/topic/microsoft-net-framework-4-8-offline-installer-for-windows-9d23f658-3b97-68ab-d013-aa3c3e7495e0
###         Download Skype For Business ISO
###                  https://www.microsoft.com/en-us/evalcenter/download-skype-business-server-2019
###             Open ISO and Extract folders under Skype4BusinessPath such that in the root of Skype4BusinessPath is autorun.inf, and Setup and Support Folders
###         Download Latest Skype For Business Cumulative Update
###             See   https://docs.microsoft.com/en-us/skypeforbusiness/sfb-server-updates
###                   Place in Skype4BusinessCU
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
      start-process $Skype4BusinessPrereqPath"\ndp48-x86-x64-allos-enu.exe" -Wait -Argumentlist " /q /norestart"
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
      Add-WindowsFeature RSAT-ADDS, Web-Server, Web-Static-Content, Web-Default-Doc, Web-Http-Errors, Web-Asp-Net, Web-Net-Ext, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Http-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Basic-Auth, Web-Windows-Auth, Web-Client-Auth, Web-Filtering, Web-Stat-Compression, Web-Dyn-Compression, NET-WCF-HTTP-Activation45, Web-Asp-Net45, Web-Mgmt-Tools, Web-Scripting-Tools, Web-Mgmt-Compat, Windows-Identity-Foundation, Server-Media-Foundation, Telnet-Client, BITS, ManagementOData, Web-Mgmt-Console, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service
     }


####
####  Check is ADPS Module is installed before proceeding with Schema check
####
$ADPSModule = get-module | ? {$_.Name -eq "ActiveDirectory"}
IF ($ADPSModule.count -eq '1') 
       {
       $LDAPDomain = (get-addomain).DistinguishedName
       $ExchangeSchemaLocation = 'AD:\CN=ms-Exch-Schema-Version-Pt,CN=Schema,CN=Configuration,'+$LDAPDomain
       $ADSchema = Get-ItemProperty $ExchangeSchemaLocation -Name rangeUpper
       If ($ADSchema.rangeUpper -gt '16999') {write-host "Active Directory Schema already extended for Exchange 2019" -ForegroundColor Green}
       Else {
             write-host "Extending Active Directory Schema" -Foregroundcolor green
             start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /ps"
             write-host "Pausing for Schema replication" -Foregroundcolor green
             Start-Sleep -seconds 300
            }
       }

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

$TargetExchangePath = 'E:\Program,Files\Microsoft\Exchange,Server\v15'
#####Fix for first bad servers

$TargetExchangePSPath = $TargetExchangePath + "\bin\RemoteExchange.ps1"
Write-Host $TargetExchangePSPath 
Import-Module $TargetExchangePSPath
Connect-ExchangeServer -auto -ClientApplication:ManagementShell

####Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn
####Connect-ExchangeServer -auto -ClientApplication:ManagementShell
get-mailbox
####Obtain Certificate
Get-OwaVirtualDirectory
Get-EcpVirtualDirectory
Get-ActiveSyncVirtualDirectory
Get-OabVirtualDirectory
Get-WebServicesVirtualDirectory
Get-OutlookAnywhere
Get-PowerShellVirtualDirectory
Get-ClientAccessService
Get-MapiVirtualDirectory



