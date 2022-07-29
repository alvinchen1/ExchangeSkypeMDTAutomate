
###################################################################################################
########################### CREATE Admin Server VMs ##############################################
#

### This script will:
#
# -Create a Multiple VMs on Hyper-V using PowerShell.
#
# This script will create multiple VMs.
# Update the following variables before running:
# - $VMFolderPath
# - $Servers

# Get-Help New-VM

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-ADM-CREATE-VMs.log
Start-Transcript -Path \\DEV-MDT-01\DEPLOYMENTSHARE$\LOGS\$env:COMPUTERNAME\USS-ADM-CONFIG-1.log


###################################################################################################
# MODIFY/ENTER These Values

### ENTER VM Folder path
$VMFolderPath = "C:\VM_C"

# ENTER VM names.
# $servers=@("VM1","VM2","VM3","VM4")
$servers=@("USS-SRV-11","USS-SRV-20")


###################################################################################################
foreach ($server in $servers)
{
# Create VM and the OS (C:\) drive.
# $tempVM = New-VM -Name $server -Generation 2 -NewVHDPath "$VMFolderPath\$server\Virtual Hard Disks\$($server)_C.vhdx" -NewVHDSizeBytes 100GB -MemoryStartupBytes 4GB -Path $VMFolderPath\ -SwitchName vSwitch-External
$tempVM = New-VM -Name $server -Generation 2 -NewVHDPath "$VMFolderPath\$server\Virtual Hard Disks\$($server)_C.vhdx" -NewVHDSizeBytes 100GB -Path $VMFolderPath\ -SwitchName vSwitch-External

# Set the number of processors
Set-VMProcessor -VMName $server -Count 2

# Create Addtional Data drives (D:\) drive.
New-VHD -Path "$VMFolderPath\$server\Virtual Hard Disks\$($server)_D.vhdx" -SizeBytes 80GB -Dynamic
Add-VMHardDiskDrive -VMName $server -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$server\Virtual Hard Disks\$($server)_D.vhdx"
 
# Set VM Memory - DYNAMIC - sets Minimum, Maximum memory 
# Set-VMMemory -VMName $server -DynamicMemoryEnabled $true -StartupBytes 4GB -MinimumBytes 2GB -MaximumBytes 8GB

# Set VM Memory - STATIC - sets Minimum, Maximum memory
Set-VMMemory -VMName $server -StartupBytes 8GB 

# Add DVD to VM
$DVD = Add-VMDvdDrive -VM $tempVM -ControllerNumber 0 #-ControllerLocation 2

# Set Boot device
Set-VMFirmware -VM $tempVM -FirstBootDevice $DVD
}
# Set-VMDvdDrive -VMName $server -Path f:\iso\8250.iso
# Start-VM -Name $server

###################################################################################################
Stop-Transcript