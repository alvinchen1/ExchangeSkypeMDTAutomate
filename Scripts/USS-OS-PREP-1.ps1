<#
NAME
    OS-PREP-1.ps1

SYNOPSIS
    Configures VM for optimum performance

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
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value


# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Turn Off UAC
New-ItemProperty -Path HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system -Name EnableLUA -PropertyType DWord -Value 0 -Force

# Set Server OS for "Adjust for best performance"
$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
Try 
{
    $s = (Get-ItemProperty -ErrorAction stop -Name visualfxsetting -Path $path).visualfxsetting 
    If ($s -ne 2) 
    {
        Set-ItemProperty -Path $path -Name 'VisualFXSetting' -Value 2  
    }
}
Catch 
{
    New-ItemProperty -Path $path -Name 'VisualFXSetting' -Value 2 -PropertyType 'DWORD'
}

# Set Power Plan to High Performance
Powercfg -SETACTIVE SCHEME_MIN

# Remove "Automatically manage paging file size setting for all Drives".
$pagefile = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
$pagefile.AutomaticManagedPagefile = $false
$pagefile.put() | Out-Null

# Set the pagefile on C Drive.
$pagefileset = Get-WmiObject Win32_pagefilesetting
$pagefileset.InitialSize = 1024
$pagefileset.MaximumSize = 2048
$pagefileset.Put() | Out-Null

# Enable Remote Desktop
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Stop/Prevent Server Manager from loading at startup
Invoke-Command -ScriptBlock { New-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -PropertyType DWORD -Value "0x1" –Force}
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose

# Add the windows server backup feature for DPM
Install-WindowsFeature -Name Windows-Server-Backup

# Enable Firewall Rule - ALL File and Printer Sharing rule
Netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes

# Change DVD Drive Letter from D: to X:. 
$DvdDrive = Get-CimInstance -Class Win32_Volume -Filter "driveletter='D:'"
Set-CimInstance -InputObject $DvdDrive -Arguments @{DriveLetter="X:"}

# Copy CMTrace
Write-Host -foregroundcolor Green "Copying CMTrace"
Copy $InstallShare\CMTRACE\CMTrace.exe C:\ 

Stop-Transcript
