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
$ScriptName = Split-Path $MyInvocation.MyCommand.Path -Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$DTG = Get-Date -Format yyyyMMddTHHmm
$RootDir = Split-Path $ScriptDir -Parent
$ConfigFile = "$RootDir\config.xml"

Start-Transcript -Path "$RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log"
Start-Transcript -Path "$env:WINDIR\Temp\$env:COMPUTERNAME-$DTG-$ScriptName.log"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) {Throw "ERROR: Unable to locate $ConfigFile Exiting..."}
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$DomainDnsName = ($WS | ? {($_.Name -eq "DomainDnsName")}).Value
$Windows2019SourcePath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\W2019\sources\sxs"
$DOTNETFRAMEWORKPath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\DOTNETFRAMEWORK_4.8"
$Skype4BusinessPath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\SkypeForBusiness\OCS_Eval"
$SkypeForBusiness = ($XML.Component | ? {($_.Name -eq "SkypeForBusiness")}).Settings.Configuration
$SkypeForBusinessCUPath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\Skype4BusinessCU"
$SQLServer2019Path = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\SQLServer2019"
$CSShareName = ($SkypeForBusiness | ? {($_.Name -eq "CSShareName")}).Value
$CSShareNamePath = ($SkypeForBusiness | ? {($_.Name -eq "CSShareNamePath")}).Value
$LDAPDomain = ($WS | ? {($_.Name -eq "DomainDistinguishedName")}).Value
$CertTemplate = ($WS | ? {($_.Name -eq "DomainName")}).Value + "WebServer"

###################################################################################################
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
###                   Place in SQLServer2019
###         Download Latest SQL Server 2019 Cumulative Update
###                  https://XXXXXX
###                   Place in SQLServer2019
###------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
clear-host

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

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Check pending reboot
If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}


$BootStrapCore = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Core Components"}
If ($BootStrapCore.count -eq '0') 
{
    write-host "Installing Skype for Business Server Core" -ForegroundColor Green
    start-process $Skype4BusinessPath"\Setup\amd64\setup.exe" -Wait -Argumentlist "/bootstrapcore"
}
Else 
{
    write-host "Skype for Business Server detected, skipping bootstrap core" -Foregroundcolor green
}

####
####  Check is ADPS Module is installed before proceeding with Schema check, currently not working consistently, will attempt to update ####       schema when get-addomain fails
####
$BootStrapCore = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Core Components"}
If ($BootStrapCore.count -eq '1') 
{
    import-module "C:\Program Files\Common Files\Skype for Business Server 2019\Modules\SkypeForBusiness\SkypeForBusiness.psd1"
    import-module ActiveDirectory 2>&1 | out-null
    $ADPSModule = get-module | ? {$_.Name -eq "ActiveDirectory"}
    If ($ADPSModule.count -eq '1') 
    {
        $ADOSchemaLocation = 'CN=Schema,CN=Configuration,'+$LDAPDomain
        If ((get-adobject -SearchBase $ADOSchemaLocation -filter * | Where {$_.DistinguishedName -like "CN=ms-RTC-SIP-SchemaVersion*"}).count -eq 0) 
        {
            $ADSchemaLocation = 'AD:\CN=Schema,CN=Configuration,'+$LDAPDomain
            $SkypeSchemaLocation = 'AD:\CN=ms-RTC-SIP-SchemaVersion,CN=Schema,CN=Configuration,'+$LDAPDomain
            $ADSchema = Get-ItemProperty $SkypeSchemaLocation -Name rangeUpper
            If ($ADSchema.rangeUpper -lt '1149') 
            {
                write-host "Extending AD Schema for Skype For Business" -Foregroundcolor green
                Install-CSAdServerSchema -Confirm:$false
                write-host "Pausing for Schema replication" -Foregroundcolor green
                Start-Sleep -seconds 300
            }
        }
        Else 
        {
            write-host "Active Directory Schema already extended for Skype For Business 2019" -ForegroundColor Green
        }
    }
    Else 
    {
        write-host "Active Directory PowerShell not detected, skipping Schema check" -ForegroundColor Red
        exit
    }
}
Else 
{
    write-host "Skype for Business Server not detected, skipping schema check" -Foregroundcolor green
    exit
}

