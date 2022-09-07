<#
NAME
    Config-XADGPO.ps1

SYNOPSIS
    Creates Exchange GPO(s) in the domain

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
$Deployment = ($XML.Component | ? {($_.Name -eq "Deployment")}).Settings.Configuration
$Site = ($Deployment | ? {($_.Name -eq "Site")}).Value
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$DomainName = ($WS | ? {($_.Name -eq "DomainName")}).Value
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value
$GPOZipFileExch = "$InstallShare\Import-GPOs\Exchange.zip"
$LocalDir = "C:\temp\ExchGPO\$DTG"

$GPOs = @(
'DC-WS2019-Exchange'
)

Import-Module ActiveDirectory
$DomainDN = (Get-ADRootDSE).defaultNamingContext
$DC = (Get-ADDomainController -Filter * | Select-Object Name | Sort-Object Name | Select-Object -First 1).Name

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

Function Test-XCert ($CertTemplate)
{
    Write-Host "Checking if certificate derived from $CertTemplate is in local store"
    $CertCheck = [bool] (Get-ChildItem Cert:\LocalMachine\My | ? {$_.Extensions.format(1)[0] -match "Template=$CertTemplate"})
    Write-Host $CertCheck
    return $CertCheck
}

Function Import-GPOs
{
    Write-Verbose "----- Entering Import-GPOs function -----"

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

    # Import GPO(s)
    Import-Module GroupPolicy
    foreach ($GPO in $GPOs) {Import-GPO -BackupGpoName $GPO -TargetName $GPO -Path "$LocalDir\Exchange" -CreateIfNeeded}

    # Link GPO(s)
    New-GPLink -Name "DC-WS2019-Exchange" -Target "OU=Domain Controllers,$DomainDN" -LinkEnabled Yes -Order 1
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

Import-GPOs

# Check if certificate from 'DOMAIN Web Server' template successfully imported
#Test-XCert ("$DomainName Web Server")

Stop-Transcript
