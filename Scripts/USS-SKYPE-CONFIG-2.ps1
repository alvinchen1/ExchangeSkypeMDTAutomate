<#
NAME
    USS-SKYPE-CONFIG-2.ps1

SYNOPSIS
    Installs Skype For Business in the AD domain

SYNTAX
    .\$ScriptName
 #>

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path �Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path �Parent
$RootDir = Split-Path $ScriptDir �Parent
$ConfigFile = "$RootDir\config.xml"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) 
{
    Write-Host "Missing configuration file $ConfigFile" -ForegroundColor Red
### Stop-Transcript
    Exit
}

$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value 
$DomainDnsName = ($WS | ? {($_.Name -eq "DomainDnsName")}).Value
$Windows2019SourcePath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\W2019\sources\sxs"
$Skype4BusinessPrereqPath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\Skype4BusinessPrereqs"
$DOTNETFRAMEWORKPath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\DOTNETFRAMEWORK_4.8"
$Skype4BusinessPath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\SkypeForBusiness\OCS_Eval"
$SkypeForBusiness = ($XML.Component | ? {($_.Name -eq "SkypeForBusiness")}).Settings.Configuration
$CSShareName = ($SkypeForBusiness | ? {($_.Name -eq "CSShareName")}).Value
$CSShareNamePath = ($SkypeForBusiness | ? {($_.Name -eq "CSShareNamePath")}).Value
$LDAPDomain = ($WS | ? {($_.Name -eq "DomainDistinguishedName")}).Value
$CertTemplatePrefix = ($WS | ? {($_.Name -eq "DomainName")}).Value

###################################################################################################
### Start-Transcript
### Stop-Transcript
### Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\$ScriptName.log
Start-Transcript -Path $RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log

###------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
###
###    Alvin Chen
###    Install Skype For Business 2019
###    Prerequisites, a file share, AD joined, IP addressed, Schema Admins, Enterprise Admins, all variables above set
###
###    Prerequisties as of 7/26/2022
###         https://docs.microsoft.com/en-us/SkypeForBusiness/plan/system-requirements
###         Download .net Framework 4.8:  
###                  https://go.microsoft.com/fwlink/?linkid=2088631
###             See   https://support.microsoft.com/en-us/topic/microsoft-net-framework-4-8-offline-installer-for-windows-9d23f658-3b97-68ab-d013-aa3c3e7495e0
###                   Place in DOTNETFRAMEWORK_4.8
###         Download Skype For Business ISO
###                  https://www.microsoft.com/en-us/evalcenter/download-skype-business-server-2019
###             Open ISO and Extract folders under Skype4BusinessPath such that in the root of Skype4BusinessPath is autorun.inf, and Setup and Support Folders
###         Download Latest Skype For Business Cumulative Update
###             See   https://docs.microsoft.com/en-us/skypeforbusiness/sfb-server-updates
###                   Place in Skype4BusinessCU
###         Download Latest SQL Server 2019 Express Offline
###                  https://download.microsoft.com/download/7/c/1/7c14e92e-bdcb-4f89-b7cf-93543e7112d1/SQLEXPRADV_x64_ENU.exe
###                   Place in Skype4BusinessCU
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
If ($WindowsFeature.count -gt '34') {write-host "Windows Server prerequisites already installed" -ForegroundColor Green}
Else {
      IF ((Test-PendingReboot) -eq $false) {
      write-host "Installing Windows Server Prerequisites" -Foregroundcolor green
######      Install-WindowsFeature RSAT-ADDS, Web-Server, Web-Static-Content, Web-Default-Doc, Web-Http-Errors, Web-Asp-Net, Web-Net-Ext, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Http-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Basic-Auth, Web-Windows-Auth, Web-Client-Auth, Web-Filtering, Web-Stat-Compression, Web-Dyn-Compression, NET-WCF-HTTP-Activation45, Web-Asp-Net45, Web-Mgmt-Tools, Web-Scripting-Tools, Web-Mgmt-Compat, Windows-Identity-Foundation, Server-Media-Foundation, Telnet-Client, BITS, ManagementOData, Web-Mgmt-Console, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service -Source $Windows2019SourcePath
######      Install-WindowsFeature RSAT-ADDS, Web-Server, Web-Static-Content, Web-Default-Doc, Web-Http-Errors, Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Http-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Basic-Auth, Web-Windows-Auth, Web-Client-Auth, Web-Filtering, Web-Stat-Compression, Web-Dyn-Compression, NET-WCF-HTTP-Activation45, Web-Asp-Net45, Web-Mgmt-Tools, Web-Scripting-Tools, Web-Mgmt-Compat, Windows-Identity-Foundation, Server-Media-Foundation, Telnet-Client, BITS, ManagementOData, Web-Mgmt-Console, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, -Source $Windows2019SourcePath
######      Install-WindowsFeature RSAT-ADDS, Web-Server, Web-Static-Content, Web-Default-Doc, Web-Http-Errors, Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Http-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Basic-Auth, Web-Windows-Auth, Web-Client-Auth, Web-Filtering, Web-Stat-Compression, Web-Dyn-Compression, NET-WCF-HTTP-Activation45, Web-Asp-Net45, Web-Mgmt-Tools, Web-Scripting-Tools, Web-Mgmt-Compat, Windows-Identity-Foundation, Server-Media-Foundation, Telnet-Client, BITS, ManagementOData, Web-Mgmt-Console, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, NET-Framework-Features, NET-Framework-Core -Source $Windows2019SourcePath
      Add-WindowsFeature RSAT-ADDS, Web-Server, Web-Static-Content, Web-Default-Doc, Web-Http-Errors, Web-Asp-Net, Web-Net-Ext, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Http-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Basic-Auth, Web-Windows-Auth, Web-Client-Auth, Web-Filtering, Web-Stat-Compression, Web-Dyn-Compression, NET-WCF-HTTP-Activation45, Web-Asp-Net45, Web-Mgmt-Tools, Web-Scripting-Tools, Web-Mgmt-Compat, Windows-Identity-Foundation, Server-Media-Foundation, Telnet-Client, BITS, ManagementOData, Web-Mgmt-Console, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service -Source $Windows2019SourcePath
      }
      Else {
            write-host "Reboot Needed... return script after reboot." -Foregroundcolor red
            exit
           }
     }

