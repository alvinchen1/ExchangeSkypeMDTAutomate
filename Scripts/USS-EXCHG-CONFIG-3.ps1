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
$Exchange = ($XML.Component | ? {($_.Name -eq "Exchange")}).Settings.Configuration
$TargetExchangePath = ($Exchange | ? {($_.Name -eq "TargetExchangePath")}).Value
$ExchangeOrgName = ($Exchange | ? {($_.Name -eq "ExchangeOrgName")}).Value
$ExchangeMailURL = ($Exchange | ? {($_.Name -eq "ExchangeMailURL")}).Value
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$DomainName = ($WS | ? {($_.Name -eq "DomainName")}).Value
$DomainDnsName = ($WS | ? {($_.Name -eq "DomainDnsName")}).Value 
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value
$ExchangePath = ($WS | ? {($_.Name -eq "InstallShare")}).Value + "\Exchange"
$CertTemplate = "$DomainName Web Server"
$OWAVirtualDirectory = "https://" + $ExchangeMailURL + "/owa"
$ECPVirtualDirectory = "https://" + $ExchangeMailURL + "/ecp"
$OABVirtualDirectory = "https://" + $ExchangeMailURL + "/OAB"
$MAPIVirtualDirectory = "https://" + $ExchangeMailURL + "/mapi"
$ActiveSyncVirtualDirectory = "https://" + $ExchangeMailURL + "/Microsoft-Server-ActiveSync"
$WebServicesVirtualDirectory = "https://" + $ExchangeMailURL + "/EWS/Exchange.asmx"
$GPOZipFileExch = "$InstallShare\Import-GPOs\Exchange.zip"
$LocalDir = "C:\temp\ExchGPO\$DTG"

Import-Module ActiveDirectory
$LDAPDomain = (Get-ADRootDSE).defaultNamingContext

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

Function Set-XADSchema
{
    Write-Verbose "----- Entering Set-XADSchema function -----"
    
    If (!(Test-ADObject ("CN=ms-Exch-Schema-Version-Pt,CN=Schema,CN=Configuration,$LDAPDomain"))) 
    {
        Write-Host "Extending Active Directory Schema" -Foregroundcolor green
        Test-FilePath ("$ExchangePath\setup.exe")
        start-process "$ExchangePath\setup.exe" -Wait -NoNewWindow -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /ps"
        Write-Host "Pausing for Schema replication" -Foregroundcolor green
        Start-Sleep -seconds 300
    }
    Else 
    {
        $ExchangeSchemaLocation = 'AD:\CN=ms-Exch-Schema-Version-Pt,CN=Schema,CN=Configuration,'+$LDAPDomain
        $ADSchema = Get-ItemProperty $ExchangeSchemaLocation -Name rangeUpper
        If ($ADSchema.rangeUpper -lt '16999') 
        {
            Write-Host "Extending Active Directory Schema" -Foregroundcolor green
            Test-FilePath ("$ExchangePath\setup.exe")
            start-process "$ExchangePath\setup.exe" -Wait -NoNewWindow -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /ps"
            Write-Host "Pausing for Schema replication" -Foregroundcolor green
            Start-Sleep -seconds 300
        }
        Else {Write-Host "Active Directory Schema already extended for Exchange 2019" -ForegroundColor Green}
    }
}

Function Set-XADPrep
{
    Write-Verbose "----- Entering Set-XADPrep function -----"
    
    If (!(Test-ADObject ("CN=Microsoft Exchange System Objects,$LDAPDomain"))) 
    {
        Write-Host "Preparing Active Directory for Exchange 2019" -Foregroundcolor green
        Test-FilePath ("$ExchangePath\setup.exe")
        start-process "$ExchangePath\setup.exe" -Wait -NoNewWindow -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /PrepareAD /OrganizationName:$ExchangeOrgName"
        Write-Host "Pausing for Active Directory replication" -Foregroundcolor green
        Start-Sleep -seconds 300
    }
    Else
    {
        $ExchangeSchemaLocation = 'AD:\CN=ms-Exch-Schema-Version-Pt,CN=Schema,CN=Configuration,'+$LDAPDomain
        $ADSchema = Get-ItemProperty $ExchangeSchemaLocation -Name rangeUpper
        If ($ADSchema.rangeUpper -lt '16999') 
        {
            $ADExchangePrepped = "AD:\CN=Microsoft Exchange System Objects," + $LDAPDomain
            $ADExchangePreppedobjversion = Get-ItemProperty $ADExchangePrepped -Name objectVersion
            If ($ADExchangePreppedobjversion.objectVersion -gt '13230') {Write-Host "Active Directory already Prepared for Exchange 2019" -ForegroundColor Green}
            Else 
            {
                Write-Host "Preparing Active Directory for Exchange 2019" -Foregroundcolor green
                Test-FilePath ("$ExchangePath\setup.exe")
                start-process "$ExchangePath\setup.exe" -Wait -NoNewWindow -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /PrepareAD /OrganizationName:$ExchangeOrgName"
                Write-Host "Pausing for Active Directory replication" -Foregroundcolor green
                Start-Sleep -seconds 300
            }
        }
        If ($ADSchema.rangeUpper -ge '16999') {Write-Host "Active Directory already Prepared for Exchange 2019" -ForegroundColor Green}
    }
}

