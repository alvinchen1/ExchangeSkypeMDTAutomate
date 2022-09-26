########## S2D-CONFIG-3 ############	

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Create the S2D Cluster - Using the New-Cluster command
# -Clean S2D drives
# -Enabling Storage Spaces Direct - Using the Enable-ClusterStorageSpacesDirect command.
# -Create S2D Volumes
# -Enable the CSV cache


###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\S2D-CONFIG-3.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\S2D-CONFIG-3.log

### ENTER the host name for the S2D Cluster nodes
$NODE1 = "USS-PV-01"
$NODE2 = "USS-PV-02"

### ENTER cluster name
$S2DCLUSTER = "USS-PV-CLUSTER1"

### ENTER Cluster IP Addresses
$CLUSTER_IP = "10.1.102.81"

### ENTER Storage NIC Subnets
### These networks need to be Ignored/Excluded during cluster creation
$STORNET_1 = "10.10.10.0/24"
$STORNET_2 = "20.20.20.0/24"

### ENTER MDT SERVER
$MDTSERVER = "DEP-MDT-01"

### ENTER LAST NODE TO BUILD BEFORE THE LAST NODE STARTS CLUSTER CONFIG.
$DEPNODE = "USS-PV-01"


### ENTER CLUSTER NETWORKS NAMES/SUBNETS
$MGMTSUB = "10.1.102.*"
$MGMTNAME = "MANAGEMENT"

$LIVMIGSUB1 = "10.10.10.*"
$LIVMIGNAME1 = "LIVMIG-CLUSTER1"

$LIVMIGSUB2 = "20.20.20.*"
$LIVMIGNAME2 = "LIVMIG-CLUSTER2"


###################################################################################################
# Check to see if Other nodes for the Cluster have finish building and are ready to be clustered
#
# Wait for other dependent cluster nodes to finish building.
#
$FileName = "\\$MDTSERVER\DEPLOY_SHARE_OFF$\LOGS\$DEPNODE-READY.txt"

If (!(Test-Path $FileName)) {
    
    do {
    Write-Host -foregroundcolor Yellow "Other Cluster Nodes Still Building...Sleeping for 20 Seconds..."
    Start-Sleep 20
    } until (Test-Path $FileName)
} Write-Host -foregroundcolor green "Other Cluster Nodes are Ready...Continuing to Cluster Creation..."


###################################################################################################
############################ Test the Nodes to determine if there ready for the cluster
##################################################################################################
# Creating the host cluster
# Verify that the nodes are ready for cluster creation, and then create the host cluster.
# Note: The Test-Cluster cmdlet generates an HTML report of all performed validations and includes a summary of the validations. Review this report before creating a cluster.
#
# Run the Test-Cluster cmdlet:
# Run the following on "ONE" node in the cluster.
# Test-Cluster -Node SAT-PV-01, SAT-PV-02 –Include 'Storage', 'Inventory', 'Network', 'System Configuration'
# Note if the test-cluster command shows a failure with S2D when running the -include Storage Spaces Direct option
# -run the "(If Needed) Clean drives" section below and re-run the test.
# Test-Cluster -Node USS-PV-01, USS-PV-02 –Include 'Storage Spaces Direct', 'Inventory', 'Network', 'System Configuration'



###################################################################################################
############################## Create the S2D Cluster 
###################################################################################################
# Note: For the "-IgnoreNetwork" parameter, specify all storage network subnets as arguments. 
# Switchless configuration requires that all storage network subnets are provided as arguments to the -IgnoreNetwork parameter.
#
# In this command, the "StaticAddress" parameter is used to specify an IP address for the cluster in the same IP subnet 
# as the host management network. The NoStorage switch parameter specifies that the cluster is to be created without any shared storage.
#
# "IgnoreNetwork" Specifies one or more networks to ignore when running the cmdlet. Networks with DHCP enabled are always included, 
# but other networks need a static address to be specified using the StaticAddress parameter or should be explicitly ignored 
# with this IgnoreNetwork parameter.
#
# -NoStorage specifies that shared storage is ignored during the cluster creation. The cluster created at the end of the operation will not have shared storage. 
# Shared Storage can be added using the Get-ClusterAvailableDisk cmdlet with Add-ClusterDisk.
#
# Note: The New-Cluster cmdlet generates an HTML report of all performed configurations and includes a summary of the configurations. 
# Review the report before enabling Storage Spaces Direct.
#
# Run the following on "ONE" node (USS-PV-01) in the cluster.
# New-Cluster -Name USS-PV-CLUSTER1 -Node USS-PV-01, USS-PV-02 -StaticAddress 172.25.56.60 -NoStorage -IgnoreNetwork 10.10.10.0/24,20.20.20.0/24 -Verbose
#
# Note the TEAM_MGMT NICs must have a gateway address. If it doesn't the cluster build will fail with an error saying the static IP address could not be found on 
# any cluster network.
New-Cluster -Name $S2DCLUSTER -Node $NODE1, $NODE2 -StaticAddress $CLUSTER_IP -NoStorage -IgnoreNetwork $STORNET_1,$STORNET_2 -Verbose