$WindowsFeature = Get-WindowsFeature -Name Web* | Where Installed
$dotnetFramework48main = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').version.Substring(0,1)
$dotnetFramework48rev = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').version.Substring(2,1)
If ($dotnetFramework48main -eq '4' -and $dotnetFramework48rev -gt 7) {write-host ".net Framework 4.8 already installed" -ForegroundColor Green}
Else {
      If ($WindowsFeature.count -gt '34') {
         write-host "Installing .net Framework 4.8" -Foregroundcolor green
         start-process $DOTNETFRAMEWORKPath"\ndp48-x86-x64-allos-enu.exe" -Wait -Argumentlist " /q /norestart"
      }
      Else {
            write-host "Windows Components for Skype Not Installed...skipping net Framework 4.8" -Foregroundcolor red
            exit
           }
     }

$BootStrapCore = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Core Components"}
If ($BootStrapCore.count -eq '0') {
      write-host "Installing Skype for Business Server Core" -ForegroundColor Green
      start-process $Skype4BusinessPath"\Setup\amd64\setup.exe" -Wait -Argumentlist "/bootstrapcore"
      }
Else {
      write-host "Skype for Business Server detected, skipping bootstrap core" -Foregroundcolor green
     }

####
####  Check is ADPS Module is installed before proceeding with Schema check, currently not working consistently, will attempt to update ####       schema when get-addomain fails
####
###get-addomain 2>&1 | out-null

$BootStrapCore = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Core Components"}
If ($BootStrapCore.count -eq '1') {
      import-module "C:\Program Files\Common Files\Skype for Business Server 2019\Modules\SkypeForBusiness\SkypeForBusiness.psd1"
      import-module ActiveDirectory 2>&1 | out-null
      $ADPSModule = get-module | ? {$_.Name -eq "ActiveDirectory"}
      IF ($ADPSModule.count -eq '1') {
             $ADOSchemaLocation = 'CN=Schema,CN=Configuration,'+$LDAPDomain
             IF ((get-adobject -SearchBase $ADOSchemaLocation -filter * | Where {$_.DistinguishedName -like "CN=ms-RTC-SIP-SchemaVersion*"}).count -eq 0) {
                 $ADSchemaLocation = 'AD:\CN=Schema,CN=Configuration,'+$LDAPDomain
                 $SkypeSchemaLocation = 'AD:\CN=ms-RTC-SIP-SchemaVersion,CN=Schema,CN=Configuration,'+$LDAPDomain
                 $ADSchema = Get-ItemProperty $SkypeSchemaLocation -Name rangeUpper
                 If ($ADSchema.rangeUpper -lt '1149') {
                     write-host "Extending AD Schema for Skype For Business" -Foregroundcolor green
                     Install-CSAdServerSchema -Confirm:$false
                     write-host "Pausing for Schema replication" -Foregroundcolor green
                     Start-Sleep -seconds 300
                  }
             }
             Else {
                   write-host "Active Directory Schema already extended for Skype For Business 2019" -ForegroundColor Green
                  }
      }
      Else {
            write-host "Active Directory PowerShell not detected, skipping Schema check" -ForegroundColor Red
            exit
           }
      }
