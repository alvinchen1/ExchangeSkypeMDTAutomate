<#
NAME
    ADM-CONFIG-3.ps1

SYNOPSIS
    Creates multiple VMs on Hyper-V host

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
$VMFolderPath = "D:\VM_D"
# DC1: SRV-50
$SERV1 = ($WS | ? {($_.Role -eq "DC1")}).Name
$SERV1_CPU = 2
$SERV1_MEM = 8GB
$SERV1_C_DRV = 510GB
# DPM: SRV-58
$SERV2 = ($WS | ? {($_.Role -eq "DPM")}).Name 
$DPMSTORFolderPath = "E:\DPMSTORAGE" # Created on the ADMIN server Physical E: drive
$SERV2_CPU = 4
$SERV2_MEM = 16GB
$SERV2_C_DRV = 510GB
$SERV2_D_DRV = 999GB
$SERV2_E_DRV = 300GB
$SERV2_F_DRV = 50TB

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Create VMs
Write-Host -ForegroundColor Green "Creating VMs"

# DC1
$tempVM = New-VM -Name $SERV1 -Generation 2 -NewVHDPath "$VMFolderPath\$SERV1\Virtual Hard Disks\$($SERV1)_C.vhdx" -NewVHDSizeBytes $SERV1_C_DRV -Path $VMFolderPath\ -SwitchName vSwitch-External
Set-VMProcessor -VMName $SERV1 -Count $SERV1_CPU
Set-VMMemory -VMName $SERV1 -StartupBytes $SERV1_MEM
$DVD = Add-VMDvdDrive -VM $tempVM -ControllerNumber 0
Set-VMFirmware -VM $tempVM -FirstBootDevice $DVD

# DPM
$tempVM = New-VM -Name $SERV2 -Generation 2 -NewVHDPath "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_C.vhdx" -NewVHDSizeBytes $SERV2_C_DRV -Path $VMFolderPath\ -SwitchName vSwitch-External
Set-VMProcessor -VMName $SERV2 -Count $SERV2_CPU
New-VHD -Path "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_D.vhdx" -SizeBytes $SERV2_D_DRV -Dynamic
Add-VMHardDiskDrive -VMName $SERV2 -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_D.vhdx"
New-VHD -Path "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_E.vhdx" -SizeBytes $SERV2_E_DRV -Dynamic
Add-VMHardDiskDrive -VMName $SERV2 -ControllerType SCSI -ControllerNumber 0 –Path "$VMFolderPath\$SERV2\Virtual Hard Disks\$($SERV2)_E.vhdx"
New-VHD -Path "$DPMSTORFolderPath\$($SERV2)_F.vhdx" -SizeBytes $SERV2_F_DRV -Dynamic
Add-VMHardDiskDrive -VMName $SERV2 -ControllerType SCSI -ControllerNumber 0 –Path "$DPMSTORFolderPath\$($SERV2)_F.vhdx"
Set-VMMemory -VMName $SERV2 -StartupBytes $SERV2_MEM
$DVD = Add-VMDvdDrive -VM $tempVM -ControllerNumber 0
Set-VMFirmware -VM $tempVM -FirstBootDevice $DVD

Stop-Transcript
