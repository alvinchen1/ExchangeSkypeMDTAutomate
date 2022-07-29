
###################################################################################################
########################### CREATE VMs ##############################################

### This script will:
#
# -Create a Multiple VM with PowerShell.
#

# Get-Help New-VM

# Update the following variables before running:
# - $VMFolderPath
# - $Servers

# ENTER VM Folder path
# $VMFolderPath = "C:\ClusterStorage\VM_VOL2"
$VMFolderPath = "C:\ClusterStorage\VM_VOL1"

# ENTER VM Names.
# $servers=@("VM1","VM2","VM3","VM4")
$servers=@("USS-SRV-12","USS-SRV-14","USS-SRV-15", "USS-SRV-16","USS-SRV-17","USS-SRV-18")
# $servers=@("VM1")

# ENTER the number of CPU/PROCS
$CPU_CNT = 2

# ENTER Memory Size
$MEMSIZE = 8GB

# ENTER Disk Size
$C_DRIVE = 120GB
$D_DRIVE = 200GB
$E_DRIVE = 300GB
$F_DRIVE = 400GB


foreach ($server in $servers)
{
# Create VM and the OS (C:\) drive.
# $tempVM = New-VM -Name $server -Generation 2 -NewVHDPath "$VMFolderPath\$server\Virtual Hard Disks\$($server)_C.vhdx" -NewVHDSizeBytes 100GB -MemoryStartupBytes 4GB -Path $VMFolderPath\ -SwitchName vSwitch-External
# $tempVM = New-VM -Name $server -Generation 2 -NewVHDPath "$VMFolderPath\$server\Virtual Hard Disks\$($server)_C.vhdx" -NewVHDSizeBytes 100GB -Path $VMFolderPath\ -SwitchName vSwitch-External
$tempVM = New-VM -Name $server -Generation 2 -NewVHDPath "$VMFolderPath\$server\Virtual Hard Disks\$($server)_C.vhdx" -NewVHDSizeBytes $C_DRIVE -Path $VMFolderPath\ -SwitchName vSwitch-External

# Set the number of processors
Set-VMProcessor -VMName $server -Count $CPU_CNT

# Create Addtional Data drives (D:\) drive.
# New-VHD -Path "$VMFolderPath\$server\Virtual Hard Disks\$($server)_D.vhdx" -SizeBytes 80GB -Dynamic
New-VHD -Path "$VMFolderPath\$server\Virtual Hard Disks\$($server)_D.vhdx" -SizeBytes $D_Drive -Dynamic
Add-VMHardDiskDrive -VMName $server -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$server\Virtual Hard Disks\$($server)_D.vhdx"

# Create Addtional Data drives (E:\) drive.
# New-VHD -Path "$VMFolderPath\$server\Virtual Hard Disks\$($server)_E.vhdx" -SizeBytes 80GB -Dynamic
New-VHD -Path "$VMFolderPath\$server\Virtual Hard Disks\$($server)_E.vhdx" -SizeBytes $E_Drive -Dynamic
Add-VMHardDiskDrive -VMName $server -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$server\Virtual Hard Disks\$($server)_E.vhdx"

# Create Addtional Data drives (F:\) drive.
# New-VHD -Path "$VMFolderPath\$server\Virtual Hard Disks\$($server)_F.vhdx" -SizeBytes 80GB -Dynamic
New-VHD -Path "$VMFolderPath\$server\Virtual Hard Disks\$($server)_F.vhdx" -SizeBytes $F_Drive -Dynamic
Add-VMHardDiskDrive -VMName $server -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$server\Virtual Hard Disks\$($server)_F.vhdx"

# Set VM Memory - DYNAMIC - sets Minimum, Maximum memory 
# Set-VMMemory -VMName $server -DynamicMemoryEnabled $true -StartupBytes 4GB -MinimumBytes 2GB -MaximumBytes 8GB

# Set VM Memory - STATIC - sets Minimum, Maximum memory
# Set-VMMemory -VMName $server -StartupBytes 8GB 
Set-VMMemory -VMName $server -StartupBytes $MEMSIZE

# Add DVD to VM
$DVD = Add-VMDvdDrive -VM $tempVM -ControllerNumber 0 #-ControllerLocation 2

# Set Boot device
Set-VMFirmware -VM $tempVM -FirstBootDevice $DVD

# This command makes the VM highly available.
Add-ClusterVirtualMachineRole -VirtualMachine $server

# Set-VMDvdDrive -VMName $server -Path f:\iso\8250.iso
Start-VM -Name $server
}