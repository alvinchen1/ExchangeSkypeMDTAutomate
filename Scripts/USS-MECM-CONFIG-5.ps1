###################################################################################################
##################### USS-MECM-CONFIG-4.ps1 ###################################################
###################################################################################################
#
### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Install Report Viewer 2010 for MECM Admin Console
# -Install MECM Admin Console

# -Configure NO_SMS_ON_DRIVE.SMS Files
# -Install Remote Differential Compression for Windows Server 2019
# -Install REPORT VIEWER 2012 RUNTIME and Microsoft System CLR Types for Microsoft SQL Server 2012
# -Install WSUS on a SQL Database
# -Set WSUS Application Pool Maximum Private memory
#
# *** Before runnng this script ensure that ALL the PREREQ and Software to install WSUS is located in the
# WSUS_STAGING folder on the MDT STAGING Share. ***
#
#
###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-MECM-CONFIG-5.ps1.log
Start-Transcript -Path \\DEV-MDT-01\DEPLOYMENTSHARE$\LOGS\$env:COMPUTERNAME\USS-MECM-CONFIG-5.ps1.log


###################################################################################################
# MODIFY/ENTER These Values Before Running This Script.
#
### ENTER the MECM Server name.
$MECMSRV = "USS-SRV-14"

### ENTER MDT STAGING FOLDER
$MDTSTAGING = "\\DEV-MDT-01\STAGING"

### ENTER WSUS CONTENT Drive.
$WSUS_CONT_DRV = "E:\WSUS"

###################################################################################################
### Install Report Viewer 2010 for MECM Admin Console
### Install MECM Admin Console
# Write-Host -foregroundcolor green "Copying MECM Admin Console folder to local drive"
# Copy-Item $MDTSTAGING\AdminConsole -Destination C:\ -Recurse -Force

### Install Report Viewer 2010 for MECM Admin Console
# Write-Host -foregroundcolor green "Installing Report Viewer 2010 SP1 Redist (KB2549864)"
# Start-Process -Wait C:\AdminConsole\ReportViewer.exe /q

### This WORKS...Install MECM Admin Console
# Start-Process -Wait C:\AdminConsole\AdminConsole.msi -ArgumentList 'INSTALL=ALL ALLUSERS=1 TARGETDIR="D:\MECM\AdminConsole" DEFAULTSITESERVERNAME=AUSS-SRV-14.USS.LOCAL ADDLOCAL="AdminConsole,SCUIFramework" /passive /norestart'


###################################################################################################
### Configure NO_SMS_ON_DRIVE.SMS Files
# Only configure on drive you DON’T want SCCM to install on. (C, F, G).
# SCCM install and inboxes are on the D:\ drive
# SCCM DP and WSUS Content is on the E:\ drive
Write-Host -foregroundcolor green "Create NO_SMS_ON_DRIVE.SMS File on NON-MECM Drives..."
New-Item C:\NO_SMS_ON_DRIVE.SMS -ItemType file
New-Item F:\NO_SMS_ON_DRIVE.SMS -ItemType file
New-Item G:\NO_SMS_ON_DRIVE.SMS -ItemType file

###################################################################################################
### Install Remote Differential Compression for Windows Server 2019. 
Write-Host -foregroundcolor green "Installing Remote Differential Compression for Windows Server 2019..."
Install-WindowsFeature RDC

###################################################################################################
### Install WSUS 
# When using a WID database for WSUS
# the "&" symbol/call operator allows PowerShell to call and execute a command in a string.
# the call operator "&" allow you to execute/run a CMD command, script or funtion in PowerShell.
# Install-WindowsFeature -Name UpdateServices -IncludeManagementTools
# & ‘C:\Program Files\Update Services\Tools\WsusUtil.exe’ postinstall content_dir=D:\WSUS
#
# When using a SQL database for WSUS
Write-Host -foregroundcolor green "Installing WSUS"
Install-WindowsFeature -Name Updateservices-Services,UpdateServices-DB -IncludeManagementTools

# If SQL server is installed on the default SQL instance (MSSQLSERVER) on the local server...run this:
# Note this is when the SUSDB is created in the SQL Instance and when the WSUS folder is created in the file system.
# the "&" symbol/call operator allows PowerShell to call and execute a command in a string.
# the call operator "&" allow you to execute/run a CMD command, script or funtion in PowerShell.
# & ‘C:\Program Files\Update Services\Tools\WsusUtil.exe’ postinstall SQL_INSTANCE_NAME="SAT-SRV-14\" content_dir=E:\WSUS
#
### Configure WSUS
Write-Host -foregroundcolor green "Configuring WSUS DB on SQL..."
& ‘C:\Program Files\Update Services\Tools\WsusUtil.exe’ postinstall SQL_INSTANCE_NAME="$MECMSRV\" content_dir=$WSUS_CONT_DRV

# If SQL server is installed on a remote SQL server instance (MSSQLSERVER or SCCM) include the remote server name and SQL instance:
# Note this is when the SUSDB is created in the SQL Instance and when the WSUS folder is created in the file system.
# the "&" symbol/call operator allows PowerShell to call and execute a command in a string.
# the call operator "&" allow you to execute/run a CMD command, script or funtion in PowerShell.
# & ‘C:\Program Files\Update Services\Tools\WsusUtil.exe’ postinstall SQL_INSTANCE_NAME="SAT-SRV-14\" content_dir=D:\WSUS

### Set WSUS Application Pool Maximum Private memory
# Set/Configure IIS WSUS App Pool recycling properties
# Set Application Pool Maximum Private memory - Set the Private Memory Limit to 4-8GB (4,000,000 KB)...Or "0" for unlimited.
# https://community.spiceworks.com/topic/2009397-how-to-configure-iis-app-pool-recycling-properties-with-powershell
Write-Host -foregroundcolor green "Setting WSUS Application Max Private Memory - (4GB)..."
Set-WebConfiguration "/system.applicationHost/applicationPools/add[@name='WsusPool']/recycling/periodicRestart/@privateMemory" -Value 4000000


###################################################################################################
Stop-Transcript


# ******* REBOOT SERVER HERE ******