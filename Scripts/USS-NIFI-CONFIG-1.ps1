###################################################################################################
##################### USS-NIFI-CONFIG-1.ps1 ###################################################
###################################################################################################

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Configure the MGMT NIC and set its IP Address and DNS Address.

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-NIFI-CONFIG-1.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-NIFI-CONFIG-1.log


###################################################################################################
### MODIFY These Values
### ENTER WSUS MGMT NIC IP Addresses Info
$MECM_MGMT_IP = "10.1.102.63"
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
# Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $MECM_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $MECM_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false

### Set the MGMT NIC DNS Addresses
# Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses '10.1.102.50','10.1.102.51'
Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2


###################################################################################################
Stop-Transcript


######################################### REBOOT THE SERVER ###########################################
# Restart-Computer