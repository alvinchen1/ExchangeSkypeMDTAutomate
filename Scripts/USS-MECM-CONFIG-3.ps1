###################################################################################################
##################### USS-MECM-CONFIG-3.ps1 ###################################################
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
 
# *** Before runnng this script ensure that the following drive exist on the MECM Site server ***
#
# (C:)(120gb+) RAID 1 OS - Page file (4k, NTFS)
# (D:)(250gb+) RAID 1 MECM - SCCM Inboxes, SCCMContentlib (4k, NTFS)
# (E:)(300gb+) RAID 1 WSUS/SUP, DP Content, MDT (4k, NTFS)
# (F:)(50gb+) RAID 5 SQLDB - (64k BlockSize, ReFS)
# (G:)(60gb+) RAID 1 SQLLOGS - transaction logs,UserDBlog, SQL TempDB logs, SCCMBackup (64k BlockSize, ReFS)
#
###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-MECM-CONFIG-3.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-MECM-CONFIG-3.log

###################################################################################################
### MODIFY These Values
### ENTER WSUS CONTENT Drive.
# 
$WSUS_CONT_DRV = "E:\WSUS"

### ENTER SQL INFO
$SQLSVRNAME = "USS-SRV-52"
$SQLSVRACCT = "SVC-CM-SQL01"
$DOMNAME = 'USS.LOCAL'

### ENTER MDT STAGING FOLDER
$MDTSTAGING = "\\DEP-MDT-01\STAGING"

### ENTER SCCM STAGING FOLDER
# $SCCMSTAGING = "\\DEP-MDT-01\STAGING\SCCM_STAGING"

### ENTER SQL CONFIGURATION FILE
# Note this file needs to be in the MDT STAGING folder (D:\STAGING\SCCM_STAGING\SCRIPTS)
$SQLCONFIGFILE = "USS_SQL2019ForMECM2203.ini"
### ENTER WADK Folder$WADKDIR = "E:\WADK"

### ENTER MECM SERVER NAME.
# $MECMSRV = "USS-SRV-52"



###################################################################################################
### COPY OSD_STAGING FOLDER TO LOCAL DRIVE 
Write-Host -foregroundcolor green "Copying OSD_STAGING Folder to local drive - D:\"
Copy-Item $MDTSTAGING\OSD_STAGING -Destination D:\ -Recurse -Force


###################################################################################################
### CREATE SQL FOLDERS 
# The SC-SRV-52 server will be used as the SQL server
# This should be ran on the SQL server.
#
# Run this script on the SQL SERVER (USS-SRV-52).
#
# Create Folders for SQL Install:
# Grant the SQL service account (SVC-CM-SQL01) full control to the below folders.
# Note if SQL will be installed on a single storage/LUNS, then the folders can all be on the same drive letter.
# Note if this will be a multi-SQL instance, and all the SQL files will be place on a single storage/LUNS, 
# -then create one drive letter per SQL instance. Meaning if you will have a SCCM and SCOM SQL instance then create a D:\MSSQL and an E:\MSSQL folder/VHDX.
# After folder creation, Grant the SQL service account (SVC-CM-SQL01) full control to the above folders.
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
# Note you need to grant the SVC-CM-SQL01 service account full control to these folders.
# Get-Acl F:\MSSQL | Format-List
Write-Host -foregroundcolor green "Grant SQL Service account Full Control to SQL Folders..."

$ssa = Get-Acl F:\MSSQL
$ssa.SetAccessRuleProtection($True, $False)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SVC-CM-NAA permissions to the SCCM folders.
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa.AddAccessRule($rule)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-CM-SQL01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
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
# This group is used to grant the SVC-CM-SQL01 permissions to the SCCM folders.
$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa1.AddAccessRule($rule1)

$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-CM-SQL01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
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
# This group is used to grant the SVC-CM-SQL01 permissions to the SCCM folders.
$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa2.AddAccessRule($rule2)

$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-CM-SQL01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
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
# This group is used to grant the SVC-CM-SQL01 permissions to the SCCM folders.
$rule3 = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa3.AddAccessRule($rule3)

$rule3 = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-CM-SQL01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
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
#### The script below assumes all SQL files have been copied to the D:\MECM_STAGING\SQL_2019_ENT\ folders.
# Run this on the SCCM site server (XXX-SRV-52)
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
# setspn -A MSSQLSvc/USS-SRV-52.USS.LOCAL:1433 SVC-CM-SQL01
# setspn -A MSSQLSvc/USS-SRV-52:1433 SVC-CM-SQL01
Write-Host -foregroundcolor green "Set SQL Service Accounts SPN..."
setspn -A MSSQLSvc/"$SQLSVRNAME.$DOMNAME":1433 $SQLSVRACCT
setspn -A MSSQLSvc/"$SQLSVRNAME":1433 $SQLSVRACCT

