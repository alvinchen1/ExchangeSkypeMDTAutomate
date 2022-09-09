######## USS-OS-PREP-1 ######

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Turn Off UAC
# -Set Server OS for "Adjust for best performance.
# -Set Power Plan to High Performance
# -Set the Page File Size for (***HDD DRIVES***)(NOT SSD DRIVES)
# -Enable Remote Desktop
# -Stop/Prevent Server Manager from loading at startup
# -Add the windows server backup feature for DPM
# -Enable Firewall Rule - ALL File and Printer Sharing rule
# -Change DVD Drive Letter from D: to X:
# -Copy CMTrace

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-OS-PREP-1.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-OS-PREP-1.log

###################################################################################################
# MODIFY/ENTER These Values Before Running This Script.
#
### ENTER MDT STAGING FOLDER
$MDTSTAGING = "\\DEP-MDT-01\STAGING"


###################################################################################################
### Turn Off UAC
# This will take effect after the systems reboots.
New-ItemProperty -Path HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system -Name EnableLUA -PropertyType DWord -Value 0 -Force

# *** THIS COMMAND REQUIRES A SYSTEM REBOOT ***


###################################################################################################
### Set Server OS for "Adjust for best performance"
$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
try {
    $s = (Get-ItemProperty -ErrorAction stop -Name visualfxsetting -Path $path).visualfxsetting 
    if ($s -ne 2) {
        Set-ItemProperty -Path $path -Name 'VisualFXSetting' -Value 2  
        }
    }
catch {
    New-ItemProperty -Path $path -Name 'VisualFXSetting' -Value 2 -PropertyType 'DWORD'
    }

###################################################################################################
### Set Power Plan to High Performance
Powercfg -SETACTIVE SCHEME_MIN

###################################################################################################
### Set the Page File Size for (***HDD DRIVES***)(NOT SSD DRIVES)
# https://www.tutorialspoint.com/how-to-change-pagefile-settings-using-powershell
# If the Pagefile is automatically managed, you can’t modify the settings
#
# Remove "Automatically manage paging file size setting for all Drives".
$pagefile = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
$pagefile.AutomaticManagedPagefile = $false
$pagefile.put() | Out-Null

# Set the pagefile on C Drive.
$pagefileset = Get-WmiObject Win32_pagefilesetting
$pagefileset.InitialSize = 1024
$pagefileset.MaximumSize = 2048
$pagefileset.Put() | Out-Null

# To set the page file to the "E:" drive
# Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{name="E:\pagefile.sys";
# InitialSize = 0; MaximumSize = 0} -EnableAllPrivileges | Out-Null

### Set the Page File Size for (***SSD DRIVES***)(NOT HDD DRIVES)
# Remove "Automatically manage paging file size setting for all Drives".
# $pagefile = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
# $pagefile.AutomaticManagedPagefile = $false
# $pagefile.put() | Out-Null

# Set the pagefile to "No Page File".
# $pagefileset = Get-WmiObject Win32_pagefilesetting
# $pagefileset.Delete() | Out-Null

###################################################################################################
### Enable Remote Desktop
# These command witll enable Remote Desktop and set the RDP firewall ports on the local server.
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

###################################################################################################
### Stop/Prevent Server Manager from loading at startup
# $SRVNAME = HOSTNAME
# Invoke-Command -ComputerName $SRVNAME -ScriptBlock { New-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -PropertyType DWORD -Value "0x1" –Force}
# These commmands prevent Server Manager from loading at startup and disables the Server Manager Schedule task
Invoke-Command -ScriptBlock { New-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -PropertyType DWORD -Value "0x1" –Force}
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose


#################################### Add Windows Server Backup Feature ############################
### Add the windows server backup feature for DPM
Install-WindowsFeature -Name Windows-Server-Backup


###################################################################################################
### Enable Firewall Rule - ALL File and Printer Sharing rule
Netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes

###################################################################################################
### Change DVD Drive Letter from D: to X:. 
$DvdDrive = Get-CimInstance -Class Win32_Volume -Filter "driveletter='D:'"
Set-CimInstance -InputObject $DvdDrive -Arguments @{DriveLetter="X:"}

# Copy CMTrace
Write-Host -foregroundcolor green "Copying CMTrace"
Copy $MDTSTAGING\CMTRACE\CMTrace.exe C:\ 

###################################################################################################
Stop-Transcript

######### REBOOT SERVER ##########