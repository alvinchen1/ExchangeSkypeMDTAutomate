###################################################################################################
###################################### USS-MECM-POST-1.ps1 ####################################
###################################################################################################
# 
## Use the commands below to Configure SCCM CB 2103 Post steps.
##
## Before running this script, ensure that the SCCM CB install has completed.
# Before running this script, set the "Client Setting Name" (xxx) of the policy. 
# Before running the "DEPLOY CUSTOM $domainName CLIENT SETTINGS" define a Collection Name.

### This script is designed to work with MDT.
### MDT will handle Reboots.
#
### This script will:
#
# -Create the New Client settings
# -Import/Load the MECM/Configuration Manager Module
# -Create MECM Collections folders based on entries below.
# -CREATE MECM "DEPLOYMENT" COLLECTIONS based on entries in the COLLLIST.csv file.

# -CREATE CUSTOM CLIENT SETTINGS
# -DEPLOY CUSTOM CLIENT SETTINGS
# -Set MECM Administrative Users and Groups - Access to MECM Console
#
# This script prerequisite is an existing MECM Site.
#
#
###################################################################################################
### Start-Transcript
# Stop-Transcript
# Overwrite existing log.
Start-Transcript -Path C:\Windows\Temp\MDT-PS-LOGS\USS-MECM-POST-1.log
Start-Transcript -Path \\DEV-MDT-01\DEPLOYMENTSHARE$\LOGS\$env:COMPUTERNAME\USS-MECM-POST-1.log


###################################################################################################
# MODIFY/ENTER These Values Before Running This Script.

### ENTER MECM Variables.
$domainName = “USS”

### ENTER the name of the Collection to deploy the Custom Client Setting policy
$POLCOLL = "ALL-SP1-DESKTOPS"

### ENTER Collection CSV File Name
# Ensure that this file is in the MDT D:\STAGING\SCCM_STAGING\SCRIPTS\CREATE_COLLECTIONS folder before running script.
$CSVFileName = "SP1-COLLLIST.CSV"

### ENTER MECM STAGING FOLDER
$MDTSTAGING = "\\DEV-MDT-01\STAGING"

###################################################################################################
### Import/Load the Configuration Manager Module 
#
# Import the Configuration Manager module by using the Import-Module cmdlet. 
# For MECM 2111
# Starting in version 2111, when you install the Configuration Manager console, the path to the module is now 
# added to the system environment variable, PSModulePath. For more information, see about_PSModulePath. 
# With this change, you can import the module just by its Name: "Import-Module ConfigurationManager"
#
# https://docs.microsoft.com/en-us/powershell/sccm/overview?view=sccm-ps
#
# For MECM 2103:
# ---Default Location - C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\ConfigurationManager.psd1
# ---D:\MECM\AdminConsole\bin
# Change to the module's directory
# Set-Location 'C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin'
# Set-Location 'D:\MECM\AdminConsole\bin'
# Import-Module .\ConfigurationManager.psd1
#
# Set-Location "$env:SMS_ADMIN_UI_PATH\..\"
# Import-Module D:\MECM\AdminConsole\bin\ConfigurationManager.psd1
#
# Switch the path to the Configuration Manager site.
# Set-Location SP1:
# Set-location $SiteCode":"
#
### Load Configuration Manager PowerShell Module...Set SiteCode Variable
Write-Host -foregroundcolor green "Load PowerShell Module"
import-module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')
$Drive = Get-PSDrive -PSProvider CMSite
CD "$($Drive):"

### Set SiteCode
# Confirm you can run MECM commands...if info is returned running this command, you are ready to run MECM commands.
# Get the SCCM Site information
# Get-CMSite
$SiteCode = Get-PSDrive -PSProvider CMSITE

###################################################################################################
### CREATE MECM " DEPLOYMENT" COLLECTIONS From CSV file
# Purpose : This script create SCCM Collections folders, collections and maintenance windows. 
# This script will:
# -Create SCCM folders based on entries below.
# -Create SCCM collections based on entries in the COLLLIST.csv file.
# -If the collection has a maintenance it should have an entry defined in the "MW" column in the COLLLIST.csv file.
# -If it is a normal collection no entry will be under the "MW" column in the colllist.csv file.
#
# Before running this script:
# -Update the default SCCM folder below
# -Update the COLLLIST.CSV file
# 
# Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
#
# *** NOTE THESE DEPLOYMENT COLLECTIONS NEED TO RUN BEFORE CREATING THE "CREATE CUSTOM CLIENT SETTINGS" ***
# *** SOME OF THE THE "CREATE CUSTOM CLIENT SETTINGS" DEDEND ON DEPLOYMENT COLLECTIONS ***
#
### Create Default MECM Collection Folders
Write-Host -foregroundcolor green "Creating Collection Root Folders"

