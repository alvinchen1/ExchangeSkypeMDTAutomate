###################################################################################################
##################### USS-MECM-CONFIG-5.ps1 
###################################################################################################
#
### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -COPY MECM CONFIGURATION FILE TO LOCAL DRIVE
# -Install Report Viewer 2010 for MECM Admin Console
# -Install MECM Admin Console
# -Check if SQL services are started.
# -Install MECM 2103 (unattended)
# -Configure SQL 2019 Reporting Service

# Run SCCM Precheck to confirm all prerequisites are in place
# C:\SCCM_STAGING\MECM_CB_2103\SMSSETUP\BIN\X64\Prereqchk.exe /LOCAL


###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-MECM-CONFIG-5.log
Start-Transcript -Path \\DEP-MDT-01\DEPLOY_SHARE_OFF$\LOGS\$env:COMPUTERNAME\USS-MECM-CONFIG-5.log

###################################################################################################
# MODIFY/ENTER These Values Before Running This Script.

### ENTER MDT STAGING FOLDER
$MDTSTAGING = "\\DEP-MDT-01\STAGING"

### ENTER MECM CONFIGURATION FILE
# Note this file needs to be in the MDT STAGING folder (D:\STAGING\SCRIPTS)
# UPDATE the "PrerequisitePath=" in this file (PrerequisitePath=\\SRV-MDT-01\STAGING\MECM_CB_2103_PREQCOMP)
# $MECMCONFIGFILE = "MECM_CB_2103_ALLROLES.ini"
# $MECMCONFIGFILE = "MECM_CB_2203_ALLROLES.ini"

# $MECMPOSTSCPT = "USS-MECM-POST-1.ps1"

###################################################################################################
### Install Report Viewer 2010 for MECM Admin Console
### Install MECM Admin Console
# Write-Host -foregroundcolor green "Copying MECM Admin Console folder to local drive"
# Copy-Item $MDTSTAGING\AdminConsole_2203 -Destination C:\MECM_CB_2203 -Recurse -Force

### Install Report Viewer 2010 for MECM Admin Console
# Write-Host -foregroundcolor green "Installing Report Viewer 2010 SP1 Redist (KB2549864)"
# Start-Process -Wait C:\MECM_CB_2203\AdminConsole_2203\ReportViewer.exe /q
Write-Host -foregroundcolor green "Installing Report Viewer 2010 SP1 Redist (KB2549864)"
Start-Process -Wait C:\MECM_STAGING\AdminConsole_2203\ReportViewer.exe /q

### This WORKS...Install MECM Admin Console
Write-Host -foregroundcolor green "Installing MECM Admin Console"
# Start-Process -Wait C:\MECM_STAGING\AdminConsole_2203\AdminConsole.msi -ArgumentList 'INSTALL=ALL ALLUSERS=1 TARGETDIR="D:\MECM\AdminConsole" DEFAULTSITESERVERNAME=USS-SRV-52.USS.LOCAL ADDLOCAL="AdminConsole,SCUIFramework" /passive /norestart'
Start-Process -Wait C:\MECM_STAGING\MECM_CB_2203\SMSSETUP\BIN\I386\AdminConsole.msi -ArgumentList 'INSTALL=ALL ALLUSERS=1 TARGETDIR="D:\MECM\AdminConsole" DEFAULTSITESERVERNAME=USS-SRV-52.USS.LOCAL ADDLOCAL="AdminConsole,SCUIFramework" /passive /norestart'


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

