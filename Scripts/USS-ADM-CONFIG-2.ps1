<#
NAME
    ADM-CONFIG-2.ps1

SYNOPSIS
    Configures Hyper-V virtual switch and adds Windows Defender exclusions for Hyper-V

SYNTAX
    .\$ScriptName
#>

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path –Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path –Parent
$DTG = Get-Date -Format yyyyMMddTHHmm
$RootDir = Split-Path $ScriptDir –Parent

Start-Transcript -Path "$RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log"
Start-Transcript -Path "$env:WINDIR\Temp\$env:COMPUTERNAME-$DTG-$ScriptName.log"

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Create Hyper-V virtual switch
New-VMSwitch -Name "vSwitch-External" -NetAdapterName "TEAM_VM" -AllowManagementOS $false

# Add Windows Defender exclusions
Add-MpPreference -ExclusionPath "C:\VM_C" -Force
Add-MpPreference -ExclusionPath "D:\VM_D" -Force
Add-MpPreference -ExclusionExtension ".vhd" -Force
Add-MpPreference -ExclusionExtension ".vhdx" -Force
Add-MpPreference -ExclusionExtension ".avhd" -Force
Add-MpPreference -ExclusionExtension ".avhdx" -Force
Add-MpPreference -ExclusionExtension ".vsv" -Force
Add-MpPreference -ExclusionExtension ".iso" -Force
Add-MpPreference -ExclusionExtension ".rct" -Force
Add-MpPreference -ExclusionExtension ".vmcx" -Force
Add-MpPreference -ExclusionExtension ".vmrs" -Force
Add-MpPreference -ExclusionPath "$Env:ProgramData\Microsoft\Windows\Hyper-V" -Force
Add-MpPreference -ExclusionPath "$Env:ProgramFiles\Hyper-V" -Force
Add-MpPreference -ExclusionPath "$Env:SystemDrive\ProgramData\Microsoft\Windows\Hyper-V\Snapshots" -Force
Add-MpPreference -ExclusionPath "$Env:Public\Documents\Hyper-V\Virtual Hard Disks" -Force
Add-MpPreference -ExclusionPath "C:\Users\Public Documents\Hyper-V\Virtual Hard Disks" -Force
Add-MpPreference -ExclusionProcess "$Env:systemroot\System32\Vmms.exe" -Force
Add-MpPreference -ExclusionProcess "$Env:systemroot\System32\Vmwp.exe" -Force

Stop-Transcript
