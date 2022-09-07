<#
NAME
    USS-EXCHG-CONFIG-3.ps1

SYNOPSIS
    Installs Exchange Server 2019 in the AD domain

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
If (!(Test-Path -Path $ConfigFile)) {Throw "ERROR: Unable to locate $ConfigFile Exiting..."}
$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$Exchange = ($XML.Component | ? {($_.Name -eq "Exchange")}).Settings.Configuration
$TargetExchangePath = ($Exchange | ? {($_.Name -eq "TargetExchangePath")}).Value
$ExchangeOrgName = ($Exchange | ? {($_.Name -eq "ExchangeOrgName")}).Value
$ExchangeMailURL = ($Exchange | ? {($_.Name -eq "ExchangeMailURL")}).Value
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value 
$DomainDnsName = ($WS | ? {($_.Name -eq "DomainDnsName")}).Value 
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

Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\$ScriptName.log
Start-Transcript -Path $RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log

Import-Module ActiveDirectory
$LDAPDomain = (Get-ADRootDSE).defaultNamingContext
$DC = (Get-ADDomainController -Filter * | Select-Object Name | Sort-Object Name | Select-Object -First 1).Name

###------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
###
###    Alvin Chen
###    Install Exchange 2019
###    Prerequisites, a file share, AD joined, IP addressed, Schema Admins, Enterprise Admins, Exchange Drive, all variables above set, 
###         DNS name resolution for ExchangeMailURL
###
###    Prerequisties as of 7/15/2022
###         https://docs.microsoft.com/en-us/exchange/plan-and-deploy/prerequisites?view=exchserver-2019
###
###     Known post steps as of 8/10/2022
###         Add product key Set-ExchangeServer <ServerName> -ProductKey <ProductKey>
###------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
clear-host

# =============================================================================
# FUNCTIONS
# =============================================================================

Function Check-Role()
{
   param (
    [Parameter(Mandatory=$false, HelpMessage = "Enter what role you want to check for. Default check is for 'Administrator'")]
    [System.Security.Principal.WindowsBuiltInRole]$role = [System.Security.Principal.WindowsBuiltInRole]::Administrator
   )

    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object 'System.Security.Principal.WindowsPrincipal' $windowsIdentity

    return $windowsPrincipal.IsInRole($role)
}

Function Test-ADObject ($DN)
{
    Write-Host "Checking existence of $DN"
    Try 
    {
        Get-ADObject "$DN"
        Write-Host "True"
    }
    Catch 
    {
        $null
        Write-Host "False"
    }
}

Function Get-ADSchemaObjects
{
    # Exchange Schema Version
    $sc = (Get-ADRootDSE).SchemaNamingContext
    $ob = "CN=ms-Exch-Schema-Version-Pt," + $sc
    Write-Output "RangeUpper: $((Get-ADObject $ob -pr rangeUpper).rangeUpper)"

    # Exchange Object Version (domain)
    $dc = (Get-ADRootDSE).DefaultNamingContext
    $ob = "CN=Microsoft Exchange System Objects," + $dc
    Write-Output "ObjectVersion (Default): $((Get-ADObject $ob -pr objectVersion).objectVersion)"

    # Exchange Object Version (forest)
    $cc = (Get-ADRootDSE).ConfigurationNamingContext
    $fl = "(objectClass=msExchOrganizationContainer)"
    Write-Output "ObjectVersion (Configuration): $((Get-ADObject -LDAPFilter $fl -SearchBase $cc -pr objectVersion).objectVersion)"
}