###################################################################################################
### Install MECM 2103 unattended
# The script below assumes all SCCM files have been copied to the C:\SCCM_STAGING\MECM_CB_2103\ folders.
# Run this on the SCCM site server (XXX-SRV-52)
#
# Note the MECM powershell script willl start the install and then exit...the MECM install is still proceeding...
# Monitor the C:\ConfigMgrSetup.log for status and progress
# Start-Process "C:\SCCM_STAGING\MECM_CB_2103\SMSSETUP\BIN\X64\Setup.exe" -Wait -ArgumentList '/NOUSERINPUT /Script C:\SCCM_STAGING\SCRIPTS\MECM_CB_2103_ALLROLES.ini'
# Start-Process "$MDTSTAGING\MECM_CB_2103\SMSSETUP\BIN\X64\Setup.exe" -Wait -NoNewWindow -ArgumentList '/NOUSERINPUT /Script $MDTSTAGING\SCRIPTS\MECM_CB_2103_ALLROLES.ini'
# Write-Host -foregroundcolor green "Installing MECM 2103 unattended using MECM Configuration file"
# Start-Process "$MDTSTAGING\MECM_CB_2103\SMSSETUP\BIN\X64\Setup.exe" -Wait -NoNewWindow -ArgumentList '/NOUSERINPUT /Script C:\Windows\Temp\MECM_CB_2103_ALLROLES.ini'

# Start-Process "C:\MECM_CB_2103\SMSSETUP\BIN\X64\Setup.exe" -Wait -ArgumentList '/NOUSERINPUT /Script C:\Windows\Temp\MECM_CB_2103_ALLROLES.ini'
# Start-Process "C:\MECM_CB_2203\SMSSETUP\BIN\X64\Setup.exe" -Wait -ArgumentList '/NOUSERINPUT /Script C:\Windows\Temp\MECM_CB_2203_ALLROLES.ini'
# Start-Process "C:\MECM_CB_2203\SMSSETUP\BIN\X64\Setup.exe" -Wait -ArgumentList '/NOUSERINPUT /Script C:\MECM_CB_2203\MECM_CB_2203_ALLROLES.ini'

# Start MECM install as a backgroud job. The PowerShell script will continue processing all other commands.
# It will not wait for this job to finish before continuing. We will add a Wait-Job command later in the script to determine when
# the PowerShell script should continue.
# If you attempt to run the MECM installlation using Start-Process or ...\Setup.exe it will cause the MDT TS step to fail
# server to fail with error 
Write-Host -foregroundcolor green "Installing MECM 2103 unattended using MECM Configuration file"
Start-Job -Name "MECMINSTALL" -ScriptBlock {Start-Process "C:\MECM_STAGING\MECM_CB_2203\SMSSETUP\BIN\X64\Setup.exe" -Wait -ArgumentList '/NOUSERINPUT /Script C:\MECM_STAGING\MECM_CB_2203\MECM_CB_2203_ALLROLES.ini'}
Start-Sleep -Seconds 20

# Start Tracking Sync Time
$startTime = Get-Date

While (((Get-Content C:\ConfigMgrSetup.log) -like "*Completed Configuration Manager Server Setup*").count -eq 0){
    Write-Host -foregroundcolor Green Waiting MECM Installation...
    Start-Sleep -Seconds 120
    $endTime = Get-Date
    Write-Host -foregroundcolor Green "Started: $startTime"
    Write-Host -foregroundcolor Green "MECM Installation has been Running For:"
    $endTime-$startTime | Format-Table -Property Days, Hours, Minutes
    }

$endTime = Get-Date
Write-Host -foregroundcolor Green "Started: $startTime"
Write-Host -foregroundcolor Green "Ended: $endTime" 
Write-Host -foregroundcolor Green "Total MECM INSTALL Time:"
# $endTime-$startTime
$endTime-$startTime | Format-Table -Property Days, Hours, Minutes

# Wait until the MECM installation is completed before continuing the PS script.
# Wait-Job -Name "MECMINSTALL" -ErrorAction SilentlyContinue

# ******* THIS COMMAND REQUIRES A SERVER REBOOT ******



###################################################################################################
### Configure SQL 2019 Reporting Service (SSRS) *** ***
# Refer to the Build DOC to install the SQL Server Reporting Services
# The doc will cover install the SQL Server Reporting Services, configure it, and set the Reporting service account to an AD account.
# Run this on the MECM server (XXX-SRV-52)

# Configure SQL Reporting Service (SSRS)
#

<#
#>
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

$configset

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


# ******* REBOOT SERVER HERE ****** 

# Start-Sleep 240

###################################################################################################
Stop-Transcript


