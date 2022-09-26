<#
NAME
    AD-CONFIG-3.ps1

SYNOPSIS
    Creates OUs, service accounts, and security groups in AD for the solution

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
$PKI = ($XML.Component | ? {($_.Name -eq "PKI")}).Settings.Configuration
$RootCACred = ($PKI | ? {($_.Name -eq "RootCACred")}).Value
$DEFPASS = ConvertTo-SecureString -AsPlainText -Force -String $RootCACred

Import-Module ActiveDirectory
Import-Module GroupPolicy
$DomainDN = (Get-ADDomain).DistinguishedName

# =============================================================================
# FUNCTIONS
# =============================================================================

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

Function Set-ADConfig 
{
    Write-Verbose "----- Entering Set-ADConfig function -----"

    # --------------- Create OUs ---------------
    Write-Host -foregroundcolor green "Provisioning OUs"

    # STAGING OU
    If (!(Test-ADObject ("OU=STAGING,$DomainDN"))) 
        {New-ADOrganizationalUnit -Name "STAGING" -Path $DomainDN}
    If (!(Get-GPInheritance "OU=STAGING,$DomainDN").GpoInheritanceBlocked) 
        {Set-GPInheritance "OU=STAGING,$DomainDN" -IsBlocked Yes}

    # T0 top-level OUs
    If (!(Test-ADObject ("OU=Admin,$DomainDN"))) 
        {New-ADOrganizationalUnit -Name "Admin" -Path $DomainDN}
    If (!(Test-ADObject ("OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADOrganizationalUnit -Name "Tier 0" -Path "OU=Admin,$DomainDN"}

    # T0 Service Account OUs
    If (!(Test-ADObject ("OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADOrganizationalUnit -Name "T0-Service Accounts" -Path "OU=Tier 0,OU=Admin,$DomainDN"}
    If (!(Test-ADObject ("OU=DPM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADOrganizationalUnit -Name "DPM" -Path "OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"}
    If (!(Test-ADObject ("OU=MECM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADOrganizationalUnit -Name "MECM" -Path "OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"}
    If (!(Test-ADObject ("OU=NXPS,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADOrganizationalUnit -Name "NXPS" -Path "OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"}
    If (!(Test-ADObject ("OU=SLWD,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN")))
        {New-ADOrganizationalUnit -Name "SLWD" -Path "OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"}

    # T0 Groups OUs
    If (!(Test-ADObject ("OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADOrganizationalUnit -Name "T0-Groups" -Path "OU=Tier 0,OU=Admin,$DomainDN"}
    If (!(Test-ADObject ("OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADOrganizationalUnit -Name "T0-Admins" -Path "OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"}

    # --------------- Create Service Accounts ---------------
    Write-Host -foregroundcolor green "Provisioning Service Accounts"

    # SQL
    If (!(Test-ADObject ("CN=SVC-CM-SQL01,OU=MECM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADUser SVC-CM-SQL01 -Accountpassword $DEFPASS -Description "MECM SQL Account" -DisplayName "SVC-CM-SQL01" -Path "OU=MECM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN" -Enabled $true}

    # MECM
    If (!(Test-ADObject ("CN=SVC-CM-NAA,OU=MECM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADUser SVC-CM-NAA -Accountpassword $DEFPASS -Description "MECM Network Access Account" -DisplayName "SVC-CM-NAA" -Path "OU=MECM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN" -Enabled $true}
    If (!(Test-ADObject ("CN=SVC-CM-CLIPUSH,OU=MECM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADUser SVC-CM-CLIPUSH -Accountpassword $DEFPASS -Description "MECM PUSH Account" -DisplayName "SVC-CM-CLIPUSH" -Path "OU=MECM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN" -Enabled $true}
    If (!(Test-ADObject ("CN=SVC-CM-RSP,OU=MECM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADUser SVC-CM-RSP -Accountpassword $DEFPASS -Description "MECM Reporting Service Account" -DisplayName "SVC-CM-RSP" -Path "OU=MECM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN" -Enabled $true}

    # DPM
    If (!(Test-ADObject ("CN=SVC-DPMSQL-01,OU=DPM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADUser SVC-DPMSQL-01 -Accountpassword $DEFPASS -Description "DPM SQL Account" -DisplayName "SVC-DPMSQL-01" -Path "OU=DPM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN" -Enabled $true}
    If (!(Test-ADObject ("CN=SVC-DPM-RSP,OU=DPM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADUser SVC-DPM-RSP -Accountpassword $DEFPASS -Description "DPM Reporting Service Account" -DisplayName "SVC-DPM-RSP" -Path "OU=DPM,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN" -Enabled $true}

    # SOLARWINDS
    If (!(Test-ADObject ("CN=SVC-SW-SQL01,OU=SLWD,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADUser SVC-SW-SQL01 -Accountpassword $DEFPASS -Description "SOLARWINDS SQL Account" -DisplayName "SVC-SW-SQL01" -Path "OU=SLWD,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN" -Enabled $true}

    # General
    If (!(Test-ADObject ("CN=SVC-TASK-SCHED,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADUser SVC-TASK-SCHED -Accountpassword $DEFPASS -Description "TASK Schedule Account" -DisplayName "SVC-TASK-SCHED" -Path "OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN" -Enabled $true}
    If (!(Test-ADObject ("CN=SVC-CLUS-WIT01,OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADUser SVC-CLUS-WIT01 -Accountpassword $DEFPASS -Description "Cluster Witness Account" -DisplayName "SVC-CLUS-WIT01" -Path "OU=T0-Service Accounts,OU=Tier 0,OU=Admin,$DomainDN" -Enabled $true}

    # --------------- Create Groups ---------------
    Write-Host -foregroundcolor green "Provisioning Security Groups"

    If (!(Test-ADObject ("CN=ADM-SQL-ADMINS,OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADGroup "ADM-SQL-ADMINS" -GroupScope "DomainLocal" -Description "SQL Servers Group" -Path "OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"}
    If (!(Test-ADObject ("CN=MECM-FULLAdministrator,OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADGroup "MECM-FULLAdministrator" -GroupScope "DomainLocal" -Description "MECM FULL Administrator" -Path "OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"}
    If (!(Test-ADObject ("CN=MECM-SoftwareUpdateMgr,OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADGroup "MECM-SoftwareUpdateMgr" -GroupScope "DomainLocal" -Description "MECM Software Update Manager" -Path "OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"}
    If (!(Test-ADObject ("CN=MECM-OperationAdmin,OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADGroup "MECM-OperationAdmin" -GroupScope "DomainLocal" -Description "MECM Operation Administrator" -Path "OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"}
    If (!(Test-ADObject ("CN=MECM-EndPointMgr,OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"))) 
        {New-ADGroup "MECM-EndPointMgr" -GroupScope "DomainLocal" -Description "MECM EndPoint Protection Manager" -Path "OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"}
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

Set-ADConfig

Stop-Transcript
