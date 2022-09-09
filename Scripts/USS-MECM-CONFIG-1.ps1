###################################################################################################
##################### USS-MECM-CONFIG-1.ps1 ###################################################
###################################################################################################

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Configure the MGMT NIC and set its IP Address and DNS Address.
# -COPY WSUS STAGING FOLDER TO LOCAL DRIVE
# -COPY MECM STAGING FOLDER TO LOCAL DRIVE
# -Install .NET Framework 3.5.1
# -Install .NET Framework 4.8
# -Install BITS and IIS
# -Copy CMTrace 
# -Install REPORT VIEWER 2051 RUNTIME and Microsoft System CLR Types for Microsoft SQL Server 2051
# -INSTALL RSAT-AD-PowerShell
# -Set Offline Disks Online
# -Initilize ALL disk
# -Partiton and Assign Drive Letter to ALL Disk
# -Format the Volumes
#
# *** Before runnng this script ensure that the following drive exist on the MECM Site server ***
#
# (C:)(510gb+) RAID 1 OS - Page file (4k, NTFS)
# (D:)(250gb+) RAID 1 MECM - SCCM Inboxes, SCCMContentlib (4k, NTFS)
# (E:)(300gb+) RAID 1 WSUS/SUP, DP Content, MDT (4k, NTFS)
# (F:)(50gb+) RAID 5 SQLDB - (64k BlockSize, ReFS)
# (G:)(60gb+) RAID 1 SQLLOGS - transaction logs,UserDBlog, SQL TempDB logs, SCCMBackup (64k BlockSize, ReFS)
#
## UPDATE the variables in the following SCCM_STAGING\SCRIPTS Folder:
# -MECM_CB_2103_ALLROLES.ini
# -USS_SQL2019ForSCCM2103.ini

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-MECM-CONFIG-1.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-MECM-CONFIG-1.log


###################################################################################################
### MODIFY These Values
### ENTER WSUS MGMT NIC IP Addresses Info
$MECM_MGMT_IP = "10.1.102.52"
$DNS1 = "10.1.102.50"
$DNS2 = "10.1.102.51"
$DEFAULTGW = "10.1.102.1"
$PREFIXLEN = "24" # Set subnet mask /24, /25

### ENTER MDT STAGING FOLDER
$MDTSTAGING = "\\DEP-MDT-01\STAGING"

### ENTER SCCM STAGING FOLDER
# $MDTSTAGING = "\\DEP-MDT-01\STAGING\SCCM_STAGING"

### ENTER WSUS STAGING FOLDER
# $MDTSTAGING = "\\DEP-MDT-01\STAGING\WSUS_STAGING"

### ENTER WSUS STAGING FOLDER:
# This is the folder that contains all the PREREQ and Software to install WSUS.
# $MDTSTAGINGFLDR = '\\DEP-MDT-01\STAGING\WSUS_STAGING'

### ENTER MECM STAGING FOLDER:
# This is the folder that contains all the PREREQ and Software to install WSUS.
# $MECMSTAGINGFLDR = '\\DEP-MDT-01\STAGING\SCCM_STAGING'

###################################################################################################
Write-Host -foregroundcolor green "Configure NICs..."

### Rename the NICs
#
Rename-NetAdapter –Name “Ethernet” –NewName “NIC_MGMT1_1GB”

###################################################################################################
### Prepare MGMT NICs for New IP Address 
# Remove IP Address from MGMT NIC.
Get-netadapter NIC_MGMT1_1GB | get-netipaddress –addressfamily ipv4 | remove-netipaddress -Confirm:$false

### Set the MGMT NICs IP Addresses 
#
# Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $MECM_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $MECM_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false

### Set the MGMT NIC DNS Addresses
# Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses '10.1.102.50','10.1.102.51'
Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2

