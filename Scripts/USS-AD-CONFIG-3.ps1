################### USS-AD-CONFIG-3 ################################################################


### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Create OUs
# -Create MSQL Service Accounts
# -Create MECM Service Accounts
# -Create Admin Security Groups
# -Populate Security Group Membership
# -(OPTIONAL) Create Base SSLF GPOs
 
# This script prerequisite is an existing AD Forest.

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-AD-CONFIG-3.log
Start-Transcript -Path \\SRV-MDT-01\DEPLOYMENTSHARE$\LOGS\USS-AD-CONFIG-3.log

###################################################################################################
### BEGING OU, ACCOUNTS and GROUP CREATIONS

Function ProvisionForest {
#Get Distinguished Name of Forest
$DN = (Get-ADDomain).DistinguishedName
#Verify that OU structure does not already exist
try
{
    Get-ADOrganizationalUnit -Identity "OU=Resources,$DN" | Out-Null
    Write-Host  -foregroundcolor red "Forest is already provisioned SCRIPT IS HALTING!!!!!"
    Start-Sleep 10
    Stop-Process -processname powershell
}
catch
{
    Write-Host -foregroundcolor green "Forest has not been provisioned SCRIPT WILL CONTINUE!"
}  

### Set partial path for Services OU
# $SR = "OU=Services,OU=Resources"

### Set partial path for ACCOUTS OU
# $ACT = "OU=ACCOUNTS"

### Set partial path for SERVERS OU
# $IN = "OU=Install,OU=Accounts,OU=Resources"
# $SVR = "OU=SERVERS"


### Set partial path for Admin Groups OU
# $AG = "OU=Admin Groups,OU=Groups,OU=Resources"

###################################################################################################
### Create OUs
Write-Host -foregroundcolor green "Provisioning OUs"
# New-ADOrganizationalUnit Accounts -Path "OU=Resources,$DN" -ProtectedFromAccidentalDeletion 0
# New-ADOrganizationalUnit Admins -Path "OU=Accounts,OU=Resources,$DN" -ProtectedFromAccidentalDeletion 0
# New-ADOrganizationalUnit Service -Path "OU=Accounts,OU=Resources,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit ADMINS -Path "$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit GROUPS -Path "$DN" -ProtectedFromAccidentalDeletion 0
# New-ADOrganizationalUnit STAGING -Path "$DN" -ProtectedFromAccidentalDeletion 0

# ACCOUNTS OUs
New-ADOrganizationalUnit ACCOUNTS -Path "$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit DPM -Path "OU=ACCOUNTS,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit MECM -Path "OU=ACCOUNTS,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit NXPS -Path "OU=ACCOUNTS,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit SLWD -Path "OU=ACCOUNTS,$DN" -ProtectedFromAccidentalDeletion 0

# SERVERS OUs
New-ADOrganizationalUnit SERVERS -Path "$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit 2019 -Path "OU=SERVERS,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit PA -Path "OU=2019,OU=SERVERS,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit PM -Path "OU=2019,OU=SERVERS,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit PS -Path "OU=2019,OU=SERVERS,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit PV -Path "OU=2019,OU=SERVERS,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit TST -Path "OU=2019,OU=SERVERS,$DN" -ProtectedFromAccidentalDeletion 0

# USER ACCOUNTS OUs
New-ADOrganizationalUnit "USER ACCOUNTS" -Path "$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit "DISABLED USERS" -Path "OU=USER ACCOUNTS,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit "ENABLED USERS" -Path "OU=USER ACCOUNTS,$DN" -ProtectedFromAccidentalDeletion 0

# WORKSTATIONS OUs
New-ADOrganizationalUnit WORKSTATIONS -Path "$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit WIN10 -Path "OU=WORKSTATIONS,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit PHYSICAL -Path "OU=WIN10,OU=WORKSTATIONS,$DN" -ProtectedFromAccidentalDeletion 0
New-ADOrganizationalUnit VIRTUAL -Path "OU=WIN10,OU=WORKSTATIONS,$DN" -ProtectedFromAccidentalDeletion 0

###################################################################################################
### Create ACCOUNTS
#
### Create MSQL Service Accounts
# New-ADUser RFsvcDBSCluster -ChangePasswordAtLogon $true -Description "SQL Cluster Service Account" -DisplayName "RFsvcDBSCluster" -Path "OU=SvcAccts,OU=DBS,$SR,$DN"
# New-ADUser RFsvcDBSAgent -ChangePasswordAtLogon $true -Description "SQL Agent Service Account" -DisplayName "RFsvcDBSAgent" -Path "OU=SvcAccts,OU=DBS,$SR,$DN"
# New-ADUser RFsvcDBSAnlyss -ChangePasswordAtLogon $true -Description "SQL Analysis Service Account" -DisplayName "RFsvcDBSAnlyss" -Path "OU=SvcAccts,OU=DBS,$SR,$DN"

# TODO: Pull this password value from an environment variable
#$DEFPASS = (ConvertTo-SecureString -String ... -AsPlainText -Force)
New-ADUser SVC-CM-SQL01 -Accountpassword $DEFPASS -Description "MECM SQL Account" -DisplayName "SVC-CM-SQL01" -Path "OU=MECM,OU=ACCOUNTS,$DN" -Enabled $true

### Create MECM Service Accounts
# New-ADUser RFsvcCMDomJon -ChangePasswordAtLogon $true -Description "CM Domain Join Service Account" -DisplayName "RFsvcCMDomJon" -Path "OU=SvcAccts,OU=CM,$SR,$DN"
# New-ADUser RFsvcCMNetAcs -ChangePasswordAtLogon $true -Description "CM Network Access Service Account" -DisplayName "RFsvcCMNetAcs" -Path "OU=SvcAccts,OU=CM,$SR,$DN"
$DEFPASS = (ConvertTo-SecureString -String Passw0rd99 -AsPlainText -Force)
New-ADUser SVC-CM-NAA -Accountpassword $DEFPASS -Description "MECM Network Access Account" -DisplayName "SVC-CM-NAA" -Path "OU=MECM,OU=ACCOUNTS,$DN" -Enabled $true
New-ADUser SVC-CM-CLIPUSH -Accountpassword $DEFPASS -Description "MECM PUSH Account" -DisplayName "SVC-CM-CLIPUSH" -Path "OU=MECM,OU=ACCOUNTS,$DN" -Enabled $true

### Create DPM Service Accounts
New-ADUser SVC-DPMSQL-01 -Accountpassword $DEFPASS -Description "DPM SQL Account" -DisplayName "SVC-DPMSQL-01" -Path "OU=DPM,OU=ACCOUNTS,$DN" -Enabled $true

### Create General Use Accounts
New-ADUser SVC-TASK-SCHED -Accountpassword $DEFPASS -Description "TASK Schedule Account" -DisplayName "SVC-TASK-SCHED" -Path "OU=ACCOUNTS,$DN" -Enabled $true
New-ADUser SVC-CLUS-WIT01 -Accountpassword $DEFPASS -Description "Cluster Witness Account" -DisplayName "SVC-CLUS-WIT01" -Path "OU=ACCOUNTS,$DN" -Enabled $true

###################################################################################################
### Create GROUPS
#
### Create Admin Security Groups
# New-ADGroup "RF CM Admins" -GroupScope Global -Description "ConfigMgr Enterprise Administrators" -Path "$AG,$DN"
# New-ADGroup "RF CM Reporting Users" -GroupScope Global -Description "Users with Read-only Access to the ConfigMgr Reporting Point" -Path "$AG,$DN"
# New-ADGroup "RF CM Servers" -GroupScope Global -Description "ConfigMgr Servers Group for the Enterprise" -Path "$AG,$DN"
Write-Host -foregroundcolor green "Provisioning Security Groups"
New-ADGroup "ADM-SQL-ADMINS" -GroupScope "DomainLocal" -Description "SQL Servers Group" -Path "OU=GROUPS,$DN"
New-ADGroup "MECM-FULLAdministrator" -GroupScope "DomainLocal" -Description "MECM FULL Administrator" -Path "OU=GROUPS,$DN"
New-ADGroup "MECM-SoftwareUpdateMgr" -GroupScope "DomainLocal" -Description "MECM Software Update Manager" -Path "OU=GROUPS,$DN"
New-ADGroup "MECM-OperationAdmin" -GroupScope "DomainLocal" -Description "MECM Operation Administrator" -Path "OU=GROUPS,$DN"
New-ADGroup "MECM-EndPointMgr" -GroupScope "DomainLocal" -Description "MECM EndPoint Protection Manager" -Path "OU=GROUPS,$DN"

### Populate Security Group Membership
# Write-Host -foregroundcolor green "Provisioning Security Group Memberships"

# Add-ADGroupMember "RF DPM Admins" -Members "RF Full Admins", "RFsvcDPMInstall"

# Add-ADGroupMember "RF RDP Admins" -Members "RF Full Admins", "RF Local Admins", "RF DPM Admins", "RF MGT Admins","RF MSCS Admins", "RF DBS Admins"

# Add-ADGroupMember "RF MSCS Admins" -Members "RFsvcCLInstall", "RF Full Admins"
# Add-ADGroupMember "RF DBS Admins" -Members "RF Full Admins", "RFsvcDBSInstall", "RFsvcDBSAgent", "RFsvcDBSAnlyss", "RFsvcDBSServer"

#Create Base SSLF GPOs
# Write-Host -foregroundcolor green "Provisioning Base SSLF GPOs"
# Import-GPO -BackupId c51f4cd2-24a9-47b5-be8a-c6f80e9e4b4c -Path "C:\GPO Backups" -TargetName "WS08R2-SSLF-Domain 1.0" -CreateIfNeeded
# Import-GPO -BackupId 29d29f9d-bd52-442f-9c5a-ae927d7266bb -Path "C:\GPO Backups" -TargetName "WS08R2-SSLF-Domain-Controller 1.0" -CreateIfNeeded
# Import-GPO -BackupId 939c0627-c15a-44fc-8198-0191c52c6131 -Path "C:\GPO Backups" -TargetName "WS08R2-SSLF-Member-Server 1.0" -CreateIfNeeded
}

ProvisionForest

###################################################################################################
Stop-Transcript


