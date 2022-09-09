###################################################################################################
###################### USS-DPM-CONFIG-3.ps1 ###############
###################################################################################################

### ENTER MDT STAGING FOLDER
$MDTSTAGING = "\\DEP-MDT-01\STAGING"

Write-Host -foregroundcolor green "Manually ConfigureSQL 2019 Reporting Service before Continuing..."
Write-Host -foregroundcolor green "Do not Continue until RS has been configured and the server Rebooted..."

Pause

###################################################################################################
############# Install DPM  ###################################################################
#### The script below assumes all DPM files have been copied to the C:\DPM_STAGING\SCDPM_2019_1801 folders.
# Run this on the DPM server (SAT-SRV-20)
# Note the DPM install is being performed by the batch file below
# Note I couldn't get command to run in PowerShell 
###################################################################################################
# 
# Write-Host -foregroundcolor green "Copy DPM file to local Drive..."
# Copy-Item $MDTSTAGING\SCDPM_2019_1801 -Destination C:\ -Recurse -Force
# Copy-Item $MDTSTAGING\SCDPM_2019_UR3 -Destination C:\ -Recurse -Force
# Copy-Item $MDTSTAGING\DPM_AGENT_2019_UR3 -Destination C:\ -Recurse -Force
# Copy-Item $MDTSTAGING\SCRIPTS\DPM\USS_DPMSetup.ini -Destination C:\SCDPM_2019_1801 -Recurse -Force

Write-Host -foregroundcolor green "Copy DPM file to local Drive..."
Copy-Item $MDTSTAGING\SCDPM_2022 -Destination C:\ -Recurse -Force
Copy-Item $MDTSTAGING\SCDPM_2022_HOTFIX_KB5015376 -Destination C:\ -Recurse -Force
Copy-Item $MDTSTAGING\SCRIPTS\DPM\USS_DPMSetup.ini -Destination C:\SCDPM_2022 -Recurse -Force

# Install DPM
# This command must be run with "Domain Admin" permissions.
Write-Host -foregroundcolor green "Installing DPM..."
# Start-Process "C:\SCCM_STAGING\MECM_CB_2103\SMSSETUP\BIN\X64\Setup.exe" -Wait -ArgumentList '/NOUSERINPUT /Script C:\SCCM_STAGING\SCRIPTS\MECM_CB_2103_ALLROLES.ini'
# Start "C:\SCDPM_2019_1801\Setup.exe" -Wait -ArgumentList '/i /f C:\SCDPM_2019_1801\USS_DPMSetup.ini /l C:\SCDPM_2019_1801\dpmlog.txt'
Start "C:\SCDPM_2022\Setup.exe" -Wait -ArgumentList '/i /f C:\SCDPM_2022\USS_DPMSetup.ini /l C:\SCDPM_2022\dpmlog.txt'

###################################################################################################
# Apply Update Rollup to DPM
# (If needed) Extract DPM server rollup package to C:\DPM_STAGING\SCDPM_2019_UR3\SERVER
# C:\DPM_STAGING\SCDPM_2019_UR3\dataprotectionmanager-kb5001202.exe /x
#
# Install DPM Server Update Rollup 
# Write-Host -foregroundcolor green "Installing DPM Update Rollup..."
# Msiexec.exe /norestart /update C:\SCDPM_2019_UR3\Server\dataprotectionmanager-kb5001202.msp

# Install DPM 2022 Hotfix KB5015376
Write-Host -foregroundcolor green "Installing DPM Hotfix KB5015376..."
Msiexec.exe /norestart /passive /update C:\SCDPM_2022_HOTFIX_KB5015376\Server\dataprotectionmanager-kb5015376.msp


###################################################################################################
# ***OPTIONAL***THIS IS ONLY NEEDED ON A REMOTE MACHINE
# Apply DPM Server console only update
#(If needed) Extract DPM Console rollup package to C:\DPM_STAGING\SCDPM_2019_UR3\Console
# C:\DPM_STAGING\SCDPM_2019_UR3\DPMCENTRALCONSOLESERVER-KB5001202.exe /x

#(If needed) Install DPM Console Update Rollup 
# Msiexec.exe /update C:\DPM_STAGING\SCDPM_2019_UR3\Console\DPMCENTRALCONSOLESERVER-KB5001202.msp



# ******* REBOOT SERVER HERE ******