###################################################################################################
### COPY MECM CONFIGURATION FILE TO LOCAL DRIVE 
# Copy the MECM_STAGING folder to the MDT STAGING folder:
# Copy-Item $MECMSTAGINGFLDR -Destination C:\ -Recurse -Force
# Copy-Item $MDTSTAGING\SCRIPTS\USS_SQL2019ForSCCM2103.ini -Destination C:\Windows\Temp -Recurse -Force
# Write-Host -foregroundcolor green "Copying MECM CONFIG FILE to local drive - C:\Windows\Temp"
# Copy-Item $MDTSTAGING\SCRIPTS\$MECMCONFIGFILE -Destination C:\Windows\Temp\MECM_CB_2103_ALLROLES.ini -Recurse -Force
# Write-Host -foregroundcolor green "Copying MECM CONFIG FILE to local drive - C:\"
# Copy-Item $MDTSTAGING\SCRIPTS\$MECMCONFIGFILE -Destination C:\Windows\Temp\MECM_CB_2103_ALLROLES.ini -Recurse -Force
# Copy-Item $MDTSTAGING\MECM_CB_2103 -Destination C:\ -Recurse -Force
# Copy-Item $MDTSTAGING\MECM_CB_2103_PREQCOMP -Destination C:\ -Recurse -Force
#
# Copy-Item $MDTSTAGING\MECM_CB_2203 -Destination C:\ -Recurse -Force
# Copy-Item $MDTSTAGING\MECM_CB_2203_PREQCOMP -Destination C:\ -Recurse -Force
Write-Host -foregroundcolor green "Copying MECM_STAGING Folder to local drive - C:\"
Copy-Item $MDTSTAGING\MECM_STAGING -Destination C:\ -Recurse -Force
Copy-Item $MDTSTAGING\SCRIPTS\MECM\* -Destination C:\MECM_STAGING\MECM_CB_2203

###################################################################################################
### Install WSUS 2019 Prerequisites 
# The script below assumes all WSUS and Prereqs files have been copied to the C:\WSUS_STAGING folders.
# Run this on the WSUS server (USS-WSUS-01)
#
# Install .NET Framework 3.5.1
# Ensure you copy the Windows 2019 DVD\Sources\Sxs folder in the staging folder
# Dism /online /enable-feature /featurename:NetFx3 /All /Source:C:\WSUS_STAGING\W2019\Sources\Sxs /LimitAccess
Write-Host -foregroundcolor green ".NET Framework 3.5.1..."
# Dism /online /enable-feature /featurename:NetFx3 /All /Source:$MDTSTAGING\W2019\Sources\Sxs /LimitAccess
Dism /online /enable-feature /featurename:NetFx3 /All /Source:C:\MECM_STAGING\W2019\Sources\Sxs /LimitAccess

###################################################################################################
### Install MECM 2103 Prerequisites 
# The script below assumes all SCCM and Prereqs files have been copied to the D:\MECM_STAGING folders.
#
# Run this script on the SCCM SITE SERVER (USS-SRV-52).
#
###
# Install .NET Framework 4.8
# Ensure you copy the DOTNETFRAMEWORK_4.8 folder to the staging folder
# Start-Process $MDTSTAGING\DOTNETFRAMEWORK_4.8\ndp48-x86-x64-allos-enu.exe -Wait -NoNewWindow -ArgumentList "/passive /norestart"
Write-Host -foregroundcolor green "Installing .NET Framework 4.8..."
Start-Process C:\MECM_STAGING\DOTNETFRAMEWORK_4.8\ndp48-x86-x64-allos-enu.exe -Wait -NoNewWindow -ArgumentList "/passive /norestart"

### Install BITS and IIS
# Bits is needed for the Distribution Point and  Management Point.
Write-Host -foregroundcolor green "Installing BITS and Web-WMI..."
Install-WindowsFeature BITS
Install-WindowsFeature Web-WMI

