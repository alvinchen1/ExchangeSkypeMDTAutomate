
###################################################################################################
########################### USS-S2D-CONFIG-4 ##############################################

### This script will:
#
# -Create a Multiple VM with PowerShell.
#

# Get-Help New-VM

# Update the following variables before running:
# - $VMFolderPath
# - $SVRNAMEs
#

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\S2D-CONFIG-4.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\S2D-CONFIG-4.log

# ENTER VM Folder path
# $VMFolderPath = "C:\ClusterStorage\VM_VOL2"
$VMFolderPath = "C:\ClusterStorage\VM_VOL1"

# ENTER VM Names.
# $SVRNAMEs=@("VM1","VM2","VM3","VM4")
# $SVRNAMEs=@("USS-SRV-12","USS-SRV-14","USS-SRV-15", "USS-SRV-16","USS-SRV-17","USS-SRV-18")
# $SVRNAMEs=@("VM1")

# ENTER ServerName : CPU Count : MemorySize : NumberOfDisk(MAX 4): 
# $servers=@("AAA-11:2:8GB:2","AAA-12:1:4GB:3")

# ENTER - ServerName : CPU Count : NumberOfDisk(MAX 4): 
# $servers=@("AAA-11:2:0","AAA-12:1:2","AAA-15:1:3")
$servers=@("USS-SRV-51:2:0","USS-SRV-52:4:4","USS-SRV-53:2:0", "USS-SRV-54:2:2","USS-SRV-55:2:0","USS-SRV-56:2:0","USS-SRV-57:2:0","USS-SRV-59:2:1","USS-SRV-60:2:4","USS-SRV-61:2:1","USS-SRV-62:2:1","USS-SRV-63:2:1","USS-SRV-64:2:1","USS-WKS-01:2:1","USS-WKS-02:2:1")

# ENTER the number of CPU/PROCS
# $CPU_CNT = 2

# ENTER Memory Size
$MEMSIZE = 8GB

# ENTER Disk Size
$C_DRIVE = 120GB
$D_DRIVE = 200GB
$E_DRIVE = 300GB
$F_DRIVE = 400GB
$G_DRIVE = 500GB

foreach ($server in $servers)
{

$TEMP = $server -split ':'
$SVRNAME = $TEMP[0]
$CPU_CNT = $TEMP[1]
$Diskcnt = $TEMP[2]

# Create VM and the OS (C:\) drive.
# $tempVM = New-VM -Name $SVRNAME -Generation 2 -NewVHDPath "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_C.vhdx" -NewVHDSizeBytes 100GB -MemoryStartupBytes 4GB -Path $VMFolderPath\ -SwitchName vSwitch-External
# $tempVM = New-VM -Name $SVRNAME -Generation 2 -NewVHDPath "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_C.vhdx" -NewVHDSizeBytes 100GB -Path $VMFolderPath\ -SwitchName vSwitch-External
$tempVM = New-VM -Name $SVRNAME -Generation 2 -NewVHDPath "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_C.vhdx" -NewVHDSizeBytes $C_DRIVE -Path $VMFolderPath\ -SwitchName vSwitch-External

# Set the number of processors
Set-VMProcessor -VMName $SVRNAME -Count $CPU_CNT

# Set VM Memory - DYNAMIC - sets Minimum, Maximum memory 
# Set-VMMemory -VMName $SVRNAME -DynamicMemoryEnabled $true -StartupBytes 4GB -MinimumBytes 2GB -MaximumBytes 8GB

# Set VM Memory - STATIC - sets Minimum, Maximum memory
# Set-VMMemory -VMName $SVRNAME -StartupBytes 8GB 
# Set-VMMemory -VMName $SVRNAME -VMMemory ($MEMSIZE + "GB")
# Set-VMMemory -VMName $SVRNAME -StartupBytes ($MEMSIZE + "GB")
Set-VMMemory -VMName $SVRNAME -StartupBytes $MEMSIZE


# Add DVD to VM
$DVD = Add-VMDvdDrive -VM $tempVM -ControllerNumber 0 #-ControllerLocation 2

# Set Boot device
Set-VMFirmware -VM $tempVM -FirstBootDevice $DVD


###################################################################################################
# CREATE ADDITIONAL DATA DISK


# Create No Addtional Data drives.
if ($Diskcnt -eq 0) {
# write-output "The $SVRNAME has $Diskcnt Disk"
}

# Create 1 Addtional Data drives (D:\) drive.
if ($Diskcnt -eq 1) {
# write-output "The $SVRNAME has $Diskcnt Disk"
# New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx" -SizeBytes 80GB -Dynamic
New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx" -SizeBytes $D_Drive -Dynamic
Add-VMHardDiskDrive -VMName $SVRNAME -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx"
}

# Create 2 Addtional Data drives (D:\,E:\) drives.
if ($Diskcnt -eq 2) {
#	write-output "The $SVRNAME has $Diskcnt Disk"
# New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx" -SizeBytes 80GB -Dynamic
New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx" -SizeBytes $D_Drive -Dynamic
Add-VMHardDiskDrive -VMName $SVRNAME -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx"
New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_E.vhdx" -SizeBytes $E_Drive -Dynamic
Add-VMHardDiskDrive -VMName $SVRNAME -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_E.vhdx"
}

# Create 3 Addtional Data drives (D:\,E:\,F:\) drives.
if ($Diskcnt -eq 3) {
#	write-output "The $SVRNAME has $Diskcnt Disk"
# New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx" -SizeBytes 80GB -Dynamic
New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx" -SizeBytes $D_Drive -Dynamic
Add-VMHardDiskDrive -VMName $SVRNAME -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx"
New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_E.vhdx" -SizeBytes $E_Drive -Dynamic
Add-VMHardDiskDrive -VMName $SVRNAME -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_E.vhdx"
New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_F.vhdx" -SizeBytes $F_Drive -Dynamic
Add-VMHardDiskDrive -VMName $SVRNAME -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_F.vhdx"

}

# Create 4 Addtional Data drives (D:\,E:\,F:\,G:\) drives.
if ($Diskcnt -eq 4) {
#	write-output "The $SVRNAME has $Diskcnt Disk"
# New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx" -SizeBytes 80GB -Dynamic
New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx" -SizeBytes $D_Drive -Dynamic
Add-VMHardDiskDrive -VMName $SVRNAME -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_D.vhdx"
New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_E.vhdx" -SizeBytes $E_Drive -Dynamic
Add-VMHardDiskDrive -VMName $SVRNAME -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_E.vhdx"
New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_F.vhdx" -SizeBytes $F_Drive -Dynamic
Add-VMHardDiskDrive -VMName $SVRNAME -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_F.vhdx"
New-VHD -Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_G.vhdx" -SizeBytes $G_Drive -Dynamic
Add-VMHardDiskDrive -VMName $SVRNAME -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SVRNAME\Virtual Hard Disks\$($SVRNAME)_G.vhdx"
}

# This command makes the VM highly available.
Add-ClusterVirtualMachineRole -VirtualMachine $SVRNAME

# Set-VMDvdDrive -VMName $SVRNAME -Path f:\iso\8250.iso
Start-VM -Name $SVRNAME
}

###################################################################################################
Stop-Transcript