Function Set-XADSchema
{
    Write-Verbose "----- Entering Set-XADSchema function -----"
    
    $ADOSchemaLocation = 'CN=Schema,CN=Configuration,'+$LDAPDomain
    If ((get-adobject -SearchBase $ADOSchemaLocation -filter * | Where {$_.DistinguishedName -like "CN=ms-exch-schema*"}).count -eq 0) {
        write-host "Extending Active Directory Schema" -Foregroundcolor green
        start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /ps"
        write-host "Pausing for Schema replication" -Foregroundcolor green
        Start-Sleep -seconds 300
    }
    Else {
        $ADSchemaLocation = 'AD:\CN=Schema,CN=Configuration,'+$LDAPDomain
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
}

Function Set-XADPrep
{
    Write-Verbose "----- Entering Set-XADPrep function -----"
    
    $ADOSchemaLocation = 'CN=Schema,CN=Configuration,'+$LDAPDomain
    If ((get-adobject -SearchBase $ADOSchemaLocation -filter * | Where {$_.DistinguishedName -like "CN=ms-exch-schema*"}).count -eq 0) 
    {
        $ADSchemaLocation = 'AD:\CN=Schema,CN=Configuration,'+$LDAPDomain
        $ExchangeSchemaLocation = 'AD:\CN=ms-Exch-Schema-Version-Pt,CN=Schema,CN=Configuration,'+$LDAPDomain
        $ADSchema = Get-ItemProperty $ExchangeSchemaLocation -Name rangeUpper
        If ($ADSchema.rangeUpper -lt '16999') 
        {
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

Function Test-PendingReboot
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

# Ensure script is run elevated
If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

# Extend schema
Set-XADSchema

# Prepare AD
Set-XADPrep

# Install Exchange

$Exchange = Get-Package  | ? {$_.Name -like "Microsoft Exchange Server"}
If ($Exchange.count -eq '0' -and (Test-PendingReboot) -eq $false) {
     write-host "Installing Exchange 2019" -Foregroundcolor green
     start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /TargetDir:$TargetExchangePath /CustomerFeedbackEnabled:False /Mode:install /Roles:mb /OrganizationName:$ExchangeOrgName"
     }
Else {
     write-host "Microsoft Exchange Server already installed or reboot needed" -ForegroundColor Green
     }

$Exchange = Get-Package | ? {$_.Name -like "Microsoft Exchange Server*"}
If ($Exchange.count -gt '0') {
     write-host "Checking for Exchange" -ForegroundColor Green
     
     if ((get-module | ? {$_.Name -eq "RemoteExchange"}).count -eq 0) {
          write-host "Starting Exchange Management Shell" -ForegroundColor Green
          $TargetExchangePSPath = $TargetExchangePath + "\bin\RemoteExchange.ps1"
          Import-Module $TargetExchangePSPath
          Connect-ExchangeServer -auto -ClientApplication:ManagementShell
     }
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
     ###### CHECK if there is a cert with the ExchangeURL?
     ######
     Write-Host 'Obtaining New Certificate' -ForegroundColor Green
     IF ((get-adgroup -identity "Web Servers").ObjectClass -eq "group") {
          Add-AdGroupMember -identity "Web Servers" -members $env:COMPUTERNAME$
          $Certificate = Get-Certificate -Template $CertTemplate -DNSName $ExchangeMailURL -CertStoreLocation cert:\LocalMachine\My
          $Certificate | FL
          Write-Host 'Binding Certificate to Exchange Services' -ForegroundColor Green
          Enable-ExchangeCertificate -thumbprint $Certificate.certificate.thumbprint -Services IIS,POP,IMAP,SMTP -confirm:$false -force
          Get-ExchangeCertificate
          }
     }
Else {
      write-host "Exchange Not Installed" -Foregroundcolor green
     }

write-host 'Checking DNS for' $ExchangeMailURL -ForegroundColor Green
$dnsresolve = resolve-dnsname $ExchangeMailURL 2>&1 | out-null

IF ($dnsresolve.count -lt 1) {
      Import-Module DNSServer
      $dotDomainDNSName = "." + $DomainDNSName
      $ExchangeCNAME = $ExchangeMailURL -replace $dotDomainDNSName,""
      $addomaincontroller = (get-addomaincontroller).name
      $ExchangeFQDN = ([System.Net.DNS]::GetHostByName($env:computerName)).hostname
      $DNSZone = get-dnsserverzone -computername $addomaincontroller -name $DomainDNSName
      Add-DnsServerResourceRecord -cname -Computername $addomaincontroller -ZoneName $DNSZone.ZoneName -name $ExchangeCNAME -HostNameAlias $ExchangeFQDN -TimeToLive 00:05:00
      write-host 'Creating DNS for' $ExchangeMailURL -ForegroundColor Green
      }

Stop-Transcript

######################################### REBOOT SERVER ###########################################
