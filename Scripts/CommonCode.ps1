
$config = Get-Content $PSScriptRoot\USS-CONFIG.json | ConvertFrom-Json

workflow CopyVhdxTemplateWorkflow{
    param(
        [Parameter(Mandatory)][string]$FileShare,
        [Parameter(Mandatory)][string]$DestinationFolder,
        [Parameter(Mandatory)][string[]]$VmNames
    )

    ForEach -Parallel ($vmName in $VmNames){
        $destination = "$DestinationFolder\$vmName\Virtual Hard Disks\$($vmName)_C.vhdx"
        Copy-Item -Path "$fileShare\SysPrepTemplate.vhdx" -Destination (New-Item -Type File -Path $destination -Force)
    }
}

function Restart-ComputerOnLan{
    param(
        [Parameter(Mandatory)][string]$ComputerName
    )
    Write-Host "Restarting $ComputerName"
    Restart-Computer -ComputerName $ComputerName -Wait -For Powershell -Timeout 300
}