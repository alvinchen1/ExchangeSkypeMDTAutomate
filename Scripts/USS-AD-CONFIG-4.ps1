##################### USS-AD-CONFIG-4.ps1 ############################################
# This script must be ran after the AD-CONFIG-3.ps1 is ran.
#
### This script is designed to work with MDT.
### MDT will set host name in OS.
### MDT will handle Reboots.
#
### This script will:
#
# -Configure the MGMT NIC and set its IP Address and DNS Address.
# -Install AD DS, DNS and GPMC
# -Add an Additional domain controllers to an existing domain. - Using the ADDSDomainController command. 
# -Enable Remote Desktop
# -Stop/Prevent Server Manager from loading at startup

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-AD-CONFIG-4.log
Start-Transcript -Path \\SRV-MDT-01\DEPLOYMENTSHARE$\LOGS\USS-AD-CONFIG-4.log

###################################################################################################
# MODIFY/ENTER These Values

### Enter the domain controller host names.
# MDT will set host name in OS
$DC1 = "USS-SRV-11"
$DC2 = "USS-SRV-12"

### Set MGMT NIC IP Addresses
$DC1_MGMT_IP = "10.10.5.11"
$DC2_MGMT_IP = "10.10.5.12"

$DNS1 = "10.10.5.11"
$DNS2 = "10.10.5.12"
$DEFAULTGW = "10.10.5.1"
$PREFIXLEN = "24" # Set subnet mask /24, /25

# Add additional Domain Controller
$domainname = “USS.LOCAL”
$netbiosName = “USS”

# Note the DSRM password is ... Update it before running this script.
# TODO: Pull this password value from an environment variable
#$DSRMPASS = (ConvertTo-SecureString -String ... -AsPlainText -Force)

### Get host name
$HOSTNAME = HOSTNAME


###################################################################################################
### Rename the NICs
#
Rename-NetAdapter –Name “Ethernet” –NewName “NIC_MGMT1_1GB”

### Prepare MGMT NICs for New IP Address ##########################################################
# Remove IP Address from TEAMs.
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
# Get-NetAdapter TEAM_MGMT | Set-DnsClientServerAddress -ServerAddresses '10.10.5.11','10.10.5.12'
Get-NetAdapter NIC_MGMT1_1GB | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2

# Add the AD-Domain-Services role
# Install AD DS, DNS and GPMC
$featureLogPath = "c:\poshlog\featurelog.txt"
New-Item $featureLogPath -ItemType file -Force
start-job -Name addFeature -ScriptBlock {
Add-WindowsFeature -Name “ad-domain-services” -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name “dns” -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name “gpmc” -IncludeAllSubFeature -IncludeManagementTools }
Wait-Job -Name addFeature
Get-WindowsFeature | Where installed >>$featureLogPath

Start-Sleep -s 60

# Install ADDSDomainController for additional DC
Install-ADDSDomainController -CreateDnsDelegation:$false `
-DomainName $domainname `
-SafeModeAdministratorPassword $DSRMPASS `
-DatabasePath “C:\Windows\NTDS” `
-LogPath "C:\Windows\NTDS" `
-InstallDns:$true `
-NoRebootOnCompletion:$true `
-SysvolPath “C:\Windows\SYSVOL” `
-Force:$true `
-NoGlobalCatalog:$false `
-SiteName "Default-First-Site-Name"

 
# Don't reboot after install ... Let MDT reboot the comupter..."-NoRebootOnCompletion:$true"


###################################################################################################
Stop-Transcript


### REBOOT SERVER
