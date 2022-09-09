<#
NAME
    New-IssuingCA.ps1

SYNOPSIS
    Installs an Issuing Certificate Authority in the AD domain

SYNTAX
    .\$ScriptName
 #>

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path –Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path –Parent
$DTG = Get-Date -Format yyyyMMddTHHmm
$RootDir = Split-Path $ScriptDir –Parent
$ConfigFile = "$RootDir\config.xml"

Start-Transcript -Path "$RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log"
Start-Transcript -Path "$env:WINDIR\Temp\$env:COMPUTERNAME-$DTG-$ScriptName.log"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) {Throw "ERROR: Unable to locate $ConfigFile Exiting..."}
$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$DomainName = ($WS | ? {($_.Name -eq "DomainName")}).Value
$DomainDistinguishedName = ($WS | ? {($_.Name -eq "DomainDistinguishedName")}).Value
$DomainDnsName = ($WS | ? {($_.Name -eq "DomainDnsName")}).Value
$PKI = ($XML.Component | ? {($_.Name -eq "PKI")}).Settings.Configuration
$RootCA = ($PKI | ? {($_.Name -eq "RootCA")}).Value
$RootCACred = ($PKI | ? {($_.Name -eq "RootCACred")}).Value
$CDP = ($PKI | ? {($_.Name -eq "CDP")}).Value + '.' + $DomainDnsName
$IssuingCA = ($PKI | ? {($_.Name -eq "IssuingCA")}).Value
$CertReqLocation = "C:\PKIData\REQ"
$CertDB = "C:\PKIData\Database"
$ApprovedCertLocation = "C:\PKIData\CERT"
$CertCRLLocation = "C:\PKIData\CRL"
$CryptoProviderName = "RSA#Microsoft Software Key Storage Provider"
$KeyLength = "4096"
$HashAlgorithmName = "SHA512"
$CACommonName = "$DomainName Issuing CA"
$OutputCertRequestFile = "$CertReqLocation\$DomainName Issuing CA.req"
$ApprovedCertFile = "$ApprovedCertLocation\$CACommonName.crt"
$CAAccountName = "$DomainName\$IssuingCA$"
$CRLPublicationURLs = "6:http://pki/crl/%3%8%9.crl\n65:C:\PKIData\CRL\%3%8%9.crl\n65:file:\\pki\crl\%3%8%9.crl\n79:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10"
$CACertPublicationURLs = "2:http://pki/crl/%3.crt\n1:C:\PKIData\AIA\%3.crt\n1:file:\\pki\crl\%3.crt\n2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11"

$CAPolicyFileContent = @"
[Version]
Signature="`$Windows NT$"

[Certsrv_Server]
LoadDefaultTemplates=0

"@

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

Function Install-IssuingCA
{
    Write-Verbose "----- Install-IssuingCA function -----"
    
    If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

    # Create PKI Directories
    If (!(Test-Path $CertReqLocation)) {New-Item $CertReqLocation -ItemType Directory}
    If (!(Test-Path $CertDB)) {New-Item $CertDB -ItemType Directory}
    If (!(Test-Path $ApprovedCertLocation)) {New-Item $ApprovedCertLocation -ItemType Directory}
    If (!(Test-Path $CertCRLLocation)) {New-Item $CertCRLLocation -ItemType Directory}
    $CAPolicyFileContent | Out-File "$env:WINDIR\CAPolicy.inf" -Force -Encoding ascii

    # Install and config EnterpriseSubordinateCA in the AD domain
    Import-Module ADCSDeployment
    Install-AdcsCertificationAuthority -CAType EnterpriseSubordinateCA -CACommonName "$CACommonName" -CADistinguishedNameSuffix "$DomainDistinguishedName" -OverwriteExistingCAinDS -OverwriteExistingDatabase -CryptoProviderName "$CryptoProviderName" -KeyLength $KeyLength -HashAlgorithmName $HashAlgorithmName -OutputCertRequestFile "$OutputCertRequestFile" -DatabaseDirectory $CertDB -LogDirectory $CertDB -IgnoreUnicode -Verbose -Force

    # Enable Auditing
    auditpol /set /subcategory:"Certification services" /success:enable /failure:enable

    If (!(Test-Path $OutputCertRequestFile)) {Throw "An error occurred with Install-IssuingCA. Review the contents of the transcript log."}
}

