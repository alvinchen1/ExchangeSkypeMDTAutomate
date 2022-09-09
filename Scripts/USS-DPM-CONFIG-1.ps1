###################################################################################################
##################### USS-DPM-CONFIG-1.ps1 ###################################################
###################################################################################################

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Configure the MGMT NIC and set its IP Address and DNS Address.

# -Set Offline Disks Online
# -Initilize ALL disk
# -Partiton and Assign Drive Letter to ALL Disk
# -Format the Volumes
#
# *** Before runnng this script ensure that the following drive exist on the DPM Site server ***
#
# (C:)(158gb+) OS - Page file (4k, NTFS)
# (D:)(1TB+) DPM_PROG_FILES - (4k, NTFS)
# (E:)(300GB+) SQL_DB - (64k, ReFS)
# (F:)(50-250TB+) DPM_STOR - (64k BlockSize, ReFS)(VHDX file on physical server (PA-01)

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-DPM-CONFIG-1.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-DPM-CONFIG-1.log


###################################################################################################
### MODIFY These Values
### ENTER WSUS MGMT NIC IP Addresses Info
$DPM_MGMT_IP = "10.1.102.58"
$DNS1 = "10.1.102.50"
$DNS2 = "10.1.102.51"
$DEFAULTGW = "10.1.102.1"
$PREFIXLEN = "24" # Set subnet mask /24, /25

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
# Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DPM_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DPM_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false

### Set the MGMT NIC DNS Addresses
# Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses '10.1.102.50','10.1.102.51'
Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2

###################################################################################################
Write-Host -foregroundcolor green "Configure Disk for DPM..."

### Set Offline Disks Online 
# Get-Disk
Set-disk 1 -isOffline $false
Set-disk 2 -isOffline $false
Set-disk 3 -isOffline $false
# Set-disk 4 -isOffline $false

###################################################################################################
### Initilize ALL disk
Get-Disk | where PartitionStyle -eq 'raw' | Initialize-Disk -PartitionStyle GPT

###################################################################################################
### Partiton and Assign Drive Letter to ALL Disk
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter D 
New-Partition -DiskNumber 2 -UseMaximumSize -DriveLetter E
New-Partition -DiskNumber 3 -UseMaximumSize -DriveLetter F
#New-Partition -DiskNumber 4 -UseMaximumSize -DriveLetter G

### Format the Volumes
Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel “DPM_PROG_FILES” -Confirm:$false
Format-Volume -DriveLetter E -FileSystem ReFS -AllocationUnitSize 64KB -NewFileSystemLabel “SQL_DB” -Confirm:$false
Format-Volume -DriveLetter F -FileSystem ReFS -AllocationUnitSize 64KB -NewFileSystemLabel “DPM_STOR” -Confirm:$false
# Format-Volume -DriveLetter G -FileSystem ReFS -AllocationUnitSize 64KB -NewFileSystemLabel  “SPARE” -Confirm:$false


###################################################################################################
Stop-Transcript


######################################### REBOOT THE SERVER ###########################################
# Restart-Computer