### Prepare Forest
###     TO DO: Check to see if Forest Already Prepared, Group CSAdministrators?
###            Check if member of Enteprise Admins
$CSAdminsobj = Get-ADGroup -LDAPFilter "(SAMAccountName=CSAdministrator)"
$BootStrapCore = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Core Components"}
If ($BootStrapCore.count -eq '1') 
{
    If ($CSAdminsobj -eq $null)
    {
        write-host "Preparing Forest for Skype For Business." -ForegroundColor Green
        Enable-CSAdForest  -Verbose -Confirm:$false
        write-host "Forest Prepared for Skype For Business." -ForegroundColor Green
        write-host "Pausing for Forest Prep replication." -Foregroundcolor green
        Start-Sleep -seconds 300
    }
    Else 
    {
        write-host "Forest Already Prepared for Skype For Business 2019." -ForegroundColor Green
    }
}
Else 
{
    write-host "Skype for Business Server not detected, skipping forest prep." -Foregroundcolor green
}

### Prepare Domain
$ADDomainPrep = get-csaddomain
If ($ADDomainPrep -ne "LC_DOMAINSETTINGS_STATE_READY") 
{ 
    write-host "Preparing Domain for Skype For Business." -ForegroundColor Green
    Enable-CSAdDomain -Verbose -Confirm:$false
    write-host "Domain Prepared for Skype For Business." -ForegroundColor Green
}
Else 
{
    write-host "Domain already prepared for Skype For Business." -Foregroundcolor green
}

###Add to  CSAdministrators and RTCUniversalServerAdmins
If ($CSAdminsobj -ne $null) 
{
    $CSAdminsMembers = Get-ADGroupMember -Identity CSAdministrator -Recursive | Select -ExpandProperty Name
    If ($CSAdminsMembers -contains $env:UserName)
    {
        write-host $env:UserName "already in CSAdministrator Group." -Foregroundcolor green
    }
    Else 
    {
        Add-AdGroupMember -identity "CSAdministrator" -members $env:UserName
        write-host $env:UserName "added to CSAdministrator.  Logoff and Logon may be needed before proceeding." -Foregroundcolor red
    }
}


$RTCUniversalServerAdminsobj = Get-ADGroup -LDAPFilter "(SAMAccountName=RTCUniversalServerAdmins)"
If ($RTCUniversalServerAdminsobj -ne $null) 
{
    $RTCUniversalServerAdminsMembers = Get-ADGroupMember -Identity RTCUniversalServerAdmins -Recursive | Select -ExpandProperty Name
    If ($RTCUniversalServerAdminsMembers -contains $env:UserName) 
    {
        write-host $env:UserName "already in RTCUniversalServerAdmins Group." -Foregroundcolor green
    }
    Else 
    {
        Add-AdGroupMember -identity "RTCUniversalServerAdmins" -members $env:UserName
        write-host $env:UserName "added to RTCUniversalServerAdmins.  Logoff and Logon may be needed before proceeding." -Foregroundcolor red
    }
}

####Install Admin Tools
$AdminTools  = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Administrative Tools*"}
If ($AdminTools.count -eq '1') 
{
    write-host "Skype for Business Server 2019, Administrative Tools already installed." -ForegroundColor Green
}
Else 
{
    write-host "Installing Skype for Business Server 2019, Administrative Tools" -Foregroundcolor green
    start-process msiexec.exe -Wait -Argumentlist " /i $Skype4BusinessPath\Setup\amd64\Setup\admintools.msi /qn"
}

IF ((get-fileshare | ? {$_.Name -eq $CSShareName}).count -eq "0") 
{
    write-host "Creating CSShare" -Foregroundcolor green
    [system.io.directory]::CreateDirectory($CSShareNamePath)
    New-SMBShare -Name $CSShareName -Path $CSShareNamePath -FullAccess "Authenticated Users" -CachingMode None
}
Else 
{
    Write-host "CSShare already exists." -ForegroundColor Green
}

If ((get-service | Where {$_.Name -eq 'MSSQL$RTC'}).count -eq 0) 
{
    Write-host "Creating CMS Database." -ForegroundColor Green
    start-process "C:\Program Files\Skype for Business Server 2019\Deployment\Bootstrapper.exe" -Wait -Argumentlist " /BootstrapSQLExpress"
    start-process "netsh" -Wait -Argumentlist ' advfirewall firewall add rule name="SQL Browser" dir=in action=allow protocol=UDP localport=1434'
}
Else 
{
    Write-host "CMS Database already exists." -ForegroundColor Green
}

