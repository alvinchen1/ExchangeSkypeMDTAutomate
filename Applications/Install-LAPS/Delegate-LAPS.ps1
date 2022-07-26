<# ############################################################################

TITLE:       Install-LAPS-AD.ps1
DESCRIPTION: Installs Local Administrator Password Solution (LAPS) for AD
VERSION:     1.0.0

USAGE:       Elevated PowerShell prompt

############################################################################ #>


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

# Build array of computer OUs to delegate permissions
$ComputerOU = 'CN=Computers,' + $DomainDistinguishedName
$ServersOU = 'OU=Servers,' + $DomainDistinguishedName
$WorkstationsOU = 'OU=Workstations,' + $DomainDistinguishedName
$TopLevelComputerOUs = ($ComputerOU,$ServersOU,$WorkstationsOU)

$AdmPwdGroup = "Administrators"

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

# Ensure script is run elevated
If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

# Extend schema
Import-Module AdmPwd.PS
Update-AdmPwdADSchema

# Delegate permissions on OUs containing computer objects
foreach ($OU in $TopLevelComputerOUs)
{
    Set-AdmPwdComputerSelfPermission -OrgUnit $OU
    Set-AdmPwdReadPasswordPermission -OrgUnit $OU -AllowedPrincipals $AdmPwdGroup
    Set-AdmPwdResetPasswordPermission -OrgUnit $OU -AllowedPrincipals $AdmPwdGroup
}

Write-Host "`n$ScriptName Complete.`n" -ForeGround "yellow" -back "black"
