<#
NAME
    Config-OS.ps1

SYNOPSIS
    Configures network adapter(s) and hard drive(s)

SYNTAX
    .\$ScriptName
#>

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path –Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path –Parent
$DTG = Get-Date -Format yyyyMMddTHHmm
$RootDir = Split-Path $ScriptDir –Parent
$ConfigFile = "$RootDir\config.xml"

Start-Transcript -Path "$RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log"
Start-Transcript -Path "$env:WINDIR\Temp\$env:COMPUTERNAME-$DTG-$ScriptName.log"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) {Throw "ERROR: Unable to locate $ConfigFile Exiting..."} 
$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$Server = $Env:COMPUTERNAME
$MgmtIP = ($WS | ? {($_.Name -eq "$Server")}).Value
$DNS1 = ($WS | ? {($_.Role -eq "DC1")}).Value
$DNS2 = ($WS | ? {($_.Role -eq "DC2")}).Value
$DefaultGW = ($WS | ? {($_.Name -eq "DefaultGateway")}).Value
$PrefixLen = ($WS | ? {($_.Name -eq "SubnetMaskBitLength")}).Value

# =============================================================================
# MAIN ROUTINE
# =============================================================================

<# Rename the NICs per following naming convention:
 - MGMT: Management traffic [reserved for cluster management, Remote Deskop, Windows Admin Center, Windows PowerShell, etc.]
 - STOR: Storage traffic [reserved for Storage Spaces Direct (S2D)/Live Migration using Server Message Block (SMB)]
 - VM:   Compute traffic [reserved business use of app and services hosted by the VM]
#>
Write-Host -ForegroundColor Green "Renaming NICs"
If (Get-NetAdapter "Ethernet" -ErrorAction SilentlyContinue) {Rename-NetAdapter –Name "Ethernet" –NewName "$MgmtNICName"}
Rename-NetAdapter –Name "Ethernet 2" –NewName "NIC_MGMT2_1GB"
Rename-NetAdapter –Name "CPU SLOT 2 Port 1" –NewName "NIC_VM1_10GB"
Rename-NetAdapter –Name "CPU SLOT 2 Port 2" –NewName "NIC_VM2_10GB"
Rename-NetAdapter –Name "CPU SLOT 6 Port 1" –NewName "NIC_VM3_10GB"
Rename-NetAdapter –Name "CPU SLOT 6 Port 2" –NewName "NIC_VM4_10GB"

# Team NICs
New-NetLbfoTeam -Name "TEAM_MGMT" -TeamMembers "NIC_MGMT1_1GB","NIC_MGMT2_1GB" -TeamingMode SwitchIndependent -LoadBalancingAlgorithm HyperVPort -Confirm:$false
New-NetLbfoTeam -Name "TEAM_VM" -TeamMembers "NIC_VM1_10GB","NIC_VM2_10GB","NIC_VM3_10GB","NIC_VM4_10GB" -TeamingMode SwitchIndependent -LoadBalancingAlgorithm HyperVPort -Confirm:$false
Start-Sleep -Seconds 40

# Configure NICs
Get-NetAdapter "TEAM_MGMT" | Get-NetIPAddress -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false
Get-NetAdapter "TEAM_MGMT" | New-NetIPAddress -IPAddress $MgmtIP -AddressFamily IPv4 -PrefixLength $PrefixLen -DefaultGateway $DefaultGW -Confirm:$false
Get-NetAdapter "TEAM_MGMT" | Set-DnsClientServerAddress -ServerAddresses $DNS1,$DNS2
Disable-NetAdapterBinding "TEAM_MGMT" -ComponentID ms_tcpip6

Get-NetAdapter "TEAM_VM" | Get-NetIPAddress -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false
Get-NetAdapter "TEAM_VM" | Set-DnsClient -RegisterThisConnectionsAddress $false
Disable-NetAdapterBinding -Name "TEAM_VM" -ComponentID ms_msclient # Client for Microsoft Networks
Disable-NetAdapterBinding -Name "TEAM_VM" -ComponentID ms_server # File and Printer Sharing for Microsoft Networks
Disable-NetAdapterBinding -Name "TEAM_VM" -ComponentID ms_tcpip6 # Internet Protocol Version 6 (TCP/IPv6)             
Disable-NetAdapterBinding -Name "TEAM_VM" -ComponentID ms_lltdio # Link-Layer Topology Discovery Mapper I/O Driver    
Disable-NetAdapterBinding -Name "TEAM_VM" -ComponentID ms_rspndr # Link-Layer Topology Discovery Responder  

# Install Windows features
Install-WindowsFeature -Name Hyper-V, Failover-Clustering, RSAT-Clustering -IncludeManagementTools
Install-WindowsFeature -Name BitLocker, RSAT-AD-Tools, GPMC -IncludeAllSubFeature -IncludeManagementTools

# Configure disks and storage pool(s)
Write-Host -ForegroundColor Green "Configuring disks"
Get-StoragePool | ? IsPrimordial -eq $false | Set-StoragePool -IsReadOnly:$false -ErrorAction SilentlyContinue
Get-StoragePool | ? IsPrimordial -eq $false | Get-VirtualDisk | Remove-VirtualDisk -Confirm:$false -ErrorAction SilentlyContinue
Get-StoragePool | ? IsPrimordial -eq $false | Remove-StoragePool -Confirm:$false -ErrorAction SilentlyContinue
Get-PhysicalDisk | Reset-PhysicalDisk -ErrorAction SilentlyContinue
Get-Disk | ? Number -ne $null | ? IsBoot -ne $true | ? IsSystem -ne $true | ? PartitionStyle -ne RAW | % {
        $_ | Set-Disk -isoffline:$false
        $_ | Set-Disk -isreadonly:$false
        $_ | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false
        $_ | Set-Disk -isreadonly:$true
        $_ | Set-Disk -isoffline:$true
    }

New-StoragePool –FriendlyName SSD_POOL –StorageSubsystemFriendlyName "Windows Storage*" –PhysicalDisks (Get-PhysicalDisk -CanPool $True | Where-Object MediaType -EQ SSD)
New-StoragePool –FriendlyName HDD_POOL –StorageSubsystemFriendlyName "Windows Storage*" –PhysicalDisks (Get-PhysicalDisk -CanPool $True | Where-Object MediaType -EQ HDD)
New-Volume -StoragePoolFriendlyName SSD_POOL -FriendlyName "VMs-REFS" -FileSystem REFS -AllocationUnitSize 64KB -UseMaximumSize -ResiliencySettingName Parity –DriveLetter D
New-Volume -StoragePoolFriendlyName HDD_POOL -FriendlyName "DPMSTOR-REFS" -FileSystem REFS -AllocationUnitSize 64KB -UseMaximumSize -ResiliencySettingName Parity –DriveLetter E

Stop-Transcript