Function Approve-IssuingCA
{
    Write-Verbose "----- Approve-IssuingCA function -----"
    
    # Config WinRM to trust offline root CA
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value $RootCA -Concatenate -Force

    # Submit cert req and approve on root CA
    If (!(Test-Path $OutputCertRequestFile)) 
    {
        Throw "Unable to locate $OutputCertRequestFile. Review the contents of the transcript log."
    }
    Else
    {
        $RootCAPwd = ConvertTo-SecureString -AsPlainText -Force -String $RootCACred
        $CredsRootCA = New-Object System.Management.Automation.PSCredential -ArgumentList "$RootCA\Administrator",$RootCAPwd
        $SessionRootCA = New-PSSession -ComputerName "$RootCA" -Credential $CredsRootCA
        If (!($SessionRootCA)) {Throw "Unable to establish remote PSSession with $RootCA"}
        Copy-Item -Path $OutputCertRequestFile -Destination "C:\PKIData\REQ\" -ToSession $SessionRootCA
    }

    Invoke-Command -Session $SessionRootCA {
        $DTG = Get-Date -Format yyyyMMddTHHmm
        $Transcript =  "$env:WINDIR\Temp\$env:COMPUTERNAME-$DTG-Approve-IssuingCA.log"
        Start-Transcript -Path $Transcript
        cd C:\PKIData\REQ\
        $StatusCertReq = certreq -submit -q "$using:OutputCertRequestFile"
        $CertReqID = $StatusCertReq[0] -replace "[()\D+]", ""
        Import-Module -Name PSPKI
        Connect-CertificationAuthority | Get-PendingRequest -RequestID $CertReqID | Approve-CertificateRequest
        Connect-CertificationAuthority | Get-IssuedRequest
        certreq -retrieve -q $CertReqID "C:\PKIData\REQ\$using:DomainName Issuing CA.crt"
        Stop-Transcript
    }

    # Copy root files to subordinate CA
    Copy-Item -FromSession $SessionRootCA "C:\PKIData\CRL\Root CA.crl" -Destination "C:\PKIData\Root CA.crl"
    Copy-Item -FromSession $SessionRootCA "C:\PKIData\AIA\Root CA.crt" -Destination "C:\PKIData\Root CA.crt"
    Copy-Item -FromSession $SessionRootCA "C:\PKIData\RootCA_Base64.crt" -Destination "C:\PKIData\RootCA_Base64.crt"
    Copy-Item -FromSession $SessionRootCA "C:\PKIData\REQ\$DomainName Issuing CA.crt" -Destination "C:\PKIData\CERT\$DomainName Issuing CA.crt"

    If (!(Test-Path "C:\PKIData\CERT\$DomainName Issuing CA.crt")) {Throw "An error occurred with Approve-IssuingCA. Review the contents of the transcript log."}
}

