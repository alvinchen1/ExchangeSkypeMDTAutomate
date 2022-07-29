########## S2D-CONFIG-1 ############

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Configure the MGMT TEAM NIC and set its IP Address and DNS Address.
# -Enable Remote Desktop
# -Stop/Prevent Server Manager from loading at startup
# -Install Hyper-V
# -Add the windows server backup feature for DPM
# -Install Failover Cluster Manager roles.
# -Enable Firewall Rule - ALL File and Printer Sharing rule
# -Enable Firewall Rule - WMI for S2D cluster creation
# -Enable Firewall Rule - Enable Windows Remote Management for S2D cluster creation
# -Change DVD Drive Letter from D: to X:. 




### ENTER the host name for the S2D Cluster nodes
# MDT will set host name in OS
$NODENAME = HOSTNAME

$NODE1 = "USS-PV-01"
$NODE2 = "USS-PV-02"
$NODE3 = "USS-PV-03"

### ENTER MGMT "TEAM" NIC IP Addresses
$NODE1_MGMT_IP = "10.10.5.31"
$NODE2_MGMT_IP = "10.10.5.32"
$NODE3_MGMT_IP = "40.40.40.40"

$DNS1 = "10.10.5.11"
$DNS2 = "10.10.5.12"
$DEFAULTGW = "10.10.5.1"
$PREFIXLEN = "25" # Set subnet mask /24, /25

### ENTER Storage NIC IP Addreses
$NODE1_STOR_IP_1 = "10.10.10.11"
$NODE1_STOR_IP_2 = "20.20.20.11"
$NODE2_STOR_IP_1 = "10.10.10.12"
$NODE2_STOR_IP_2 = "20.20.20.12"
$NODE3_STOR_IP_1 = "10.10.10.13"
$NODE3_STOR_IP_2 = "20.20.20.13"

$PREFIXLEN_S = "24" # Set subnet mask /24, /25

$DEFAULTGW_S_1 = "10.10.10.1"
$DEFAULTGW_S_2 = "20.20.20.1"



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

Rename-NetAdapter –Name “NIC1” –NewName “NIC_MGMT1_10GB”
Rename-NetAdapter –Name “NIC2” –NewName “NIC_MGMT2_10GB”
Rename-NetAdapter –Name “NIC3” –NewName “NIC_VM1_10GB”
Rename-NetAdapter –Name “NIC4” –NewName “NIC_VM2_10GB”
Rename-NetAdapter –Name “SLOT 2 Port 1” –NewName “NIC_STOR1_25GB”
Rename-NetAdapter –Name “SLOT 2 Port 2” –NewName “NIC_STOR2_25GB”

###################################################################################################
### TEAM MGMT NICs 
### (OPTION#_1_PHYSICAL SERVER NICs) Set the NIC Teams (Load-Balancing Failover - LBFO)
New-NetLbfoTeam -Name "TEAM_MGMT" -TeamMembers "NIC_MGMT1_10GB","NIC_MGMT2_10GB" -TeamingMode SwitchIndependent -LoadBalancingAlgorithm HyperVPort -Confirm:$false

Start-Sleep -Seconds 20

### Prepare MGMT NICs for New IP Address ##########################################################
# Remove IP Address from TEAMs.
Get-netadapter TEAM_MGMT | get-netipaddress –addressfamily ipv4 | remove-netipaddress -Confirm:$false


### Configure MGMT and STORAGE NICs ###############################################################
If($NODENAME -eq $NODE1){
### Set the Storage NICs IP Addresses (NIC-CONFIG-DELL-AX740-NODE_2)
# S2D Host (USS-PV-01)
# write-host("Host Name is USS-PV-01")
Get-netadapter NIC_STOR1_25GB | New-NetIPAddress -IPAddress $NODE1_STOR_IP_1 -AddressFamily IPv4 -PrefixLength $PREFIXLEN_S –defaultgateway $DEFAULTGW_S_1 -Confirm:$false
Get-netadapter NIC_STOR2_25GB | New-NetIPAddress -IPAddress $NODE1_STOR_IP_2 -AddressFamily IPv4 -PrefixLength $PREFIXLEN_S –defaultgateway $DEFAULTGW_S_2 -Confirm:$false

# Set IP Address on TEAMs.
Get-netadapter TEAM_MGMT | New-NetIPAddress -IPAddress $NODE1_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
}