Function Import-GPOs
{
    Write-Verbose "----- Entering Import-GPOs function -----"

    # Create OU
    If (!(Test-ADObject ("OU=Exchange,OU=T0-Servers,OU=Tier 0,OU=Admin,$LDAPDomain"))) 
    {New-ADOrganizationalUnit -Name "Exchange" -Path "OU=T0-Servers,OU=Tier 0,OU=Admin,$LDAPDomain"}

    # Import GPO(s)
    Test-FilePath ($GPOZipFileExch)
    Expand-Archive -LiteralPath $GPOZipFileExch -DestinationPath $LocalDir -Force
    cd $LocalDir

    # Get SID from Exchange Servers group and update "DC-WS2019-Exchange" GPO
    $SID = (Get-ADGroup "Exchange Servers").SID.Value

$DCXADGPOContent = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeSecurityPrivilege = *S-1-5-32-544,*$SID
"@

    Test-FilePath ("$LocalDir\Exchange\{7EBB1837-C555-487F-86E7-27A9F707A086}\DomainSysvol\GPO\Machine\microsoft\windows nt\SecEdit\GptTmpl.inf")
    $DCXADGPOContent | Out-File "$LocalDir\Exchange\{7EBB1837-C555-487F-86E7-27A9F707A086}\DomainSysvol\GPO\Machine\microsoft\windows nt\SecEdit\GptTmpl.inf" -Force

    Import-Module GroupPolicy
    $GPOs = @('DC-WS2019-Exchange','SVR-WS2019-Exchange')
    foreach ($GPO in $GPOs) 
    {
        Write-Host "Importing $GPO" -Foregroundcolor Green
        Import-GPO -BackupGpoName $GPO -TargetName $GPO -Path "$LocalDir\Exchange" -CreateIfNeeded
    }

    # Link GPO(s)
    New-GPLink -Name "DC-WS2019-Exchange" -Target "OU=Domain Controllers,$LDAPDomain" -LinkEnabled Yes -Order 1 -ErrorAction SilentlyContinue
    New-GPLink -Name "SVR-WS2019-Exchange" -Target "OU=Exchange,OU=T0-Servers,OU=Tier 0,OU=Admin,$LDAPDomain" -LinkEnabled Yes -Order 1 -ErrorAction SilentlyContinue

    # Perform GPUpdate on the DCs to apply new Exchange GPO setting
    $DCs = (Get-ADDomainController -Filter * | Select-Object Name | Sort-Object Name).Name
    Start-Sleep -seconds 30
    foreach ($DC in $DCs) 
    {
        $SessionDC = New-PSSession -ComputerName $DCs
        If (!($SessionDC)) 
        {
            Write-Host "Unable to remotely perform GPUpdate on $SessionDC" -ForegroundColor Red -BackgroundColor White
        }
        Else
        {
            Invoke-Command -Session $SessionDC {Invoke-GPUpdate -Target Computer -Force}
        }
    }
}