Function Config-CDP
{
    Write-Verbose "----- Entering Config-CDP function -----"
    
    # Grant Issuing CA computer account NTFS and share permissions on CDP
    Invoke-Command -Session $SessionCDP {
        $DTG = Get-Date -Format yyyyMMddTHHmm
        $Transcript =  "$env:WINDIR\Temp\$env:COMPUTERNAME-$DTG-Config-CDP.log"
        Start-Transcript -Path $Transcript
        If (!(Get-SmbShare -Name 'CRL')) {Throw "Unable to locate CRL share"}
        $Acl = (Get-Item "C:\inetpub\PKI\crl").GetAccessControl('Access')
        Grant-SmbShareAccess -Name 'CRL' -AccountName "$using:CAAccountName" -AccessRight Full -Force
        $Acl = (Get-Item "C:\inetpub\PKI\crl").GetAccessControl('Access')
        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$using:CAAccountName", 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $Acl.SetAccessRule($Ar)
        Set-Acl -path "C:\inetpub\PKI\crl" -AclObject $Acl
        Write-Host -Message "ACLs Modified"
        Stop-Transcript
    }
    
    # Ensure certificates are in place on CDP
    Copy-Item -Path $ApprovedCertFile -Destination "C:\inetpub\PKI\crl" -Force -ToSession $SessionCDP
    Copy-Item -Path "C:\PKIData\Root CA.crt" -Destination "C:\inetpub\PKI\crl" -Force -ToSession $SessionCDP
    Copy-Item -Path "C:\PKIData\Root CA.crl" -Destination "C:\inetpub\PKI\crl" -Force -ToSession $SessionCDP
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
    $service = Get-Service | Where-Object {$_.Name -eq "certsvc"}
    If ($service.Status -eq "Running") {Restart-Service certsvc}
    Else {Start-Service certsvc}
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
        return $false
    }
}

Function Set-RegistryKeys
{
    Write-Verbose "----- Entering Set-RegistryKeys function -----"

    certutil -setreg CA\CRLPublicationURLs $CRLPublicationURLs
    certutil -setreg CA\CACertPublicationURLs $CACertPublicationURLs
    # Audit all events
    certutil –setreg CA\AuditFilter 127
    # Disable auto enrollment of SANs: https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/ff625722(v=ws.10)
    certutil -setreg policy\EditFlags -EDITF_ATTRIBUTESUBJECTALTNAME2

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

Function Test-CDP
{
    Write-Verbose "----- Entering Test-CDP function -----"
    
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
}

Function Check-PKIHealthStatus
{
    Write-Verbose "----- Entering Check-PKIHealthStatus function -----"
    
    # Get Issuing CA's health status
    Import-Module -Name PSPKI
    $HealthStatus = (Get-CertificationAuthority | Get-EnterprisePKIHealthStatus).Status
    If ($HealthStatus -eq 'Error')
    {
        $service = Get-Service | Where-Object {$_.Name -eq "certsvc"}
        If ($service.Status -eq "Running") {Restart-Service certsvc}
        Else {Start-Service certsvc}
    }
    $HealthStatus = (Get-CertificationAuthority | Get-EnterprisePKIHealthStatus).Status
    If ($HealthStatus -ne 'Ok')
    {
        Write-Host "Run pkiview.msc or certsrv.msc and verify the health of the CA" -ForegroundColor Red -BackgroundColor Yellow
    }
    Else
    {
        Write-Host "Installation and configuration of the Issuing CA is complete" -ForegroundColor Green
    }
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

Install-IssuingCA
Approve-IssuingCA

# Configure CDP
$SessionCDP = New-PSSession -ComputerName $CDP
If (!($SessionCDP)) {Throw "Unable to establish remote PSSession with $SessionCDP"}
Config-CDP

# Install approved certificate
Install-Cert
If(!(Test-Cert)) {Throw "Certificate needs to be installed."}

# Configure registry keys
Set-RegistryKeys

Export-SubCACert

Copy-Item -Path C:\Windows\System32\CertSrv\CertEnroll\*.* -Destination C:\PKIData -Force
Copy-Item -Path "C:\PKIData\RootCA_Base64.crt" -Destination "C:\inetpub\PKI\crl" -Force -ToSession $SessionCDP
Copy-Item -Path "C:\PKIData\$DomainName IssuingCA_Base64.crt" -Destination "C:\inetpub\PKI\crl" -Force -ToSession $SessionCDP

Test-CDP
#Check-PKIHealthStatus

Stop-Transcript
