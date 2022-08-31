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
$ScriptName = Split-Path $MyInvocation.MyCommand.Path –Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path –Parent
$RootDir = Split-Path $ScriptDir –Parent
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
$SkypeForBusinessCUPath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\Skype4BusinessCU"
$SQLServer2019Path = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\SQLServer2019"
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

###### Must be separated because Web-Asp-Net, Web-Net-Ext cannot install until after .net Framework 4.8 is installed, server rebooted otherwise get DISMAPI_Error__Failed_To_Enable_Updates,Microsoft.Windows.ServerManager.Commands.AddWindowsFeatureCommand

$WindowsFeature = Get-WindowsFeature -Name Web* | Where Installed
If ($WindowsFeature.count -gt '35') {
   write-host "Windows Server prerequisites already installed" -ForegroundColor Green
   }
   Else {
         IF ((Test-PendingReboot) -eq $false) {
            IF ((Get-ChildItem -Path $Windows2019SourcePath).count -gt 1) {
                write-host "Installing Windows Server Prerequisites" -Foregroundcolor green
                start-process "dism.exe" -Wait -Argumentlist " /Online /Enable-Feature /FeatureName:netFX3 /All /LimitAccess /source:$Windows2019SourcePath"
                Add-WindowsFeature RSAT-ADDS, Web-Server, Web-Static-Content, Web-Default-Doc, Web-Http-Errors, Web-Asp-Net, Web-Net-Ext, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Http-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Basic-Auth, Web-Windows-Auth, Web-Client-Auth, Web-Filtering, Web-Stat-Compression, Web-Dyn-Compression, NET-WCF-HTTP-Activation45, Web-Asp-Net45, Web-Mgmt-Tools, Web-Scripting-Tools, Web-Mgmt-Compat, Windows-Identity-Foundation, Server-Media-Foundation, Telnet-Client, BITS, ManagementOData, Web-Mgmt-Console, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service -Source $Windows2019SourcePath
                }
                Else {
                      write-host ".net Framework SXS not found." -Foregroundcolor red
                      exit
                     }
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
$CSAdminsobj = Get-ADGroup -LDAPFilter "(SAMAccountName=CSAdministrator)"
$BootStrapCore = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Core Components"}
If ($BootStrapCore.count -eq '1') {
      IF ($CSAdminsobj -eq $null){
            write-host "Preparing Forest for Skype For Business." -ForegroundColor Green
            Enable-CSAdForest  -Verbose -Confirm:$false
            write-host "Forest Prepared for Skype For Business." -ForegroundColor Green
            write-host "Pausing for Forest Prep replication." -Foregroundcolor green
            Start-Sleep -seconds 300
      }
      ELSE {
            write-host "Forest Already Prepared for Skype For Business 2019." -ForegroundColor Green
            }
      }
Else {
      write-host "Skype for Business Server not detected, skipping forest prep." -Foregroundcolor green
     }

### Prepare Domain
$ADDomainPrep = get-csaddomain
if ($ADDomainPrep -ne "LC_DOMAINSETTINGS_STATE_READY") { 
     write-host "Preparing Domain for Skype For Business." -ForegroundColor Green
     Enable-CSAdDomain -Verbose -Confirm:$false
     write-host "Domain Prepared for Skype For Business." -ForegroundColor Green
     }
Else {
     write-host "Domain already prepared for Skype For Business." -Foregroundcolor green
     }

###Add to  CSAdministrators and RTCUniversalServerAdmins
IF ($CSAdminsobj -ne $null) {
     $CSAdminsMembers = Get-ADGroupMember -Identity CSAdministrator -Recursive | Select -ExpandProperty Name
     IF ($CSAdminsMembers -contains $env:UserName){
         write-host $env:UserName "already in CSAdministrator Group." -Foregroundcolor green
     }
     ELSE {
          Add-AdGroupMember -identity "CSAdministrator" -members $env:UserName
          write-host $env:UserName "added to CSAdministrator.  Logoff and Logon may be needed before proceeding." -Foregroundcolor red
          }
     }


$RTCUniversalServerAdminsobj = Get-ADGroup -LDAPFilter "(SAMAccountName=RTCUniversalServerAdmins)"
IF ($RTCUniversalServerAdminsobj -ne $null) {
     $RTCUniversalServerAdminsMembers = Get-ADGroupMember -Identity RTCUniversalServerAdmins -Recursive | Select -ExpandProperty Name
     IF ($RTCUniversalServerAdminsMembers -contains $env:UserName){
         write-host $env:UserName "already in RTCUniversalServerAdmins Group." -Foregroundcolor green
     }
     ELSE {
          Add-AdGroupMember -identity "RTCUniversalServerAdmins" -members $env:UserName
          write-host $env:UserName "added to RTCUniversalServerAdmins.  Logoff and Logon may be needed before proceeding." -Foregroundcolor red
          }
    }
####Install Admin Tools
$AdminTools  = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Administrative Tools*"}
If ($AdminTools.count -eq '1') {write-host "Skype for Business Server 2019, Administrative Tools already installed." -ForegroundColor Green}
Else {
      write-host "Installing Skype for Business Server 2019, Administrative Tools" -Foregroundcolor green
      start-process msiexec.exe -Wait -Argumentlist " /i $Skype4BusinessPath\Setup\amd64\Setup\admintools.msi /qn"
     }

IF ((get-fileshare | ? {$_.Name -eq $CSShareName}).count -eq "0") {
    write-host "Creating CSShare" -Foregroundcolor green
    [system.io.directory]::CreateDirectory($CSShareNamePath)
    New-SMBShare -Name $CSShareName -Path $CSShareNamePath -FullAccess "Authenticated Users" -CachingMode None
    }
ELSE {
     Write-host "CSShare already exists." -ForegroundColor Green
}

IF ((get-service | Where {$_.Name -eq 'MSSQL$RTC'}).count -eq 0) {
     Write-host "Creating CMS Database." -ForegroundColor Green
     start-process "C:\Program Files\Skype for Business Server 2019\Deployment\Bootstrapper.exe" -Wait -Argumentlist " /BootstrapSQLExpress"
     start-process "netsh" -Wait -Argumentlist ' advfirewall firewall add rule name="SQL Browser" dir=in action=allow protocol=UDP localport=1434'
     }
ELSE {
     Write-host "CMS Database already exists." -ForegroundColor Green
}

Write-host "Run Skype For Business Server Topology Builder, build new topology and successfully publish." -ForegroundColor Red
###################################################################################################
Stop-Transcript
exit
######################################### REBOOT SERVER ###########################################
