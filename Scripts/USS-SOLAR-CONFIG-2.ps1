###################################################################################################
##################### USS-SOLAR-CONFIG-2.ps1 ###################################################
###################################################################################################

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Create Folders for SQL Install
# -Set SQL Service account permission on SQL Folders
# -Install SQL Server 2019 Enterprise Edition
# --Install SQL 2019 using SQL Configuration file
# -Set Windows Firewall ports for SQL
# -Set SQL Service Accounts SPN
# -Install Latest Cumulative Update Package for SQL Server 2019
# -Install SQL SSMS 18.8
# -ADD DEFENDER WSUS Exclusions
 
# *** Before runnng this script ensure that the following drive exist on the SOLAR Site server ***
#
# (C:)(120gb+) RAID 1 OS - Page file (4k, NTFS)
# (D:)(250gb+) RAID 1 SOLAR - SCCM Inboxes, SCCMContentlib (4k, NTFS)
# (E:)(300gb+) RAID 1 WSUS/SUP, DP Content, MDT (4k, NTFS)
# (F:)(50gb+) RAID 5 SQLDB - (64k BlockSize, ReFS)
# (G:)(60gb+) RAID 1 SQLLOGS - transaction logs,UserDBlog, SQL TempDB logs, SCCMBackup (64k BlockSize, ReFS)
#
###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-SOLAR-CONFIG-2.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-SOLAR-CONFIG-2.log

###################################################################################################
### MODIFY These Values
### ENTER SQL INFO
$SQLSVRNAME = "USS-SRV-60"
$SQLSVRACCT = "SVC-SW-SQL01"
$DOMNAME = 'USS.LOCAL'

### ENTER MDT STAGING FOLDER
$MDTSTAGING = "\\DEP-MDT-01\STAGING"

### ENTER SQL CONFIGURATION FILE
# Note this file needs to be in the MDT STAGING folder (D:\STAGING\SCRIPTS\SOLARWINDS)
$SQLCONFIGFILE = "USS_SQL2019ForSW.ini"


###################################################################################################
### CREATE SQL FOLDERS 
# The SC-SRV-14 server will be used as the SQL server
# This should be ran on the SQL server.
#
# Run this script on the SQL SERVER (SAT-SRV-14).
#
# Create Folders for SQL Install:
# Grant the SQL service account (SVC-SW-SQL01) full control to the below folders.
# Note if SQL will be installed on a single storage/LUNS, then the folders can all be on the same drive letter.
# Note if this will be a multi-SQL instance, and all the SQL files will be place on a single storage/LUNS, 
# -then create one drive letter per SQL instance. Meaning if you will have a SCCM and SCOM SQL instance then create a D:\MSSQL and an E:\MSSQL folder/VHDX.
# After folder creation, Grant the SQL service account (SVC-SW-SQL01) full control to the above folders.
Write-Host -foregroundcolor green "Create Folders for SQL..."

New-Item F:\MSSQL –Type Directory
New-Item F:\MSSQL\TempDB –Type Directory
New-Item F:\MSSQL\UserDB –Type Directory
New-Item G:\MSSQL –Type Directory
New-Item G:\MSSQL\UserDBLOG –Type Directory
New-Item G:\MSSQL\TempDBLogs –Type Directory
New-Item G:\MSSQLBackup –Type Directory
New-Item E:\SRSReportKeys –Type Directory

###################################################################################################
### Grant SQL Service account Full Control to SQL Folders (F:\MSSQL)
# Note you need to grant the SVC-SW-SQL01 service account full control to these folders.
# Get-Acl F:\MSSQL | Format-List
Write-Host -foregroundcolor green "Grant SQL Service account Full Control to SQL Folders..."

