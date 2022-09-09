###################################################################################################
##################### USS-WSUS-CONFIG-2.ps1 ###################################################
###################################################################################################

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Create the WSUS IMPORT folder
# -Finish WSUS Install and Configuation
# -Set WSUS Application Pool Maximum Private memory
# -COPY WSUS STAGING FOLDER TO LOCAL DRIVE
# -Install SQL_SERVER_2014_EXPRESS_x64
# -ADD DEFENDER WSUS Exclusions

# *** Before runnng this script ensure that the following drive exist on the WSUS server:
# (C:)(100b+) For OS, page file (4k, NTFS)
# (D:)(400gb+) MECM Share (4k, NTFS)
# (E:)(300gb+) WSUS (4k, NTFS)

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-WSUS-CONFIG-2.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-WSUS-CONFIG-2.log


###################################################################################################
# MODIFY/ENTER These Values Before Running This Script.
#
## Set the followng variables in this script below.
#   -$SCCMFOLDER = the SCCMShare content folder (on USS-SRV-54)...it could be D: or E:...Update accordingly
#   -$NETACCT = Network Access Account that will be used for OSD
#   $MECMSRV = SCCM SITE server
#   $SCCMCONTENT = SCCM Content server.
$NETACCT = "SVC-CM-NAA"
$SCCMCONTENT = "USS-SRV-54$"
$MECMSRV = "USS-SRV-52$"
$SCCMFOLDER = "D:\SCCMSHARE"

### ENTER WSUS CONTENT Drive.
$WSUS_CONT_DRV = "E:\WSUS"

### ENTER SCCM STAGING FOLDER
$MDTSTAGING = "\\DEP-MDT-01\STAGING"

### Create the WSUS IMPORT folder #################################################################
# Write-Host -foregroundcolor green "Creating the WSUS IMPORT folder..."
# New-Item D:\WSUSImports –Type Directory


### COPY WSUS FOLDER TO LOCAL DRIVE ###########################################################################
#
Write-Host -foregroundcolor green "Copying WSUS/SCCMShare folders to D:\ and E:\"
Copy-Item C:\WSUS_STAGING\WSUSImports -Destination D:\ -Recurse
Copy-Item $MDTSTAGING\SCCMShare -Destination D:\ -Recurse

########################### Finish WSUS Install and Configuation ##################################
# & ‘C:\Program Files\Update Services\Tools\WsusUtil.exe’ postinstall content_dir=D:\WSUS
Write-Host -foregroundcolor green "Configuring WSUS..."
& ‘C:\Program Files\Update Services\Tools\WsusUtil.exe’ postinstall content_dir=$WSUS_CONT_DRV

Write-Host -foregroundcolor green "Sleep for 30 Seconds..."
Start-Sleep -s 30

## When using a SQL database for WSUS
# Install-WindowsFeature -Name Updateservices-Services,UpdateServices-DB -IncludeManagementTools
#
# If SQL server is installed on the default SQL instance (MSSQLSERVER) on the local server...run this:
# Note this is when the SUSDB is created in the SQL Instance and when the WSUS folder is created in the file system.
# & ‘C:\Program Files\Update Services\Tools\WsusUtil.exe’ postinstall SQL_INSTANCE_NAME="HK-SRV-52\" content_dir=E:\WSUS
#
# If SQL server is installed on a remote SQL server instance (MSSQLSERVER or SCCM) include the remote server name and SQL instance:
# Note this is when the SUSDB is created in the SQL Instance and when the WSUS folder is created in the file system.
# & ‘C:\Program Files\Update Services\Tools\WsusUtil.exe’ postinstall SQL_INSTANCE_NAME="HK-SRV-52\" content_dir=E:\WSUS
#
# Set Application Pool Maximum Private memory - Set the Private Memory Limit to 4-8GB (4,000,000 KB)...Or "0" for unlimited.
#
# Set WSUS Application Pool Maximum Private memory
# Set/Configure IIS WSUS App Pool recycling properties
# Set Application Pool Maximum Private memory - Set the Private Memory Limit to 4-8GB (4,000,000 KB)...Or "0" for unlimited.
# https://community.spiceworks.com/topic/2009397-how-to-configure-iis-app-pool-recycling-properties-with-powershell
# https://stackoverflow.com/questions/11187304/how-to-set-iis-applicationpool-private-memory-limit-value-using-powershell
Write-Host -foregroundcolor green "Set WSUS Application Pool Maximum Private memory (4GB)..."
Set-WebConfiguration "/system.applicationHost/applicationPools/add[@name='WsusPool']/recycling/periodicRestart/@privateMemory" -Value 4000000


