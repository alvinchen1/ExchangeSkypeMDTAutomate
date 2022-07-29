###################################################################################################
##################### USS-MECM-CONFIG-6.ps1 
###################################################################################################
#
### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Install MECM 2103 (unattended)
# -Install SQL 2019 Reporting Service
# -BIG NOTE you must configure the Reporting Service *** MANUALLY ***.
#
# Run SCCM Precheck to confirm all prerequisites are in place
# C:\SCCM_STAGING\MECM_CB_2103\SMSSETUP\BIN\X64\Prereqchk.exe /LOCAL


###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-MECM-CONFIG-6.log
Start-Transcript -Path \\DEV-MDT-01\DEPLOYMENTSHARE$\LOGS\$env:COMPUTERNAME\USS-MECM-CONFIG-6.log

###################################################################################################
# MODIFY/ENTER These Values Before Running This Script.

### ENTER MDT STAGING FOLDER
$MDTSTAGING = "\\DEV-MDT-01\STAGING"

### ENTER MECM CONFIGURATION FILE
# Note this file needs to be in the MDT STAGING folder (D:\STAGING\SCRIPTS)
# UPDATE the "PrerequisitePath=" in this file (PrerequisitePath=\\SRV-MDT-01\STAGING\MECM_CB_2103_PREQCOMP)
# $MECMCONFIGFILE = "MECM_CB_2103_ALLROLES.ini"
$MECMCONFIGFILE = "MECM_CB_2203_ALLROLES.ini"

$MECMPOSTSCPT = "USS-MECM-POST-1.ps1"


###################################################################################################
### COPY MECM CONFIGURATION FILE TO LOCAL DRIVE 
# Copy the SCCM_STAGING folder to the MDT STAGING folder:
# Copy-Item $MECMSTAGINGFLDR -Destination C:\ -Recurse -Force
# Copy-Item $MDTSTAGING\SCRIPTS\USS_SQL2019ForSCCM2103.ini -Destination C:\Windows\Temp -Recurse -Force
# Write-Host -foregroundcolor green "Copying MECM CONFIG FILE to local drive - C:\Windows\Temp"
# Copy-Item $MDTSTAGING\SCRIPTS\$MECMCONFIGFILE -Destination C:\Windows\Temp\MECM_CB_2103_ALLROLES.ini -Recurse -Force

Write-Host -foregroundcolor green "Copying MECM CONFIG FILE to local drive - C:\"
# Copy-Item $MDTSTAGING\SCRIPTS\$MECMCONFIGFILE -Destination C:\Windows\Temp\MECM_CB_2103_ALLROLES.ini -Recurse -Force
# Copy-Item $MDTSTAGING\MECM_CB_2103 -Destination C:\ -Recurse -Force
# Copy-Item $MDTSTAGING\MECM_CB_2103_PREQCOMP -Destination C:\ -Recurse -Force

Copy-Item $MDTSTAGING\MECM_CB_2203 -Destination C:\ -Recurse -Force
Copy-Item $MDTSTAGING\MECM_CB_2203_PREQCOMP -Destination C:\ -Recurse -Force
Copy-Item $MDTSTAGING\SCRIPTS\$MECMCONFIGFILE -Destination C:\MECM_CB_2203\MECM_CB_2203_ALLROLES.ini -Recurse -Force
Copy-Item $MDTSTAGING\SCRIPTS\$MECMPOSTSCPT -Destination C:\MECM_CB_2203 -Recurse -Force

INSTALL-MECM-SUPPRESS-ERRORS.ps1

###################################################################################################
### Install MECM 2103 unattended
# The script below assumes all SCCM files have been copied to the C:\SCCM_STAGING\MECM_CB_2103\ folders.
# Run this on the SCCM site server (XXX-SRV-14)
#
# Note the MECM powershell script willl start the install and then exit...the MECM install is still proceeding...
# Monitor the C:\ConfigMgrSetup.log for status and progress
# Start-Process "C:\SCCM_STAGING\MECM_CB_2103\SMSSETUP\BIN\X64\Setup.exe" -Wait -ArgumentList '/NOUSERINPUT /Script C:\SCCM_STAGING\SCRIPTS\MECM_CB_2103_ALLROLES.ini'
# Start-Process "$MDTSTAGING\MECM_CB_2103\SMSSETUP\BIN\X64\Setup.exe" -Wait -NoNewWindow -ArgumentList '/NOUSERINPUT /Script $MDTSTAGING\SCRIPTS\MECM_CB_2103_ALLROLES.ini'
# Write-Host -foregroundcolor green "Installing MECM 2103 unattended using MECM Configuration file"
# Start-Process "$MDTSTAGING\MECM_CB_2103\SMSSETUP\BIN\X64\Setup.exe" -Wait -NoNewWindow -ArgumentList '/NOUSERINPUT /Script C:\Windows\Temp\MECM_CB_2103_ALLROLES.ini'



# Write-Host -foregroundcolor green "Installing MECM 2103 unattended using MECM Configuration file"
# Start-Process "C:\MECM_CB_2103\SMSSETUP\BIN\X64\Setup.exe" -Wait -ArgumentList '/NOUSERINPUT /Script C:\Windows\Temp\MECM_CB_2103_ALLROLES.ini'
# Start-Process "C:\MECM_CB_2203\SMSSETUP\BIN\X64\Setup.exe" -Wait -ArgumentList '/NOUSERINPUT /Script C:\Windows\Temp\MECM_CB_2203_ALLROLES.ini'

# ******* THIS COMMAND REQUIRES A SERVER REBOOT ******


###################################################################################################
###  Install SQL 2019 Reporting Service 
# The SQL Reporting service needed for the SCCM Reporting can be installed manually or automated (PowerShell script).
# We will install the SQL Reporting service using PowerShell
# We will configure the SQL Reporting service using the GUI.
#
######## The PowerShell script below will install the SQL 2019 Reporting Service on a SQL 2019 installation. 
# If you're using a different version of SQL, you should test the script on it before using the script below.
#
# There is no completion screen for the SQL Reporting service installation...check task manager to confirm its completion.
#
# Start-Process "C:\SCCM_STAGING\SQL_2019_RS\SQLServerReportingServices.exe" -Wait -ArgumentList '/passive /norestart /IAcceptLicenseTerms /PID=2C9JR-K3RNG-QD4M4-JQ2HR-8468J'
# Write-Host -foregroundcolor green "Installing SQL 2019 Reporting Service"
# Start-Process "$MDTSTAGING\SQL_2019_RS\SQLServerReportingServices.exe" -Wait -NoNewWindow -ArgumentList '/passive /norestart /IAcceptLicenseTerms /PID=2C9JR-K3RNG-QD4M4-JQ2HR-8468J'
 
# Note if you don't reboot the server here you will not see the "Reporting Services Configuration Manager" on the \
# start menu.
#
# ******* THIS COMMAND REQUIRES A SERVER REBOOT ******


###################################################################################################
### Configure SQL 2019 Reporting Service (SSRS) *** Manually ***
# Refer to the Build DOC to install the SQL Server Reporting Services
# The doc will cover install the SQL Server Reporting Services, configure it, and set the Reporting service account to an AD account.
# Run this on the MECM server (XXX-SRV-14)

# ******* REBOOT SERVER HERE ****** 

# Start-Sleep 240

###################################################################################################
Stop-Transcript

###### Tell MDT this step was successfull...JOHN TESTING.....
# RETURN 0

