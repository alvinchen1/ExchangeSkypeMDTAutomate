<#
NAME
    New-IssuingCA.ps1

SYNOPSIS
    Installs an Issuing Certificate Authority in the AD domain

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
$CertReqLocation = ($PKI | ? {($_.Name -eq "CertReqLocation")}).Value
$CertDB = ($PKI | ? {($_.Name -eq "CertDB")}).Value
$ApprovedCertLocation = ($PKI | ? {($_.Name -eq "ApprovedCertLocation")}).Value
$CertCRLLocation = ($PKI | ? {($_.Name -eq "CertCRLLocation")}).Value
$CryptoProviderName = ($PKI | ? {($_.Name -eq "CryptoProviderName")}).Value
$KeyLength = ($PKI | ? {($_.Name -eq "KeyLength")}).Value
$HashAlgorithmName = ($PKI | ? {($_.Name -eq "HashAlgorithmName")}).Value
$CACommonName = "$DomainName Issuing CA"
$OutputCertRequestFile = "$CertReqLocation\$DomainName Issuing CA.req"

$CAPolicyFileContent = @"
[Version]
Signature="$Windows NT$"

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

# =============================================================================
# MAIN ROUTINE
# =============================================================================

If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

# Create PKI Directories
If (!(Test-Path $CertReqLocation)) {New-Item $CertReqLocation -ItemType Directory}
If (!(Test-Path $CertDB)) {New-Item $CertDB -ItemType Directory}
If (!(Test-Path $ApprovedCertLocation)) {New-Item $ApprovedCertLocation -ItemType Directory}
If (!(Test-Path $CertCRLLocation)) {New-Item $CertCRLLocation -ItemType Directory}
$CAPolicyFileContent | Out-File "$env:WINDIR\CAPolicy.inf" -Force

# Install and config EnterpriseSubordinateCA in the AD domain
Import-Module ADCSDeployment
Install-AdcsCertificationAuthority -CAType EnterpriseSubordinateCA -CACommonName "$CACommonName" -CADistinguishedNameSuffix "$DomainDistinguishedName" -OverwriteExistingCAinDS -OverwriteExistingDatabase -CryptoProviderName "$CryptoProviderName" -KeyLength $KeyLength -HashAlgorithmName $HashAlgorithmName -OutputCertRequestFile "$OutputCertRequestFile" -DatabaseDirectory $CertDB -LogDirectory $CertDB -IgnoreUnicode -Verbose -Force

# Enable Auditing
auditpol /set /subcategory:"Certification services" /success:enable /failure:enable

If (!(Test-Path $OutputCertRequestFile)) 
{
    Throw "An error occurred with the install. Review the contents of the transcript log."
}
Else
{
    Write-Host "`nIMPORTANT: The ADCS installation is NOT yet complete. Proceed to use the following request file to obtain a certificate from the Root CA: `n$OutputCertRequestFile`n" -ForeGround "yellow" -back "black"
}

Stop-Transcript