### COPY WSUS CONTENT FOLDER TO WSUSCONTENT FOLDER ###########################################################################
#
Write-Host -foregroundcolor green "Copying WSUSContent folders to E:\WSUS\WSUSContent"
Copy-Item C:\WSUS_STAGING\WSUSImports\WsusContent\* -Destination E:\WSUS\WsusContent -Recurse


###################################################################################################
############# Create the SCCM Share Folders #######################################################
# The AUSS-SRV-54 server will be used as the SCCMShare server
#
# Run this script on the SCCM SHARE/CONTENT SERVER (AUSS-SRV-54).
#
# Run this script in an *** "Administrators session" *** of PowerShell ISE
#
# These folders will be used for files needed to operate SCCM.
# This script creates the SCCM SHARE folder, Shares the folder and sets the NTFS and share permissions.
# Note the $NETACCT account is used for OSD.
# The $SCCMCONTENT computer account is optional and used to grant the server access to the share.
###################################################################################################

### Create the SCCM SHARE folder
Write-Host -foregroundcolor green "Creating the SCCM SHARE folder..."

# New-Item $SCCMFOLDER –Type Directory
Get-Acl $SCCMFOLDER | Format-List

$acl = Get-Acl $SCCMFOLDER
$acl.SetAccessRuleProtection($True, $False)

# Applied to This Folder, Subfolders and Files
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the $NETACCT permissions to the SCCM folders.
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$NETACCT","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SCCM Content server ($SCCMCONTENT) computer account permissions to the SCCM folders.
# This is done to grant the SCCM Content server access to the SCCMshare if it is remote.
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$SCCMCONTENT","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SCCM site server ($MECMSRV) computer account permissions to the SCCM folders.
# This is done to grant the SCCM site server access to the SCCMshare if it is remote.
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$MECMSRV","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Applied to This Folder, Subfolders and Files
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Apply the permision to the folder
Set-Acl $SCCMFOLDER $acl

### Share the folder... 
# Use the method below to add multiple users/groups with the same permissions to the share
# Note do not add/include the domain name when setting the variables ($FullAccessAccts, $CHGAccessAccts, etc..)
# $CHGAccessAccts = (“SALEDPT”,”LOCALGRP”)
# $READAccessAccts=(“MARKGRP”,”BARKGRP”)
Write-Host -foregroundcolor green "Share MECM Folders..."

$FullAccessAccts = (“Administrators”,”$NETACCT”,"$SCCMCONTENT","$MECMSRV")
#New-SMBShare –Name “Shared” –Path “C:\Shared” –FullAccess $FullAccessAccts –ChangeAccess $CHGAccessAccts –ReadAccess $READAccessAccts
#New-SMBShare –Name “Shared” –Path “C:\Shared” –FullAccess “Administrators”
New-SMBShare –Name “SCCMSHARE” –Path “$SCCMFOLDER” –FullAccess $FullAccessAccts


###################################################################################################
### Install SQL_SERVER_2014_EXPRESS_x64
# Install the TOOLS option only.
# This command can be used to provide the SQLCMD command used to configure WSUS Custom indexes.
#
# Write-Host -foregroundcolor green "Istalling SQL_SERVER_2014_EXPRESS_x64..."
# Start-Process -Wait -FilePath "C:\WSUSMaint\SQL_SERVER_2014_EXPRESS_x64\InstallSQL2014Express.cmd"


###################################################################################################
########################## INSTALL PREREQISITES FOR SQLCMD
# REBOOT SERVER AFTER THESE COMMAND INSTALLS
#
# Note a Server Reboot is needed after this command. If you don't the SQLCMD command may fail.
# REBOOT AFTER THIS COMMAND.
#
### INSTALL Visual C++ Redistributable for Visual Studio 2019 (x64)
C:\WSUS_STAGING\SQLCMD\VC_redist.x64.exe /passive /norestart
Start-Sleep -Seconds 15

### INSTALL Microsoft ODBC Driver <17> for SQL Server
# Start-Process -Wait C:\MECM_CB_2203\AdminConsole_2203\AdminConsole.msi -ArgumentList 'INSTALL=ALL ALLUSERS=1 TARGETDIR="D:\MECM\AdminConsole" DEFAULTSITESERVERNAME=USS-SRV-14.USS.LOCAL ADDLOCAL="AdminConsole,SCUIFramework" /passive /norestart'
# Start-Process -Wait C:\WSUSMaint\SQLCMD\msodbcsql.msi -ArgumentList 'IACCEPTMSODBCSQLLICENSETERMS=YES /passive /norestart'

