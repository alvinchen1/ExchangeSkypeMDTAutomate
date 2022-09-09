########## S2D-CONFIG-2 ############

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Create virtual switch with SET TEAMED NICs.
# -Set VM TEAMED NICs IP Address VM TEAMED NIC
# -For the "TEAM_VM", Unregister/Uncheck "Register this connection's addresses" and "Use this connection's DNS suffix"
# -Disable Network Adapter Bindings on "TEAM_VM" NICs/TEAMs
# -ADD DEFENDER HYPER-V Exclusions

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\S2D-CONFIG-2.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\S2D-CONFIG-2.log

### ENTER the host name for the S2D Cluster nodes
# MDT will set host name in OS
$NODENAME = HOSTNAME

$NODE1 = "USS-PV-01"
$NODE2 = "USS-PV-02"
$NODE3 = "USS-PV-03"

### Set Virtual Switch "TEAM" NIC IP Addresses
$NODE1_VSWITCH_IP = "10.1.102.83"
$NODE2_VSWITCH_IP = "10.1.102.85"
$NODE3_VSWITCH_IP = "40.40.40.50"
$DEFAULTGW = "10.1.102.1"

$PREFIXLEN = "24" # Set subnet mask /24, /25


###################################################################################################
### Create a HYPER-V VIRTUAL SWITCH/TEAM the NIC_VM NICs using Switch Embedded Teaming (SET)
# Switch Embedded Teaming = SET
# The command below will configure the Hyper-V switch and TEAM the NICs. 
# You can only create a SET Team with a NIC that is used for a Hyper-V Virtual Switch
# This command will create a Hyper-V Virtual switch and assign NICs to it. It will also create a SET TEAM with the NICs.
# Once you've configured this SET enabled virtual switch you do not have to configure teaming separately.
# Run the following in the OS.
#
# Run the following on "EACH" node in the cluster.
# Create virtual switch with SET TEAMED NICs
New-VMSwitch -Name "vSwitch-External" -NetAdapterName "NIC_VM1_10GB","NIC_VM2_10GB" -Notes "vSwitch-External" -EnableEmbeddedTeaming $true

### Set VM TEAMED NICs IP Address VM TEAMED NIC ###############################################################
# The direct connect linked NIC ports (Cluster/Storage/LIVMIG) are not teamed.

If($NODENAME -eq $NODE1){
### Set the virtual switch TEAM NICs IP Addresses (NIC-CONFIG-DELL-AX740-NODES)
# S2D Host (USS-PV-01)
# write-host("Host Name is USS-PV-01")
# Get-netadapter "vEthernet (vSwitch-External)" | New-NetIPAddress -IPAddress '10.1.102.85' -AddressFamily IPv4 -PrefixLength 25 –defaultgateway '10.1.102.1' -Confirm:$false
Get-netadapter "vEthernet (vSwitch-External)" | New-NetIPAddress -IPAddress $NODE1_VSWITCH_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
}


If($NODENAME -eq $NODE2){
### Set the virtual switch TEAM NICs IP Addresses (NIC-CONFIG-DELL-AX740-NODES)
# S2D Host (USS-PV-02)
# write-host("Host Name is USS-PV-02")
# Get-netadapter "vEthernet (vSwitch-External)" | New-NetIPAddress -IPAddress '10.1.102.85' -AddressFamily IPv4 -PrefixLength 25 –defaultgateway '10.1.102.1' -Confirm:$false
Get-netadapter "vEthernet (vSwitch-External)" | New-NetIPAddress -IPAddress $NODE2_VSWITCH_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
}


If($NODENAME -eq $NODE3){
### Set the virtual switch TEAM NICs IP Addresses (NIC-CONFIG-DELL-AX740-NODES)
# S2D Host (USS-PV-03)
# write-host("Host Name is USS-PV-03")
# Get-netadapter "vEthernet (vSwitch-External)" | New-NetIPAddress -IPAddress '10.1.102.85' -AddressFamily IPv4 -PrefixLength 25 –defaultgateway '10.1.102.1' -Confirm:$false
Get-netadapter "vEthernet (vSwitch-External)" | New-NetIPAddress -IPAddress $NODE3_VSWITCH_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false
}


##################################################################################################
### Unregister/Uncheck "Register this connection's addresses" 
### For the "TEAM_VM", Unregister/Uncheck "Register this connection's addresses" and "Use this connection's DNS suffix"
### The below example would check the Register this connection's addresses in DNS box and uncheck the Use this connection's DNS suffix in DNS box"
# https://stackoverflow.com/questions/57366593/how-to-set-dns-suffix-and-registration-using-powershell
# No need to set a DNS entry on the direct connect linked NIC ports (Cluster/Storage/LIVMIG).
# Get-NetAdapter TEAM_VM | Set-DnsClient -RegisterThisConnectionsAddress $false
Get-NetAdapter "vEthernet (vSwitch-External)" | Set-DnsClient -RegisterThisConnectionsAddress $false

