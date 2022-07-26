<#
NAME
    Approve-IssuingCA.ps1

SYNOPSIS
    Copies certificate request file from sub CA to root CA and then approves the request

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
$DomainDistinguishedName = ($WS | ? {($_.Name -eq "DomainDistinguishedName")}).Value
$PKI = ($XML.Component | ? {($_.Name -eq "PKI")}).Settings.Configuration
$RootCA = ($PKI | ? {($_.Name -eq "RootCA")}).Value
$CDP = ($PKI | ? {($_.Name -eq "CDP")}).Value
$IssuingCA = ($PKI | ? {($_.Name -eq "IssuingCA")}).Value
$CertReqLocation = ($PKI | ? {($_.Name -eq "CertReqLocation")}).Value
$CertDB = ($PKI | ? {($_.Name -eq "CertDB")}).Value
$ApprovedCertLocation = ($PKI | ? {($_.Name -eq "ApprovedCertLocation")}).Value
$CertCRLLocation = ($PKI | ? {($_.Name -eq "CertCRLLocation")}).Value
$CACommonName = "$DomainName Issuing CA"
$OutputCertRequestFile = "$CertReqLocation\$DomainName Issuing CA.req"

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Config WinRM to trust offline root CA
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $RootCA -Concatenate -Force

If (!(Test-Path $OutputCertRequestFile)) 
{
    Throw "An error occurred with the install. Review the contents of the transcript log."
}
Else
{
    $CredsRootCA = Get-Credential -UserName "$RootCA\Administrator" -Message "Enter password for Root CA local Administrator account"
    $SessionRootCA = New-PSSession -ComputerName "$RootCA" -Credential $CredsRootCA
    Copy-Item -Path $OutputCertRequestFile -Destination "C:\PKIData\REQ\" -ToSession $SessionRootCA
}

# Submit cert req and approve on root CA
Invoke-Command -Session $SessionRootCA {
cd C:\PKIData\REQ\
$StatusCertReq = certreq -submit -q "$using:OutputCertRequestFile"
$CertReqID = $StatusCertReq[0] -replace "[()\D+]", ""
Import-Module -Name PSPKI
Get-CertificationAuthority | Get-PendingRequest -RequestID $CertReqID | Approve-CertificateRequest
Get-CertificationAuthority | Get-IssuedRequest
certreq -retrieve -q $CertReqID "C:\PKIData\REQ\$using:DomainName Issuing CA.crt"
}

# Copy root files to subordinate CA
Copy-Item -FromSession $SessionRootCA "C:\PKIData\CRL\Root CA.crl" -Destination "C:\PKIData\Root CA.crl"
Copy-Item -FromSession $SessionRootCA "C:\PKIData\AIA\Root CA.crt" -Destination "C:\PKIData\Root CA.crt"
Copy-Item -FromSession $SessionRootCA "C:\PKIData\RootCA_Base64.crt" -Destination "C:\PKIData\RootCA_Base64.crt"
Copy-Item -FromSession $SessionRootCA "C:\PKIData\REQ\$DomainName Issuing CA.crt" -Destination "C:\PKIData\CERT\$DomainName Issuing CA.crt"

Stop-Transcript
