<#
NAME
    AD-CONFIG-2.ps1

SYNOPSIS
    Installs AD DS, DNS, and GPMC features for AD forest
    Creates a new AD forest and adds a DC
    Enables Remote Desktop and prevents Server Manager from loading at startup

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
$DomainDnsName = ($WS | ? {($_.Name -eq "DomainDnsName")}).Value
$DomainName = ($WS | ? {($_.Name -eq "DomainName")}).Value
$PKI = ($XML.Component | ? {($_.Name -eq "PKI")}).Settings.Configuration
$RootCACred = ($PKI | ? {($_.Name -eq "RootCACred")}).Value
$DSRMPASS = ConvertTo-SecureString -AsPlainText -Force -String $RootCACred

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Add prerequisites (Windows Features) to build an Active Directory forest
Add-WindowsFeature -Name "AD-Domain-Services,DNS,GPMC" -IncludeAllSubFeature -IncludeManagementTools

# Install AD Forest
Install-ADDSForest -CreateDnsDelegation:$false `
-DomainName $DomainDnsName `
-SafeModeAdministratorPassword $DSRMPASS `
-DatabasePath "C:\Windows\NTDS" `
-DomainNetbiosName $DomainName `
-ForestMode "7" `
-DomainMode "7" `
-LogPath "C:\Windows\NTDS" `
-InstallDns:$true `
-NoRebootOnCompletion:$true `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true

Stop-Transcript
