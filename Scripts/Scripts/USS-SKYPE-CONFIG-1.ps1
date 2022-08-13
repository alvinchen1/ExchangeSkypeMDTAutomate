###################################################################################################
##################### USS-SKYPE-CONFIG-1.ps1 ###################################################
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
# *** Before runnng this script ensure that the following drive exist on the MECM Site server ***
#
# (C:)(120gb+) OS - Page file (4k, NTFS)
# (D:)(30gb+) SKYPE-BIN - (4k, NTFS)
# (E:)(500gb+) SKYPE-DB - (4k, NTFS)
# (F:)(40gb+) SKYPE-LOGS - (64k BlockSize, ReFS)

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path –Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path –Parent
$RootDir = Split-Path $ScriptDir –Parent
$ConfigFile = "$RootDir\config.xml"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) 
{
    Write-Host "Missing configuration file $ConfigFile" -ForegroundColor Red
### Stop-Transcript
    Exit
}
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value 

###################################################################################################
### Start-Transcript
### Stop-Transcript
### Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\$ScriptName.log
Start-Transcript -Path $RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
###Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-EXCHG-CONFIG-1.log
###Start-Transcript -Path \\DEV-MDT-01\DEPLOYMENTSHARE$\LOGS\$env:COMPUTERNAME\USS-EXCHG-CONFIG-1.log

###################################################################################################
### MODIFY These Values
### ENTER WSUS MGMT NIC IP Addresses Info
$MECM_MGMT_IP = "10.10.5.19"
$DNS1 = "10.10.5.11"
$DNS2 = "10.10.5.12"
$DEFAULTGW = "10.10.5.1"
$PREFIXLEN = "25" # Set subnet mask /24, /25

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
# Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses '10.10.5.11','10.10.5.12'
Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2

###################################################################################################
#Write-Host -foregroundcolor green "Configure Disk for EXCHAGE..."

### Set Offline Disks Online 
# Get-Disk
# Set-disk 1 -isOffline $false
# Set-disk 2 -isOffline $false
# Set-disk 3 -isOffline $false
# Set-disk 4 -isOffline $false

###################################################################################################
### Initilize ALL disk
# Get-Disk | where PartitionStyle -eq 'raw' | Initialize-Disk -PartitionStyle GPT

###################################################################################################
### Partiton and Assign Drive Letter to ALL Disk
# New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter D 
# New-Partition -DiskNumber 2 -UseMaximumSize -DriveLetter E
# New-Partition -DiskNumber 3 -UseMaximumSize -DriveLetter F
# New-Partition -DiskNumber 4 -UseMaximumSize -DriveLetter G

### Format the Volumes
# Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel “EXCHG-BIN” -Confirm:$false
# Format-Volume -DriveLetter E -FileSystem ReFS -AllocationUnitSize 64KB -NewFileSystemLabel “EXCHG-DB” -Confirm:$false
# Format-Volume -DriveLetter F -FileSystem ReFS -AllocationUnitSize 64KB -NewFileSystemLabel “EXCHG-LOGS” -Confirm:$false
# Format-Volume -DriveLetter G -FileSystem ReFS -AllocationUnitSize 64KB -NewFileSystemLabel  “DATA” -Confirm:$false


###################################################################################################
Stop-Transcript


######################################### REBOOT THE SERVER ###########################################
# Restart-Computer