new-item -Name 'DEPLOYMENTS' -Path $($SiteCode.Name+":\DeviceCollection")
new-item -Name 'ADMIN' -Path $($SiteCode.Name+":\DeviceCollection\DEPLOYMENTS")
new-item -Name 'MW' -Path $($SiteCode.Name+":\DeviceCollection\DEPLOYMENTS")
new-item -Name 'OSD' -Path $($SiteCode.Name+":\DeviceCollection\DEPLOYMENTS")
new-item -Name 'PATCHES' -Path $($SiteCode.Name+":\DeviceCollection\DEPLOYMENTS")
new-item -Name 'SOFTWARE' -Path $($SiteCode.Name+":\DeviceCollection\DEPLOYMENTS")

### Define possible limiting collections
$LimitingCollectionAll = "All Systems"
$LimitingCollectionAllUnknown = "All Unknown Computers"

### Refresh Schedule
$Schedule = New-CMSchedule –RecurInterval Days –RecurCount 7

### Read entries from COLLLIST.csv file and create collectons.
# The colllist.csv file is delimited by a ";"
# For a tab-separated file, you can read the file like below:
# Import-Csv -Path File1.csv -Delimiter "`t"
#
# Import-Csv C:\SCCM_STAGING\SCRIPTS\CREATE_COLLECTIONS\$SiteCode.Name+-COLLLIST.csv -Delimiter ';' |
# Import-Csv C:\SCCM_STAGING\SCRIPTS\CREATE_COLLECTIONS\"+$SiteCode.Name+"1-COLLLIST.csv -Delimiter ';' |
# Import-Csv C:\SCCM_STAGING\SCRIPTS\CREATE_COLLECTIONS\$CSVFileName -Delimiter ';' |
Write-Host -foregroundcolor green "Creating Collections..."
Import-Csv -Path FileSystem::$MDTSTAGING\SCRIPTS\$CSVFileName -Delimiter ';' |
    ForEach-Object {
        # Read entries from COLLLIST.csv file.
        $Collection = $_.Collection
        $Comment = $_.Comment
        $CollFolder = $_.CollFolder
        $LimitColl = $_.LimitColl
        $Query = $_."Query"
        $MW = $_.MW

# If $Query is empty,this means it doesn't have a SQL query in the COLLLIST.csv
If (!$Query) {
            ### Create collections
            New-CMDeviceCollection -Name $Collection -Comment $Comment -LimitingCollectionName $LimitColl -RefreshSchedule $Schedule -RefreshType 2 | Out-Null
            Write-host *** Collection $Collection created ***

            ### Move the collection to the right folder
            $FolderPath = $SiteCode.Name+":$COLLFOLDER"
            Move-CMObject -FolderPath $FolderPath -InputObject (Get-CMDeviceCollection -Name $Collection)

            ### Create Maintenance Windows for collections
            # Maintenance Windows Collections will not have queries
            # If there is an entry in the "MW" column of colllist.csv file, create colleciton maintenance window.
            # If there is an entry in the "MW" Column run the following:
            If ($MW) {
                $MWCollection = Get-CMDeviceCollection -Name $Collection
                New-CMMaintenanceWindow -CollectionID $MWCollection.CollectionID -ApplyTo SoftwareUpdatesOnly -Schedule $(Invoke-Expression $MW) -Name $Collection | Out-Null
                     }
            #If there is no entry in the "MW" column then:
            }
 Else
                {
                New-CMDeviceCollection -Name $Collection -Comment $Comment -LimitingCollectionName $LimitColl -RefreshSchedule $Schedule -RefreshType 2 | Out-Null
                Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection -QueryExpression $Query -RuleName $Collection
                
                Write-host *** Collection $Collection created ***
                $FolderPath = $SiteCode.Name+":$COLLFOLDER"
                Move-CMObject -FolderPath $FolderPath -InputObject (Get-CMDeviceCollection -Name $Collection)
                }
            }


###################################################################################################
### CREATE CUSTOM CLIENT SETTINGS 
#
# First create the New Client settings 
# https://dexterposh.blogspot.com/2014/03/powershell-sccm-2012-r2-adding-roles.html
# https://docs.microsoft.com/en-us/powershell/module/configurationmanager/set-cmclientsetting?view=sccm-ps
Write-Host -foregroundcolor green "Creating Custom Client Settings"

