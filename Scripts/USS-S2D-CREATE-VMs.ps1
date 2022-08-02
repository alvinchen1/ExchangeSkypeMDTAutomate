
param([xml]$config)

if($null -eq $config){
    $configPath = "$PSScriptRoot/../config.xml"
    Write-Host "Reading in $configPath"
    [xml]$config = Get-Content $configPath
}

$servers = $config.Installer.Component.Settings.Configuration | Where-Object Host -eq 'Cluster'
$VMFolderPath = "C:\ClusterStorage\VM_VOL1"
$CPU_CNT = 2
$MEMSIZE = 8GB

$driveLetters = @('C','D','E','F')
$driveSizes = @(120GB,200GB,300GB,400GB)
foreach ($server in $servers)
{
    $vm = New-VM `
        -Name $server.Name `
        -Generation 2 `
        -MemoryStartupBytes $MEMSIZE `
        -Path $VMFolderPath\ `
        -SwitchName vSwitch-External

    for ($i = 0; $i -le $server.AdditionalDataDisks; $i++) {
        $driveLetter = $driveLetters[$i]
        $driveSize = $driveSizes[$i]
        $fullPath = "$VMFolderPath\$($server.Name)\Virtual Hard Disks\$($server.Name)_$driveLetter.vhdx"
        New-VHD `
            -Path $fullPath `
            -SizeBytes $driveSize `
            -Dynamic
        Add-VMHardDiskDrive `
            -VM $vm `
            -Path $fullPath `
            -ControllerType SCSI `
            -ControllerNumber 0
    }

    Set-VMProcessor -VM $vm -Count $CPU_CNT
    $DVD = Add-VMDvdDrive -VM $vm -ControllerNumber 0
    Set-VMFirmware -VM $vm -FirstBootDevice $DVD
    $vm | Add-ClusterVirtualMachineRole
    Start-VM -VM $vm
}