
##################### USS-AD-CONFIG-2.ps1 ############################################
#
# This script must be ran after the AD-CONFIG-1.ps1 is ran and the server has been rebooted.
#
### MDT will handle Reboots.
#
### This script will:
#
# -Install AD DS, DNS and GPMC - Add prerequisites (Windows Features) to build an Active Directory forest - 
# -Create a New AD Forest and Add a Domain Controller - Using Install-ADDSForest.
# -Enable Remote Desktop
# -Stop/Prevent Server Manager from loading at startup

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-AD-CONFIG-2.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-AD-CONFIG-2.log

###################################################################################################
# MODIFY/ENTER These Values
#
# ENTER New Forest name and DSRM Password.
$domainname = “USS.LOCAL”
$netbiosName = “USS”
# Note the DSRM password ... Update it before running this script.
$DSRMPASS = (ConvertTo-SecureString -String !QAZ2wsx#EDC4rfv -AsPlainText -Force)


###################################################################################################
########## Add the Active Directory Domain Services role, the DNS Server role, and the Group Policy management feature
# Add prerequisites (Windows Features) to build an Active Directory forest - Install AD DS, DNS and GPMC
$featureLogPath = “c:\poshlog\featurelog.txt”
start-job -Name addFeature -ScriptBlock {
Add-WindowsFeature -Name “ad-domain-services” -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name “dns” -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name “gpmc” -IncludeAllSubFeature -IncludeManagementTools }
Wait-Job -Name addFeature
Get-WindowsFeature | Where installed >>$featureLogPath

Start-Sleep -s 60

################## Install New AD Forest #############################################################
# Create New Forest, Add Domain Controller
Install-ADDSForest -CreateDnsDelegation:$false `
-DomainName $domainname `
-SafeModeAdministratorPassword $DSRMPASS `
-DatabasePath “C:\Windows\NTDS” `
-DomainNetbiosName $netbiosName `
-ForestMode "7" `
-DomainMode "7" `
-LogPath "C:\Windows\NTDS" `
-InstallDns:$true `
-NoRebootOnCompletion:$true `
-SysvolPath “C:\Windows\SYSVOL” `
-Force:$true
# Don't allow Install-ADDSForest reboot
# Let MDT reboot the comupter..."-NoRebootOnCompletion:$true"

###################################################################################################
Stop-Transcript
