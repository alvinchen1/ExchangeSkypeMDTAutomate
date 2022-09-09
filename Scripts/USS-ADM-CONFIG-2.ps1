########## ADM-CONFIG-2 ############


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
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-ADM-CONFIG-2.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-ADM-CONFIG-2.log


###################################################################################################
# MODIFY/ENTER These Values

### ENTER/SET the following variable before running this script.
# $vSWITCH_IP = "10.10.5.49"
# $DEFAULTGW = "10.10.5.1"
# $PREFIXLEN = "25" # Set subnet mask /24, /25

##################################################################################################
########## Create a HYPER-V VIRTUAL SWITCH on a "PHYSICAL" Machine
New-VMSwitch -name vSwitch-External  -NetAdapterName TEAM_VM -AllowManagementOS $false

### Set VM TEAMED NICs IP Address VM TEAMED NIC ###############################################################
# The direct connect linked NIC ports (Cluster/Storage/LIVMIG) are not teamed.
# Get-netadapter "vEthernet (vSwitch-External)" | New-NetIPAddress -IPAddress '10.10.5.34' -AddressFamily IPv4 -PrefixLength 25 –defaultgateway '10.10.5.1' -Confirm:$false

<# Get-netadapter "vEthernet (vSwitch-External)" | New-NetIPAddress -IPAddress $vSWITCH_IP -AddressFamily IPv4 -PrefixLength $PREFIXLEN –defaultgateway $DEFAULTGW -Confirm:$false

# Get-NetAdapter vether* | Remove-VMNetAdapter -Confirm:$false

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

#>

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
Add-MpPreference -ExclusionPath "C:\VM_C" -Force
Add-MpPreference -ExclusionPath "D:\VM_D" -Force
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