If ((get-service | Where {$_.Name -eq 'MSSQL$RTCLOCAL'}).count -eq 0) 
{
    Write-host "Creating Local Configuration Store." -ForegroundColor Green
    start-process "netsh" -Wait -Argumentlist ' advfirewall firewall add rule name="SQL Browser" dir=in action=allow protocol=UDP localport=1434'
    start-process "C:\Program Files\Skype for Business Server 2019\Deployment\Bootstrapper.exe" -Wait -Argumentlist " /BootstrapLocalMgmt"
    Write-host "Local Configuration Store created.  Importing Configuration into Local Store." -ForegroundColor Green
    $CSConfiguration = Export-CsConfiguration -AsBytes
    Import-CsConfiguration -ByteInput $CSConfiguration -LocalStore
    Write-host "Enabling Replica." -ForegroundColor Green
    Enable-CSReplica -force
    Write-host "Replica enabled.  Installing Skype For Business Roles" -ForegroundColor Green
    ###### Replicate-CsCmsCertificates
    start-process "C:\Program Files\Skype for Business Server 2019\Deployment\Bootstrapper.exe" -Wait
}
Else 
{
    Write-host "Local Configuration Store already exists." -ForegroundColor Green
}

Write-Host 'Obtaining New Certificate' -ForegroundColor Green
If ((get-adgroup -identity "Web Servers").ObjectClass -eq "group") 
{
    Add-AdGroupMember -identity "Web Servers" -members $env:COMPUTERNAME$
    $SkypeFQDN = ([System.Net.DNS]::GetHostByName($env:computerName)).hostname
    $Certificate = Get-Certificate -Template $CertTemplate -DNSName $SkypeFQDN,dialin.$DomainDnsName,meet.$DomainDnsName,lyncdiscoverinternal.$DomainDnsName,lyncdiscover.$DomainDnsName,sip.$DomainDnsName -CertStoreLocation cert:\LocalMachine\My -subjectname cn=$SkypeFQDN
    Set-CSCertificate -Type Default,WebServicesInternal,WebServicesExternal -Thumbprint $Certificate.certificate.thumbprint -Confirm:$false
    $Certificate | FL
}

If ((get-package | where {($_.Name -like "Skype for Business*") -and ($_.Version -eq "7.0.2046.0")}).count -gt '9') 
{
    write-host "Applying Skype for Business Server Cumulative Update." -ForegroundColor Green
    start-process $SkypeForBusinessCUPath"\SkypeServerUpdateInstaller" -Wait -Argumentlist "/silentmode"
    Stop-CsWindowsService
    start-process "net " -Wait -Argumentlist " stop w3svc"
    Install-CsDatabase -Update -LocalDatabases
}
Else 
{
    write-host "Skype for Business not installed or Skype for Business Cumulative Updates already Applied." -Foregroundcolor green
}