# Install REPORT VIEWER 2012 RUNTIME and Microsoft System CLR Types for Microsoft SQL Server 2012
# These are still needed for SCCM CB 1902 to read WSUS Reports.
# No other version of Report Viewer (2015, 2016, etc..) will work. If you don't use 2012 you will get an error message when 
# you attempt to open a WSUS report.
# The Start-Process msiexec -Wait -ArgumentList switches calls the .MSI and wait for the process to finish before continuing.
# Start-Process msiexec -Wait -ArgumentList '/I C:\WSUS_STAGING\REPORT_VIEWER_2012\SQLSysCLRTypes.msi /passive /norestart'
# Start-Process msiexec -Wait -ArgumentList '/I C:\WSUS_STAGING\REPORT_VIEWER_2012\ReportViewer.msi /passive /norestart'
# Start-Process msiexec -Wait -NoNewWindow -ArgumentList '/I $MDTSTAGING\REPORT_VIEWER_2012\SQLSysCLRTypes.msi /passive /norestart'
# Start-Process msiexec -Wait -NoNewWindow -ArgumentList '/I $MDTSTAGING\REPORT_VIEWER_2012\ReportViewer.msi /passive /norestart'
#
# Install Microsoft System CLR Types for Microsoft SQL Server 2012
Write-Host -foregroundcolor green "Install Microsoft System CLR Types..."
Start-Process msiexec -Wait -ArgumentList '/I C:\MECM_STAGING\REPORT_VIEWER_2012\SQLSysCLRTypes.msi /passive /norestart'
Start-Process msiexec -Wait -ArgumentList '/I C:\MECM_STAGING\REPORT_VIEWER_2012\ReportViewer.msi /passive /norestart'

<# JohnNote this works 9-4-22

$argumentList = @(
  '/i'
  '"{0}"' -f "$MDTSTAGING\REPORT_VIEWER_2012\SQLSysClrTypes.msi"
  '/passive'
  '/norestart'
)
$startArgs = @{
  "FilePath" = "msiexec.exe"
  "ArgumentList" = $argumentList
  "Wait" = $true
}
Start-Process @startArgs

# Install REPORT VIEWER 2012 RUNTIME
Write-Host -foregroundcolor green "Install REPORT VIEWER 2012 RUNTIME..."
$argumentList = @(
  '/i'
  '"{0}"' -f "$MDTSTAGING\REPORT_VIEWER_2012\ReportViewer.msi"
  '/passive'
  '/norestart'
)
$startArgs = @{
  "FilePath" = "msiexec.exe"
  "ArgumentList" = $argumentList
  "Wait" = $true
}
Start-Process @startArgs

#>

### INSTALL RSAT-AD-PowerShell
# Note the Add-WindowsFeature RSAT-AD-PowerShell command requires a SYSTEM REBOOT to take affect.
#
# Install the ActiveDirectory module for powershell 
# This is added to create the MECM System Management container on a domain controller.
# It will be removed after the container is created.
Write-Host -foregroundcolor green "Install RSAT-AD-PowerShell..."
Add-WindowsFeature RSAT-AD-PowerShell

###################################################################################################
Write-Host -foregroundcolor green "Configure Disk for MECM..."
Write-Host -foregroundcolor green "Setting Disk to Online..."
### Set Offline Disks Online 
# Get-Disk
Set-disk 1 -isOffline $false
Set-disk 2 -isOffline $false
Set-disk 3 -isOffline $false
Set-disk 4 -isOffline $false

###################################################################################################
Write-Host -foregroundcolor green "Initilizing, Partitioning, Create/Formating Disk/Volumes for MECM..."
# This step Initialize/Partitions Disk, Create and Format Volumes and assigns Drive Letters
# Note we stop the ShellHWDetection service to prevent prompting for confirmation when the format-volume command is used.
# Note stopping the ShellHWDetection service prevents the prompt "You need to format the disk in Drive X" although the disk is formatted.
Stop-Service -Name ShellHWDetection
Get-disk 1| Initialize-Disk -PartitionStyle GPT -PassThru|New-Partition -DriveLetter D -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "MECM" -Confirm:$false
Get-disk 2| Initialize-Disk -PartitionStyle GPT -PassThru|New-Partition -DriveLetter E -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "WSUS-WADK" -Confirm:$false
Get-disk 3| Initialize-Disk -PartitionStyle GPT -PassThru|New-Partition -DriveLetter F -UseMaximumSize | Format-Volume -FileSystem REFS -NewFileSystemLabel "SQLDB" -AllocationUnitSize 64KB -Confirm:$false
Get-disk 4| Initialize-Disk -PartitionStyle GPT -PassThru|New-Partition -DriveLetter G -UseMaximumSize | Format-Volume -FileSystem REFS -NewFileSystemLabel "SQLLOGS" -AllocationUnitSize 64KB -Confirm:$false
Start-Service -Name ShellHWDetection

###################################################################################################
Stop-Transcript


######################################### REBOOT THE SERVER ###########################################
# Restart-Computer
