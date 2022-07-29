
###################################################################################################
##################### USS-MECM-CONFIG-2.ps1 ###################################################
###################################################################################################

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Extend the AD Schema for MECM
# -Create the SYSTEM MANAGEMENT Container for MECM
#
# *** Before runnng this script ensure that ALL the PREREQ and Software to install WSUS is located in the
# WSUS_STAGING folder on the MDT STAGING Share. ***

# You must run this PowerShell command with an account with Schema Admin permission. It is needed to
# extend the AD Schema for MECM and to create the System Management container in Active Directory.


###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-MECM-CONFIG-2.log
Start-Transcript -Path \\DEV-MDT-01\DEPLOYMENTSHARE$\LOGS\$env:COMPUTERNAME\USS-MECM-CONFIG-2.log

###################################################################################################
### Modify These Values
### ENTER MECM Server host names.
# MDT will set host name in OS
$MECMSRV = "USS-SRV-14"

### ENTER MDT STAGING FOLDER
$MDTSTAGING = "\\DEV-MDT-01\STAGING"

### ENTER SCCM STAGING FOLDER
# $-SCCMSTAGING = "\\SRV-MDT-01\STAGING\SCCM_STAGING"

###################################################################################################
### Extend the AD Schema for MECM 
# C:\SCCM_STAGING\MECM_CB_2103_ExtendSchema\X64\extadsch.exe
Write-Host -foregroundcolor green "Extending AD Schema for MECM..."
& $MDTSTAGING\MECM_CB_2103_ExtendSchema\X64\extadsch.exe

###################################################################################################
### Create the SYSTEM MANAGEMENT Container for MECM
#
# Method 2: Using Active Directory module with the Get-Acl and Set-Acl cmdlets
# You can use the script below to get and assign Full Control permission to a computer object on an OU:
#
# Load the AD module
# Import-Module ActiveDirectory
# Get-Module -ListAvailable
#
# Note the Add-WindowsFeature RSAT-AD-PowerShell command requires a SYSTEM REBOOT to take affect.
#
# Install the ActiveDirectory module for powershell 
# This is only needed to create the MECM System Management container on a domain controller.
# Add-WindowsFeature RSAT-AD-PowerShell
# Get the Forest root DN.
Write-Host -foregroundcolor green "Creating SYSTEM MANAGEMENT Container for MECM..."

$root = (Get-ADRootDSE).defaultNamingContext

# Get or Create the System Management container
$ou = $null
try
{
$ou = Get-ADObject "CN=System Management,CN=System,$root"
}
catch
{
Write-Verbose "System Management container does not currently exist."
}


if ($ou -eq $null)
{
$ou = New-ADObject -Type Container -name "System Management" -Path "CN=System,$root" -Passthru
}

# $acl = get-acl "ad:OU=xxx,DC=com"
# $acl = get-acl "ad:CN=System Management1,CN=SYSTEM,DC=USS,DC=LOCAL"
$acl = get-acl "ad:CN=System Management,CN=System,$root"

# Get access right of the current OU
$acl.access 

# Get/Set the computer object which will be assigned with Full Control permission within the OU
# $computer = get-adcomputer "USS-SRV-14"
$computer = get-adcomputer $MECMSRV

# Get the SID of the computer.
$sid = [System.Security.Principal.SecurityIdentifier] $computer.SID

# Create a new access control entry to allow access to the OU
$identity = [System.Security.Principal.IdentityReference] $SID
$adRights = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
$type = [System.Security.AccessControl.AccessControlType] "Allow"
$inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
$ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $identity,$adRights,$type,$inheritanceType

# Add the ACE to the ACL, then set the ACL to save the changes
$acl.AddAccessRule($ace)

# Set-acl -aclobject $acl "ad:CN=System Management1,CN=SYSTEM,DC=USS,DC=LOCAL"
Set-acl -aclobject $acl "ad:CN=System Management,CN=System,$root"

# Uninstall the ActiveDirectory module for powershell 
# This is only needed to create the MECM System Management container on a domain controller.
Write-Host -foregroundcolor green "Uninstalling RSAT..."
Uninstall-WindowsFeature RSAT-AD-PowerShell


###################################################################################################
Stop-Transcript

