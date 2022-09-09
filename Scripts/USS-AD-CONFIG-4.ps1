##################### USS-AD-CONFIG-4.ps1 ############################################
# 
# INSTALL AN ADDITIONAL DOMAIN CONTROLLER 
#
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
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-AD-CONFIG-4.log

###################################################################################################
# MODIFY/ENTER These Values

### Enter the domain controller host names.
# MDT will set host name in OS
$DC1 = "USS-SRV-50"
$DC2 = "USS-SRV-51"

### Set MGMT NIC IP Addresses
$DC1_MGMT_IP = "10.1.102.50"
$DC2_MGMT_IP = "10.1.102.51"

$DNS1 = "10.1.102.50"
$DNS2 = "10.1.102.51"
$DEFAULTGW = "10.1.102.1"
$PREFIXLEN = "24" # Set subnet mask /24, /25

# Add additional Domain Controller
$domainname = “USS.LOCAL”
$netbiosName = “USS”
# Note the DSRM password is Passw0rd99 ... Update it before running this script.
$DSRMPASS = (ConvertTo-SecureString -String !QAZ2wsx#EDC4rfv -AsPlainText -Force)

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
# Host (USS-SRV-50)
# write-host("Host Name is USS-SRV-50")
#
# Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DC1_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DC1_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false

}

If($HOSTNAME -eq $DC2){
### Set the MGMT NICs IP Addresses 
# Host (USS-SRV-51)
# write-host("Host Name is USS-SRV-51")
#
# Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DC1_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
Get-netadapter NIC_MGMT1_1GB | New-NetIPAddress -IPAddress $DC2_MGMT_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false

}

### Set the MGMT NIC DNS Addresses
# Get-NetAdapter TEAM_MGMT | Set-DnsClientServerAddress -ServerAddresses '10.1.102.50','10.1.102.51'
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
