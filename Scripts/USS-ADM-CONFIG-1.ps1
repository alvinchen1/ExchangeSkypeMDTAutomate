########## ADM-CONFIG-1 ############



### This script is designed to work with MDT.
### MDT will handle Reboots.
#
#
# *** Before runnng this script ensure that the following drive exist on the server ***
#
# (C:)(120gb+) OS - Page file (4k, NTFS)
# (D:)(7TB+) MECM - VMs (64k, ReFS)
# (E:)(100-250TB+) - DPM STORAGE (64k, ReFS)
#
### This script will:
#
# -Configure the MGMT TEAM NIC and set its IP Address and DNS Address.
# -Configure the VM TEAM NIC and set its IP Address and DNS Address.
# -DISABLE NETWORK ADAPTER BINDINGS on the VM TEAM
# -Install Hyper-V
# -Install Failover Cluster Manager roles.

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-ADM-CONFIG-1.log
Start-Transcript -Path \\DEV-MDT-01\DEPLOYMENTSHARE$\LOGS\$env:COMPUTERNAME\USS-ADM-CONFIG-1.log

###################################################################################################
# MODIFY/ENTER These Values

### Set the following variable before running this script.
$MGMT_NIC_IP = "10.10.5.55"
# $MGMT_NIC_IP = "10.10.5.30"
$DNS1 = "10.10.5.11"
$DNS2 = "10.10.5.12"
$DEFAULTGW = "10.10.5.1"
$PREFIXLEN = "25" # Set subnet mask /24, /25

###################################################################################################
### Rename the NICs
#
### -Compute traffic - traffic originating from or destined for a virtual machine (VM)
### -Storage traffic - traffic for Storage Spaces Direct (S2D)/Live Migration using Server Message Block (SMB)
### -Management traffic - traffic important to an administrator for cluster management, such as Active Directory, Remote Desktop, Windows Admin Center, and Windows PowerShell.
#
# NIC NAMING LEGEND:
# -MGMT = Management traffic
# -STOR = Storage traffic
# -VM = Compute traffic
#
# -NIC_MGMT1_10GB (For Host management traffic)
# -NIC_MGMT2_10GB (For Host management traffic)
# -NIC_VM1_10GB (For virtual machine network traffic)
# -NIC_VM2_10GB (For virtual machine network traffic)
# -NIC_STOR1_25GB (For storage (S2D) traffic) (Direct-Attach Cables)
# -NIC_STOR2_25GB (For storage (S2D) traffic) Direct-Attach Cables)
Rename-NetAdapter –Name “Ethernet” –NewName “NIC_MGMT1_1GB”
Rename-NetAdapter –Name “Ethernet 2” –NewName “NIC_MGMT2_1GB”
Rename-NetAdapter –Name “CPU SLOT 2 Port 1” –NewName “NIC_VM1_10GB”
Rename-NetAdapter –Name “CPU SLOT 2 Port 2” –NewName “NIC_VM2_10GB”
Rename-NetAdapter –Name “CPU SLOT 6 Port 1” –NewName “NIC_VM3_10GB”
Rename-NetAdapter –Name “CPU SLOT 6 Port 2” –NewName “NIC_VM4_10GB”

###################################################################################################
### TEAM MGMT and VM NICs 
### (OPTION#_1_PHYSICAL SERVER NICs) Set the NIC Teams (Load-Balancing Failover - LBFO)
New-NetLbfoTeam -Name "TEAM_MGMT" -TeamMembers "NIC_MGMT1_10GB","NIC_MGMT2_10GB" -TeamingMode SwitchIndependent -LoadBalancingAlgorithm HyperVPort -Confirm:$false
New-NetLbfoTeam -Name "TEAM_VM" -TeamMembers "NIC_VM1_10GB","NIC_VM2_10GB","NIC_VM3_10GB","NIC_VM4_10GB" -TeamingMode SwitchIndependent -LoadBalancingAlgorithm HyperVPort -Confirm:$false

Start-Sleep -Seconds 40

### Prepare MGMT and VM NICs for New IP Address ##########################################################
# Remove IP Address from TEAMs.
Get-netadapter TEAM_MGMT | get-netipaddress –addressfamily ipv4 | remove-netipaddress -Confirm:$false
Get-netadapter TEAM_VM | get-netipaddress –addressfamily ipv4 | remove-netipaddress -Confirm:$false

### Configure MGMT NICs ###############################################################

# Set IP Address on TEAMs.
Get-netadapter TEAM_MGMT | New-NetIPAddress -IPAddress $MGMT_NIC_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false

### Set the MGMT TEAMs DNS Addresses
# DO NOT set a DNS address for the "TEAM_VM" and "TEAM_STOR NIC/TEAMS. 
# We don't want the TEAM_VM and TEAM_STOR TEAMS to register in DNS.
# Get-NetAdapter TEAM_MGMT | Set-DnsClientServerAddress -ServerAddresses '10.10.5.11','10.10.5.12'
Get-NetAdapter TEAM_MGMT | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2

##################################################################################################
### 
### For the "TEAM_VM", Unregister/Uncheck "Register this connection's addresses" and "Use this connection's DNS suffix"
### The below example would check the Register this connection's addresses in DNS box and uncheck the Use this connection's DNS suffix in DNS box"
# https://stackoverflow.com/questions/57366593/how-to-set-dns-suffix-and-registration-using-powershell
Get-NetAdapter TEAM_VM | Set-DnsClient -RegisterThisConnectionsAddress $false


