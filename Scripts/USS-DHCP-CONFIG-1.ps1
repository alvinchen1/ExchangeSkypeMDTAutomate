
###################################################################################################
##################### USS-DHCP-CONFIG-1.ps1 ###################################################
###################################################################################################
#
### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Configure the MGMT NIC and set its IP Address and DNS Address.
# -Install DHCP Service
# -Add-DhcpServerSecurityGroup cmdlet adds security groups to the Dynamic Host Configuration Protocol (DHCP) server
# -Create DHCP Scopes
# -Create Scope Options (DNS,Default GW, Etc...)
# -Enable Remote Desktop
# -Stop/Prevent Server Manager from loading at startup

###################################################################################################
# MODIFY/ENTER These Values

### ENTER DHCP Server host names.
# MDT will set host name in OS
$DHCPSRV = "USS-SRV-15"

### ENTER SCOPE NAME
$SCOPENAME = "USS"

### ENTER DHCP MGMT NIC IP Addresses Info
$DHCPSRV_MGMT_IP = "10.10.5.15"
$DNS1 = "10.10.5.11"
$DNS2 = "10.10.5.12"
$DEFAULTGW = "10.10.5.1"
$PREFIXLEN = "24" # Set subnet mask /24, /25

### ENTER DHCP Scope info
$DHCP_START_RANGE = "10.10.5.101"
$DHCP_END_RANGE = "10.10.5.254"
$DHCP_MASK = "255.255.255.0"
$DHCP_SCOPEID = "10.10.5.0"


###################################################################################################
### Rename the NICs
#
Rename-NetAdapter –Name “Ethernet” –NewName “NIC_MGMT1_1GB”

### Prepare MGMT NICs for New IP Address ##########################################################
# Remove IP Address from MGMT NIC.
Get-netadapter NIC_MGMT1_1GB | get-netipaddress –addressfamily ipv4 | remove-netipaddress -Confirm:$false

### Set the MGMT NICs IP Addresses 
#
# Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DHCPSRV_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DHCPSRV_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false

### Set the MGMT NIC DNS Addresses
# Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses '10.10.5.11','10.10.5.12'
Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2

# Install DHCP Service
Install-WindowsFeature DHCP -IncludeManagementTools -ComputerName $DHCPSRV

# Add-DhcpServerInDC - Adds the computer that runs the DHCP server service to the list of authorized DHCP server services in Active Directory.
# This command is not needed if running DHCP in a workgroup.
# Add-DhcpServerInDC -DNSName $DHCPSRV -IPAddress $DHCPSRV_IP

# The Add-DhcpServerSecurityGroup cmdlet adds security groups to the Dynamic Host Configuration Protocol (DHCP) server. 
# The cmdlet adds the DHCP Users and DHCP Administrators security groups
Add-DhcpServerSecurityGroup -Computername $DHCPSRV

# Add DHCP registry key.
Invoke-Command -ComputerName $DHCPSRV -ScriptBlock {Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2}

# Create DHCP Scopes
# Add-DhcpServerv4Scope -ComputerName $DHCPSRV -Name "INFRA-WKSTN" -StartRange 10.10.5.100 -EndRange 10.10.5.100 -SubnetMask 255.255.255.0 -State Active
# Add-DhcpServerv4Scope -ComputerName $DHCPSRV -Name "INFRA-VMs" -StartRange 10.10.5.100 -EndRange 10.10.5.100 -SubnetMask 255.255.255.0 -State Active
# Add-DhcpServerv4Scope -ComputerName $DHCPSRV -Name "USS SERVERS" -StartRange 10.10.5.101 -EndRange 10.10.5.254 -SubnetMask 255.255.255.0 -State Active
# Add-DhcpServerv4Scope -ComputerName $DHCPSRV -Name "USS SERVERS" -StartRange $DHCP_START_RANGE -EndRange $DHCP_END_RANGE -SubnetMask $DHCP_MASK -State Active
Add-DhcpServerv4Scope -ComputerName $DHCPSRV -Name "$SCOPENAME SERVERS" -StartRange $DHCP_START_RANGE -EndRange $DHCP_END_RANGE -SubnetMask $DHCP_MASK -State Active

# Create Scope Options for 10.10.5.0/25
# Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid "10.10.5.0" -OptionId 066 -Value "MGT-WDS-01.contoso.com" #Boot server/SCCM PXE Point
# Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid "10.10.5.0" -OptionId 067 -Value "boot\x86\wdsnbp.com"  # Boot file Name
# Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid "10.10.5.0" -OptionId 006 -Value "10.10.5.11", "10.10.5.12" #DNS Servers
# Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid "10.10.5.0" -OptionId 006 -Value "10.10.5.11" #DNS Servers
# Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid "10.10.5.0" -OptionId 006 -Value "10.10.5.12" #DNS Servers
Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid $DHCP_SCOPEID -OptionId 006 -Value $DNS1,$DNS2 #DNS Servers
Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid $DHCP_SCOPEID -OptionId 003 -Value $DEFAULTGW #Default GW


######################################### REBOOT SERVER ###########################################
# Restart-Computer