If($NODENAME -eq $NODE2){
### Set the Storage NICs IP Addresses (NIC-CONFIG-DELL-AX740-NODE_2)
# S2D Host (USS-PV-02)
# write-host("Host Name is USS-PV-02")
Get-netadapter NIC_STOR1_25GB | New-NetIPAddress -IPAddress $NODE2_STOR_IP_1 -AddressFamily IPv4 -PrefixLength $PREFIXLEN_S –defaultgateway $DEFAULTGW_S_1 -Confirm:$false
Get-netadapter NIC_STOR2_25GB | New-NetIPAddress -IPAddress $NODE2_STOR_IP_2 -AddressFamily IPv4 -PrefixLength $PREFIXLEN_S –defaultgateway $DEFAULTGW_S_2 -Confirm:$false

# Set IP Address on TEAMs.
Get-netadapter TEAM_MGMT | New-NetIPAddress -IPAddress $NODE2_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
}


If($NODENAME -eq $NODE3){
### Set the Storage NICs IP Addresses (NIC-CONFIG-DELL-AX740-NODE_2)
# S2D Host (USS-PV-03)
# write-host("Host Name is USS-PV-02")
Get-netadapter NIC_STOR1_25GB | New-NetIPAddress -IPAddress $NODE3_STOR_IP_1 -AddressFamily IPv4 -PrefixLength $PREFIXLEN_S –defaultgateway $DEFAULTGW_S_1 -Confirm:$false
Get-netadapter NIC_STOR2_25GB | New-NetIPAddress -IPAddress $NODE3_STOR_IP_2 -AddressFamily IPv4 -PrefixLength $PREFIXLEN_S –defaultgateway $DEFAULTGW_S_2 -Confirm:$false

# Set IP Address on TEAMs.
Get-netadapter TEAM_MGMT | New-NetIPAddress -IPAddress $NODE3_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
}


### Set the MGMT TEAMs DNS Addresses
# DO NOT set a DNS address for the "TEAM_VM" and "TEAM_STOR NIC/TEAMS. 
# We don't want the TEAM_VM and TEAM_STOR TEAMS to register in DNS.
# Get-NetAdapter TEAM_MGMT | Set-DnsClientServerAddress -ServerAddresses '10.10.5.11','10.10.5.12'
Get-NetAdapter TEAM_MGMT | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2


###################################################################################################
### Enable Remote Desktop
# These command witll enable Remote Desktop and set the RDP firewall ports on the local server.
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

###################################################################################################
### Stop/Prevent Server Manager from loading at startup
# $SRVNAME = HOSTNAME
# Invoke-Command -ComputerName $SRVNAME -ScriptBlock { New-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -PropertyType DWORD -Value "0x1" –Force}
# These commmands prevent Server Manager from loading at startup and disables the Server Manager Schedule task
Invoke-Command -ScriptBlock { New-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -PropertyType DWORD -Value "0x1" –Force}
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose

###################################################################################################
### Install Hyper-V
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools

#################################### Add Windows Server Backup Feature ############################
### Add the windows server backup feature for DPM
Install-WindowsFeature -Name Windows-Server-Backup

###################################################################################################
# Install Failover Cluster Manager roles.
Install-WindowsFeature -Name Failover-Clustering –IncludeManagementTools
Install-windowsfeature RSAT-Clustering –IncludeAllSubFeature


###################################################################################################
### Enable ALL File and Printer Sharing rule
Netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes

### Enable WMI for S2D cluster creation
Netsh advfirewall firewall set rule group="Windows Management Instrumentation (wmi)" new enable=Yes

### Enable Windows Remote Management for S2D cluster creation
Netsh advfirewall firewall set rule group="Windows Remote Management" new enable=Yes

### Change DVD Drive Letter from D: to X:. 
$DvdDrive = Get-CimInstance -Class Win32_Volume -Filter "driveletter='D:'"
Set-CimInstance -InputObject $DvdDrive -Arguments @{DriveLetter="X:"}


################################### REBOOT SERVER #################################################





