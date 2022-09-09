###################################################################################################
###################### USS-DPM-CONFIG-3.ps1 ###############
###################################################################################################

# This script will:
# -Configure SQL Reporting Service (SSRS)
# -Install DPM
# -Apply Update Rollup to DPM
# -Install DPM 2022 Hotfix KB5015376

###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-DPM-CONFIG-3.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-DPM-CONFIG-3.log

### ENTER MDT STAGING FOLDER
$MDTSTAGING = "\\DEP-MDT-01\STAGING"


##################################################################################################
# Configure SQL Reporting Service (SSRS)
#

Write-Host -foregroundcolor green "Conifiguring SQL 2019 Reporting Service"

function Get-ConfigSet()
{
	# return Get-WmiObject –namespace "root\Microsoft\SqlServer\ReportServer\RS_SSRS\v14\Admin" `
	return Get-WmiObject –namespace "root\Microsoft\SqlServer\ReportServer\RS_SSRS\v15\Admin" `
		-class MSReportServer_ConfigurationSetting -ComputerName localhost
}

# Allow importing of sqlps module
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

# Retrieve the current configuration
$configset = Get-ConfigSet

# $configset

If (! $configset.IsInitialized)
{
	# Get the ReportServer and ReportServerTempDB creation script
	[string]$dbscript = $configset.GenerateDatabaseCreationScript("ReportServer", 1033, $false).Script

	# Import the SQL Server PowerShell module
	Import-Module sqlps -DisableNameChecking | Out-Null

	# Establish a connection to the database server (localhost)
	$conn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $env:ComputerName
	$conn.ApplicationName = "SSRS Configuration Script"
	$conn.StatementTimeout = 0
	$conn.Connect()
	$smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $conn

	# Create the ReportServer and ReportServerTempDB databases
	$db = $smo.Databases["master"]
	$db.ExecuteNonQuery($dbscript)

	# Set permissions for the databases
	$dbscript = $configset.GenerateDatabaseRightsScript($configset.WindowsServiceIdentityConfigured, "ReportServer", $false, $true).Script
	$db.ExecuteNonQuery($dbscript)

	# Set the database connection info
	$configset.SetDatabaseConnection("(local)", "ReportServer", 2, "", "")

	$configset.SetVirtualDirectory("ReportServerWebService", "ReportServer", 1033)
	$configset.ReserveURL("ReportServerWebService", "http://+:80", 1033)


	# For SSRS 2016-2017 only, older versions have a different name
	$configset.SetVirtualDirectory("ReportServerWebApp", "Reports", 1033)
	$configset.ReserveURL("ReportServerWebApp", "http://+:80", 1033)

	$configset.InitializeReportServer($configset.InstallationID)

	# Re-start services?
	$configset.SetServiceState($false, $false, $false)
	Restart-Service $configset.ServiceName
	$configset.SetServiceState($true, $true, $true)

	# Update the current configuration
	$configset = Get-ConfigSet

	# Output to screen
	$configset.IsReportManagerEnabled
	$configset.IsInitialized
	$configset.IsWebServiceEnabled
	$configset.IsWindowsServiceEnabled
	$configset.ListReportServersInDatabase()
	$configset.ListReservedUrls();

#	$inst = Get-WmiObject –namespace "root\Microsoft\SqlServer\ReportServer\RS_SSRS\v14" `
	$inst = Get-WmiObject –namespace "root\Microsoft\SqlServer\ReportServer\RS_SSRS\v15" `
		-class MSReportServer_Instance -ComputerName localhost

	$inst.GetReportServerUrls()
}

Write-Host -foregroundcolor green "Finished Configuring SQL 2019 Reporting Service ..."

###################################################################################################
############# Copy DPM files to Local System  ###################################################################
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


###################################################################################################
# Check if SQL services are started. If service is not started start it, sleep for 10 seconds and keep trying until service starts.
# The MECM install will fail if the SQL service is not started.

$Service = 'MSSQLSERVER'
If ((Get-Service $Service).Status -ne 'Running') {
   do {
       Start-Service $Service -ErrorAction SilentlyContinue
       Start-Sleep 5
   } until ((Get-Service $Service).Status -eq 'Running')
# }Return "$($Service) has STARTED"
} Write-Host -foregroundcolor green "$($Service) has STARTED"


$Service = 'SQLSERVERAGENT'
If ((Get-Service $Service).Status -ne 'Running') {
   do {
       Start-Service $Service -ErrorAction SilentlyContinue
       Start-Sleep 5
   } until ((Get-Service $Service).Status -eq 'Running')
# }Return "$($Service) has STARTED"
} Write-Host -foregroundcolor green "$($Service) has STARTED"


# Start-Service MSSQLSERVER
# Start-Service SQLSERVERAGENT

# PAUSE


###################################################################################################
############# Install DPM  ###################################################################
#### The script below assumes all DPM files have been copied to the C:\DPM_STAGING\SCDPM_2019_1801 folders.
# Run this on the DPM server (XXX-SRV-58)
# Note the DPM install is being performed by the batch file below
# Note I couldn't get command to run in PowerShell 
# This command must be run with "Domain Admin" permissions.
Write-Host -foregroundcolor green "Installing DPM..."
# Start-Process "C:\SCCM_STAGING\MECM_CB_2103\SMSSETUP\BIN\X64\Setup.exe" -Wait -ArgumentList '/NOUSERINPUT /Script C:\SCCM_STAGING\SCRIPTS\MECM_CB_2103_ALLROLES.ini'
# Start "C:\SCDPM_2019_1801\Setup.exe" -Wait -ArgumentList '/i /f C:\SCDPM_2019_1801\USS_DPMSetup.ini /l C:\SCDPM_2019_1801\dpmlog.txt'
Start "C:\DPM_STAGING\SCDPM_2022\Setup.exe" -Wait -ArgumentList '/i /f C:\DPM_STAGING\SCRIPTS\USS_DPMSetup.ini /l C:\DPM_STAGING\SCRIPTS\dpmlog.txt'

###################################################################################################
# Apply Update Rollup to DPM
# (If needed) Extract DPM server rollup package to C:\DPM_STAGING\SCDPM_2019_UR3\SERVER
# C:\DPM_STAGING\SCDPM_2019_UR3\dataprotectionmanager-kb5001202.exe /x
#
# Install DPM Server Update Rollup 
# Write-Host -foregroundcolor green "Installing DPM Update Rollup..."
# Msiexec.exe /norestart /update C:\SCDPM_2019_UR3\Server\dataprotectionmanager-kb5001202.msp
# Start-Process msiexec -Wait -NoNewWindow -ArgumentList '/I $MDTSTAGING\REPORT_VIEWER_2012\ReportViewer.msi /passive /norestart'

# Install DPM 2022 Hotfix KB5015376
# Note this hotfix requires a reboot.
# Msiexec.exe /norestart /passive /update C:\SCDPM_2022_HOTFIX_KB5015376\Server\dataprotectionmanager-kb5015376.msp
Write-Host -foregroundcolor green "Installing DPM Hotfix KB5015376..."
Start-Process Msiexec.exe -Wait -NoNewWindow -ArgumentList '/passive /norestart /Update C:\DPM_STAGING\SCDPM_2022_HOTFIX_KB5015376\Server\dataprotectionmanager-kb5015376.msp'

###################################################################################################
# ***OPTIONAL***THIS IS ONLY NEEDED ON A REMOTE MACHINE
# Apply DPM Server console only update
#(If needed) Extract DPM Console rollup package to C:\DPM_STAGING\SCDPM_2019_UR3\Console
# C:\DPM_STAGING\SCDPM_2019_UR3\DPMCENTRALCONSOLESERVER-KB5001202.exe /x

#(If needed) Install DPM Console Update Rollup 
# Msiexec.exe /update C:\DPM_STAGING\SCDPM_2019_UR3\Console\DPMCENTRALCONSOLESERVER-KB5001202.msp

Stop-Transcript

# ******* REBOOT SERVER HERE ******


