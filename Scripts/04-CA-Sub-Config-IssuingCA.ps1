<#
NAME
    Config-IssuingCA.ps1

SYNOPSIS
    Configures the Issuing Certificate Authority in the AD domain

SYNTAX
    .\$ScriptName
 #>

Start-Transcript

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
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$DomainName = ($WS | ? {($_.Name -eq "DomainName")}).Value
$DomainDnsName = ($WS | ? {($_.Name -eq "DomainDnsName")}).Value
$DomainDistinguishedName = ($WS | ? {($_.Name -eq "DomainDistinguishedName")}).Value
$PKI = ($XML.Component | ? {($_.Name -eq "PKI")}).Settings.Configuration
$CDP = ($PKI | ? {($_.Name -eq "CDP")}).Value + '.' + $DomainDnsName
$ApprovedCertLocation = ($PKI | ? {($_.Name -eq "ApprovedCertLocation")}).Value
$CACommonName = "$DomainName Issuing CA"
$ApprovedCertFile = "$ApprovedCertLocation\$CACommonName.crt"
$CDPShare = "\\$CDP\crl"
$CRLPublicationURLs = @('6:http://pki/crl/%3%8%9.crl','65:C:\PKIData\CRL\%3%8%9.crl','65:file:\\pki\crl\%3%8%9.crl','79:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10')
$CertPublicationURLs = @('2:http://pki/crl/%3.crt','1:C:\PKIData\AIA\%3.crt','1:file:\\pki\crl\%3.crt','2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11')
$EditFlags = '0x15014e'
$AuditFilter = '0x0000007f'


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

Function Check-Prereqs
{
    Write-Verbose "----- Entering Check-Prereqs function -----"
    
    # Ensure script is run elevated
    If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

    # Ensure certificate is present
    If(!(Test-Path -Path $ApprovedCertFile)) {Throw "Unable to locate the approved cert: $ApprovedCertFile"}
}

Function Install-Cert
{
    Write-Verbose "----- Entering Install-Cert function -----"
    
    Write-Verbose "Publishing RootCA certificate and CRL..."
    certutil -dspublish -f "C:\PKIData\Root CA.crt" RootCA
    certutil -dspublish -f "C:\PKIData\Root CA.crl"
    certutil -pulse

    Write-Verbose -Message "Installing certificate..."
    certutil -installcert "$ApprovedCertFile"
    Sleep 10

    Write-Verbose -Message "Certificate installed and service started"
    Start-Service certsvc
    Write-Host "CA Certificate install completed"
}

Function Test-Cert
{
    Write-Verbose "----- Entering Test-Cert function -----"
    
    Write-Verbose -Message "Checking if certificate is installed..."
    $check = (Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -like "*$CACommonName*"})
    If(($check.Subject -like "*$CACommonName*") -eq "True")
    {
        Write-Verbose -Message "Certificate installed."
        $service = Get-Service | Where-Object {$_.Name -eq "certsvc"}
        If($service.Status -eq "Running")
        {
            return $true
        }
        Else
        {
            Start-Service certsvc
            return $true
        }
    }
    Else
    {
        Write-Verbose -Message "Certificate needs to be installed."
        return $false
    }
}

Function Set-RegistryKeys
{
    Write-Verbose "----- Entering Set-RegistryKeys function -----"
    
    $CertSvcReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$CACommonName" -ErrorAction "SilentlyContinue"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$CACommonName" -Name "CRLPublicationURLs" -Type MultiString -Value $CRLPublicationURLs -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$CACommonName" -Name "CACertPublicationURLs" -Type MultiString -Value $CertPublicationURLs -Force    
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$CACommonName\PolicyModules\CertificateAuthority_MicrosoftDefault.Policy" -Name "EditFlags" -Type Dword -Value $EditFlags -Force

    If (!($CertSvcReg.AuditFilter))
    {
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$CACommonName" -Name "AuditFilter" -PropertyType Dword -Value $AuditFilter -Force
    }
    Else
    {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$CACommonName" -Name "AuditFilter" -Type Dword -Value $AuditFilter -Force
    }

    $service = Get-Service | Where-Object {$_.Name -eq "certsvc"}
    If ($service.Status -eq "Running") {Restart-Service certsvc}
    Else {Start-Service certsvc}
}

Function Export-SubCACert
{
    Write-Verbose "----- Entering Export-SubCACert function -----"
    
    # Export subordinate CA cert in Base-64 encoded X.509 format
    $Cert = Get-ChildItem Cert:\LocalMachine\My -recurse | Where-Object {$_.Subject -like "CN=$DomainName Issuing CA*"}
    Export-Certificate -Cert $Cert -FilePath "C:\PKIData\$DomainName IssuingCA_Base64.cer" -Type CERT
    certutil -encode "C:\PKIData\$DomainName IssuingCA_Base64.cer" "C:\PKIData\$DomainName IssuingCA_Base64.crt"
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

Check-Prereqs

# Ensure certificates are in place on CDP
If (!(Test-Path $ApprovedCertFile)) 
{
    Throw "Unable to locate $ApprovedCertFile. Review the contents of the transcript log."
}
Else
{
    #$CredsCDP = Get-Credential -UserName "$DomainName\Administrator" -Message "Enter password for domain admin account"
    $SessionCDP = New-PSSession -ComputerName $CDP #-Credential $CredsCDP
    Copy-Item -Path $ApprovedCertFile -Destination "C:\inetpub\PKI\crl" -Force -ToSession $SessionCDP
    Copy-Item -Path "C:\PKIData\Root CA.crt" -Destination "C:\inetpub\PKI\crl" -Force -ToSession $SessionCDP
    Copy-Item -Path "C:\PKIData\Root CA.crl" -Destination "C:\inetpub\PKI\crl" -Force -ToSession $SessionCDP
}

# Install approved certificate
Install-Cert
If(!(Test-Cert)) {Throw "Certificate needs to be installed."}

# Configure registry keys
Set-RegistryKeys

Export-SubCACert

# Copy certificates to CDP
Copy-Item -Path "C:\PKIData\RootCA_Base64.crt" -Destination "C:\inetpub\PKI\crl" -Force -ToSession $SessionCDP
Copy-Item -Path "C:\PKIData\$DomainName IssuingCA_Base64.crt" -Destination "C:\inetpub\PKI\crl" -Force -ToSession $SessionCDP

# Test CDP URLs
Write-Host "`nhttp://pki/crl/Root%20CA.crl"
(Invoke-WebRequest http://pki/crl/Root%20CA.crl -UseBasicParsing).StatusDescription

Write-Host "`nhttp://pki/crl/Root%20CA.crt"
(Invoke-WebRequest http://pki/crl/Root%20CA.crt -UseBasicParsing).StatusDescription

Write-Host "`nhttp://pki/crl/RootCA_Base64.crt"
(Invoke-WebRequest http://pki/crl/RootCA_Base64.crt -UseBasicParsing).StatusDescription

Write-Host "`nhttp://pki/crl/$DomainName%20Issuing%20CA.crt"
(Invoke-WebRequest http://pki/crl/$DomainName%20Issuing%20CA.crt -UseBasicParsing).StatusDescription

Write-Host "`nhttp://pki/crl/$DomainName%20IssuingCA_Base64.crt"
(Invoke-WebRequest http://pki/crl/$DomainName%20IssuingCA_Base64.crt -UseBasicParsing).StatusDescription

Stop-Transcript