If ((get-service | ? {$_.Name -like 'MSSQL*'}).count -eq 3) 
{
    If ((Test-PendingReboot) -eq $false)
    {
        write-host "Checking SQL Server Version on RTC." -ForegroundColor Green
        If ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL").RTC -eq "MSSQL13.RTC")
        {
            write-host "Upgrading RTC SQL Server instance to SQL Server 2019." -Foregroundcolor green
            Stop-CsWindowsService
            start-process "net " -Wait -Argumentlist " stop w3svc"
            Start-Sleep -seconds 300
            ####start-process $SQLServer2019Path"\SQLEXPRADV_x64_ENU.exe" -Wait -Argumentlist " /qs /ACTION=Upgrade /IACCEPTSQLSERVERLICENSETERMS /INSTANCENAME=RTC /HIDECONSOLE /ERRORREPORTING=0 /UpdateEnabled=0"
            start-process $SQLServer2019Path"\SQLEXPRADV_x64_ENU.exe" -Wait -Argumentlist " /qs /ACTION=Upgrade /IACCEPTSQLSERVERLICENSETERMS /INSTANCENAME=RTC /HIDECONSOLE /ERRORREPORTING=0 /UpdateEnabled=1 /UpdateSource=$SQLServer2019Path"
        }
        Else 
        {
            write-host "RTC SQL Server instance is SQL Server 2019." -Foregroundcolor green
        }
        
        write-host "Checking SQL Server Version on RTCLOCAL." -ForegroundColor Green
        If ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL").RTCLOCAL -eq "MSSQL13.RTCLOCAL")
        {
            write-host "Upgrading RTCLOCAL SQL Server instance to SQL Server 2019." -Foregroundcolor green
            Stop-CsWindowsService
            start-process "net " -Wait -Argumentlist " stop w3svc"
            Start-Sleep -seconds 300
            ####start-process $SQLServer2019Path"\SQLEXPRADV_x64_ENU.exe" -Wait -Argumentlist " /qs /ACTION=Upgrade /IACCEPTSQLSERVERLICENSETERMS /INSTANCENAME=RTCLOCAL /HIDECONSOLE /ERRORREPORTING=0 /UpdateEnabled=0"
            start-process $SQLServer2019Path"\SQLEXPRADV_x64_ENU.exe" -Wait -Argumentlist " /qs /ACTION=Upgrade /IACCEPTSQLSERVERLICENSETERMS /INSTANCENAME=RTCLOCAL /HIDECONSOLE /ERRORREPORTING=0 /UpdateEnabled=1 /UpdateSource=$SQLServer2019Path"
        }
        Else 
        {
            write-host "RTCLOCAL SQL Server instance is SQL Server 2019." -Foregroundcolor green
        }
        
        write-host "Checking SQL Server Version on LYNCLOCAL." -ForegroundColor Green
        If ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL").LYNCLOCAL -eq "MSSQL13.LYNCLOCAL")
        {
            write-host "Upgrading LYNCLOCAL SQL Server instance to SQL Server 2019." -Foregroundcolor green
            Stop-CsWindowsService
            start-process "net " -Wait -Argumentlist " stop w3svc"
            Start-Sleep -seconds 300
            ####start-process $SQLServer2019Path"\SQLEXPRADV_x64_ENU.exe" -Wait -Argumentlist " /qs /ACTION=Upgrade /IACCEPTSQLSERVERLICENSETERMS /INSTANCENAME=LYNCLOCAL /HIDECONSOLE /ERRORREPORTING=0 /UpdateEnabled=0"
            start-process $SQLServer2019Path"\SQLEXPRADV_x64_ENU.exe" -Wait -Argumentlist " /qs /ACTION=Upgrade /IACCEPTSQLSERVERLICENSETERMS /INSTANCENAME=LYNCLOCAL /HIDECONSOLE /ERRORREPORTING=0 /UpdateEnabled=1 /UpdateSource=$SQLServer2019Path"
        }
        Else 
        {
            write-host "RTC SQL Server instance is SQL Server 2019." -Foregroundcolor green
        }
    }
    Else 
    {
        write-host "Reboot Needed before SQL Server Updates can be performed." -Foregroundcolor red
    }
}
Else 
{
    write-host "3 SQL Server Instanaces not present or reboot needed." -Foregroundcolor green
}


###################################################################################################
#### DNS Entries
####       Need to get IP address and name from variables
write-host 'Checking DNS for' meet.$DomainDnsName -ForegroundColor Green

$dnsresolve = resolve-dnsname meet.$DomainDnsName 2>&1 | out-null

IF ($dnsresolve.count -eq 0)
{
    Import-Module DNSServer
    $dotDomainDNSName = "." + $DomainDNSName
    $addomaincontroller = (get-addomaincontroller).name
    $SkypeFQDN = ([System.Net.DNS]::GetHostByName($env:computerName)).hostname
    $DNSZone = get-dnsserverzone -computername $addomaincontroller -name $DomainDNSName
    Add-DnsServerResourceRecord -cname -Computername $addomaincontroller -ZoneName $DNSZone.ZoneName -name dialin -HostNameAlias $SkypeFQDN -TimeToLive 00:05:00
    Add-DnsServerResourceRecord -cname -Computername $addomaincontroller -ZoneName $DNSZone.ZoneName -name meet -HostNameAlias $SkypeFQDN -TimeToLive 00:05:00
    Add-DnsServerResourceRecord -cname -Computername $addomaincontroller -ZoneName $DNSZone.ZoneName -name lyncdiscoverinternal -HostNameAlias $SkypeFQDN -TimeToLive 00:05:00
    Add-DnsServerResourceRecord -cname -Computername $addomaincontroller -ZoneName $DNSZone.ZoneName -name lyncdiscover -HostNameAlias $SkypeFQDN -TimeToLive 00:05:00
    Add-DnsServerResourceRecord -cname -Computername $addomaincontroller -ZoneName $DNSZone.ZoneName -name sip -HostNameAlias $SkypeFQDN -TimeToLive 00:05:00
    Add-DnsServerResourceRecord -Srv -Name "_sipinternaltls._tcp" -ZoneName $DNSZone.ZoneName -DomainName $DomainDnsName -Priority 0 -Weight 0 -Port 5060 -TimeToLive 00:05:00
}

###################################################################################################
Stop-Transcript

######################################### REBOOT SERVER ###########################################
