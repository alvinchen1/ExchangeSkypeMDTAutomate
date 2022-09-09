###################################################################################################
###################### USS-DPM-CONFIG-2.ps1 ###############
###################################################################################################

## Use the commands below to Install and Configure DPM 2019_1801 on a single server/PC.
##
## Before running this script, update the following:

## Create the drives for the automatic deployment of DPM on the server
## On the DPM server ensure these drives are present:
# (C:)(158gb+) RAID 1 for OS, page file (4k, NTFS)
# (D:)(3000gb+) RAID 5 for SQL DB, transaction logs,UserDBlog, SQL TempDB logs, (64k BlockSize, ReFS)
# (E:)(<100 TB>+) DPM Storage (MBS) (64k BlockSize, ReFS)

## Set the followng variables in this script below with find and replace:
#   -C:\DPM_STAGING = DPM Staging folder
#   -E:\SRSReportKeys = SQL SSRS Report key folder, SQL Reporting service key...normally on SQL server
#   -E:\DPMSQL = SQL Database folder
#   -E:\DPMSQL = SQL Database log folder
#   -E:\DPMSQLBackup = SQL Backup folder
#   -SVC-DPMSQL-01 = SQL service account tht will be used for SQL
#   -ADM-SQL-ADMINS = SQL Admin group
#   -SQL2019ForDPM = SQL Configuration file
#   -SQL_INSTANCE_NAME=SAT-SRV-58
#   -SPN name DPMSQLSvc/SAT-SRV-58
#   -C:\DPM_STAGING\REPORT_VIEWER_5812 = version of Report Viewer used for WSUS.

# This script will:
# -CREATE SQL FOLDERS FOR DPM
# -Set Permissions on SQL Folders
# -Grant SQL Service account Full Control to SQL Folders
# -Install DPM Prerequisites
# -Install .NET Framework 3.5.1
# -COPY DPM FILE TO LOCAL DRIVE
# -Set SQL Service Accounts SPN
# -Set Windows Firewall ports for SQL
# -Install Hyper=V and PowerShell Management Tools
# -COPY SQL CONFIGURATION FILE TO LOCAL DRIVE
# -Install SQL 2019 using SQL Configuration file
# -Install Latest Cumulative Update Package for SQL Server 2019
# -Install SQL SSMS 18.12
# -Install SQL 2019 Reporting Service
# -Set SQL 2019 Reporting Service (SSRS) Account

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-DPM-CONFIG-2.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-DPM-CONFIG-2.log

###################################################################################################
# MODIFY/ENTER These Values Before Running This Script.

### ENTER MDT STAGING FOLDER
$MDTSTAGING = "\\DEP-MDT-01\STAGING"

### ENTER SQL INFO
$SQLSVRNAME = "USS-SRV-58"
$SQLSVRACCT = "SVC-DPMSQL-01"
$DOMNAME = 'USS.LOCAL'

### ENTER SQL CONFIGURATION FILE
# Note this file needs to be in the MDT STAGING folder (D:\STAGING\SCCM_STAGING\SCRIPTS)
$SQLCONFIGFILE = "SQL2019ForDPM2019.ini"

# Set DPM Reporting Service Account and password
$serviceAccount = "uss\svc-dpm-rsp"
$servicePW = "!QAZ2wsx#EDC4rfv"

###################################################################################################
############# CREATE SQL FOLDERS FOR DPM ##########################################################
###################################################################################################
# Create Folders for SQL Install:
# Grant the SQL service account (SVC-DPMSQL-01) full control to the below folders.
# Note if SQL will be installed on a single storage/LUNS, then the folders can all be on the same drive letter.
# Note if this will be a multi-SQL instance, and all the SQL files will be place on a single storage/LUNS, 
# -then create one drive letter per SQL instance. Meaning if you will have a DPM and SCOM SQL instance then create a E:\DPMSQL and an E:\DPMSQL folder/VHDX.
# After folder creation, Grant the SQL service account (SVC-DPMSQL-01) full control to the above folders.

New-Item D:\DPMPROG –Type Directory
New-Item E:\DPMSQL –Type Directory
New-Item E:\DPMSQL\x86 –Type Directory
New-Item E:\DPMSQL\TempDB –Type Directory
New-Item E:\DPMSQL\UserDB –Type Directory
# New-Item E:\DPMSQL –Type Directory
New-Item E:\DPMSQL\UserDBLOG –Type Directory
New-Item E:\DPMSQL\TempDBLogs –Type Directory
New-Item E:\DPMSQLBackup –Type Directory
New-Item E:\SRSReportKeys –Type Directory

