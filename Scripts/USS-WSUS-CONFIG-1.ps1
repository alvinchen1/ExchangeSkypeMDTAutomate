###################################################################################################
##################### USS-WSUS-CONFIG-1.ps1 ###################################################
###################################################################################################

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Configure the MGMT NIC and set its IP Address and DNS Address.
# -COPY WSUS STAGING FOLDER TO LOCAL DRIVE
# -Install .NET Framework 3.5.1
# -Copy CMTrace
# -Install REPORT VIEWER 2012 RUNTIME and Microsoft System CLR Types for Microsoft SQL Server 2012
# -Install WSUS Service
# -Set Offline Disks Online
# -Initilize ALL disk
# -Partiton and Assign Drive Letter to ALL Disk
# -Format the Volumes


# *** Before runnng this script ensure that ALL the PREREQ and Software to install WSUS is located in the
# $WSUSSTAGING folder on the MDT server. ***

# *** Before runnng this script ensure that the following drive exist on the WSUS server:
# (C:)(100b+) For OS, page file (4k, NTFS)
# (D:)(400gb+) MECM Share (4k, NTFS)
# (E:)(300gb+) WSUS (4k, NTFS)


###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-WSUS-CONFIG-1.log
Start-Transcript -Path \\DEV-MDT-01\DEPLOYMENTSHARE$\LOGS\USS-WSUS-CONFIG-1.log

###################################################################################################
# MODIFY/ENTER These Values Before Running This Script.

### ENTER WSUS Server host names.
# MDT will set host name in OS
$WSUSSRV = "USS-SRV-16"

### ENTER WSUS MGMT NIC IP Addresses Info
$WSUSSRV_MGMT_IP = "10.10.5.16"
$DNS1 = "10.10.5.11"
$DNS2 = "10.10.5.12"
$DEFAULTGW = "10.10.5.1"
$PREFIXLEN = "25" # Set subnet mask /24, /25

### ENTER SCCM STAGING FOLDER
$MDTSTAGING = "\\DEV-MDT-01\STAGING"

###################################################################################################
### Rename the NICs
#
Write-Host -foregroundcolor green "Configure the NICs..."
Rename-NetAdapter –Name “Ethernet” –NewName “NIC_MGMT1_1GB”

Write-Host -foregroundcolor green "Configuring NICs"
### Prepare MGMT NICs for New IP Address ##########################################################
# Remove IP Address from MGMT NIC.
Get-netadapter NIC_MGMT1_1GB | get-netipaddress –addressfamily ipv4 | remove-netipaddress -Confirm:$false

### Set the MGMT NICs IP Addresses 
#
# Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $WSUSSRV_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $WSUSSRV_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false

### Set the MGMT NIC DNS Addresses
# Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses '10.10.4.11','10.10.4.12'
Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2

### COPY WSUS STAGING FOLDER TO LOCAL DRIVE ###########################################################################
# Copy the WSUS_STAGING folder to the MDT STAGING folder:
# Copy-Item '\\BBB-SC-01\d$\WSUS_STAGING' -Destination D:\STAGING -Recurse
# Copy-Item '\\SRV-MDT-01\STAGING\WSUS_STAGING' -Destination C:\ -Recurse
# Copy-Item $MDTSTAGING -Destination C:\ -Recurse
Write-Host -foregroundcolor green "Copying WSUS Script folders to C:\"

Copy-Item $MDTSTAGING\SCRIPTS\WSUSScripts -Destination C:\ -Recurse
Copy-Item $MDTSTAGING\SCRIPTS\WSUSMaint -Destination C:\ -Recurse
Copy-Item $MDTSTAGING\SQLCMD -Destination C:\WSUSMaint -Recurse
Copy-Item $MDTSTAGING\SQL_SERVER_2014_EXPRESS_x64 -Destination C:\WSUSMaint -Recurse


###################################################################################################
############# Install WSUS 2019 Prerequisites #####################################################
#### The script below assumes all WSUS and Prereqs files have been copied to the C:\WSUS_STAGING folders.
# Run this on the WSUS server (USS-WSUS-01)
#
# Install .NET Framework 3.5.1
# Ensure you copy the Windows 2019 DVD\Sources\Sxs folder in the staging folder
Write-Host -foregroundcolor green "Installing .NET Framework 3.5.1"
Dism /online /enable-feature /featurename:NetFx3 /All /Source:$MDTSTAGING\W2019\Sources\Sxs /LimitAccess

# Copy CMTrace
# Write-Host -foregroundcolor green "Copying CMTrace"
# Copy $MDTSTAGING\CMTRACE\CMTrace.exe C:\ 

# Install REPORT VIEWER 2012 RUNTIME and Microsoft System CLR Types for Microsoft SQL Server 2012
# These are still needed for SCCM CB 1902 to read WSUS Reports.
# No other version of Report Viewer (2015, 2016, etc..) will work. If you don't use 2012 you will get an error message when 
# you attempt to open a WSUS report.
# The Start-Process msiexec -Wait -ArgumentList switches calls the .MSI and wait for the process to finish before continuing.
# Start-Process msiexec -Wait -ArgumentList '/I C:\WSUS_STAGING\REPORT_VIEWER_2012\SQLSysCLRTypes.msi /passive /norestart'
# Start-Process msiexec -Wait -ArgumentList '/I C:\WSUS_STAGING\REPORT_VIEWER_2012\ReportViewer.msi /passive /norestart'
# Install Microsoft System CLR Types for Microsoft SQL Server 2012
Write-Host -foregroundcolor green "Install Microsoft System CLR Types"

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
Write-Host -foregroundcolor green "Install REPORT VIEWER 2012 RUNTIME"
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

# Start-Sleep -s 20

###################################################################################################
############# Install WSUS ##########################################
#
## When using a WID database for WSUS
# the "&" symbol/call operator allows PowerShell to call and execute a command in a string.
# the call operator "&" allow you to execute/run a CMD command, script or funtion in PowerShell.
Write-Host -foregroundcolor green "Installing WSUS"
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools

Write-Host -foregroundcolor green "Configuring Disk for WSUS"
### Set Offline Disks Online
# Get-Disk
Set-disk 1 -isOffline $false
Set-disk 2 -isOffline $false
Set-disk 3 -isOffline $false

### Initilize ALL disk
Get-Disk | where PartitionStyle -eq 'raw' | Initialize-Disk -PartitionStyle GPT

### Partiton and Assign Drive Letter to ALL Disk
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter D 
New-Partition -DiskNumber 2 -UseMaximumSize -DriveLetter E
New-Partition -DiskNumber 3 -UseMaximumSize -DriveLetter F

### Format the Volumes
Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel “MECMShare” -Confirm:$false
Format-Volume -DriveLetter E -FileSystem NTFS -NewFileSystemLabel “WSUS” -Confirm:$false
Format-Volume -DriveLetter F -FileSystem NTFS -NewFileSystemLabel “DATA2” -Confirm:$false

###################################################################################################
Stop-Transcript

######################################### REBOOT SERVER ###########################################
# Restart-Computer