##################################################################################################
### (POWERSHELL) – DISABLE NETWORK ADAPTER BINDINGS
### Disable Network Adapter Bindings on "TEAM_VM" NICs/TEAMs
# To disable a specific binding such as Client for Microsoft Networks, you can use the Disable-NetAdapterBinding cmdlet.
# List All Bindings on server.
# Get-NetAdapterBinding
#
# Only perform this step on the "TEAM_VM" NICs/TEAMs.
# DO NOT Perform this step on the TEAM_MGMT NIC/TEAM.
# Disable the follwing bindings:
Disable-NetAdapterBinding -Name "TEAM_VM" -ComponentID ms_msclient # Client for Microsoft Networks
Disable-NetAdapterBinding -Name "TEAM_VM" -ComponentID ms_server # File and Printer Sharing for Microsoft Networks
Disable-NetAdapterBinding -Name "TEAM_VM" -ComponentID ms_tcpip6 # Internet Protocol Version 6 (TCP/IPv6)             
Disable-NetAdapterBinding -Name "TEAM_VM" -ComponentID ms_lltdio # Link-Layer Topology Discovery Mapper I/O Driver    
Disable-NetAdapterBinding -Name "TEAM_VM" -ComponentID ms_rspndr # Link-Layer Topology Discovery Responder            

###################################################################################################
### Install Hyper-V
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools

###################################################################################################
# Install Failover Cluster Manager roles.
Install-WindowsFeature -Name Failover-Clustering –IncludeManagementTools
Install-windowsfeature RSAT-Clustering –IncludeAllSubFeature

###################################################################################################
### Configure SSD and HDD Disk For Admin Server #######################################
Write-Host -foregroundcolor green "Configuring Disk for Admin Server..."
###################################################################################################

### Create Storage Pool
# The following example shows which physical disks are available in the primordial pool.
# Get-StoragePool -IsPrimordial $true | Get-PhysicalDisk -CanPool $True
# -MediaType SSD
# Get-StoragePool -IsPrimordial $true | Get-PhysicalDisk -CanPool $True
# Get-StoragePool -IsPrimordial $true | Get-PhysicalDisk -CanPool $True
# Get-PhysicalDisk -CanPool $True | Where-Object MediaType -EQ SSD | ft FriendlyName, MediaType 
# The following example creates a new storage pool named StoragePool1 that uses all available disks.
# New-StoragePool –FriendlyName StoragePool1 –StorageSubsystemFriendlyName "Windows Storage*" –PhysicalDisks (Get-PhysicalDisk –CanPool $True)

### Remove any existing Virtual Disk
Get-VirtualDisk | Remove-VirtualDisk -Confirm:$false

### Remove any existing Storage Pools
Get-StoragePool | Remove-StoragePool -Confirm:$false

# Get-VirtualDisk
# Get-StoragePool
# Get-Volume

### Clean Existing Drives for Storage Pools
# https://docs.microsoft.com/en-us/windows-server/storage/storage-spaces/deploy-storage-spaces-direct
# Before you enable Storage Spaces Direct, ensure your drives are empty: no old partitions or other data.
# Note use this when the drives that will be used for S2D have been used before.
# This script will permanently remove any data on any drives other than the operating system boot drive!
# Run the following script, substituting your computer names, to remove all any old partitions or other data.
Get-StoragePool | ? IsPrimordial -eq $false | Set-StoragePool -IsReadOnly:$false -ErrorAction SilentlyContinue
Get-StoragePool | ? IsPrimordial -eq $false | Get-VirtualDisk | Remove-VirtualDisk -Confirm:$false -ErrorAction SilentlyContinue
Get-StoragePool | ? IsPrimordial -eq $false | Remove-StoragePool -Confirm:$false -ErrorAction SilentlyContinue
Get-PhysicalDisk | Reset-PhysicalDisk -ErrorAction SilentlyContinue
Get-Disk | ? Number -ne $null | ? IsBoot -ne $true | ? IsSystem -ne $true | ? PartitionStyle -ne RAW | % {
        $_ | Set-Disk -isoffline:$false
        $_ | Set-Disk -isreadonly:$false
        $_ | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false
        $_ | Set-Disk -isreadonly:$true
        $_ | Set-Disk -isoffline:$true
    }

### Create SSD POOL Using All SSD Drives
# Remove-StoragePool SSD_POOL -Confirm:$false
# Remove-StoragePool HDD_POOL -Confirm:$false
#
### Create SSD POOL Using All SSD Drives
New-StoragePool –FriendlyName SSD_POOL –StorageSubsystemFriendlyName "Windows Storage*" –PhysicalDisks (Get-PhysicalDisk -CanPool $True | Where-Object MediaType -EQ SSD)

### Create HDD POOL Using All HDD Drives
New-StoragePool –FriendlyName HDD_POOL –StorageSubsystemFriendlyName "Windows Storage*" –PhysicalDisks (Get-PhysicalDisk -CanPool $True | Where-Object MediaType -EQ HDD)

###################################################################################################
### Create Virtual Disk, Create Volume, Format Disk, Assigns Drive Letter.
#
# Uses parity uses 70-80% of total available disk space/size.
New-Volume -StoragePoolFriendlyName SSD_POOL -FriendlyName "VMs-REFS" -FileSystem REFS -AllocationUnitSize 64KB -UseMaximumSize -ResiliencySettingName Parity –DriveLetter D
New-Volume -StoragePoolFriendlyName HDD_POOL -FriendlyName "DPMSTOR-REFS" -FileSystem REFS -AllocationUnitSize 64KB -UseMaximumSize -ResiliencySettingName Parity –DriveLetter E

# Get-VirtualDisk
# Get-StoragePool
# Get-Volume

# Remove-Partition -DriveLetter D -Confirm:$false
# Remove-Partition -DriveLetter E -Confirm:$false
# Remove-VirtualDisk -FriendlyName VM -Confirm:$false
# Remove-VirtualDisk -FriendlyName DPMSTOR -Confirm:$false

###################################################################################################
Stop-Transcript


### REBOOT SERVER