Function Test-XCert ($CertTemplate)
{
    Write-Host "Checking if certificate derived from $CertTemplate is in local store" -ForegroundColor Green
    $CertCheck = [bool] (Get-ChildItem Cert:\LocalMachine\My | ? {$_.Extensions.format(1)[0] -match "Template=$CertTemplate"})
    Write-Host $CertCheck
    return $CertCheck
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

# Import GPO(s) after Exchange groups have been created by Domain Prep
Import-GPOs

# Install Exchange
$Exchange = Get-Package  | ? {$_.Name -like "Microsoft Exchange Server"}
If ($Exchange.count -eq '0' -and (!(Check-PendingReboot)))
{
    Write-Host "Installing Exchange 2019" -Foregroundcolor green
    Test-FilePath ("$ExchangePath\setup.exe")
    start-process "$ExchangePath\setup.exe" -Wait -NoNewWindow -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /TargetDir:$TargetExchangePath /CustomerFeedbackEnabled:False /Mode:install /Roles:mb /OrganizationName:$ExchangeOrgName"
}
Else 
{
    Write-Host "Microsoft Exchange Server already installed or reboot needed" -ForegroundColor Green
}

$Exchange = Get-Package | ? {$_.Name -like "Microsoft Exchange Server*"}
If ($Exchange.count -gt '0') 
{
    Write-Host "Checking for Exchange" -ForegroundColor Green
     
    If ((get-module | ? {$_.Name -eq "RemoteExchange"}).count -eq 0) 
    {
        Write-Host "Starting Exchange Management Shell" -ForegroundColor Green
        $TargetExchangePSPath = $TargetExchangePath + "\bin\RemoteExchange.ps1"
        Import-Module $TargetExchangePSPath
        Connect-ExchangeServer -auto -ClientApplication:ManagementShell
    }
    
    Write-Host 'Checking OWA Virtual Directories InternalURL' -ForegroundColor Green
    If ((Get-OwaVirtualDirectory | ? {$_.InternalURL -notlike $OWAVirtualDirectory}).count -gt 0) 
    {
        Get-OwaVirtualDirectory | ? {$_.InternalURL -notlike $OWAVirtualDirectory} | fl InternalURL
        Write-Host 'Setting OWA Virtual Directories InternalURL' -ForegroundColor Yellow
        Get-OwaVirtualDirectory | ? {$_.InternalURL -notlike $OWAVirtualDirectory} | set-OwaVirtualDirectory -InternalURL $OWAVirtualDirectory
        Write-Host 'New OWA Virtual Directories InternalURL' -ForegroundColor Red
        Get-OwaVirtualDirectory | fl InternalURL
    }
    
    Write-Host 'Checking OWA Virtual Directories ExternalURL' -ForegroundColor Green
    If ((Get-OwaVirtualDirectory | ? {$_.ExternalURL -notlike $OWAVirtualDirectory}).count -gt 0) 
    {
        Get-OwaVirtualDirectory | ? {$_.ExternalURL -notlike $OWAVirtualDirectory} | fl ExternalURL
        Write-Host 'Setting OWA Virtual Directories ExternalURL' -ForegroundColor Yellow
        Get-OwaVirtualDirectory | ? {$_.ExternalURL -notlike $OWAVirtualDirectory} | set-OwaVirtualDirectory -ExternalURL $OWAVirtualDirectory
        Write-Host 'New OWA Virtual Directories ExternalURL' -ForegroundColor Red
        Get-OwaVirtualDirectory | fl ExternalURL
    }

    Write-Host 'Checking ECP Virtual Directories InternalURL' -ForegroundColor Green
    If ((Get-ECPVirtualDirectory | ? {$_.InternalURL -notlike $ECPVirtualDirectory}).count -gt 0) 
    {
        Get-ECPVirtualDirectory | ? {$_.InternalURL -notlike $ECPVirtualDirectory} | fl InternalURL
        Write-Host 'Setting ECP Virtual Directories InternalURL' -ForegroundColor Yellow
        Get-ECPVirtualDirectory | ? {$_.InternalURL -notlike $ECPVirtualDirectory} | set-ECPVirtualDirectory -InternalURL $ECPVirtualDirectory
        Write-Host 'New ECP Virtual Directories InternalURL' -ForegroundColor Red
        Get-ECPVirtualDirectory | fl InternalURL
    }

    Write-Host 'Checking ECP Virtual Directories ExternalURL' -ForegroundColor Green
    If ((Get-ECPVirtualDirectory | ? {$_.ExternalURL -notlike $ECPVirtualDirectory}).count -gt 0) 
    {
        Get-ECPVirtualDirectory | ? {$_.ExternalURL -notlike $ECPVirtualDirectory} | fl ExternalURL
        Write-Host 'Setting ECP Virtual Directories ExternalURL' -ForegroundColor Yellow
        Get-ECPVirtualDirectory | ? {$_.ExternalURL -notlike $ECPVirtualDirectory} | set-ECPVirtualDirectory -ExternalURL $ECPVirtualDirectory
        Write-Host 'New ECP Virtual Directories ExternalURL' -ForegroundColor Red
        Get-ECPVirtualDirectory | fl ExternalURL
    }

    Write-Host 'Checking OAB Virtual Directories InternalURL' -ForegroundColor Green
    If ((Get-OABVirtualDirectory | ? {$_.InternalURL -notlike $OABVirtualDirectory}).count -gt 0) 
    {
        Get-OABVirtualDirectory | ? {$_.InternalURL -notlike $OABVirtualDirectory} | fl InternalURL
        Write-Host 'Setting OAB Virtual Directories InternalURL' -ForegroundColor Yellow
        Get-OABVirtualDirectory | ? {$_.InternalURL -notlike $OABVirtualDirectory} | set-OABVirtualDirectory -InternalURL $OABVirtualDirectory
        Write-Host 'New OAB Virtual Directories InternalURL' -ForegroundColor Red
        Get-OABVirtualDirectory | fl InternalURL
    }

    Write-Host 'Checking OAB Virtual Directories ExternalURL' -ForegroundColor Green
    If ((Get-OABVirtualDirectory | ? {$_.ExternalURL -notlike $OABVirtualDirectory}).count -gt 0) 
    {
        Get-OABVirtualDirectory | ? {$_.ExternalURL -notlike $OABVirtualDirectory} | fl ExternalURL
        Write-Host 'Setting OAB Virtual Directories ExternalURL' -ForegroundColor Yellow
        Get-OABVirtualDirectory | ? {$_.ExternalURL -notlike $OABVirtualDirectory} | set-OABVirtualDirectory -ExternalURL $OABVirtualDirectory
        Write-Host 'New OAB Virtual Directories ExternalURL' -ForegroundColor Red
        Get-OABVirtualDirectory | fl ExternalURL
    }

    Write-Host 'Checking MAPI Virtual Directories InternalURL' -ForegroundColor Green
    If ((Get-MAPIVirtualDirectory | ? {$_.InternalURL -notlike $MAPIVirtualDirectory}).count -gt 0) 
    {
        Get-MAPIVirtualDirectory | ? {$_.InternalURL -notlike $MAPIVirtualDirectory} | fl InternalURL
        Write-Host 'Setting MAPI Virtual Directories InternalURL' -ForegroundColor Yellow
        Get-MAPIVirtualDirectory | ? {$_.InternalURL -notlike $MAPIVirtualDirectory} | set-MAPIVirtualDirectory -InternalURL $MAPIVirtualDirectory
        Write-Host 'New MAPI Virtual Directories InternalURL' -ForegroundColor Red
        Get-MAPIVirtualDirectory | fl InternalURL
    }
    
    Write-Host 'Checking MAPI Virtual Directories ExternalURL' -ForegroundColor Green
    If ((Get-MAPIVirtualDirectory | ? {$_.ExternalURL -notlike $MAPIVirtualDirectory}).count -gt 0) 
    {
        Get-MAPIVirtualDirectory | ? {$_.ExternalURL -notlike $MAPIVirtualDirectory} | fl ExternalURL
        Write-Host 'Setting MAPI Virtual Directories ExternalURL' -ForegroundColor Yellow
        Get-MAPIVirtualDirectory | ? {$_.ExternalURL -notlike $MAPIVirtualDirectory} | set-MAPIVirtualDirectory -ExternalURL $MAPIVirtualDirectory
        Write-Host 'New MAPI Virtual Directories ExternalURL' -ForegroundColor Red
        Get-MAPIVirtualDirectory | fl ExternalURL
    }
    
    Write-Host 'Checking ActiveSync Virtual Directories InternalURL' -ForegroundColor Green
    If ((Get-ActiveSyncVirtualDirectory | ? {$_.InternalURL -notlike $ActiveSyncVirtualDirectory}).count -gt 0) 
    {
        Get-ActiveSyncVirtualDirectory | ? {$_.InternalURL -notlike $ActiveSyncVirtualDirectory} | fl InternalURL
        Write-Host 'Setting ActiveSync Virtual Directories InternalURL' -ForegroundColor Yellow
        Get-ActiveSyncVirtualDirectory | ? {$_.InternalURL -notlike $ActiveSyncVirtualDirectory} | set-ActiveSyncVirtualDirectory -InternalURL $ActiveSyncVirtualDirectory
        Write-Host 'New ActiveSync Virtual Directories InternalURL' -ForegroundColor Red
        Get-ActiveSyncVirtualDirectory | fl InternalURL
    }

    Write-Host 'Checking ActiveSync Virtual Directories ExternalURL' -ForegroundColor Green
    If ((Get-ActiveSyncVirtualDirectory | ? {$_.ExternalURL -notlike $ActiveSyncVirtualDirectory}).count -gt 0) 
    {
        Get-ActiveSyncVirtualDirectory | ? {$_.ExternalURL -notlike $ActiveSyncVirtualDirectory} | fl ExternalURL
        Write-Host 'Setting ActiveSync Virtual Directories ExternalURL' -ForegroundColor Yellow
        Get-ActiveSyncVirtualDirectory | ? {$_.ExternalURL -notlike $ActiveSyncVirtualDirectory} | set-ActiveSyncVirtualDirectory -ExternalURL $ActiveSyncVirtualDirectory
        Write-Host 'New ActiveSync Virtual Directories ExternalURL' -ForegroundColor Red
        Get-ActiveSyncVirtualDirectory | fl ExternalURL
    }

    Write-Host 'Checking WebServices Virtual Directories InternalURL' -ForegroundColor Green
    If ((Get-WebServicesVirtualDirectory | ? {$_.InternalURL -notlike $WebServicesVirtualDirectory}).count -gt 0) 
    {
        Get-WebServicesVirtualDirectory | ? {$_.InternalURL -notlike $WebServicesVirtualDirectory} | fl InternalURL
        Write-Host 'Setting WebServices Virtual Directories InternalURL' -ForegroundColor Yellow
        Get-WebServicesVirtualDirectory | ? {$_.InternalURL -notlike $WebServicesVirtualDirectory} | set-WebServicesVirtualDirectory -InternalURL $WebServicesVirtualDirectory -force
        Write-Host 'New WebServices Virtual Directories InternalURL' -ForegroundColor Red
        Get-WebServicesVirtualDirectory | fl InternalURL
    }

    Write-Host 'Checking WebServices Virtual Directories ExternalURL' -ForegroundColor Green
    If ((Get-WebServicesVirtualDirectory | ? {$_.ExternalURL -notlike $WebServicesVirtualDirectory}).count -gt 0) 
    {
        Get-WebServicesVirtualDirectory | ? {$_.ExternalURL -notlike $WebServicesVirtualDirectory} | fl ExternalURL
        Write-Host 'Setting WebServices Virtual Directories ExternalURL' -ForegroundColor Yellow
        Get-WebServicesVirtualDirectory | ? {$_.ExternalURL -notlike $WebServicesVirtualDirectory} | set-WebServicesVirtualDirectory -ExternalURL $WebServicesVirtualDirectory -force
        Write-Host 'New WebServices Virtual Directories ExternalURL' -ForegroundColor Red
        Get-WebServicesVirtualDirectory | fl ExternalURL
    }
    
    Write-Host 'Checking Outlook Anywhere Internal Host Name' -ForegroundColor Green
    If ((Get-OutlookAnywhere | ? {$_.Internalhostname -notlike $ExchangeMailURL}).count -gt 0) 
    {
        Get-OutlookAnywhere | ? {$_.Internalhostname -notlike $ExchangeMailURL} | fl Internalhostname
        Write-Host 'Setting Outlook Anywhere Internal Host Name' -ForegroundColor Yellow
        Get-OutlookAnywhere | ? {$_.Internalhostname -notlike $ExchangeMailURL} | Set-OutlookAnywhere -Internalhostname $ExchangeMailURL -InternalClientsRequireSsl $true -DefaultAuthenticationMethod NTLM
        Write-Host 'New Outlook Anywhere Internal Host Name' -ForegroundColor Red
        Get-OutlookAnywhere | fl InternalURL
    }

    Write-Host 'Checking Outlook Anywhere External Host Name' -ForegroundColor Green
    If ((Get-OutlookAnywhere | ? {$_.Externalhostname -notlike $ExchangeMailURL}).count -gt 0) 
    {
        Get-OutlookAnywhere | ? {$_.Externalhostname -notlike $ExchangeMailURL} | fl Externalhostname
        Write-Host 'Setting Outlook Anywhere External Host Name' -ForegroundColor Yellow
        Get-OutlookAnywhere | ? {$_.Externalhostname -notlike $ExchangeMailURL} | Set-OutlookAnywhere -Externalhostname $ExchangeMailURL -ExternalClientsRequireSsl $true -DefaultAuthenticationMethod NTLM
        Write-Host 'New Outlook Anywhere External Host Name' -ForegroundColor Red
        Get-OutlookAnywhere | fl ExternalURL
    }
}
Else 
{
    Write-Host "Exchange Not Installed" -Foregroundcolor Green
}

# Create CNAMEs in DNS
Write-Host 'Checking DNS for' $ExchangeMailURL -ForegroundColor Green
Import-Module DNSServer
$dotDomainDNSName = "." + $DomainDNSName
$ExchangeCNAME = $ExchangeMailURL -replace $dotDomainDNSName,""
$DC = (Get-ADDomainController -Filter * | Select-Object Name | Sort-Object Name | Select-Object -First 1).Name
$ExchangeFQDN = ([System.Net.DNS]::GetHostByName($env:computerName)).hostname

$TestDNS1 = Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name "$ExchangeCNAME" -RRType CName -ErrorAction "SilentlyContinue"
If(!($TestDNS1)) 
{
    Add-DnsServerResourceRecordCName -ZoneName $DomainDnsName -ComputerName $DC -Name "$ExchangeCNAME" -HostNameAlias $ExchangeFQDN -TimeToLive 00:05:00
    Write-Host "The following DNS CNAME record was successfully created:" -ForegroundColor Yellow
    Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name "$ExchangeCNAME" -RRType CName
}

$TestDNS2 = Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name "autodiscover" -RRType CName -ErrorAction "SilentlyContinue"
If(!($TestDNS2)) 
{
    Add-DnsServerResourceRecordCName -ZoneName $DomainDnsName -ComputerName $DC -Name "autodiscover" -HostNameAlias $ExchangeFQDN -TimeToLive 00:05:00
    Write-Host "The following DNS CNAME record was successfully created:" -ForegroundColor Yellow
    Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name "autodiscover" -RRType CName
}

# Install cert
If (!(Test-XCert ("$CertTemplate"))) 
{
    Write-Host "Installing certificate derived from $CertTemplate template" -ForegroundColor Green
    $Template = $CertTemplate.Replace(" ","")
    $ExchangeFQDN = ([System.Net.DNS]::GetHostByName($env:computerName)).hostname
    $Certificate = Get-Certificate -Template $Template -DNSName $ExchangeFQDN,$ExchangeMailURL,autodiscover.$DomainDnsName -CertStoreLocation cert:\LocalMachine\My
    $Certificate | fl
    
    Write-Host 'Binding Certificate to Exchange Services' -ForegroundColor Green
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn
    Enable-ExchangeCertificate -thumbprint $Certificate.certificate.thumbprint -Services IIS,POP,IMAP,SMTP -confirm:$false -force
    Get-ExchangeCertificate
}

# Test Exchange URL(s)
Write-Host "Testing https://$ExchangeMailURL/owa" -ForegroundColor Green
(Invoke-WebRequest https://$ExchangeMailURL/owa -UseBasicParsing).StatusDescription

Write-Host "Testing https://autodiscover.$DomainDnsName" -ForegroundColor Green
(Invoke-WebRequest https://autodiscover.$DomainDnsName -UseBasicParsing).StatusDescription

# Move server to OU to apply GPOs upon restart
Write-Host "Moving $env:COMPUTERNAME to new OU to receive Group Policy"  -Foregroundcolor Green
Get-ADComputer $env:COMPUTERNAME | Move-ADObject -TargetPath "OU=Exchange,OU=T0-Servers,OU=Tier 0,OU=Admin,$LDAPDomain" -Verbose
(Get-ADComputer $env:COMPUTERNAME).DistinguishedName

Stop-Transcript