############# Set Permissions on SQL Folders ##############################
############# Grant SQL Service account Full Control to SQL Folders (E:\DPMSQL)
# Note you need to grant the SVC-DPMSQL-01 service account full control to these folders.
# Get-Acl E:\DPMSQL | Format-List
$ssa = Get-Acl E:\DPMSQL
$ssa.SetAccessRuleProtection($True, $False)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SVC-DPMSQL-01 permissions to the DPM folders.
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa.AddAccessRule($rule)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-DPMSQL-01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa.AddAccessRule($rule)

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("ADM-SQL-ADMINS","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa.AddAccessRule($rule)

# Applied to This Folder, Subfolders and Files
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa.AddAccessRule($rule)

# Apply the permision to the folder
Set-Acl E:\DPMSQL $ssa


############# Set Permissions on DPM Folders ##############################
############# Grant SQL Service account Full Control to SQL Folders (D:\DPMPROG)
# Note you need to grant the SVC-DPMSQL-01 service account full control to these folders.
# Get-Acl D:\DPMPROG | Format-List
$ssa1 = Get-Acl D:\DPMPROG
$ssa1.SetAccessRuleProtection($True, $False)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SVC-DPMSQL-01 permissions to the DPM folders.
$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa1.AddAccessRule($rule1)

$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-DPMSQL-01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa1.AddAccessRule($rule1)

$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("ADM-SQL-ADMINS","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa1.AddAccessRule($rule1)

# Applied to This Folder, Subfolders and Files
$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa1.AddAccessRule($rule1)

# Apply the permision to the folder
Set-Acl D:\DPMPROG $ssa1



##################### Grant SQL Service account Full Control to SQL Folders (E:\SRSReportKeys)

$ssa2 = Get-Acl E:\SRSReportKeys
$ssa2.SetAccessRuleProtection($True, $False)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SVC-DPMSQL-01 permissions to the DPM folders.
$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa2.AddAccessRule($rule2)

$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-DPMSQL-01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa2.AddAccessRule($rule2)

$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("ADM-SQL-ADMINS","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa2.AddAccessRule($rule2)

# Applied to This Folder, Subfolders and Files
$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa2.AddAccessRule($rule2)

# Apply the permision to the folder
Set-Acl E:\SRSReportKeys $ssa2

##################### Grant SQL Service account Full Control to SQL Folders (E:\DPMSQLBackup)

$ssa3 = Get-Acl E:\DPMSQLBackup
$ssa3.SetAccessRuleProtection($True, $False)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SVC-DPMSQL-01 permissions to the DPM folders.
$rule3 = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa3.AddAccessRule($rule3)

$rule3 = New-Object System.Security.AccessControl.FileSystemAccessRule("SVC-DPMSQL-01","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa3.AddAccessRule($rule3)

$rule3 = New-Object System.Security.AccessControl.FileSystemAccessRule("ADM-SQL-ADMINS","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa3.AddAccessRule($rule3)

# Applied to This Folder, Subfolders and Files
$rule3 = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$ssa3.AddAccessRule($rule3)

# Apply the permision to the folder
Set-Acl E:\DPMSQLBackup $ssa3



###################################################################################################
### COPY DPM FILE TO LOCAL DRIVE 
# Copy the SCCM_STAGING folder to the MDT STAGING folder:
# Copy-Item '\\BBB-SC-01\d$\SCCM_STAGING' -Destination D:\STAGING -Recurse
# Copy-Item '\\DEP-MDT-01\STAGING\SCCM_STAGING' -Destination C:\ -Recurse
# Copy-Item $MECMSTAGINGFLDR -Destination C:\ -Recurse -Force
# Copy-Item $MDTSTAGING\SCRIPTS\USS_SQL2019ForSCCM2103.ini -Destination C:\Windows\Temp -Recurse -Force

# Write-Host -foregroundcolor green "COPY SQL CONFIGURATION FILE TO LOCAL DRIVE..."
# Copy-Item $MDTSTAGING\SCRIPTS\$SQLCONFIGFILE -Destination C:\Windows\Temp\SQL2019ForSCCM2103.ini -Recurse -Force
# Copy-Item $MDTSTAGING\CU_NETFramework_3.5_4.8_W2019\windows10.0-kb4578973-x64-ndp48.msu -Destination C:\Windows\Temp\windows10.0-kb4578973-x64-ndp48.msu -Recurse -Force
Write-Host -foregroundcolor green "Copy DPM_STAGING to local Drive..."

Copy-Item $MDTSTAGING\DPM_STAGING -Destination C:\ -Recurse -Force

###################################################################################################
############# Install DPM Prerequisites  #####################################################
#### The script below assumes all DPM and Prereqs files have been copied to the C:\DPM_STAGING folders.
# Run this on the DPM site server (SAT-SRV-58)

# Install .NET Framework 3.5.1
# Ensure you copy the Windows 2019 DVD\Sources\Sxs folder in the staging folder
# Dism /online /enable-feature /featurename:NetFx3 /All /Source:C:\WSUS_STAGING\W2019\Sources\Sxs /LimitAccess
Write-Host -foregroundcolor green ".NET Framework 3.5.1..."
Dism /online /enable-feature /featurename:NetFx3 /All /Source:C:\DPM_STAGING\W2019\Sources\Sxs /LimitAccess

###################################################################################################
# **** JohnNote COMEBACK -CU NOT INSTALLING ****Install the latest <5858-10 Cumulative Update for .NET Framework 3.5 and 4.8 for Windows Server 2019 for x64 (KB4578973)>
# wusa.exe C:\DPM_STAGING\CumulativeUpdateFor.NETFramework 3.5 and 4.8_W2019\windows10.0-kb4578973-x64-ndp48.msu /quiet /norestart
# Start-Process wusa.exe "$MDTSTAGING\CU_NETFramework_3.5_4.8_W2019\windows10.0-kb4578973-x64-ndp48.msu" -Wait -NoNewWindow -ArgumentList '/quiet /norestart'

# wusa.exe "$MDTSTAGING\CU_NETFramework_3.5_4.8_W2019\windows10.0-kb4578973-x64-ndp48.msu" /quiet /norestart

# Start-Process "$MDTSTAGING\SQL_2019_ENT\Setup.exe" -Wait -NoNewWindow -ArgumentList '/QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile=C:\Windows\Temp\SQL2019ForSCCM2103.ini'

# wusa.exe "C:\Windows\Temp\windows10.0-kb4578973-x64-ndp48.msu" /quiet /norestart

# wusa.exe "C:\Windows\Temp\windows10.0-kb4578973-x64-ndp48.msu"
# wusa.exe "C:\Windows\Temp\windows10.0-kb5015731-x64-ndp48.msu"


# Set SQL Service Accounts SPN
# Run on the DPM Server or domain controller
# List current SPNs registered to target account
# setspn -L SVC-DPMSQL-01

# setspn -A DPMSQLSvc/SAT-SRV-58.SATURN.LAB:1433 SVC-DPMSQL-01
# setspn -A DPMSQLSvc/SAT-SRV-58:1433 SVC-DPMSQL-01


### Set SQL Service Accounts SPN
# Run on the Site Server or domain controller
# setspn -A MSSQLSvc/SAT-SRV-14.SATURN.LAB:1433 SVC-CM-SQL01
# setspn -A MSSQLSvc/SAT-SRV-14:1433 SVC-CM-SQL01
Write-Host -foregroundcolor green "Set SQL Service Accounts SPN..."
setspn -A MSSQLSvc/"$SQLSVRNAME.$DOMNAME":1433 $SQLSVRACCT
setspn -A MSSQLSvc/"$SQLSVRNAME":1433 $SQLSVRACCT


# Set Windows Firewall ports for SQL
# The default instance of SQL Server listens on Port 1433. Port 1434 is used by the SQL Browser Service which allows 
# connections to named instances of SQL Server that use dynamic ports with out having to know what port each named 
# instance is using, especially since this can change between restarts of the named instance.
# Note the ports below open the firewall for SQL and SQL Reporting Services
Write-Host -foregroundcolor green "Configuring Firewall..."
New-NetFirewallRule -DisplayName “SQL TCP Ports” -Direction Inbound –Protocol TCP -Profile Domain –LocalPort 80,443,2382,2383,1433,1434,4022 -Action allow
New-NetFirewallRule -DisplayName “SQL UDP Ports” -Direction Inbound –Protocol UDP -Profile Domain –LocalPort 1434,4022 -Action allow

# Install Hyper=V and PowerShell Management Tools
# The Hyper-V Role and the PowerShell Management tools windows feature is required.
# Note the command below will reboot/restart the VM at least twice automatically
Write-Host -foregroundcolor green "Installing Hyper-V and Management Tools..."
Dism.exe /Online /NoRestart /Enable-Feature /All /FeatureName:Microsoft-Hyper-V /FeatureName:Microsoft-Hyper-V-Management-PowerShell /quiet 
  

###################################################################################################
### COPY SQL CONFIGURATION FILE TO LOCAL DRIVE 
# Copy the SCCM_STAGING folder to the MDT STAGING folder:
# Copy-Item '\\BBB-SC-01\d$\SCCM_STAGING' -Destination D:\STAGING -Recurse
# Copy-Item '\\DEP-MDT-01\STAGING\SCCM_STAGING' -Destination C:\ -Recurse
# Copy-Item $MECMSTAGINGFLDR -Destination C:\ -Recurse -Force
# Copy-Item $MDTSTAGING\SCRIPTS\USS_SQL2019ForSCCM2103.ini -Destination C:\Windows\Temp -Recurse -Force
# Write-Host -foregroundcolor green "COPY SQL CONFIGURATION FILE TO LOCAL DRIVE..."
# Copy-Item $MDTSTAGING\SCRIPTS\DPM\$SQLCONFIGFILE -Destination C:\Windows\Temp\$SQLCONFIGFILE -Recurse -Force

###################################################################################################
############# Install SQL Server 2019 Enterprise Edition ##########################################
#### The script below assumes all SQL files have been copied to the D:\DPM_STAGINGSQL_2019_ENT\ folders.
# Run this on the DPM site server (SAT-SRV-58)
###################################################################################################
#

### Install SQL 2019 using SQL Configuration file
# Take a Snapshot/Checkpoint of VM.
# 
# C:\SCCM_STAGING\SQL_2019_ENT\Setup.exe /QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ASSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile=C:\SCCM_STAGING\SQL_2019_ENT\SQL2019ForSCCM2103
# C:\SCCM_STAGING\SQL_2019_ENT\Setup.exe /QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile=C:\SCCM_STAGING\SQL_2019_ENT\SQL2019ForSCCM2103.ini
# C:\SCCM_STAGING\SQL_2019_ENT\Setup.exe /QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="Th1rtyF0urTub^^^" /AGTSVCPASSWORD="Th1rtyF0ur^^^" /ConfigurationFile=C:\SCCM_STAGING\SCRIPTS\SAT_SQL2019ForSCCM2103.ini
# Use the "-NoNewWindow" switch if you get the following error message when attempting to run a script from a network share:
# - "Open File – Security Warning” dialog box that says “We can’t verify who created this file. Are you sure you want to open this file?”
# Start-Process "C:\SCCM_STAGING\SQL_2019_ENT\Setup.exe" -Wait -ArgumentList '/QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile=C:\SCCM_STAGING\SCRIPTS\USS_SQL2019ForSCCM2103.ini'
# Start-Process "$MDTSTAGING\SQL_2019_ENT\Setup.exe" -Wait -NoNewWindow -ArgumentList '/QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile=C:\Windows\Temp\USS_SQL2019ForSCCM2103.ini'
# Start-Process "$MDTSTAGING\SQL_2019_ENT\Setup.exe" -Wait -NoNewWindow -ArgumentList '/QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile="C:\Windows\Temp\SQL2019ForSCCM2103.ini"'
#
Write-Host -foregroundcolor green "Installing SQL 2019 using SQL Configuration file"
Start-Process "$MDTSTAGING\SQL_2019_ENT\Setup.exe" -Wait -NoNewWindow -ArgumentList '/QS /IACCEPTSQLSERVERLICENSETERMS /SQLSVCPASSWORD="!QAZ2wsx#EDC4rfv" /AGTSVCPASSWORD="!QAZ2wsx#EDC4rfv" /ConfigurationFile=C:\DPM_STAGING\SCRIPTS\SQL2019ForDPM2019.ini'

# Install Latest Cumulative Update Package for SQL Server 2019
# C:\SCCM_STAGING\SQL_2019_CU58\SQLServer5817-KB4541283-x64.exe /ACTION=INSTALL /QUIETSIMPLE /ALLINSTANCES /ENU /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS 
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
Start-Process -FilePath $MDTSTAGING\SSMS_18.12\SSMS-Setup-ENU.exe -Wait -NoNewWindow -ArgumentList '/install /passive /norestart'

# Known issue with SQL Server 2019 - Turn off Scalar UDF Inlining feature in SQL 2019
# Run the following command in a SQL Query window to disable it...NOT Powershell
# ALTER DATABASE SCOPED CONFIGURATION SET TSQL_SCALAR_UDF_INLINING = OFF

# (If necessary/Not set in SQL.ini File) - Configure SQL Memory
# Note you must reboot the server after the SSMS 18.3 install in order for the SQLCMD command to work.
# Note it is included in the Microsoft ODBC Driver 13/17 for SQL Server
# Set MAX to 8gb. Set MIN to 4gb
# JOHN NOTE Setting the memory in the SQL Configuration file works (4-30-5858)...it should be MIN 4GB and MAX 6GB.
# sqlcmd -S SAT-SRV-58 -i C:\DPM_STAGING\SCRIPTS\SetSQLMem.sql -o C:\DPM_STAGING\SCRIPTS\SetSQLMem.log

###################################################################################################
##################  Install SQL 2019 Reporting Service ################
######## The SQL Reporting service needed for the DPM Reporting can be installed manually or automated (PowerShell script).
######## The PowerShell script below will install the SQL 2019 Reporting Service on a SQL 2019 installation. If you're using a different version of SQL, 
######## you should test the script on it before using the script below.
###################################################################################################

# C:\DPM_STAGING\SQL_2019_RS\SQLServerReportingServices.exe /passive /norestart /IAcceptLicenseTerms /PID=2C9JR-K3RNG-QD4M4-JQ2HR-8468J

###################################################################################################
###  Install SQL 2019 Reporting Service 
# The SQL Reporting service needed for the SCCM Reporting can be installed manually or automated (PowerShell script).
# We will install the SQL Reporting service using PowerShell
# We will configure the SQL Reporting service using the GUI.
#
######## The PowerShell script below will install the SQL 2019 Reporting Service on a SQL 2019 installation. 
# If you're using a different version of SQL, you should test the script on it before using the script below.
#
# There is no completion screen for the SQL Reporting service installation...check task manager to confirm its completion.
#
# Start-Process "C:\SCCM_STAGING\SQL_2019_RS\SQLServerReportingServices.exe" -Wait -ArgumentList '/passive /norestart /IAcceptLicenseTerms /PID=2C9JR-K3RNG-QD4M4-JQ2HR-8468J'
Write-Host -foregroundcolor green "Installing SQL 2019 Reporting Service"
Start-Process "$MDTSTAGING\SQL_2019_RS\SQLServerReportingServices.exe" -Wait -NoNewWindow -ArgumentList '/passive /norestart /IAcceptLicenseTerms /PID=2C9JR-K3RNG-QD4M4-JQ2HR-8468J'
 
# Note if you don't reboot the server here you will not see the "Reporting Services Configuration Manager" on the \
# start menu.

# ******* REBOOT SERVER HERE ******
# Note if you don't reboot the server here you will not see the "Reporting Services Configuration Manager" on the \
# start menu.

############################

############ Set SQL 2019 Reporting Service (SSRS) Account ###################################

Write-Host -foregroundcolor green "Setting SQL 2019 Reporting Service Account"

$ns = "root\Microsoft\SqlServer\ReportServer\RS_SSRS\v15\Admin"
$RSObject = Get-WmiObject -class "MSReportServer_ConfigurationSetting" -namespace "$ns"

# Set service account
# $serviceAccount = "uss\svc-dpm-rsp"
# $serviceAccount = "NT Authority\Network Service"
# $servicePW = "!QAZ2wsx#EDC4rfv"

$useBuiltInServiceAccount = $false
$RSObject.SetWindowsServiceIdentity($useBuiltInServiceAccount, $serviceAccount, $servicePW) | out-null

# Need to reset the URLs for domain service account to work
$HTTPport = 80
$RSObject.RemoveURL("ReportServerWebService", "http://+:$HTTPport", 1033) | out-null
$RSObject.RemoveURL("ReportServerWebApp", "http://+:$HTTPport", 1033) | out-null
$RSObject.SetVirtualDirectory("ReportServerWebService", "ReportServer", 1033) | out-null
$RSObject.SetVirtualDirectory("ReportServerWebApp", "Reports", 1033) | out-null
$RSObject.ReserveURL("ReportServerWebService", "http://+:$HTTPport", 1033) | out-null
$RSObject.ReserveURL("ReportServerWebApp", "http://+:$HTTPport", 1033) | out-null

# Restart SSRS service for changes to take effect
$serviceName = $RSObject.ServiceName
Restart-Service -Name $serviceName -Force

Stop-Transcript

# ******* REBOOT SERVER HERE ****** 