#### Remove Cluster
# Get-ClusterNode
# Remove-Cluster -Cluster USS-PV-CLUSTER1


#### (If Needed) Clean drives
# https://docs.microsoft.com/en-us/windows-server/storage/storage-spaces/deploy-storage-spaces-direct
# Before you enable Storage Spaces Direct, ensure your drives are empty: no old partitions or other data.
# Note use this when the drives that will be used for S2D have been used before.
# This script will permanently remove any data on any drives other than the operating system boot drive!
# Run the following script, substituting your computer names, to remove all any old partitions or other data.
# Fill in these variables with your values
$ServerList = "$NODE1", "$NODE2"
 
Invoke-Command ($ServerList) {
    Update-StorageProviderCache
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
    Get-Disk | Where Number -Ne $Null | Where IsBoot -Ne $True | Where IsSystem -Ne $True | Where PartitionStyle -Eq RAW | Group -NoElement -Property FriendlyName
} | Sort -Property PsComputerName, Count



#######################################################################################################################
##################################### Enabling Storage Spaces Direct ##################################################
#######################################################################################################################
# After you create the cluster, run the Enable-ClusterS2D cmdlet to configure Storage Spaces Direct on the cluster. 
# Do not run the cmdlet in a remote session; instead, use the local console session.

# Run the Enable-ClusterS2d cmdlet as follows.
# The Enable-ClusterS2D cmdlet generates an HTML report of all configurations and includes a validation summary. 
# Review this report, which is typically stored in the local temporary folder on the node where the cmdlet was run. 
# The verbose output of the command shows the path to the cluster report. At the end of the operation, the cmdlet discovers and
# claims all the available disks into an auto-created storage pool. 
# Log path = C:\Windows\Cluster\Reports\EnableClusterS2D on 2021.03.19-16.47.45.htm
#Enable-ClusterS2D -Verbose
# Run the following on "ONE" node (USS-PV-01) in the cluster.
# Enable-ClusterStorageSpacesDirect -Verbose
Enable-ClusterStorageSpacesDirect -Confirm:$false

# Get-ClusterS2D

# Get-StoragePool

# Get-VirtualDisk


######################### Remove Storage Pool ###################################################
# Remove-StoragePool "S2D on USS-PV-CLUSTER1"


###################################################################################################
################################## Create Volumes #################################################
###################################################################################################
# Create one 20GB volume
# Resiliency
# --If your deployment has only two servers, Storage Spaces Direct will automatically use two-way mirroring for resiliency. 
# --If your deployment has only three servers, it will automatically use three-way mirroring
# Resiliency Options:
# -ResiliencySettingName Mirror
# -ResiliencySettingName Parity
#
# Optional Volume Names: "DATA1 or VM1 or FILES"
#
# New-Volume -StoragePoolFriendlyName S2D* -FriendlyName MultiResilient -FileSystem CSVFS_REFS -StorageTierFriendlyName Performance, Capacity -StorageTierSizes 1000GB, 9000GB
# New-Volume -Size 20GB -FriendlyName "Volume $_" -FileSystem CSVFS_ReFS -AllocationUnitSize 64k
#
# # Run the following on "ONE" node (USS-PV-01) in the cluster.
# New-Volume -Size 58TB -FriendlyName "VM_VOL1" -FileSystem CSVFS_ReFS 
New-Volume -Size 27TB -FriendlyName "VM_VOL1" -FileSystem CSVFS_ReFS
New-Volume -Size 31TB -FriendlyName "VM_VOL2" -FileSystem CSVFS_ReFS 

# Get-StoragePool

# Get-VirtualDisk 

#### Delete a Volume/VIRTUAL DISK
# This will return a list of possible values for the -FriendlyName parameter, which correspond to volume names on your cluster
# Get-VirtualDisk -CimSession USS-PV-CLUSTER1.SATURN.LAB
# Remove-VirtualDisk -FriendlyName VM_VOL1
# Remove-VirtualDisk -FriendlyName VM_VOL2
# Remove-VirtualDisk -FriendlyName ClusterPerformanceHistory

############################# Optionally enable the CSV cache #####################################
# https://docs.microsoft.com/en-us/windows-server/storage/storage-spaces/deploy-storage-spaces-direct
# You can optionally enable the cluster shared volume (CSV) cache to use system memory (RAM) as a write-through block-level cache of read operations
# -that aren't already cached by the Windows cache manager. This can improve performance for applications such as Hyper-V. 
# -The CSV cache can boost the performance of read requests and is also useful for Scale-Out File Server scenarios.
# -Enabling the CSV cache reduces the amount of memory available to run VMs on a hyper-converged cluster, 
# -so you'll have to balance storage performance with memory available to VHDs.
$ClusterName = "$S2DCLUSTER"
# $CSVCacheSize = 2048 #Size in MB
# $CSVCacheSize = 4096 #Size in MB
$CSVCacheSize = 12288 #Size in MB


