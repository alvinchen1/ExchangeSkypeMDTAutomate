<#
NAME
    New-RootCA.ps1

SYNOPSIS
    Installs a Standalone Root CA based on the standard Microsoft Consulting Services setup

DESCRIPTION
    This script installs a Standalone Root CA. The script generates the required management CMD for backup of the CA.
    Before you run the script set the correct parameters in the parameter section
    $DBDir

SYNTAX
    .\$ScriptName
    .\$ScriptName -VerboseOutput $true -DebugOutput $true

OUTPUTS
   If the -SkipExport $false the script will generate XML files containing all the information which are used to generated reports
   even if we are not connected to the environment.
 #>

Start-Transcript

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path –Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path –Parent
$ConfigFileName = $MyInvocation.MyCommand.Path.Replace("ps1","config")

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFileName)) 
{
    Write-Host "Missing configuration file $ConfigFileName" -ForegroundColor Red
    Stop-Transcript
    Exit
}
[XML]$ConfigFile = Get-Content $ConfigFileName
$AiaDir = $ConfigFile.Settings.Directories.AIA
$CaBackupCMDFileName = $ConfigFile.Settings.Directories.Script + "\BackupCA.cmd"

# =============================================================================
# FUNCTIONS
# =============================================================================

Function Install-RootCA
{
    Write-Verbose "----- Entering Install-RootCA function -----"
    
    # Create PKI Directories and Backup script
    If (!(Test-Path $ConfigFile.Settings.Directories.AIA)) {New-Item $ConfigFile.Settings.Directories.AIA -ItemType Directory}
    If (!(Test-Path $ConfigFile.settings.Directories.CRL)) {New-Item $ConfigFile.Settings.Directories.CRL -ItemType Directory}
    If (!(Test-Path $ConfigFile.Settings.Directories.Script)) {New-Item $ConfigFile.Settings.Directories.Script -ItemType Directory}
    If (!(Test-Path $ConfigFile.Settings.Directories.CertReqLocation)) {New-Item $ConfigFile.Settings.Directories.CertReqLocation -ItemType Directory}
    If (!(Test-Path $CaBackupCMDFileName))
    {
        # Create the Backup script file
        $CABackup = $ConfigFile.Settings.Scripts.Backup.InnerText
        $CABackup = $CABackup.Replace("%CaCommonName%",$ConfigFile.Settings.CAParameter.CACommonName)
        $CABackup = $CABackup.Replace("%USBMedia%",$ConfigFile.Settings.Directories.USBMedia)
        New-Item -Path $CABackupCMDFilename -ItemType File -Force
        Add-Content -Path $CaBackupCMDFileName -Value $CABackup
    }

    # Create CAPolicy.INF in Windows diectory
    if (!(Test-Path C:\Windows\CAPolicy.inf))
    {
        New-Item -Path $env:windir\CAPolicy.inf -ItemType File -Force
        Add-Content -Path $env:windir\CAPolicy.inf -Value $ConfigFile.Settings.CAPolicyInf
    }

     #Enable Auditing
    auditpol /set /subcategory:"Certification services" /success:enable /failure:enable

    # Install AD certification service
    if (!(Get-WindowsFeature -Name ADCS-Cert-Authority).Installed)
    {
        Add-WindowsFeature -Name ADCS-Cert-Authority -IncludeManagementTools  
        Install-AdcsCertificationAuthority -CACommonName $ConfigFile.Settings.CAParameter.CACommonName -CAType StandaloneRootCA -CryptoProviderName $ConfigFile.Settings.CAParameter.CryptoProvider -HashAlgorithm $ConfigFile.Settings.CAParameter.HashAlgorithm -KeyLength $configFile.Settings.CAParameter.KeyLength -Databasedirectory $ConfigFile.Settings.Directories.CADatabase -logDirectory $ConfigFile.Settings.Directories.CADatabase -ValidityPeriod $ConfigFile.Settings.CAParameter.ValidityPeriod -ValidityPeriodUnits $ConfigFile.Settings.CAParameter.ValidityPeriodUnits -OverwriteExistingKey -OverwriteExistingDatabase -Verbose -Force
    }

    certutil -setreg CA\DSdomainDN $ConfigFile.Settings.ADConfiguration.ADDistinguishedName
    $configDN = "CN=Configuration," + $ConfigFile.Settings.ADConfiguration.ADDistinguishedName
    certutil -setreg CA\DSConfigDN $configDN
    certutil -setreg CA\CRLPublicationURLs $ConfigFile.Settings.CRL.CDP
    certutil -setreg CA\CRLPeriod $ConfigFile.Settings.CRL.Period
    certutil -setreg CA\CRLPeriodUnits $ConfigFile.Settings.CRL.PeriodUnits
    certutil -setreg CA\CRLOverlapPeriod $ConfigFile.Settings.CRL.OverlapPeriod
    certutil -setreg CA\CRLOverlapPeriodUnits $ConfigFile.Settings.CRL.OverlapPeriodUnits
    certutil -setreg CA\CACertPublicationURLs $ConfigFile.Settings.AIA.PubPath
    certutil -setreg CA\ValidityPeriod $ConfigFile.Settings.SubCA.ValidityPeriod
    certutil -setreg CA\ValidityPeriodUnits $ConfigFile.Settings.SubCA.ValidityPeriodUnits
    Restart-Service certsvc

    Copy-Item $env:windir\System32\certSrv\CertEnroll\*.crt $ConfigFile.Settings.Directories.AIA

    foreach ($Crtfile in Get-ChildItem $AiaDir -Filter "$env:computerName*.crt")
    {
        $NewCrtFileName = $Crtfile.Name.Replace($env:ComputerName + "_", "")
        Move-Item $AiaDir\$Crtfile "$AiaDir\$NewCrtFilename"
    }

    certutil -CRL
}

Function Backup-RootCA
{
    Write-Verbose "----- Entering Backup-RootCA function -----"
    
    Start-Process -FilePath $CaBackupCMDFileName -Wait
}

Function Export-RootCert
{
    Write-Verbose "----- Entering Export-RootCert function -----"
    
    # Export Root CA cert in Base-64 encoded X.509 format
    $Cert = Get-ChildItem Cert:\LocalMachine\My -recurse | Where-Object {$_.Subject -eq "CN=Root CA"}
    Export-Certificate -Cert $Cert -FilePath C:\PKIData\RootCA_Base64.cer -Type CERT
    certutil -encode C:\PKIData\RootCA_Base64.cer C:\PKIData\RootCA_Base64.crt
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

Install-RootCA
Backup-RootCA
Export-RootCert

Stop-Transcript