New-CMClientSetting -Name "$domainName Client Device Settings" -Type Device -Description "$domainName Custom Client settings"

### Configure "Client Policy",  
# Set-CMClientSetting -Name "$domainName Client Device Settings" -ClientPolicy -PolicyPollingInterval 60 -EnableUserPolicyPolling $true -EnableUserPolicyOnInternet $false
Set-CmClientSettingClientPolicy -Name "$domainName Client Device Settings" -EnableUserPolicy $true -PolicyPollingMins 60 -EnableUserPolicyOnTS $true -EnableUserPolicyOnInternet $false

### Configure the "Computer Agent"
# Set-CMClientSetting -Name "$domainName Client Device Settings" -ComputerAgent -PowerShellExecutionPolicy Bypass -InitialReminderHoursInterval 48 -InterimReminderHoursInterval 4 -FinalReminderMinutesInterval 15  -PortalUrl "http://$domainName.LOCAL/CMApplicationCatalog/" -AddPortalToTrustedSiteList $true -AllowPortalToHaveElevatedTrust $true -BrandingTitle "$domainName IT Services" -InstallRestriction AllUsers -DisplayNewProgramNotification $true
# Set-CMClientSetting -Name "$domainName Client Device Settings" -ComputerAgent -PowerShellExecutionPolicy Bypass -InitialReminderHoursInterval 48 -InterimReminderHoursInterval 4 -FinalReminderMinutesInterval 15  -PortalUrl "" -AddPortalToTrustedSiteList $true -AllowPortalToHaveElevatedTrust $true -BrandingTitle "$domainName IT Services" -InstallRestriction AllUsers -DisplayNewProgramNotification $true -DisplayNewProgramNotification $true
Set-CmClientSettingComputerAgent -Name "$domainName Client Device Settings" -PowerShellExecutionPolicy Bypass -InitialReminderHr 48 -InterimReminderHr 4 -FinalReminderMins 15 -PortalUrl "" -AddPortalToTrustedSiteList $true -AllowPortalToHaveElevatedTrust $true -BrandingTitle "$domainName IT Services" -InstallRestriction AllUsers 

### Configure "Computer Restart"
# Set-CMClientSetting -Name "$domainName Client Device Settings" -ComputerRestart -RebootLogoffNotificationCountdownMins 480 -RebootLogoffNotificationFinalWindowMins 15 -ReplaceToastNotificationWithDialog $False
Set-CMClientSettingComputerRestart -Name "$domainName Client Device Settings" -CountdownMins 480 -FinalWindowMins 15 -ReplaceToastNotificationWithDialog $False

### Configure "Hardware Inventory"
# $HWInvSched = New-CMSchedule -RecurCount 1 -RecurInterval Days
# Set-CMClientSetting -Name "$domainName Client Device Settings" -HardwareInventory -Enable $True -Schedule $HWInvSched
# Set-CMClientSettingHardwareInventory -Name "John Client Device Settings" -HardwareInventory -Enable $True -Schedule $HWInvSched -MaxRandomDelayMins 240 -MaxThirdPartyMifSize 250
# $HWInvSched = New-CMSchedule -RecurCount 7 -RecurInterval Days
# Set-CMClientSetting -Name "$domainName Client Device Settings" -HardwareInventorySettings -Schedule $HWInvSched
$HWInvSched = New-CMSchedule -RecurCount 7 -RecurInterval Days
Set-CMClientSettingHardwareInventory -Name "$domainName Client Device Settings" -Enable $true -Schedule $HWInvSched

### Configure "Software Center"
# Set-CMClientSettingSoftwareCenter -Name "$domainName Client Device Settings" -EnableCustomize $true -CompanyName "$domainName IT"
Set-CMClientSettingSoftwareCenter -Name "$domainName Client Device Settings" -EnableCustomize $true -CompanyName "$domainName IT"

