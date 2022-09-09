
###################################################################################################
##################### USS-CA-CONFIG-1.ps1 ###################################################

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Configure the MGMT NIC and set its IP Address and DNS Address.
#
#
# *** Before runnng this script ensure that the following drive exist on the MECM Site server ***
#
# (C:)(120gb+) OS - Page file (4k, NTFS)

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-CA-CONFIG-1.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-CA-CONFIG-1.log

###################################################################################################
### MODIFY These Values
### ENTER the host name for the Certificate Authority
# MDT will set host name in OS
$CA_ISSUE = "USS-SRV-55"
$CA_ROOT = "USS-SRV-56"

### ENTER MGMT "TEAM" NIC IP Addresses
$CA_ISSUE_MGMT_IP = "10.1.102.55"
$CA_ROOT_MGMT_IP = "10.1.102.56"

$DNS1 = "10.1.102.50"
$DNS2 = "10.1.102.51"
$DEFAULTGW = "10.1.102.1"
$PREFIXLEN = "24" # Set subnet mask /24, /25

### Get Host Name
$CANAME = HOSTNAME


###################################################################################################
# Configure NICs
Write-Host -foregroundcolor green "Configure NICs..."

### Rename the NICs
Rename-NetAdapter –Name “Ethernet” –NewName “NIC_MGMT1_1GB”

###################################################################################################
### Prepare MGMT NICs for New IP Address 
# Remove IP Address from MGMT NIC.
Get-netadapter NIC_MGMT1_1GB | get-netipaddress –addressfamily ipv4 | remove-netipaddress -Confirm:$false

### Configure MGMT NICs ###############################################################
If($CANAME -eq $CA_ISSUE){
# Set IP Address on TEAMs.
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $CA_ISSUE_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
}

If($CANAME -eq $CA_ROOT){
# Set IP Address on TEAMs.
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $CA_ROOT_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
}

### Set the MGMT NIC DNS Addresses
# Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses '10.1.102.50','10.1.102.51'
Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2










###################################################################################################
Stop-Transcript