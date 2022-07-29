##################### USS-AD-CONFIG-1.ps1 ############################################

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Rename the NICs.
# -Remove IP Address from MGMT NIC
# -Configure MGMT NICs
# -Set the MGMT NIC DNS Addresses
# -Add RSAT-AD-Tools (Windows Features) to support Active Directory forest


###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-AD-CONFIG-1.log
Start-Transcript -Path \\SRV-MDT-01\DEPLOYMENTSHARE$\LOGS\USS-AD-CONFIG-1.log

###################################################################################################
# MODIFY/ENTER These Values
#
### ENTER domain controller host names.
# MDT will set host name in OS
$DC1 = "USS-SRV-11"
$DC2 = "USS-SRV-12"

### ENTER MGMT NIC IP Addresses
$DC1_MGMT_IP = "10.10.5.11"
$DC2_MGMT_IP = "10.10.5.12"

$DNS1 = "10.10.5.11"
$DNS2 = "10.10.5.12"
$DEFAULTGW = "10.10.5.1"
$PREFIXLEN = "24" # Set subnet mask /24, /25


###################################################################################################
### Rename the NICs
#
Rename-NetAdapter –Name “Ethernet” –NewName “NIC_MGMT1_1GB”


### Get host name
$HOSTNAME = HOSTNAME

### Prepare MGMT NICs for New IP Address ##########################################################
# Remove IP Address from MGMT NIC.
Get-netadapter NIC_MGMT1_1GB | get-netipaddress –addressfamily ipv4 | remove-netipaddress -Confirm:$false


### Configure MGMT NICs ###############################################################
If($HOSTNAME -eq $DC1){
### Set the MGMT NICs IP Addresses 
# Host (USS-SRV-11)
# write-host("Host Name is USS-SRV-11")
#
# Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DC1_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DC1_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false

}

If($HOSTNAME -eq $DC2){
### Set the MGMT NICs IP Addresses 
# Host (USS-SRV-12)
# write-host("Host Name is USS-SRV-12")
#
# Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DC1_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DC2_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false

}


### Set the MGMT NIC DNS Addresses
# Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses '10.10.5.11','10.10.5.12'
Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2

# Add RSAT-AD-Tools (Windows Features) to support Active Directory forest
$featureLogPath = “C:\poshlog\featurelog.txt”
New-Item $featureLogPath -ItemType file -Force
$addsTools = “RSAT-AD-Tools”
Add-WindowsFeature $addsTools
Get-WindowsFeature | Where installed >>$featureLogPath

###################################################################################################
Stop-Transcript

######################################### REBOOT SERVER ###########################################
# Restart-Computer