### Configure "Software Inventory"
# Hashtables are just fancy pairs of keys and values. PowerShell makes them really easy to do:
# Example: $ht = @{ "key1" = "value1"; "key2" = "value2" }
# In this case you’ll want to create an array of hashtables (one for each file you want to inventory):
# $inv1 = @{"FileName"="*.exe"; ExcludeEncryptedAndCompressedFiles=$true; ExcludeWindirAndSubfolders=$true; Subdirectories=$true; Path="C:\"}
# $inv2 = @{"FileName"="*.com"; ExcludeEncryptedAndCompressedFiles=$true; ExcludeWindirAndSubfolders=$true; Subdirectories=$true; Path="C:\"}
# $inv1 = @{"FileName"="*.exe"; Exclude=$true; ExcludeWindirAndSubfolders=$true; Subdirectories=$true; Path="C:\"}
# $inv2 = @{"FileName"="*.com"; Exclude=$true; ExcludeWindirAndSubfolders=$true; Subdirectories=$true; Path="C:\"}
# $rules = ($inv1, $inv2)
# $SWInvSched = New-CMSchedule -RecurCount 8 -RecurInterval Days
# Set-CMClientSettingSoftwareInventory -Name "$domainName Client Device Settings" -Enable $true -FileName *.EXE -FileDisplayName *.EXE -FileInventoriedName *.EXE -ReportOption FullDetail -Schedule $SWInvSched
# Set-CMClientSettingSoftwareInventory -Name "$domainName Client Device Settings" -Enable $true -ReportOption FullDetail -AddInventoryFileType $rules -Schedule $SWInvSched
$inv1 = @{"FileName"="*.exe"; Exclude=$true; ExcludeWindirAndSubfolders=$true; Subdirectories=$true; Path="C:\"}
$inv2 = @{"FileName"="*.com"; Exclude=$true; ExcludeWindirAndSubfolders=$true; Subdirectories=$true; Path="C:\"}
$rules = ($inv1, $inv2)
$SWInvSched = New-CMSchedule -RecurCount 8 -RecurInterval Days
Set-CMClientSettingSoftwareInventory -Name "$domainName Client Device Settings" -Enable $true -ReportOption FullDetail -AddInventoryFileType $rules -Schedule $SWInvSched

### Configure "Software Updates"
# This command will:
# -Enable Software Update in the Client Settings
# -Install other software deployment within 30 days to the update being deployed.
# -Enable Office 365 client management
# $HWInvSched = New-CMSchedule -RecurCount 7 -RecurInterval Days
# Set-CMClientSetting -Name "$domainName Client Device Settings" -SoftwareUpdate -Enable $True
$SSchedule = New-CMSchedule -RecurCount 7 -RecurInterval Days
$DESchedule = New-CMSchedule -RecurCount 1 -RecurInterval Days
Set-CMClientSettingSoftwareUpdate -Name "$domainName Client Device Settings" -Enable $True -EnforceMandatory $true -TimeUnit Days -BatchingTimeout 30 -Office365ManagementType $true -ScanSchedule $SSchedule -DeploymentEvaluationSchedule $DESchedule 

###################################################################################################
### DEPLOY CUSTOM CLIENT SETTINGS 
# Run the command below to deploy the new Client Setting to a specfic Collection ###########
# The client setting policy will be applied to the XXXX collection.########################
Write-Host -foregroundcolor green "Deploying Custom Client Settings"
# Start-CMClientSettingDeployment -ClientSettingName "$domainName Client Device Settings" -CollectionName "ALL-SP1-DESKTOPS"
Start-CMClientSettingDeployment -ClientSettingName "$domainName Client Device Settings" -CollectionName $POLCOLL



###################################################################################################
### Set MECM Administrative Users and Groups - Access to MECM Console
Write-Host -foregroundcolor green "Set MECM Administrative Users and Groups - Access to MECM Console"
New-CMAdministrativeUser -Name "$domainName\Domain Admins" -RoleName "Full Administrator"
New-CMAdministrativeUser -Name "$domainName\MECM-EndPointMgr" -RoleName "Endpoint Protection Manager"
New-CMAdministrativeUser -Name "$domainName\MECM-OperationAdmin" -RoleName "Operations Administrator"
New-CMAdministrativeUser -Name "$domainName\MECM-SoftwareUpdateMgr" -RoleName "Software Update Manager"

###################################################################################################
###*** CREATE REPORTING COLLECTIONS **** 
Write-Host -foregroundcolor green "CREATING REPORTING COLLECTIONSe"
### Error Handling and output
Clear-Host
$ErrorActionPreference= 'SilentlyContinue'

### Create Default Folder 
$CollectionFolder = @{Name ="REPORTING"; ObjectType =5000; ParentContainerNodeId =0}
Set-WmiInstance -Namespace "root\sms\site_$($SiteCode.Name)" -Class "SMS_ObjectContainerNode" -Arguments $CollectionFolder -ComputerName $SiteCode.Root
$FolderPath =($SiteCode.Name +":\DeviceCollection\" + $CollectionFolder.Name)

### Set Default limiting collections
$LimitingCollection ="All Systems"

### Refresh Schedule
$Schedule =New-CMSchedule –RecurInterval Days –RecurCount 7

### Find Existing Collections
$ExistingCollections = Get-CMDeviceCollection -Name "* | *" | Select-Object CollectionID, Name

### List of Collections Query
$DummyObject = New-Object -TypeName PSObject 
$Collections = @()

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients | All"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Client = 1"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices detected by SCCM"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients | No"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Client = 0 OR SMS_R_System.Client is NULL"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices without SCCM client installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | Not Latest (1910)"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion not like '5.00.8913.100%'"}},@{L="LimitingCollection"
; E={"Clients | All"}},@{L="Comment"
; E={"All devices without SCCM client version 1910"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1511"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.8325.1000'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1511 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1602"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.8355.1000'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1602 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1606"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion like '5.00.8412.100%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1606 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1610"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion like '5.00.8458.100%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1610 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1702"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion like '5.00.8498.100%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1702 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1706"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion like '5.00.8540.100%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1706 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1710"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion like '5.00.8577.100%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1710 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Hardware Inventory | Clients Not Reporting since 14 Days"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where ResourceId in (select SMS_R_System.ResourceID from SMS_R_System inner join SMS_G_System_WORKSTATION_STATUS on SMS_G_System_WORKSTATION_STATUS.ResourceID = SMS_R_System.ResourceId where DATEDIFF(dd,SMS_G_System_WORKSTATION_STATUS.LastHardwareScan,GetDate())
 > 14)"}},@{L="LimitingCollection" 
; E={"Clients | All"}},@{L="Comment"
; E={"All devices with SCCM client that have not communicated with hardware inventory over 14 days"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Laptops | All"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_SYSTEM_ENCLOSURE on SMS_G_System_SYSTEM_ENCLOSURE.ResourceID = SMS_R_System.ResourceId where SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes in ('8', '9', '10', '11', '12', '14', '18', '21')"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All laptops"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Laptops | Dell"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Manufacturer like '%Dell%'"}},@{L="LimitingCollection"
; E={"Laptops | All"}},@{L="Comment"
; E={"All laptops with Dell manufacturer"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Laptops | HP"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Manufacturer like '%HP%' or SMS_G_System_COMPUTER_SYSTEM.Manufacturer like '%Hewlett-Packard%'"}},@{L="LimitingCollection"
; E={"Laptops | All"}},@{L="Comment"
; E={"All laptops with HP manufacturer"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Laptops | Lenovo"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Manufacturer like '%Lenovo%'"}},@{L="LimitingCollection"
; E={"Laptops | All"}},@{L="Comment"
; E={"All laptops with Lenovo manufacturer"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | All"}},@{L="Query"
; E={"select * from SMS_R_System where SMS_R_System.ClientType = 3"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Mobile Devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Android"}},@{L="Query"
; E={"SELECT SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client FROM SMS_R_System
 INNER JOIN SMS_G_System_DEVICE_OSINFORMATION ON SMS_G_System_DEVICE_OSINFORMATION.ResourceID = SMS_R_System.ResourceId WHERE SMS_G_System_DEVICE_OSINFORMATION.Platform like 'Android%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Android mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | iPhone"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_DEVICE_COMPUTERSYSTEM on SMS_G_System_DEVICE_COMPUTERSYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_DEVICE_COMPUTERSYSTEM.DeviceModel like '%Iphone%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All iPhone mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | iPad"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_DEVICE_COMPUTERSYSTEM on SMS_G_System_DEVICE_COMPUTERSYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_DEVICE_COMPUTERSYSTEM.DeviceModel like '%Ipad%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All iPad mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Windows Phone 8"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_DEVICE_OSINFORMATION on SMS_G_System_DEVICE_OSINFORMATION.ResourceID = SMS_R_System.ResourceId where SMS_G_System_DEVICE_OSINFORMATION.Platform = 'Windows Phone' and SMS_G_System_DEVICE_OSINFORMATION.Version like '8.0%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Windows 8 mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Windows Phone 8.1"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_DEVICE_OSINFORMATION on SMS_G_System_DEVICE_OSINFORMATION.ResourceID = SMS_R_System.ResourceId where SMS_G_System_DEVICE_OSINFORMATION.Platform = 'Windows Phone' and SMS_G_System_DEVICE_OSINFORMATION.Version like '8.1%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Windows 8.1 mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Windows Phone 10"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_DEVICE_OSINFORMATION on SMS_G_System_DEVICE_OSINFORMATION.ResourceID = SMS_R_System.ResourceId where SMS_G_System_DEVICE_OSINFORMATION.Platform = 'Windows Phone' and SMS_G_System_DEVICE_OSINFORMATION.Version like '10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Windows Phone 10"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Microsoft Surface"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Model like '%Surface%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Windows RT mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Microsoft Surface 3"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Model = 'Surface Pro 3' OR SMS_G_System_COMPUTER_SYSTEM.Model = 'Surface 3'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Microsoft Surface 3"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Microsoft Surface 4"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Model = 'Surface Pro 4'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Microsoft Surface 4"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Others | Linux Devices"}},@{L="Query"
; E={"select * from SMS_R_System where SMS_R_System.ClientEdition = 13"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with Linux"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Others | MAC OSX Devices"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 WHERE OperatingSystemNameandVersion LIKE 'Apple Mac OS X%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All workstations with MAC OSX"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"SCCM | Console"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_ADD_REMOVE_PROGRAMS on SMS_G_System_ADD_REMOVE_PROGRAMS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_ADD_REMOVE_PROGRAMS.DisplayName like '%Configuration Manager Console%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM console installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"SCCM | Site Servers"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 where SMS_R_System.SystemRoles = 'SMS Site Server'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All systems that is SCCM site server"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"SCCM | Site Systems"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 where SMS_R_System.SystemRoles = 'SMS Site System' or SMS_R_System.ResourceNames in (Select ServerName FROM SMS_DistributionPointInfo)"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems that is SCCM site system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"SCCM | Distribution Points"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 where SMS_R_System.ResourceNames in (Select ServerName FROM SMS_DistributionPointInfo)"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems that is SCCM distribution point"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | All"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Server%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All servers"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Active"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where SMS_G_System_CH_ClientSummary.ClientActiveStatus = 1 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All servers with active state"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Physical"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ResourceId not in (select SMS_R_SYSTEM.ResourceID from SMS_R_System inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_R_System.IsVirtualMachine = 'True') and SMS_R_System.OperatingSystemNameandVersion
 like 'Microsoft Windows NT%Server%'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All physical servers"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Virtual"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.IsVirtualMachine = 'True' and SMS_R_System.OperatingSystemNameandVersion like 'Microsoft Windows NT%Server%'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All virtual servers"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Windows 2012 and 2012 R2"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Server 6.2%' or OperatingSystemNameandVersion like '%Server 6.3%'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All servers with Windows 2012 or 2012 R2 operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Windows 2016"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId where OperatingSystemNameandVersion like '%Server 10%' and SMS_G_System_OPERATING_SYSTEM.BuildNumber = '14393'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All Servers with Windows 2016"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Windows 2019"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId where OperatingSystemNameandVersion like '%Server 10%' and SMS_G_System_OPERATING_SYSTEM.BuildNumber = '17763'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All Servers with Windows 2019"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Software Inventory | Clients Not Reporting since 30 Days"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where ResourceId in (select SMS_R_System.ResourceID from SMS_R_System inner join SMS_G_System_LastSoftwareScan on SMS_G_System_LastSoftwareScan.ResourceId = SMS_R_System.ResourceId where DATEDIFF(dd,SMS_G_System_LastSoftwareScan.LastScanDate,GetDate()) > 30)"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices with SCCM client that have not communicated with software inventory over 30 days"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Clients Active"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where SMS_G_System_CH_ClientSummary.ClientActiveStatus = 1 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0"}},@{L="LimitingCollection"
; E={"Clients | All"}},@{L="Comment"
; E={"All devices with SCCM client state active"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Clients Inactive"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where SMS_G_System_CH_ClientSummary.ClientActiveStatus = 0 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0"}},@{L="LimitingCollection"
; E={"Clients | All"}},@{L="Comment"
; E={"All devices with SCCM client state inactive"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Disabled"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.UserAccountControl ='4098'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with client state disabled"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Obsolete"}},@{L="Query"
; E={"select * from SMS_R_System where SMS_R_System.Obsolete = 1"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices with SCCM client state obsolete"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Systems | x86"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.SystemType = 'X86-based PC'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with 32-bit system type"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Systems | x64"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.SystemType = 'X64-based PC'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with 64-bit system type"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Systems | Created Since 24h"}},@{L="Query"
; E={"select SMS_R_System.Name, SMS_R_System.CreationDate FROM SMS_R_System WHERE DateDiff(dd,SMS_R_System.CreationDate, GetDate()) <= 1"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems created in the last 24 hours"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Windows Update Agent | Outdated Version Win7 RTM and Lower"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_WINDOWSUPDATEAGENTVERSION on SMS_G_System_WINDOWSUPDATEAGENTVERSION.ResourceID = SMS_R_System.ResourceId inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_WINDOWSUPDATEAGENTVERSION.Version
 < '7.6.7600.256' and SMS_G_System_OPERATING_SYSTEM.Version <= '6.1.7600'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All systems with windows update agent with outdated version Win7 RTM and lower"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Windows Update Agent | Outdated Version Win7 SP1 and Higher"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_WINDOWSUPDATEAGENTVERSION on SMS_G_System_WINDOWSUPDATEAGENTVERSION.ResourceID = SMS_R_System.ResourceId inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_WINDOWSUPDATEAGENTVERSION.Version
 < '7.6.7600.320' and SMS_G_System_OPERATING_SYSTEM.Version >= '6.1.7601'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All systems with windows update agent with outdated version Win7 SP1 and higher"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | All"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Workstation%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All workstations"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Active"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where (SMS_R_System.OperatingSystemNameandVersion like 'Microsoft Windows NT%Workstation%' or SMS_R_System.OperatingSystemNameandVersion = 'Windows 7 Entreprise 6.1') and SMS_G_System_CH_ClientSummary.ClientActiveStatus = 1 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All workstations with active state"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 8"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Workstation 6.2%'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All workstations with Windows 8 operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 8.1"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Workstation 6.3%'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All workstations with Windows 8.1 operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Workstation 10.0%'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1507"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Build = '10.0.10240'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1507"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1511"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Build = '10.0.10586'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1511"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1607"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Build = '10.0.14393'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1607"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1703"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Build = '10.0.15063'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1703"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1709"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Build = '10.0.16299'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1709"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Current Branch (CB)"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.OSBranch = '0'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 CB"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Current Branch for Business (CBB)"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.OSBranch = '1'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 CBB"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Long Term Servicing Branch (LTSB)"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.OSBranch = '2'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 LTSB"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Support State - Current"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 LEFT OUTER JOIN SMS_WindowsServicingStates ON SMS_WindowsServicingStates.Build = SMS_R_System.build01 AND SMS_WindowsServicingStates.branch = SMS_R_System.osbranch01 where SMS_WindowsServicingStates.State = '2'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"Windows 10 Support State - Current"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Support State - Expired Soon"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 LEFT OUTER JOIN SMS_WindowsServicingStates ON SMS_WindowsServicingStates.Build = SMS_R_System.build01 AND SMS_WindowsServicingStates.branch = SMS_R_System.osbranch01 where SMS_WindowsServicingStates.State = '3'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"Windows 10 Support State - Expired Soon"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Support State - Expired"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 LEFT OUTER JOIN SMS_WindowsServicingStates ON SMS_WindowsServicingStates.Build = SMS_R_System.build01 AND SMS_WindowsServicingStates.branch = SMS_R_System.osbranch01 where SMS_WindowsServicingStates.State = '4'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"Windows 10 Support State - Expired"}}

##Collection 77
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1802"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8634.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1802 installed"}}

##Collection 78
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1802"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.9029.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1802"}}

##Collection 79
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1803"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.9126.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1803"}}

##Collection 80
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1708"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.8431.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1708"}}

##Collection 81
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1705"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.8201.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1705"}}

