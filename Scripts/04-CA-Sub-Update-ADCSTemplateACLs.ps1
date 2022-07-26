<#
NAME
    Update-ADCSTemplateACLs

SYNOPSIS
    Mofidifies all Explicit and Inherited ACEs on specified certificate templates

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

$ace0 = $null
$ace1 = $null
$ace2 = $null
$ace3 = $null
$ace4 = $null
$ace5 = $null
$ace6 = $null
$ace7 = $null
$nullGUID = [guid]'00000000-0000-0000-0000-000000000000'
$AutoEnrollGUID = [guid]'a05b8cc2-17bc-4802-a710-e7c15ab866a2'
$EnrollGUID = [guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'

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

Function Check-Prereqs
{
    Write-Verbose "----- Entering Check-Prereqs function -----"
    
    # Ensure script is run elevated
    If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}
    
    # Ensure RSAT-AD-PowerShell is installed
    If (!(Get-WindowsFeature RSAT-AD-PowerShell).Installed) {Add-WindowsFeature RSAT-AD-PowerShell}

    # Import modules
    Import-Module ActiveDirectory
    Import-Module -Name ADCSTemplate
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

Check-Prereqs

# Build array of certificate templates to modify and publish
$TemplateObjects = Get-ADCSTemplate | where {$_.DisplayName -like "$DomainName*"}
$TemplateObjects += Get-ADCSTemplate | where {$_.DisplayName -eq "RDS"}

ForEach ($TemplateObject in $TemplateObjects){
    $templateName = $TemplateObject.Name
    $TemplateDN = $TemplateObject.DistinguishedName
    $template = Get-ADObject ($TemplateDN) -ErrorAction SilentlyContinue
    $acl = Get-Acl "AD:$template"
    Write-Verbose -Message "Updating ACLs for Template: $templateName"

    # Remove existing explicit ACEs
    $acesToRemove = $acl.Access | where {$_.IsInherited -eq $false}

    foreach ($aceToRemove in $acesToRemove) {
        Write-Verbose -Message "...Remove: $aceToRemove.IdentityReference"
        $acl.RemoveACcessRule($aceToRemove)
    }
    # Break inheritance and remove other ACEs inherited from CN=Certificate Templates
    $acl.SetAccessRuleProtection($true, $false)
    Write-Verbose -Message "...Disable Inherited Permissions"

    #Add Read for all authenticated users
    $AuthenticatedUsers = [System.Security.Principal.SecurityIdentifier]'S-1-5-11'
    Write-Verbose -Message "...Add Authenticated Users"

    $ace0 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $AuthenticatedUsers,"ReadProperty, GenericExecute","Allow",$nullGUID,"None",$nullGUID

    # Add Enterprise Admins with Write/Read only
    $group = (Get-ADGroup "Enterprise Admins")
    $groupSid = new-object System.Security.Principal.SecurityIdentifier $group.SID
    $ace1 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"CreateChild, DeleteChild, Self, WriteProperty, DeleteTree, Delete, GenericRead, WriteDacl, WriteOwner","Allow","None",$nullGUID
   
    If($templateName -like "*DomainController*")
    {
        #DCs
        $group = (Get-ADGroup "Domain Controllers")
        $groupSid = new-object System.Security.Principal.SecurityIdentifier $group.SID

        # AutoEnroll Permissions (DCs)
        $ace2 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, GenericExecute, ExtendedRight","Allow",$AutoEnrollGUID,"None",$nullGUID 
        # Enroll  Permissions (DCs)
        $ace3 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, ReadProperty, GenericExecute, ExtendedRight","Allow",$EnrollGUID,"None",$nullGUID
        # Read  Permissions (DCs)
        $ace4 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericExecute","Allow",$nullGUID,"None",$nullGUID

        #RODCs
        $group = (Get-ADGroup "Enterprise Read-only Domain Controllers")
        $groupSid = new-object System.Security.Principal.SecurityIdentifier $group.SID

        # AutoEnroll Permissions (RODCs)
        $ace5 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, GenericExecute, ExtendedRight","Allow",$AutoEnrollGUID,"None",$nullGUID 
        # Enroll Permissions (RODC)
        $ace6 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, ReadProperty, GenericExecute, ExtendedRight","Allow",$EnrollGUID,"None",$nullGUID
        # Read Permissions (RODC)
        $ace7 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericExecute","Allow",$nullGUID,"None",$nullGUID
    }

    If($templateName -like "*Workstation*")
    {
        $group = (Get-ADGroup "Domain Computers")
        $groupSid = new-object System.Security.Principal.SecurityIdentifier $group.SID
        
        # AutoEnroll Permissions
        $ace2 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, GenericExecute, ExtendedRight","Allow",$AutoEnrollGUID,"None",$nullGUID 
        # Enroll Permissions
        $ace3 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, GenericExecute, ExtendedRight","Allow",$EnrollGUID,"None",$nullGUID 
        # Read Permissions
        $ace4 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericExecute","Allow",$nullGUID,"None",$nullGUID
    }

    If($templateName -like "*User*")
    {
        $group = (Get-ADGroup "Domain Users")
        $groupSid = new-object System.Security.Principal.SecurityIdentifier $group.SID
       
        # AutoEnroll Permissions
        $ace2 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, GenericExecute, ExtendedRight","Allow",$AutoEnrollGUID,"None",$nullGUID 

        # Enroll  Permissions
        $ace3 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, GenericExecute, ExtendedRight","Allow",$EnrollGUID,"None",$nullGUID 

        # Read Permissions
        $ace4 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericExecute","Allow",$nullGUID,"None",$nullGUID
    }

    If($templateName -like "*WebServer*")
    {
        # Enroll Permissions
        $group = (Get-ADGroup "Web Servers")
        $groupSid = new-object System.Security.Principal.SecurityIdentifier $group.SID
        
        # Enroll  Permissions
        $ace2 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, GenericExecute, ExtendedRight","Allow",$EnrollGUID,"None",$nullGUID 

        # Read Permissions
        $ace3 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericExecute","Allow",$nullGUID,"None",$nullGUID
    }

    If($templateName -eq "RDS")
    {
        $group = (Get-ADGroup "Domain Computers")
        $groupSid = new-object System.Security.Principal.SecurityIdentifier $group.SID
        
        # AutoEnroll Permissions
        $ace2 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, GenericExecute, ExtendedRight","Allow",$AutoEnrollGUID,"None",$nullGUID 
        # Enroll Permissions
        $ace3 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, GenericExecute, ExtendedRight","Allow",$EnrollGUID,"None",$nullGUID 
        # Read Permissions
        $ace4 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericExecute","Allow",$nullGUID,"None",$nullGUID

        #DCs
        $group = (Get-ADGroup "Domain Controllers")
        $groupSid = new-object System.Security.Principal.SecurityIdentifier $group.SID

        # AutoEnroll Permissions (DCs)
        $ace5 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, GenericExecute, ExtendedRight","Allow",$AutoEnrollGUID,"None",$nullGUID 
        # Enroll  Permissions (DCs)
        $ace6 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericRead, ReadProperty, GenericExecute, ExtendedRight","Allow",$EnrollGUID,"None",$nullGUID
        # Read  Permissions (DCs)
        $ace7 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $groupSid,"ReadProperty, GenericExecute","Allow",$nullGUID,"None",$nullGUID
    }

    $acl.AddAccessRule($ace0)
    $acl.AddAccessRule($ace1)
    If(!($ace2 -eq $null)){$acl.AddAccessRule($ace2)}
    If(!($ace3 -eq $null)){$acl.AddAccessRule($ace3)}
    If(!($ace4 -eq $null)){$acl.AddAccessRule($ace4)}
    If(!($ace5 -eq $null)){$acl.AddAccessRule($ace5)}
    If(!($ace6 -eq $null)){$acl.AddAccessRule($ace6)}
    If(!($ace7 -eq $null)){$acl.AddAccessRule($ace7)}
    # Update the ACL on the Template
    Set-Acl -Path "AD:$template" -AclObject $acl

    Write-Verbose -Message "Finished updating Template: $templateName"
    
    $ace0 = $null
    $ace1 = $null
    $ace2 = $null
    $ace3 = $null
    $ace4 = $null
    $ace5 = $null
    $ace6 = $null
    $ace7 = $null
}

# Restart service
$service = Get-Service | Where-Object {$_.Name -eq "certsvc"}
If($service.Status -eq "Running") {Restart-Service $service}
Else {Start-Service $service}

Stop-Transcript
