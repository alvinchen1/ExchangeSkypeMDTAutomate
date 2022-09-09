
###################################################################################################
########################### CREATE Admin Server VMs ##############################################
#

### This script will:
#
# -Create a Multiple VMs on Hyper-V using PowerShell.
#
# This script will create two VMs.


###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
# Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-ADM-CONFIG-3.log
# Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-ADM-CONFIG-3.log


###################################################################################################
# MODIFY/ENTER These Values

# USS-SRV-50.
$VMFolderPath = "D:\VM_D"
$SERV1 = "USS-SRV-50"
$SERV1_CPU = 2
$SERV1_MEM = 8GB
$SERV1_C_DRV = 510GB

# USS-SRV-58
$VMFolderPath = "D:\VM_D"
$DPMSTORFolderPath = "E:\DPMSTORAGE" # Created on the ADMIN server Physical E: drive
$SERV2 = "USS-SRV-58" 
$SERV2_CPU = 4
$SERV2_MEM = 16GB
$SERV2_C_DRV = 510GB
$SERV2_D_DRV = 999GB
$SERV2_E_DRV = 300GB
$SERV2_F_DRV = 50TB

###################################################################################################
### USS-SRV-50

# $tempVM = New-VM -Name $SERV1 -Generation 2 -NewVHDPath "$VMFolderPath\$SERV1\Virtual Hard Disks\$($SERV1)_C.vhdx" -NewVHDSizeBytes 100GB -MemoryStartupBytes 4GB -Path $VMFolderPath\ -SwitchName vSwitch-External
# $tempVM = New-VM -Name $SERV1 -Generation 2 -NewVHDPath "$VMFolderPath\$SERV1\Virtual Hard Disks\$($SERV1)_C.vhdx" -NewVHDSizeBytes 100GB -Path $VMFolderPath\ -SwitchName vSwitch-External
$tempVM = New-VM -Name $SERV1 -Generation 2 -NewVHDPath "$VMFolderPath\$SERV1\Virtual Hard Disks\$($SERV1)_C.vhdx" -NewVHDSizeBytes $SERV1_C_DRV -Path $VMFolderPath\ -SwitchName vSwitch-External

# Set the number of processors
Set-VMProcessor -VMName $SERV1 -Count $SERV1_CPU

# Set VM Memory - DYNAMIC - sets Minimum, Maximum memory 
# Set-VMMemory -VMName $SERV1 -DynamicMemoryEnabled $true -StartupBytes 4GB -MinimumBytes 2GB -MaximumBytes 8GB

# Set VM Memory - STATIC - sets Minimum, Maximum memory
# Set-VMMemory -VMName $SERV1 -StartupBytes 8GB 
Set-VMMemory -VMName $SERV1 -StartupBytes $SERV1_MEM

# Add DVD to VM
$DVD = Add-VMDvdDrive -VM $tempVM -ControllerNumber 0 #-ControllerLocation 2

# Set Boot device
Set-VMFirmware -VM $tempVM -FirstBootDevice $DVD

# This command makes the VM highly available.
# Add-ClusterVirtualMachineRole -VirtualMachine $SERV1

# Set-VMDvdDrive -VMName $SERV1 -Path f:\iso\8250.iso
# Start-VM -Name $SERV1


###################################################################################################
### USS-SRV-58

# Create VM and the OS (C:\) drive.
# $tempVM = New-VM -Name $SERV2 -Generation 2 -NewVHDPath "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_C.vhdx" -NewVHDSizeBytes 100GB -MemoryStartupBytes 4GB -Path $VMFolderPath\ -SwitchName vSwitch-External
# $tempVM = New-VM -Name $SERV2 -Generation 2 -NewVHDPath "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_C.vhdx" -NewVHDSizeBytes 100GB -Path $VMFolderPath\ -SwitchName vSwitch-External
$tempVM = New-VM -Name $SERV2 -Generation 2 -NewVHDPath "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_C.vhdx" -NewVHDSizeBytes $SERV2_C_DRV -Path $VMFolderPath\ -SwitchName vSwitch-External

# Set the number of processors
Set-VMProcessor -VMName $SERV2 -Count $SERV2_CPU

# Create Addtional Data drives (D:\) drive.
# New-VHD -Path "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_D.vhdx" -SizeBytes 80GB -Dynamic
New-VHD -Path "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_D.vhdx" -SizeBytes $SERV2_D_DRV -Dynamic
Add-VMHardDiskDrive -VMName $SERV2 -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_D.vhdx"

# Create Addtional Data drives (E:\) drive.
# New-VHD -Path "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_E.vhdx" -SizeBytes 80GB -Dynamic
New-VHD -Path "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_E.vhdx" -SizeBytes $SERV2_E_DRV -Dynamic
Add-VMHardDiskDrive -VMName $SERV2 -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_E.vhdx"


# Create Addtional Data drives (F:\) drive.
# Note this is the DPM STORAGE DRIVE. It will be created on the ADMIN server Physical drive.
New-VHD -Path "$DPMSTORFolderPath\$($SERV2)_F.vhdx" -SizeBytes $SERV2_F_DRV -Dynamic
Add-VMHardDiskDrive -VMName $SERV2 -ControllerType SCSI -ControllerNumber 0 –Path "$DPMSTORFolderPath\$($SERV2)_F.vhdx"

# Set VM Memory - DYNAMIC - sets Minimum, Maximum memory 
# Set-VMMemory -VMName $SERV2 -DynamicMemoryEnabled $true -StartupBytes 4GB -MinimumBytes 2GB -MaximumBytes 8GB

# Set VM Memory - STATIC - sets Minimum, Maximum memory
# Set-VMMemory -VMName $SERV2 -StartupBytes 8GB 
Set-VMMemory -VMName $SERV2 -StartupBytes $SERV2_MEM

# Add DVD to VM
$DVD = Add-VMDvdDrive -VM $tempVM -ControllerNumber 0 #-ControllerLocation 2

# Set Boot device
Set-VMFirmware -VM $tempVM -FirstBootDevice $DVD

# This command makes the VM highly available.
# Add-ClusterVirtualMachineRole -VirtualMachine $SERV2

# Set-VMDvdDrive -VMName $SERV2 -Path f:\iso\8250.iso
# Start-VM -Name $SERV2


###################################################################################################
# Stop-Transcript