Else {
      write-host "Skype for Business Server not detected, skipping schema check" -Foregroundcolor green
      exit
     }

### Prepare Forest
###     TO DO: Check to see if Forest Already Prepared, Group CSAdministrators?
###            Check if member of Enteprise Admins
$BootStrapCore = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Core Components"}
If ($BootStrapCore.count -eq '1' -and ((get-adgroup -identity "CSAdministrator").ObjectClass) -ne "group") {
      write-host "Preparing Forest for Skype For Business" -ForegroundColor Green
      Enable-CSAdForest  -Verbose -Confirm:$false
      #### Enable-CSAdForest  -Verbose -Confirm:$false -Report "C:\Users\otcadmin1.OTC\AppData\Local\Temp\2\Enable-CSAdForest-[2022_07_26][16_10_39].html"
      write-host "Forest Prepared for Skype For Business" -ForegroundColor Green
      Start-Sleep -seconds 300
      }
Else {
      write-host "Skype for Business Server not detected, skipping forest prep" -Foregroundcolor green
     }

### Prepare Domain
###     TO DO: Check to see if Domain Already Prepared
$ADDomainPrep = get-csaddomain
if ($ADDomainPrep -ne "LC_DOMAINSETTINGS_STATE_READY") { 
     write-host "Preparing Domain for Skype For Business" -ForegroundColor Green
     Enable-CSAdDomain -Verbose -Confirm:$false
     write-host "Domain Prepared for Skype For Business" -ForegroundColor Green
     }
Else {
     write-host "Domain already prepared for Skype For Business" -Foregroundcolor green
     }


IF ((get-adgroup -identity "CSAdministrator").ObjectClass -eq "group") {
     ####$whoami = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
     Add-AdGroupMember -identity "CSAdministrator" -members $env:UserName
     write-host $env:UserName "added to CSAdministrator.  Logoff and Logon may be needed before proceeding." -Foregroundcolor red
    }

IF ((get-adgroup -identity "RTCUniversalServerAdmins").ObjectClass -eq "group") {
     $whoami = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
     Add-AdGroupMember -identity "RTCUniversalServerAdmins" -members $env:UserName
     write-host $env:UserName "added to RTCUniversalServerAdmins.  Logoff and Logon may be needed before proceeding." -Foregroundcolor red
    }
###Add to  CSAdministrators and RTCUniversalServerAdmins

####Install Admin Tools
$AdminTools  = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Administrative Tools*"}
If ($AdminTools.count -eq '1') {write-host "Skype for Business Server 2019, Administrative Tools already installed" -ForegroundColor Green}
Else {
      write-host "Installing Skype for Business Server 2019, Administrative Tools" -Foregroundcolor green
      start-process msiexec.exe -Wait -Argumentlist " /i $Skype4BusinessPath\Setup\amd64\Setup\admintools.msi /qn"
     }


Write-Host 'Obtaining New Certificate' -ForegroundColor Green
IF ((get-adgroup -identity "Web Servers").ObjectClass -eq "group") {
     Add-AdGroupMember -identity "Web Servers" -members $env:COMPUTERNAME$
#####     $Certificate = Get-Certificate -Template $CertTemplate -DNSName $ExchangeMailURL -CertStoreLocation cert:\LocalMachine\My
#####     FQDN, dialin, meet, lyncdiscoverinternal, lyncdiscover, sip, subjectname uss-srv-19.uss.local
##### Set-CSCertificate -Type Default,WebServicesInternal,WebServicesExternal -Thumbprint 903EDD552405A9293C1A16ED65F64BA79C6604B3 -Confirm:$false -Report "C:\Users\administrator.USS\AppData\Local\Temp\3\Set-CSCertificate-[2022_08_12][14_05_47].html"
     $Certificate | FL
    }

IF ((get-fileshare | ? {$_.Name -eq $CSShareName}).count -eq "0") {
    write-host "Creating CSShare" -Foregroundcolor green
    [system.io.directory]::CreateDirectory($CSShareNamePath)
    New-SMBShare -Name $CSShareName -Path $CSShareNamePath -FullAccess "Authenticated Users" -CachingMode None
    }