##Collection 82
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Clients Online"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ResourceId in (select resourceid from SMS_CollectionMemberClientBaselineStatus where SMS_CollectionMemberClientBaselineStatus.CNIsOnline = 1)"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"System Health | Clients Online"}}

##Collection 83
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1803"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.17134'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Workstations | Windows 10 v1803"}}

##Collection 84
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Channel | Monthly"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Channel | Monthly"}}

##Collection 85
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Channel | Monthly (Targeted)"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Channel | Monthly (Targeted)"}}

##Collection 86
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Channel | Semi-Annual (Targeted)"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Channel | Semi-Annual (Targeted)"}}

##Collection 87
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Channel | Semi-Annual"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Channel | Semi-Annual"}}

##Collection 88
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1806"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8692.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1806 installed"}}

##Collection 89
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1810"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8740.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"; E={"All systems with SCCM client version 1810 installed"}}

##Collection 90
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1902"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8790.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"; E={"All systems with SCCM client version 1902 installed"}}

##Collection 91
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Duplicate Device Name"}},@{L="Query"
; E={"select R.ResourceID,R.ResourceType,R.Name,R.SMSUniqueIdentifier,R.ResourceDomainORWorkgroup,R.Client from SMS_R_System as r   full join SMS_R_System as s1 on s1.ResourceId = r.ResourceId   full join SMS_R_System as s2 on s2.Name = s1.Name   where s1.Name = s2.Name and s1.ResourceId != s2.ResourceId"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"; E={"All systems having a duplicate device record"}}

##Collection 92
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1906"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8853.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"; E={"All systems with SCCM client version 1906 installed"}}