Write-Output "Setting the CSV cache..."
(Get-Cluster $ClusterName).BlockCacheSize = $CSVCacheSize

$CSVCurrentCacheSize = (Get-Cluster $ClusterName).BlockCacheSize
Write-Output "$ClusterName CSV cache size: $CSVCurrentCacheSize MB"

###################################################################################################
# SET CLUSTER NETWORK NAMES
### Get the OLD Network Names
Write-Host -foregroundcolor green "Setting Cluster Network Names..."
$OMGMT = Get-ClusterNetwork | ?{$_.Address -like $MGMTSUB }| Select-Object name | ForEach-Object {$_.name}
$OLIVMIG1 = Get-ClusterNetwork | ?{$_.Address -like $LIVMIGSUB1 }| Select-Object name | ForEach-Object {$_.name}
$OLIVMIG2 = Get-ClusterNetwork | ?{$_.Address -like $LIVMIGSUB2 }| Select-Object name | ForEach-Object {$_.name}

### Set the New Cluster Network Names
(Get-ClusterNetwork -Name $OMGMT).Name = $MGMTNAME
(Get-ClusterNetwork -Name $OLIVMIG1).Name = $LIVMIGNAME1
(Get-ClusterNetwork -Name $OLIVMIG2).Name = $LIVMIGNAME2


###################################################################################################
# Set Cluster Network Netork Communication
# What the default output doesn't show you is the property called Role. 
# This is the property that controls the options listed in the GUI, and it can have one of three possible
# 
# Integer Values:
#  - 1: Allow cluster network communication on this network
#  - 3: Allow clients to connect through this network
#  - 0: Do not allow cluster network communication on this network

# To allow cluster network communication, but not client connections:
# $MyNetwork = Get-ClusterNetwork "MyHeartbeatNetwork"
# $MyNetwork.Role = 1
#
# Only allow Cluster traffic/communication on these networks.
Write-Host -foregroundcolor green "Setting Cluster Network Roles/Communications..."
$NETLIVMIG1 = Get-ClusterNetwork "$LIVMIGNAME1"
$NETLIVMIG1.Role = 1

$NETLIVMIG2 = Get-ClusterNetwork "$LIVMIGNAME2"
$NETLIVMIG2.Role = 1

###################################################################################################
# Setup Live Migration Networks
#
### Change the Network Orders in "Live Migration Settings"
#
# https://aidanfinn.com/?p=12724
# Get-ClusterResourceType -Name “Virtual Machine” | Set-ClusterParameter -Name MigrationNetworkOrder -Value ([String]::Join(“;”,(Get-ClusterNetwork -Name “Network1”).ID,(Get-ClusterNetwork -Name “Network2”).ID,(Get-ClusterNetwork -Name “Network3”).ID))
#
# The following command sets the Cluster Network Order to use the $LIVMIGNAME1 network then the $LIVMIGNAME2 network...confirm this in Live Migration Settings in FCM.
Write-Host -foregroundcolor green "Changing the Cluster Network Order..."
Get-ClusterResourceType -Name “Virtual Machine” | Set-ClusterParameter -Name MigrationNetworkOrder -Value ([String]::Join(“;”,(Get-ClusterNetwork -Name $LIVMIGNAME1).ID,(Get-ClusterNetwork -Name $LIVMIGNAME2).ID))

# Disable all but one network adapter using powershell for LM:
# Get-ClusterResourceType -Name “Virtual Machine” | Set-ClusterParameter -Name MigrationExcludeNetworks -Value ([String]::Join(“;”,(Get-ClusterNetwork | Where-Object {$_.Name -ne “Live Migration”}).ID))
# Get-ClusterResourceType -Name “Virtual Machine” | Set-ClusterParameter -Name MigrationExcludeNetworks -Value ([String]::Join(“;”,(Get-ClusterNetwork | Where-Object {$_.Name -ne $LIVMIGNAME1}).ID))

# Exclude a Specific Cluster Network from "Live Migration Settings" in FCM.
# The following command excludes the $MGMTNAME network from "Live Migration Settings" in FCM.
Write-Host -foregroundcolor green "Excluding Management Network from Live Migration and Cluster Traffic..."
Get-ClusterResourceType -Name “Virtual Machine” | Set-ClusterParameter -Name MigrationExcludeNetworks -Value ([String]::Join(“;”,(Get-ClusterNetwork | Where-Object {$_.Name -eq $MGMTNAME}).ID))


###################################################################################################
Stop-Transcript

###################################################################################################
############################# FINISH FINISH FINISH ################################################
### You are are now ready to add files to the VM_VOL1 volume.
### Begin creating VMs.
############################# FINISH FINISH FINISH ################################################
###################################################################################################