##################################################################################################
### (POWERSHELL) – DISABLE NETWORK ADAPTER BINDINGS
#
# Disable Network Adapter Bindings on "TEAM_VM" NICs/TEAMs
# To disable a specific binding such as Client for Microsoft Networks, you can use the Disable-NetAdapterBinding cmdlet.
# List All Bindings on server.
# Get-NetAdapterBinding
# Run the following on "EACH" node in the cluster.
# Only perform this step on the "TEAM_VM" NICs/TEAMs.
# DO NOT Perform this step on the TEAM_MGMT NIC/TEAM. 
# Disable the follwing bindings:
Disable-NetAdapterBinding -Name "vEthernet (vSwitch-External)" -ComponentID ms_msclient # Client for Microsoft Networks
Disable-NetAdapterBinding -Name "vEthernet (vSwitch-External)" -ComponentID ms_server # File and Printer Sharing for Microsoft Networks
Disable-NetAdapterBinding -Name "vEthernet (vSwitch-External)" -ComponentID ms_tcpip6 # Internet Protocol Version 6 (TCP/IPv6)             
Disable-NetAdapterBinding -Name "vEthernet (vSwitch-External)" -ComponentID ms_lltdio # Link-Layer Topology Discovery Mapper I/O Driver    
Disable-NetAdapterBinding -Name "vEthernet (vSwitch-External)" -ComponentID ms_rspndr # Link-Layer Topology Discovery Responder            

###################################################################################################
##### ADD DEFENDER HYPER-V Exclusions
# Add Defender File Exclusions
Add-MpPreference -ExclusionExtension ".vhd" -Force
Add-MpPreference -ExclusionExtension ".vhdx" -Force
Add-MpPreference -ExclusionExtension ".avhd" -Force
Add-MpPreference -ExclusionExtension ".avhdx" -Force
Add-MpPreference -ExclusionExtension ".vsv" -Force
Add-MpPreference -ExclusionExtension ".iso" -Force
Add-MpPreference -ExclusionExtension ".rct" -Force
Add-MpPreference -ExclusionExtension ".vmcx" -Force
Add-MpPreference -ExclusionExtension ".vmrs" -Force


# Add defender Folder Exclusions:
# The $Env:<Variable> is used to convert the environment variable in the OS.If you just use %WINDIR% in PS it will not translate it.
Add-MpPreference -ExclusionPath "C:\ClusterStorage" -Force
Add-MpPreference -ExclusionPath "C:\VM_C" -Force
Add-MpPreference -ExclusionPath "D:\VM_D" -Force
Add-MpPreference -ExclusionPath "E:\VM_E" -Force
Add-MpPreference -ExclusionPath "F:\VM_F" -Force
Add-MpPreference -ExclusionPath "$Env:ProgramData\Microsoft\Windows\Hyper-V" -Force
Add-MpPreference -ExclusionPath "$Env:ProgramFiles\Hyper-V" -Force
Add-MpPreference -ExclusionPath "$Env:SystemDrive\ProgramData\Microsoft\Windows\Hyper-V\Snapshots" -Force
Add-MpPreference -ExclusionPath "$Env:Public\Documents\Hyper-V\Virtual Hard Disks" -Force
Add-MpPreference -ExclusionPath "C:\Users\Public Documents\Hyper-V\Virtual Hard Disks" -Force

# Add defender Process Exclusions:
Add-MpPreference -ExclusionProcess "$Env:systemroot\System32\Vmms.exe" -Force
Add-MpPreference -ExclusionProcess "$Env:systemroot\System32\Vmwp.exe" -Force

# To view current defender exclusion, read the "ExclusionPath" after running the following command: 
# Get-mppreference

# Add MpPrefernces in to the $WDAVPREFS variable
# $WDAVPREFS = Get-MpPreference

# Display all Defender file exclusions
# $WDAVPREFS.ExclusionExtension

# Display all Defender folder exclusions
# $WDAVPREFS.ExclusionPath

# Display all Defender Process exclusions
# $WDAVPREFS.ExclusionProcess

# To get the status of the animalware software on computer
# Get-MpComputerStatus

# Add Defender file exclusion
# Add-MpPreference -ExclusionPath "C:\test\file.exe" -Force


###################################################################################################
Stop-Transcript