##Collection 93
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1809"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.17763'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Workstations | Windows 10 v1809"}}

##Collection 94
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1903"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.18362'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Workstations | Windows 10 v1903"}}

##Collection 95
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1910"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8913.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"; E={"All systems with SCCM client version 1910 installed"}}

##Collection 96
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1808"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.10730.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1808"}}

##Collection 97
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1902"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.11328.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1902"}}

##Collection 98
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1908"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.11929.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1908"}}

##Collection 99
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1912"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.12325.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1912"}}

##Collection 100
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1909"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.18363'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Workstations | Windows 10 v1909"}}

#Check Existing Collections
$Overwrite = 1
$ErrorCount = 0
$ErrorHeader = "The script has already been run. The following collections already exist in your environment:`n`r"
$ErrorCollections = @()
$ErrorFooter = "Would you like to delete and recreate the collections above? (Default : No) "
$ExistingCollections | Sort-Object Name | ForEach-Object {If($Collections.Name -Contains $_.Name) {$ErrorCount +=1 ; $ErrorCollections += $_.Name}}

#Error
If ($ErrorCount -ge1) 
    {
    Write-Host $ErrorHeader $($ErrorCollections | ForEach-Object {(" " + $_ + "`n`r")}) $ErrorFooter -ForegroundColor Yellow -NoNewline
    $ConfirmOverwrite = Read-Host "[Y/N]"
    If ($ConfirmOverwrite -ne "Y") {$Overwrite =0}
    }