Write-host "Run Prepare First Standard Edition Server" -ForegroundColor Red
Write-host "Run Skype For Business Server Topology Builder and successfully Publish Topology" -ForegroundColor Red
Write-host "Install Local Configuration Store" -ForegroundColor Red
Write-host "Run Setup or Remove Skype For Business Server Component" -ForegroundColor Red

####DNS

###First Skype For Business Server
#### Bootstrap-CsComputer
####  BoostrapSQLExpress
####C:\Users\administrator.USS>"C:\Program Files\Skype for Business Server 2019\Deployment\Bootstrapper.exe" /?
####Usage:
####Install admin console               - Bootstrapper.exe /BootstrapCore
####  Install local management store      - Bootstrapper.exe /BootstrapLocalMgmt
####  Install Admin Tools                 - Bootstrapper.exe /BootstrapAdminTools
####  Install roles specified in topology - Bootstrapper.exe
####  Prepare SQL Express RTC instance    - Bootstrapper.exe /BootstrapSqlExpress
####  Remove roles installed on machine   - Bootstrapper.exe /Scorch
#### Additional parameters:
####  Bypass checks for readiness         - /SkipPrepareCheck
####  Set source directory of MSIs        - /SourceDirectory <directory>


####Log off and back on after RTCUniversalServerAdmins?
####Install-CSDatabase


########Prepare first Standard edition server 
####Bootstrap-CsComputer

#####Install Local Configuration Store
#### Bootstrap-CsComputer
##### ENABLE-CSComputer

####Apply CU

#####   Get-Package where version = 7.0.2046.0
####    /silentmode /forcereboot
#### Reboot
#### Start-CSWindowsService


######  Apply Updates with /quite /noreboot
###### Apply SQL Server 2016 SP3 and 2 hotfixes

########REFERENCE

####$VisualC2012 = Get-Package -Name 'Microsoft Visual C++ 2012 Redistributable (x64)*' 2>&1 | out-null
#####$VisualC2012 = Get-Package -Name 'Microsoft Visual C++ 2012 Redistributable (x64)*'
####$VisualC2012 = Get-Package | where {$_.Name -like "Microsoft Visual C++ 2012 Redistributable (x64)*"}
####If ($VisualC2012.count -eq '1') {write-host "Microsoft Visual C++ 2012 Redistributable (x64) already installed" -ForegroundColor Green}
####Else {
####      write-host "Installing Visual C++ Redistributable for Visual Studio 2012 Update 4" -Foregroundcolor green
####      start-process $ExchangePrereqPath"\vcredist_x64.exe" -Wait -Argumentlist "-silent"
####     }

####$VisualC2013 = Get-Package -Name 'Microsoft Visual C++ 2013 Redistributable (x64)*' 2>&1 | out-null
####$VisualC2013 = Get-Package -Name 'Microsoft Visual C++ 2013 Redistributable (x64)*' 
####$VisualC2013 = Get-Package | ? {$_.Name -like "Microsoft Visual C++ 2013 Redistributable (x64)*"}
####If ($VisualC2013.count -eq '1') {write-host "Microsoft Visual C++ 2013 Redistributable (x64) already installed" -ForegroundColor Green}
####Else {
####      write-host "Installing Visual C++ Redistributable Package for Visual Studio 2013" -Foregroundcolor green
####      start-process $ExchangePrereqPath"\vcredist_x64_2013.exe" -Wait -Argumentlist "-silent"
####     }

####$IISURLRewrite = Get-Package -Name 'IIS URL Rewrite Module*' 2>&1 | out-null
####$IISURLRewrite = Get-Package -Name 'IIS URL Rewrite Module*' 
####$IISURLRewrite = Get-Package | ? {$_.Name -like "IIS URL Rewrite Module*"}
####If ($IISURLRewrite.count -eq '1') {write-host "IIS URL Rewrite Module already installed" -ForegroundColor Green}
####Else {
####      write-host "Installing URL Rewrite Module 2.1" -Foregroundcolor green
####      start-process msiexec.exe -Wait -Argumentlist " /i $ExchangePrereqPath\rewrite_amd64_en-US.msi /qn"
####     }

####$UCManagedAPI = Get-Package -Name 'Microsoft Server Speech Platform Runtime (x64)*' 2>&1 | out-null
####$UCManagedAPI = Get-Package -Name 'Microsoft Server Speech Platform Runtime (x64)*' 
####$UCManagedAPI = Get-Package | ? {$_.Name -like "Microsoft Server Speech Platform Runtime (x64)*"}
####If ($IISURLRewrite.count -eq '1') {write-host "Unified Communications Managed API 4.0 Runtime already installed" -ForegroundColor Green}
####Else {
####      write-host "Installing Unified Communications Managed API 4.0 Runtime" -Foregroundcolor green
####      start-process $ExchangePrereqPath"\UcmaRuntimeSetup.exe" -Wait -Argumentlist "/passive /norestart"
####     }

