<#
NAME
    New-CDP.ps1

SYNOPSIS
    Installs a CRL Distribution Point (CDP) on the IIS web server

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
If (!(Test-Path -Path $ConfigFile)) {Throw "ERROR: Unable to locate $ConfigFile Exiting..."} 
$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$DomainName = ($WS | ? {($_.Name -eq "DomainName")}).Value
$PKI = ($XML.Component | ? {($_.Name -eq "PKI")}).Settings.Configuration
$IssuingCA = ($PKI | ? {($_.Name -eq "IssuingCA")}).Value
$PkiFolder = ($PKI | ? {($_.Name -eq "PkiFolder")}).Value
$CrlFolder = "$PkiFolder\crl"
$CpFolder = "$PkiFolder\cp"
$CAAccountName = "$DomainName\$IssuingCA$"

$CAStatementContent = @"
This is our CA Policy File
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

Function Check-NTFS
{
    Write-Verbose "----- Entering Check-NTFS function -----"
    
    If (!(Test-Path $CrlFolder)) 
    {
        Write-Verbose -Message "Path does not exist"
        return $true  
    }
    Else
    {
        $Acl = (Get-Item $CrlFolder).GetAccessControl('Access')
        ForEach ($Item in $Acl)
        {
            $Ids = $Item | Select-Object -ExpandProperty Access
            ForEach ($Id in $Ids) 
            {
                If ($Id.IdentityReference -like "*$IssuingCA*") 
                {
                    Write-Verbose -Message "Permission already exists"
                    return $true
                }
            }
        }
        return $false
    }
}

Function Config-CRLShare
{
    Write-Verbose "----- Entering Config-CRLShare function -----"

    New-SmbShare -Name 'CRL' -Path $CrlFolder -Description "Share for PKI CRLs and Certs"
    Grant-SmbShareAccess -Name 'CRL' -AccountName $CAAccountName -AccessRight Full -Force
    Write-Verbose -Message "CRL share is created"
    $Acl = (Get-Item $CrlFolder).GetAccessControl('Access')
    $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($CAAccountName, 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $Acl.SetAccessRule($Ar)
    Set-Acl -path $CrlFolder -AclObject $Acl
    Write-Verbose -Message "ACLs Modified"
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

# Create PKI Directories 
If (!(Test-Path $PkiFolder)) {New-Item $PkiFolder -ItemType Directory}
If (!(Test-Path $CrlFolder)) {New-Item $CrlFolder -ItemType Directory}
If (!(Test-Path $CpFolder)) {New-Item $CpFolder -ItemType Directory}
$CAStatementContent | Out-File "$CpFolder\Root CA.htm" -Force

# Create CRL share and grant Issuing CA computer account access to the share
If (!(Check-NTFS)) {Config-CRLShare}

# Stop the default website
Import-Module WebAdministration
#Get-Website 'Default Web Site' | select * | fl 
Get-Website 'Default Web Site' | Stop-Website

# Create and start PKI website
If (!(Get-Website 'pki')) {New-WebSite -Name "pki" -Port 80 -HostHeader "pki" -PhysicalPath $PkiFolder}
Get-Website

# Config PKI site in IIS
If (!(Get-WebConfigurationProperty -filter /system.webServer/directoryBrowse -name enabled -PSPath 'IIS:\Sites\pki').Value)
{
    Set-WebConfigurationProperty -filter /system.webServer/directoryBrowse -name enabled -value true -PSPath 'IIS:\Sites\pki'
}
If (!(Get-WebConfigurationProperty -filter /system.webServer/security/requestFiltering -name allowDoubleEscaping -PSPath 'IIS:\Sites\pki').Value) 
{
    Set-WebConfigurationProperty -filter /system.webServer/security/requestFiltering -name allowDoubleEscaping -value true -PSPath 'IIS:\Sites\pki'
}

#Set-WebConfigurationProperty -PSPath 'IIS:\Sites\pki' -Filter 'system.webServer/security/requestFiltering' -Value @{VERB="OPTIONS";allowed="False"} -Name Verbs -AtIndex 0
#Get-WebConfiguration -filter 'system.webServer/security/requestFiltering/verbs/add' -PSPath 'IIS:\Sites\pki' | ft verb,allowed

# Test CDP URLs
Write-Host "`nTesting http://pki"
(Invoke-WebRequest http://pki -UseBasicParsing).StatusDescription

Write-Host "`nTesting http://pki/cp"
(Invoke-WebRequest http://pki/cp -UseBasicParsing).StatusDescription

Write-Host "`nTesting http://pki/crl"
(Invoke-WebRequest http://pki/crl -UseBasicParsing).StatusDescription

Stop-Transcript