#Create Collection And Move the collection to the right folder
If ($Overwrite -eq1) {
$ErrorCount =0

ForEach ($Collection
In $($Collections | Sort-Object LimitingCollection -Descending))

{
If ($ErrorCollections -Contains $Collection.Name)
    {
    Get-CMDeviceCollection -Name $Collection.Name | Remove-CMDeviceCollection -Force
    Write-host *** Collection $Collection.Name removed and will be recreated ***
    }
}

ForEach ($Collection In $($Collections | Sort-Object LimitingCollection))
{

Try 
    {
    New-CMDeviceCollection -Name $Collection.Name -Comment $Collection.Comment -LimitingCollectionName $Collection.LimitingCollection -RefreshSchedule $Schedule -RefreshType 2 | Out-Null
    Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -QueryExpression $Collection.Query -RuleName $Collection.Name
    Write-host *** Collection $Collection.Name created ***
    }

Catch {
        Write-host "-----------------"
        Write-host -ForegroundColor Red ("There was an error creating the: " + $Collection.Name + " collection.")
        Write-host "-----------------"
        $ErrorCount += 1
        # Pause
}

Try {
        Move-CMObject -FolderPath $FolderPath -InputObject $(Get-CMDeviceCollection -Name $Collection.Name)
        Write-host *** Collection $Collection.Name moved to $CollectionFolder.Name folder***
    }

Catch {
        Write-host "-----------------"
        Write-host -ForegroundColor Red ("There was an error moving the: " + $Collection.Name +" collection to " + $CollectionFolder.Name +".")
        Write-host "-----------------"
        $ErrorCount += 1
        # Pause
      }

}

If ($ErrorCount -ge1) {

        Write-host "-----------------"
        Write-Host -ForegroundColor Red "The script execution completed, but with errors."
        Write-host "-----------------"
        # Pause
}

Else{
        Write-host "-----------------"
        Write-Host -ForegroundColor Green "Script execution completed without error. REPORTING Collections created sucessfully."
        Write-host "-----------------"
        # Pause
    }
}

Else {
        Write-host "-----------------"
        Write-host -ForegroundColor Red ("The following collections already exist in your environment:`n`r" + $($ErrorCollections | ForEach-Object {(" " +$_ + "`n`r")}) + "Please delete all collections manually or rename them before re-executing the script! You can also select Y to do it automaticaly")
        Write-host "-----------------"
        # Pause
}


###################################################################################################
Stop-Transcript