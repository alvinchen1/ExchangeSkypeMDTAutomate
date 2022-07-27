<# ############################################################################

TITLE:       Config-AD.ps1
DESCRIPTION: Creates OUs in AD for the solution
VERSION:     1.0.0

USAGE:       Elevated PowerShell prompt

REFERENCES:  https://docs.microsoft.com/en-us/powershell/module/activedirectory/new-adorganizationalunit

############################################################################ #>

Start-Transcript

Import-Module ActiveDirectory

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
$DomainDnsName = ($WS | ? {($_.Name -eq "DomainDnsName")}).Value
$PKI = ($XML.Component | ? {($_.Name -eq "PKI")}).Settings.Configuration
$CDP = ($PKI | ? {($_.Name -eq "CDP")}).Value
$CDPFQDN = $CDP + '.' + $DomainDnsName
$DomainContext = (Get-ADRootDSE).defaultNamingContext

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

Function Test-ADObject ($DN)
{
    $Status = ""
    $ADCheck = Get-ADObject "$DN"
    If ($ADCheck.DistinguishedName -eq $DN)
    {
        Write-Verbose "Checking: $DN already exists"
        $Status = $True
    }
    Else
    {
        Write-Verbose "Checking: $DN does NOT exist"
        $Status = $False
    }
    return $Status
}

Function Create-OUs
{
	Write-Verbose "----- Entering Create-OUs function -----"
    Write-Host "Creating OUs in the domain" -ForeGround "yellow" -back "black"
 	$OUs = ""
    $OUs = $Computers | ? {($_.Create -eq "True") -and ($_.DN -ne "")}
    $OUs+= $Accounts | ? {($_.Create -eq "True") -and ($_.DN -ne "")}
    $OUs+= $Groups | ? {($_.Create -eq "True") -and ($_.DN -ne "")}
    
    foreach ($OU in $OUs)
    {
        $DN = $OU.DN
        If (!(Test-ADObject $DN))
        {
            $ParentDN = "OU=" + ($DN -Split ",OU=", 2)[1]
            $OUName = (($DN -Split ",OU=", 2)[0] -Split "OU=", 2)[1]
            Write-Verbose "Binding to ParentDN: $ParentDN"
            Write-Verbose "Creating OUName: $OUName"
            New-ADOrganizationalUnit -Name $OUName -Path $ParentDN -ProtectedFromAccidentalDeletion $true
        }
    }
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Ensure script is run elevated
If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

# Creates the OUs
If(!(Get-ADOrganizationalUnit -LDAPFilter '(name=Accounts)' -SearchBase "$DomainContext" -SearchScope OneLevel)) 
    {New-ADOrganizationalUnit -Name "Accounts" -Path $DomainContext}
If(!(Get-ADOrganizationalUnit -LDAPFilter '(name=Admins)' -SearchBase "$DomainContext" -SearchScope OneLevel)) 
    {New-ADOrganizationalUnit -Name "Admins" -Path $DomainContext}
If(!(Get-ADOrganizationalUnit -LDAPFilter '(name=Groups)' -SearchBase "$DomainContext" -SearchScope OneLevel)) 
    {New-ADOrganizationalUnit -Name "Groups" -Path $DomainContext}
If(!(Get-ADOrganizationalUnit -LDAPFilter '(name=Servers)' -SearchBase "$DomainContext" -SearchScope OneLevel)) 
    {New-ADOrganizationalUnit -Name "Servers" -Path $DomainContext}
If(!(Get-ADOrganizationalUnit -LDAPFilter '(name=2019)' -SearchBase "OU=Servers,$DomainContext" -SearchScope OneLevel)) 
    {New-ADOrganizationalUnit -Name "2019" -Path "OU=Servers,$DomainContext"}
If(!(Get-ADOrganizationalUnit -LDAPFilter '(name=Workstations)' -SearchBase "$DomainContext" -SearchScope OneLevel)) 
    {New-ADOrganizationalUnit -Name "Workstations" -Path $DomainContext}
If(!(Get-ADOrganizationalUnit -LDAPFilter '(name=Win10)' -SearchBase "OU=Workstations,$DomainContext" -SearchScope OneLevel)) 
    {New-ADOrganizationalUnit -Name "Win10" -Path "OU=Workstations,$DomainContext"}
If(!(Get-ADOrganizationalUnit -LDAPFilter '(name=Physical)' -SearchBase "OU=Win10,OU=Workstations,$DomainContext" -SearchScope OneLevel)) 
    {New-ADOrganizationalUnit -Name "Physical" -Path "OU=Win10,OU=Workstations,$DomainContext"}
If(!(Get-ADOrganizationalUnit -LDAPFilter '(name=Virtual)' -SearchBase "OU=Win10,OU=Workstations,$DomainContext" -SearchScope OneLevel)) 
    {New-ADOrganizationalUnit -Name "Virtual" -Path "OU=Win10,OU=Workstations,$DomainContext"}

# Create CNAME for CDP
$TestDNS = Get-DnsServerResourceRecord -ZoneName $DomainDnsName -Name "pki" -RRType CName -ErrorAction "SilentlyContinue"
If(!($TestDNS)) {Add-DnsServerResourceRecordCName -Name "pki" -HostNameAlias $CDPFQDN -ZoneName $DomainDnsName}

Stop-Transcript