###################################################################################################
### COPY SQL CONFIGURATION FILE TO LOCAL DRIVE 
#
Write-Host -foregroundcolor green "COPY SQL CONFIGURATION FILE TO LOCAL DRIVE..."
Copy-Item $MDTSTAGING\SCRIPTS\SQL\$SQLCONFIGFILE -Destination C:\Windows\Temp\SQL2019ForMECM2203.ini -Recurse -Force

### Install SQL 2019 using SQL Configuration file
#
# Use the "-NoNewWindow" switch if you get the following error message when attempting to run a script from a network share:
# - "Open File – Security Warning” dialog box that says “We can’t verify who created this file. Are you sure you want to open this file?”
# Start-Process "C:\MECM_STAGING\SQL_2019_ENT\Setup.exe" -Wait -ArgumentList '/QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile=C:\MECM_STAGING\SCRIPTS\USS_SQL2019ForSCCM2103.ini'
#
Write-Host -foregroundcolor green "Installing SQL 2019 using SQL Configuration file"
Start-Process "$MDTSTAGING\SQL_2019_ENT\Setup.exe" -Wait -NoNewWindow -ArgumentList '/QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile=C:\Windows\Temp\SQL2019ForMECM2203.ini'

# Install Latest Cumulative Update Package for SQL Server 2019
# C:\MECM_STAGING\SQL_2019_CU20\SQLServer2017-KB4541283-x64.exe /ACTION=INSTALL /QUIETSIMPLE /ALLINSTANCES /ENU /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS 
# Install Latest Cumulative Update Package for SQL Server 2019
## JohnNote ****This line did not work ****After CUxx install confirm SQL Version is 15.0.xxxx.xxx
# Use the "-NoNewWindow" switch if you get the following error message when attempting to run a script from a network share:
# - "Open File – Security Warning” dialog box that says “We can’t verify who created this file. Are you sure you want to open this file?”
# C:\MECM_STAGING\SQL_2019_CU15\SQLServer2019-CU15-KB5008996-x64.exe /ACTION=PATCH /QUIETSIMPLE /ALLINSTANCES /ENU /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS 
# C:\MECM_STAGING\SQL_2019_CU_16\SQLServer2019-KB5011644-x64.exe /ACTION=PATCH /QUIETSIMPLE /ALLINSTANCES /ENU /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS 
# Start-Process "C:\MECM_STAGING\SQL_2019_CU_16\SQLServer2019-KB5011644-x64.exe" -Wait -ArgumentList '/ACTION=PATCH /QUIETSIMPLE /ALLINSTANCES /ENU /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS'
Write-Host -foregroundcolor green "Installing Latest Cumulative Update Package for SQL Server 2019 (CU_16)"
Start-Process "$MDTSTAGING\SQL_2019_CU_16\SQLServer2019-KB5011644-x64.exe" -Wait -NoNewWindow -ArgumentList '/ACTION=PATCH /QUIETSIMPLE /ALLINSTANCES /ENU /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS'


###################################################################################################
### Install SQL SSMS 18.12 
# Install Microsoft SQL Server Management Studio 18
# Note I install SSMS without the /norestart and it did not prompt for a restart. Need to determine if a reboot is required.
# Run this on the SCCM site server (USS-SRV-52)
#
# C:\MECM_STAGING\SSMS_18.8\SSMS-Setup-ENU.exe /install /passive 
# C:\MECM_STAGING\SSMS_18.12\SSMS-Setup-ENU.exe /install /passive
# Start-Process -FilePath "C:\MECM_STAGING\SSMS_18.12\SSMS-Setup-ENU.exe" -Wait -ArgumentList '/install /passive'
Write-Host -foregroundcolor green "Installing SQL SSMS 18.12"
Start-Process -FilePath $MDTSTAGING\SSMS_18.12\SSMS-Setup-ENU.exe -Wait -NoNewWindow -ArgumentList '/install /passive'

# Known issue with SQL Server 2019 - Turn off Scalar UDF Inlining feature in SQL 2019
# Run the following command in a SQL Query window to disable it...NOT Powershell
# ALTER DATABASE SCOPED CONFIGURATION SET TSQL_SCALAR_UDF_INLINING = OFF

