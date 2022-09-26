
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
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-DHCP-CONFIG-1.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-DHCP-CONFIG-1.log

###################################################################################################
# MODIFY/ENTER These Values

### ENTER DHCP Server host names.
# MDT will set host name in OS
$DHCPSRV = "USS-SRV-53"

### DHCP FQDN
$DHCPFQDN = "USS-SRV-53.USS.LOCAL"

### ENTER SCOPE NAME
$SCOPENAME = "USS"

### ENTER DHCP MGMT NIC IP Addresses Info
$DHCPSRV_MGMT_IP = "10.1.102.53"
$DNS1 = "10.1.102.50"
$DNS2 = "10.1.102.51"
$DEFAULTGW_SRV = "10.1.102.1"
$DEFAULTGW_WKS = "10.1.101.1"
$PREFIXLEN = "24" # Set subnet mask /24, /25

### ENTER SERVER DHCP Scope info
$DHCP_START_RANGE_SRV = "10.1.102.100"
$DHCP_END_RANGE_SRV = "10.1.102.254"
$DHCP_MASK_SRV = "255.255.255.0"
$DHCP_SCOPEID_SRV = "10.1.102.0"

### ENTER WORKSTATIONS DHCP Scope info
$DHCP_START_RANGE_WKS = "10.1.101.100"
$DHCP_END_RANGE_WKS = "10.1.101.254"
$DHCP_MASK_WKS = "255.255.255.0"
$DHCP_SCOPEID_WKS = "10.1.101.0"


###################################################################################################
### Rename the NICs
#
Rename-NetAdapter –Name “Ethernet” –NewName “NIC_MGMT1_1GB”

### Prepare MGMT NICs for New IP Address ##########################################################
# Remove IP Address from MGMT NIC.
Get-netadapter NIC_MGMT1_1GB | get-netipaddress –addressfamily ipv4 | remove-netipaddress -Confirm:$false

### Set the MGMT NICs IP Addresses 
#
# Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DHCPSRV_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW_SRV -Confirm:$false
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DHCPSRV_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW_SRV -Confirm:$false

### Set the MGMT NIC DNS Addresses
# Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses '10.1.102.50','10.1.102.51'
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
Invoke-Command -ComputerName $DHCPSRV -ScriptBlock {Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\51 -Name ConfigurationState -Value 2}

# Create DHCP Scopes
# Add-DhcpServerv4Scope -ComputerName $DHCPSRV -Name "INFRA-WKSTN" -StartRange 10.1.102.100 -EndRange 10.1.102.100 -SubnetMask 255.255.255.0 -State Active
# Add-DhcpServerv4Scope -ComputerName $DHCPSRV -Name "INFRA-VMs" -StartRange 10.1.102.100 -EndRange 10.1.102.100 -SubnetMask 255.255.255.0 -State Active
# Add-DhcpServerv4Scope -ComputerName $DHCPSRV -Name "USS SERVERS" -StartRange 10.1.102.101 -EndRange 10.1.102.254 -SubnetMask 255.255.255.0 -State Active
# Add-DhcpServerv4Scope -ComputerName $DHCPSRV -Name "USS SERVERS" -StartRange $DHCP_START_RANGE_SRV -EndRange $DHCP_END_RANGE_SRV -SubnetMask $DHCP_MASK_SRV -State Active
Add-DhcpServerv4Scope -ComputerName $DHCPSRV -Name "$SCOPENAME SERVERS" -StartRange $DHCP_START_RANGE_SRV -EndRange $DHCP_END_RANGE_SRV -SubnetMask $DHCP_MASK_SRV -State Active
Add-DhcpServerv4Scope -ComputerName $DHCPSRV -Name "$SCOPENAME WORKSTATIONS" -StartRange $DHCP_START_RANGE_WKS -EndRange $DHCP_END_RANGE_WKS -SubnetMask $DHCP_MASK_WKS -State Active

# Delete Scope
# Remove-DhcpServerv4Scope -ScopeId 10.1.102.0

# Create Scope Options for 10.1.102.0/25
# Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid "10.1.102.0" -OptionId 066 -Value "MGT-WDS-01.contoso.com" #Boot server/SCCM PXE Point
# Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid "10.1.102.0" -OptionId 067 -Value "boot\x86\wdsnbp.com"  # Boot file Name
# Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid "10.1.102.0" -OptionId 006 -Value "10.1.102.50", "10.1.102.51" #DNS Servers
# Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid "10.1.102.0" -OptionId 006 -Value "10.1.102.50" #DNS Servers
# Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid "10.1.102.0" -OptionId 006 -Value "10.1.102.51" #DNS Servers
Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid $DHCP_SCOPEID_SRV -OptionId 006 -Value $DNS1,$DNS2 #DNS Servers
Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid $DHCP_SCOPEID_SRV -OptionId 003 -Value $DEFAULTGW_SRV #Default GW
Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid $DHCP_SCOPEID_WKS -OptionId 006 -Value $DNS1,$DNS2 #DNS Servers
Set-DhcpServerv4OptionValue -ComputerName $DHCPSRV -scopeid $DHCP_SCOPEID_WKS -OptionId 003 -Value $DEFAULTGW_WKS #Default GW

# List all authorized DHCP servers in Active Directory. Must run this command with Domain Admin creds.
# Get-DhcpServerInDC

# Authorize DHCP server

# Add-DhcpServerInDC -DnsName $DHCPFQDN -IPAddress $DHCP_SCOPEID_SRV
# Add-DhcpServerInDC -DnsName $DHCPFQDN -IPAddress $DHCP_SCOPEID_WKS

# Unauthorize DHCP Server
# Remove-DhcpServerInDC -DnsName $DHCPFQDN -IPAddress $DHCP_SCOPEID_SRV

Stop-Transcript

######################################### REBOOT SERVER ###########################################
# Restart-Computer