$ssa = Get-Acl F:\MSSQL
$ssa.SetAccessRuleProtection($True, $False)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SVC-CM-NAA permissions to the SCCM folders.
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa.AddAccessRule($rule)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-SW-SQL01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa.AddAccessRule($rule)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("ADM-SQL-ADMINS","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa.AddAccessRule($rule)

# Applied to This Folder, Subfolders and Files
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa.AddAccessRule($rule)

# Apply the permision to the folder
Set-Acl F:\MSSQL $ssa

### Grant SQL Service account Full Control to SQL Folders (G:\MSSQL)

$ssa1 = Get-Acl G:\MSSQL
$ssa1.SetAccessRuleProtection($True, $False)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SVC-SW-SQL01 permissions to the SCCM folders.
$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa1.AddAccessRule($rule1)

$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-SW-SQL01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa1.AddAccessRule($rule1)

$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("ADM-SQL-ADMINS","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa1.AddAccessRule($rule1)

# Applied to This Folder, Subfolders and Files
$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa1.AddAccessRule($rule1)

# Apply the permision to the folder
Set-Acl G:\MSSQL $ssa1

### Grant SQL Service account Full Control to SQL Folders (E:\SRSReportKeys)

$ssa2 = Get-Acl E:\SRSReportKeys
$ssa2.SetAccessRuleProtection($True, $False)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SVC-SW-SQL01 permissions to the SCCM folders.
$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa2.AddAccessRule($rule2)

$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-SW-SQL01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa2.AddAccessRule($rule2)

$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("ADM-SQL-ADMINS","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa2.AddAccessRule($rule2)

# Applied to This Folder, Subfolders and Files
$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa2.AddAccessRule($rule2)

# Apply the permision to the folder
Set-Acl E:\SRSReportKeys $ssa2

### Grant SQL Service account Full Control to SQL Folders (G:\MSSQLBackup)

$ssa3 = Get-Acl G:\MSSQLBackup
$ssa3.SetAccessRuleProtection($True, $False)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SVC-SW-SQL01 permissions to the SCCM folders.
$rule3 = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa3.AddAccessRule($rule3)

$rule3 = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-SW-SQL01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa3.AddAccessRule($rule3)

$rule3 = New-Object System.Security.AccessControl.FileSystemAccessRule("ADM-SQL-ADMINS","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa3.AddAccessRule($rule3)

# Applied to This Folder, Subfolders and Files
$rule3 = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa3.AddAccessRule($rule3)

# Apply the permision to the folder
Set-Acl G:\MSSQLBackup $ssa3


###################################################################################################
### Install SQL Server 2019 Enterprise Edition 
#### The script below assumes all SQL files have been copied to the D:\SCCM_STAGING\SQL_2019_ENT\ folders.
# Run this on the SCCM site server (XXX-SRV-14)
#
# Set Windows Firewall ports for SQL
# The default instance of SQL Server listens on Port 1433. Port 1434 is used by the SQL Browser Service which allows 
# connections to named instances of SQL Server that use dynamic ports with out having to know what port each named 
# instance is using, especially since this can change between restarts of the named instance.
# Note the ports below open the firewall for SQL and SQL Reporting Services
### Set SQL Firewall Ports
Write-Host -foregroundcolor green "Set SQL Firewall Ports..."
New-NetFirewallRule -DisplayName “SQL TCP Ports” -Direction Inbound –Protocol TCP -Profile Domain –LocalPort 80,443,2382,2383,1433,1434,4022 -Action allow
New-NetFirewallRule -DisplayName “SQL UDP Ports” -Direction Inbound –Protocol UDP -Profile Domain –LocalPort 1434,4022 -Action allow

### Set SQL Service Accounts SPN
# Run on the Site Server or domain controller
# setspn -A MSSQLSvc/SAT-SRV-14.SATURN.LAB:1433 SVC-SW-SQL01
# setspn -A MSSQLSvc/SAT-SRV-14:1433 SVC-SW-SQL01
Write-Host -foregroundcolor green "Set SQL Service Accounts SPN..."
setspn -A MSSQLSvc/"$SQLSVRNAME.$DOMNAME":1433 $SQLSVRACCT
setspn -A MSSQLSvc/"$SQLSVRNAME":1433 $SQLSVRACCT

###################################################################################################
### COPY SQL CONFIGURATION FILE TO LOCAL DRIVE 
# Copy-Item $MDTSTAGING\SCRIPTS\USS_SQL2019ForSCCM2103.ini -Destination C:\Windows\Temp -Recurse -Force
Write-Host -foregroundcolor green "COPY SQL CONFIGURATION FILE TO LOCAL DRIVE..."
Copy-Item $MDTSTAGING\SCRIPTS\SOLARWINDS\$SQLCONFIGFILE -Destination C:\Windows\Temp\$SQLCONFIGFILE -Recurse -Force

### Install SQL 2019 using SQL Configuration file
# Take a Snapshot/Checkpoint of VM.
# 
# Start-Process "$MDTSTAGING\SQL_2019_ENT\Setup.exe" -Wait -NoNewWindow -ArgumentList '/QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile=C:\Windows\Temp\USS_SQL2019ForSCCM2103.ini'
# Start-Process "$MDTSTAGING\SQL_2019_ENT\Setup.exe" -Wait -NoNewWindow -ArgumentList '/QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile="C:\Windows\Temp\SQL2019ForSCCM2103.ini"'
#
Write-Host -foregroundcolor green "Installing SQL 2019 using SQL Configuration file"
Start-Process "$MDTSTAGING\SQL_2019_ENT\Setup.exe" -Wait -NoNewWindow -ArgumentList '/QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile=C:\Windows\Temp\USS_SQL2019ForSW.ini'

# Install Latest Cumulative Update Package for SQL Server 2019
# C:\SCCM_STAGING\SQL_2019_CU20\SQLServer2017-KB4541283-x64.exe /ACTION=INSTALL /QUIETSIMPLE /ALLINSTANCES /ENU /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS 
# Install Latest Cumulative Update Package for SQL Server 2019
## JohnNote ****This line did not work ****After CUxx install confirm SQL Version is 15.0.xxxx.xxx
# Use the "-NoNewWindow" switch if you get the following error message when attempting to run a script from a network share:
# - "Open File – Security Warning” dialog box that says “We can’t verify who created this file. Are you sure you want to open this file?”
# C:\SCCM_STAGING\SQL_2019_CU15\SQLServer2019-CU15-KB5008996-x64.exe /ACTION=PATCH /QUIETSIMPLE /ALLINSTANCES /ENU /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS 
# C:\SCCM_STAGING\SQL_2019_CU_16\SQLServer2019-KB5011644-x64.exe /ACTION=PATCH /QUIETSIMPLE /ALLINSTANCES /ENU /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS 
# Start-Process "C:\SCCM_STAGING\SQL_2019_CU_16\SQLServer2019-KB5011644-x64.exe" -Wait -ArgumentList '/ACTION=PATCH /QUIETSIMPLE /ALLINSTANCES /ENU /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS'
Write-Host -foregroundcolor green "Installing Latest Cumulative Update Package for SQL Server 2019 (CU_16)"
Start-Process "$MDTSTAGING\SQL_2019_CU_16\SQLServer2019-KB5011644-x64.exe" -Wait -NoNewWindow -ArgumentList '/ACTION=PATCH /QUIETSIMPLE /ALLINSTANCES /ENU /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS'


###################################################################################################
### Install SQL SSMS 18.12 
# Install Microsoft SQL Server Management Studio 18
# Note I install SSMS without the /norestart and it did not prompt for a restart. Need to determine if a reboot is required.
# Run this on the SCCM site server (SAT-SRV-14)
#
# C:\SCCM_STAGING\SSMS_18.8\SSMS-Setup-ENU.exe /install /passive 
# C:\SCCM_STAGING\SSMS_18.12\SSMS-Setup-ENU.exe /install /passive
# Start-Process -FilePath "C:\SCCM_STAGING\SSMS_18.12\SSMS-Setup-ENU.exe" -Wait -ArgumentList '/install /passive'
Write-Host -foregroundcolor green "Installing SQL SSMS 18.12"
Start-Process -FilePath $MDTSTAGING\SSMS_18.12\SSMS-Setup-ENU.exe -Wait -NoNewWindow -ArgumentList '/install /passive'

# Known issue with SQL Server 2019 - Turn off Scalar UDF Inlining feature in SQL 2019
# Run the following command in a SQL Query window to disable it...NOT Powershell
# ALTER DATABASE SCOPED CONFIGURATION SET TSQL_SCALAR_UDF_INLINING = OFF

# ******* THE INSTALL ABOVE REQUIRES A REBOOT ******

###################################################################################################
### ADD DEFENDER WSUS Exclusions
#
# Microsoft Defender Antivirus on Windows Server 2016 and 2019 automatically enrolls you in certain exclusions,
# as defined by your specified server role. See the list of automatic exclusions (in this article). 
# These exclusions do not appear in the standard exclusion lists that are shown in the Windows Security app.
# Refer to the following link to determine which folders, files and process are automatically excluded:
# https://docs.microsoft.com/en-us/windows/security/threat-protection/microsoft-defender-antivirus/configure-server-exclusions-microsoft-defender-antivirus#list-of-automatic-exclusions
#
# To view current defender exclusion, read the "ExclusionPath" after running the following command: 
# Get-mppreference

# Add MpPrefernces in to the $WDAVPREFS variable
# $WDAVPREFS = Get-MpPreference

# Display all Defender file exclusions
# $WDAVPREFS.ExclusionExtension

# Display all Defender folder exclusions
# $WDAVPREFS.ExclusionPath

# Display all Defender Process exclusions
# $WDAVPREFS.ExclusionProcess

# To get the status of the animalware software on computer
# Get-MpComputerStatus

Write-Host -foregroundcolor green "ADDING DEFENDER WSUS Exclusions"

### Add defender Folder Exclusions:
# Add-MpPreference -ExclusionPath "C:\Windows\SoftwareDistribution\DataStore"
# Add-MpPreference -ExclusionPath "C:\Windows\SoftwareDistribution\Download"
# Add-MpPreference -ExclusionPath "C:\Windows\WID\Data"

### Add defender Extension Exclusions:
# Add-MpPreference -ExclusionExtension ".XML.GZ"
# Add-MpPreference -ExclusionExtension ".CAB"

### Add defender Process Exclusions:
# Add-MpPreference -ExclusionProcess "C:\Program Files\Update Services\Tools\WsusUtil.exe"
# Add-MpPreference -ExclusionProcess "C:\Program Files\Update Services\Services\WsusService.exe"


###################################################################################################
Stop-Transcript


# ******* REBOOT SERVER HERE ******

