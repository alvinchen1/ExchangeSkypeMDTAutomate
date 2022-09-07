<#
NAME
    CA-Config-AD.ps1

SYNOPSIS
    Creates OUs in AD for the solution

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
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value
$PkgDir = "$InstallShare\Install-LAPS"
$LAPSFile = "LAPS.x64.msi"
$LogFile = "$Env:WINDIR\Temp\LAPS.x64.log"
$GPOZipFile = "$InstallShare\Import-GPOs\$Site.zip"
$LocalDir = "C:\temp\GPO\$DTG"

# Build arrays of computer OUs to delegate LAPS permissions
Import-Module ActiveDirectory
$DomainDN = (Get-ADRootDSE).defaultNamingContext
$DC = (Get-ADDomainController -Filter * | Select-Object Name | Sort-Object Name | Select-Object -First 1).Name

# Tier 0:
$Computers = 'CN=Computers,' + $DomainDN
$T0Servers = 'OU=T0-Servers,OU=Tier 0,OU=Admin,' + $DomainDN
$T0PAWs = 'OU=T0-PAWs,OU=Tier 0,OU=Admin,' + $DomainDN
$T0OUs = ($Computers,$T0Servers,$T0PAWs)

# Tier 2:
$T2PAWs = 'OU=T2-PAWs,OU=Tier 2,OU=Admin,' + $DomainDN
$T2Desktops = 'OU=Workstations,' + $DomainDN
$Quarantine = 'OU=Computer Quarantine,' + $DomainDN
$T2OUs = ($T2PAWs,$T2Desktops,$Quarantine)

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

Function Import-GPOs
{
    Write-Verbose "----- Entering Import-GPOs function -----"

    Test-FilePath ($GPOZipFile)
    Expand-Archive -LiteralPath $GPOZipFile -DestinationPath $LocalDir -Force
    Test-FilePath ("$InstallShare\Import-GPOs\Manage-AdObjects.ps1")
    Copy-Item -Path "$InstallShare\Import-GPOs\Manage-AdObjects.ps1" -Destination $LocalDir -Force
    cd $LocalDir
    .\Manage-AdObjects.ps1 -Restore -SettingsXml '.\settings.xml' -OU -User -Group -WmiFilter -GPO All -GpoLinks LinkEnabled -Permissions -RedirectContainers -LogFile '.\restore.log' -Confirm:$false
}

Function Add-LAPS-Module
{
    Write-Verbose "----- Entering Add-LAPS-Module function -----"

    # Ensure AdmPwd.PS module is installed on the member server
    $ComputerRole = (Get-WmiObject Win32_OperatingSystem).ProductType
    If (!(Get-Module -ListAvailable -Name AdmPwd.PS) -and ($ComputerRole -eq '3'))
    {
        $Manifest = "$PkgDir\$LAPSFile"
        foreach ($File in $Manifest) {Test-FilePath ($File)}

        Write-Progress -Activity "Installing LAPS" -Status "Install log location: $LogFile" -PercentComplete -1

        $FilePath = "$PkgDir\$LAPSFile"
        $Args = @(
        'ADDLOCAL=ALL'
        '/quiet'
        '/norestart'
        '/log'
        "$LogFile"
        )
        Start-Process -FilePath $FilePath -ArgumentList $Args -Wait

        Write-Progress -Activity "Installing LAPS" -Completed -Status "Completed"    
    }
}

Function Delegate-LAPS
{
    Write-Verbose "----- Entering Delegate-LAPS function -----"

    Add-LAPS-Module

    # Extend schema
    Import-Module AdmPwd.PS
    Update-AdmPwdADSchema
    
    # Delegate permissions on OUs containing computer objects
    
    foreach ($T0OU in $T0OUs)
    {
        Set-AdmPwdComputerSelfPermission -OrgUnit $T0OU
        Set-AdmPwdReadPasswordPermission -OrgUnit $T0OU -AllowedPrincipals "Tier0Admins"
        Set-AdmPwdResetPasswordPermission -OrgUnit $T0OU -AllowedPrincipals "Tier0Admins"
    }

    foreach ($T2OU in $T2OUs)
    {
        Set-AdmPwdComputerSelfPermission -OrgUnit $T2OU
        Set-AdmPwdReadPasswordPermission -OrgUnit $T2OU -AllowedPrincipals "Tier2Admins","Tier0Admins"
        Set-AdmPwdResetPasswordPermission -OrgUnit $T2OU -AllowedPrincipals "Tier2Admins","Tier0Admins"
    }
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

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Ensure script is run elevated
If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

Import-GPOs
Delegate-LAPS

# Move Issuing CA to OU to get apply GPOs upon restart
Get-ADComputer $env:COMPUTERNAME | Move-ADObject -TargetPath "OU=CA,OU=T0-Servers,OU=Tier 0,OU=Admin,$DomainDN" -Verbose

# Ensure Tier 0 Admins are added to Domain Admins
If (Test-ADObject ("CN=Tier 0 Admins,OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN")) 
{
    Get-ADGroup "Domain Admins" | Add-ADGroupMember -Members "CN=Tier 0 Admins,OU=T0-Admins,OU=T0-Groups,OU=Tier 0,OU=Admin,$DomainDN"
    Get-ADGroupMember "Domain Admins" | Select-Object -Property name, objectClass, distinguishedName | fl
}

Stop-Transcript