# ******* THE INSTALL ABOVE REQUIRES A REBOOT ******

###################################################################################################
### Install Windows ADK and PE for Windows 10_2004 
# The command below will install Windows ADK version 2004 required features for SCCM. 
# It will install the following features:
# •	Deployment Tools
# •	User State Migration Tool
# Run this on the SCCM site server (USS-SRV-52)
#
#
# Install Windows ADK 2004
# Sleep for 60 seconds to allow the adksetup.exe program to finish installing.
# To install Windows Assessment and Deployment Kit (ADK) SILENTLY.
# C:\MECM_STAGING\WADK_10_2004_OFFLINE\adksetup.exe /quiet /installpath E:\WADK /features OptionId.UserStateMigrationTool OptionId.DeploymentTools
# Use the "-NoNewWindow" switch if you get the following error message when attempting to run a script from a network share:
# - "Open File – Security Warning” dialog box that says “We can’t verify who created this file. Are you sure you want to open this file?”
#
# Start-Process "C:\MECM_STAGING\WADK_10_2004_OFFLINE\adksetup.exe" -Wait -ArgumentList "/quiet /installpath $WADKDIR /features OptionId.UserStateMigrationTool OptionId.DeploymentTools"
Write-Host -foregroundcolor green "Installing Windows ADK 2004"
# Start-Process "$MDTSTAGING\WADK_10_2004_OFFLINE\adksetup.exe" -Wait -NoNewWindow -ArgumentList "/quiet /installpath $WADKDIR /features OptionId.UserStateMigrationTool OptionId.DeploymentTools"
Start-Process "C:\MECM_STAGING\WADK_10_2004_OFFLINE\adksetup.exe" -Wait -NoNewWindow -ArgumentList "/quiet /installpath $WADKDIR /features OptionId.UserStateMigrationTool OptionId.DeploymentTools"

### Install Windows ADK PE_2004 
# Sleep for 60 seconds to allow the adkwinpesetup.exe program to finish installing.
# Reboot the server after installation.
# C:\MECM_STAGING\WADK_10_WINPE_2004_OFFLINE\adkwinpesetup.exe /quiet /ceip off /installpath E:\WADK /Features OptionId.WindowsPreinstallationEnvironment /norestart
# Start-Process "C:\MECM_STAGING\WADK_10_WINPE_2004_OFFLINE\adkwinpesetup.exe"-Wait -NoNewWindow -ArgumentList "/quiet /ceip off /installpath $WADKDIR /Features OptionId.WindowsPreinstallationEnvironment /norestart"
Write-Host -foregroundcolor green "Installing Windows ADK PE_2004"
# Start-Process "$MDTSTAGING\WADK_10_WINPE_2004_OFFLINE\adkwinpesetup.exe"-Wait -NoNewWindow -ArgumentList "/quiet /ceip off /installpath $WADKDIR /Features OptionId.WindowsPreinstallationEnvironment /norestart"
Start-Process "C:\MECM_STAGING\WADK_10_WINPE_2004_OFFLINE\adkwinpesetup.exe"-Wait -NoNewWindow -ArgumentList "/quiet /ceip off /installpath $WADKDIR /Features OptionId.WindowsPreinstallationEnvironment /norestart"

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
Add-MpPreference -ExclusionPath "C:\WSUSMaint"
Add-MpPreference -ExclusionPath "C:\WSUSScripts"
Add-MpPreference -ExclusionPath "C:\WSUS_STAGING"
Add-MpPreference -ExclusionPath "C:\MECM_STAGING"
Add-MpPreference -ExclusionPath "$WSUS_CONT_DRV"
Add-MpPreference -ExclusionPath "D:\WSUSImports"
Add-MpPreference -ExclusionPath "D:\WSUSExports"
Add-MpPreference -ExclusionPath "C:\Windows\SoftwareDistribution\DataStore"
Add-MpPreference -ExclusionPath "C:\Windows\SoftwareDistribution\Download"
Add-MpPreference -ExclusionPath "C:\Windows\WID\Data"

### Add defender Extension Exclusions:
Add-MpPreference -ExclusionExtension ".XML.GZ"
Add-MpPreference -ExclusionExtension ".CAB"

### Add defender Process Exclusions:
Add-MpPreference -ExclusionProcess "C:\Program Files\Update Services\Tools\WsusUtil.exe"
Add-MpPreference -ExclusionProcess "C:\Program Files\Update Services\Services\WsusService.exe"


###################################################################################################
Stop-Transcript


# ******* REBOOT SERVER HERE ******