$argumentList = @(
  '/i'
  '"{0}"' -f "C:\WSUS_STAGING\SQLCMD\msodbcsql.msi"
  '/passive'
  '/norestart'
  'IACCEPTMSODBCSQLLICENSETERMS=YES'
  )

$startArgs = @{
  "FilePath" = "msiexec.exe"
  "ArgumentList" = $argumentList
  "Wait" = $true
}
Start-Process @startArgs

###
###### INSTALL Microsoft Command Line Utilies <15> for SQL Server
# Start-Process -Wait C:\MECM_CB_2203\AdminConsole_2203\AdminConsole.msi -ArgumentList 'INSTALL=ALL ALLUSERS=1 TARGETDIR="D:\MECM\AdminConsole" DEFAULTSITESERVERNAME=USS-SRV-14.USS.LOCAL ADDLOCAL="AdminConsole,SCUIFramework" /passive /norestart'
# Start-Process -Wait C:\WSUSMaint\SQLCMD\MsSqlCmdLnUtils.msi -ArgumentList '/passive /norestart'

$argumentList = @(
  '/i'
  '"{0}"' -f "C:\WSUS_STAGING\SQLCMD\MsSqlCmdLnUtils.msi"
  '/passive'
  '/norestart'
  'IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES'
)

$startArgs = @{
  "FilePath" = "msiexec.exe"
  "ArgumentList" = $argumentList
  "Wait" = $true
}
Start-Process @startArgs



<#
# Create the SCCM Share sub Folders
# New-Item $SCCMFOLDER –Type Directory
Write-Host -foregroundcolor green "Create the SCCM Share Sub Folders..."

New-Item $SCCMFOLDER\Images –Type Directory
New-Item $SCCMFOLDER\SCCM_InstallFiles –Type Directory
New-Item $SCCMFOLDER\SMS_PkgSource –Type Directory
New-Item $SCCMFOLDER\SCCM_CLIENT –Type Directory
New-Item $SCCMFOLDER\OSDDrivers –Type Directory
New-Item $SCCMFOLDER\OSDDrivers\WINPEx86 –Type Directory
New-Item $SCCMFOLDER\OSDDrivers\WINPEx86\MASS –Type Directory
New-Item $SCCMFOLDER\OSDDrivers\WINPEx86\NIC –Type Directory
New-Item $SCCMFOLDER\OSDDrivers\WINPEx64 –Type Directory
New-Item $SCCMFOLDER\OSDDrivers\WINPEx64\MASS –Type Directory
New-Item $SCCMFOLDER\OSDDrivers\WINPEx64\NIC –Type Directory
New-Item $SCCMFOLDER\OSDDrivers\W10x64 –Type Directory
New-Item $SCCMFOLDER\OSDDrivers\W2019x64 –Type Directory

#>


###################################################################################################
##### ADD DEFENDER WSUS Exclusions
###################################################################################################

# Microsoft Defender Antivirus on Windows Server 2016 and 2019 automatically enrolls you in certain exclusions,
# as defined by your specified server role. See the list of automatic exclusions (in this article). 
# These exclusions do not appear in the standard exclusion lists that are shown in the Windows Security app.
# Refer to the following link to determine which folders, files and process are automatically excluded:
# https://docs.microsoft.com/en-us/windows/security/threat-protection/microsoft-defender-antivirus/configure-server-exclusions-microsoft-defender-antivirus#list-of-automatic-exclusions

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
Write-Host -foregroundcolor green "ADDING DEFENDER WSUS Exclusions..."

# Add defender Folder Exclusions:
Add-MpPreference -ExclusionPath "C:\WSUSMaint"
Add-MpPreference -ExclusionPath "C:\WSUSScripts"
Add-MpPreference -ExclusionPath "C:\WSUS_STAGING"
Add-MpPreference -ExclusionPath "$WSUS_CONT_DRV"
Add-MpPreference -ExclusionPath "D:\WSUSImports"
Add-MpPreference -ExclusionPath "D:\WSUSExports"
Add-MpPreference -ExclusionPath "C:\Windows\SoftwareDistribution\DataStore"
Add-MpPreference -ExclusionPath "C:\Windows\SoftwareDistribution\Download"
Add-MpPreference -ExclusionPath "C:\Windows\WID\Data"

# Add defender Extension Exclusions:
Add-MpPreference -ExclusionExtension ".XML.GZ"
Add-MpPreference -ExclusionExtension ".CAB"

# Add defender Process Exclusions:
Add-MpPreference -ExclusionProcess "C:\Program Files\Update Services\Tools\WsusUtil.exe"
Add-MpPreference -ExclusionProcess "C:\Program Files\Update Services\Services\WsusService.exe"

###################################################################################################
Stop-Transcript




# ******* REBOOT SERVER HERE ******