####$WindowsFeature = Get-WindowsFeature -Name Web* | Where Installed
####If ($WindowsFeature.count -gt '45') {write-host "Windows Server prerequisites already installed" -ForegroundColor Green}
####Else {
####      write-host "Installing Windows Server Prerequisites" -Foregroundcolor green
####      Add-WindowsFeature RSAT-ADDS, Web-Server, Web-Static-Content, Web-Default-Doc, Web-Http-Errors, Web-Asp-Net, Web-Net-Ext, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Http-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Basic-Auth, Web-Windows-Auth, Web-Client-Auth, Web-Filtering, Web-Stat-Compression, Web-Dyn-Compression, NET-WCF-HTTP-Activation45, Web-Asp-Net45, Web-Mgmt-Tools, Web-Scripting-Tools, Web-Mgmt-Compat, Windows-Identity-Foundation, Server-Media-Foundation, Telnet-Client, BITS, ManagementOData, Web-Mgmt-Console, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service
####     }


####
####  Check is ADPS Module is installed before proceeding with Schema check
####
####$ADPSModule = get-module | ? {$_.Name -eq "ActiveDirectory"}
####IF ($ADPSModule.count -eq '1') 
####       {
####       $LDAPDomain = (get-addomain).DistinguishedName
####       $ExchangeSchemaLocation = 'AD:\CN=ms-Exch-Schema-Version-Pt,CN=Schema,CN=Configuration,'+$LDAPDomain
####       $ADSchema = Get-ItemProperty $ExchangeSchemaLocation -Name rangeUpper
####       If ($ADSchema.rangeUpper -gt '16999') {write-host "Active Directory Schema already extended for Exchange 2019" -ForegroundColor Green}
####       Else {
####             write-host "Extending Active Directory Schema" -Foregroundcolor green
####             start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /ps"
####             write-host "Pausing for Schema replication" -Foregroundcolor green
####             Start-Sleep -seconds 300
####            }
####       }

####$ADExchangePrepped = "AD:\CN=Microsoft Exchange System Objects," + $LDAPDomain
####$ADExchangePreppedobjversion = Get-ItemProperty $ADExchangePrepped -Name objectVersion
####If ($ADExchangePreppedobjversion.objectVersion -gt '13230') {write-host "Active Directory already Prepared for Exchange 2019" -ForegroundColor Green}
####Else {
####      write-host "Preparing Active Directory" -Foregroundcolor green
####      start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /PrepareAD       /OrganizationName:$ExchangeOrgName"
####      write-host "Pausing for Active Directory replication" -Foregroundcolor green
####      Start-Sleep -seconds 300
####     }

####$Exchange = Get-Package -Name 'Microsoft Exchange Server' 2>&1 | out-null
####$Exchange = Get-Package -Name 'Microsoft Exchange Server' 
####$Exchange = Get-Package  | ? {$_.Name -like "Microsoft Exchange Server"}
####If ($Exchange.count -eq '1') {write-host "Microsoft Exchange Server already installed" -ForegroundColor Green}
####Else {
####      write-host "Installing Exchange 2019" -Foregroundcolor green
####      start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /TargetDir:$TargetExchangePath /CustomerFeedbackEnabled:False /Mode:install /Roles:mb"
####     }

####$TargetExchangePath = 'E:\Program,Files\Microsoft\Exchange,Server\v15'
#####Fix for first bad servers

####$TargetExchangePSPath = $TargetExchangePath + "\bin\RemoteExchange.ps1"
####Write-Host $TargetExchangePSPath 
####Import-Module $TargetExchangePSPath
####Connect-ExchangeServer -auto -ClientApplication:ManagementShell
####
####Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn
####Connect-ExchangeServer -auto -ClientApplication:ManagementShell
####get-mailbox
####Obtain Certificate
####Get-OwaVirtualDirectory
####Get-EcpVirtualDirectory
####Get-ActiveSyncVirtualDirectory
####Get-OabVirtualDirectory
####Get-WebServicesVirtualDirectory
####Get-OutlookAnywhere
####Get-PowerShellVirtualDirectory
####Get-ClientAccessService
####Get-MapiVirtualDirectory
###################################################################################################
Stop-Transcript

######################################### REBOOT SERVER ###########################################
