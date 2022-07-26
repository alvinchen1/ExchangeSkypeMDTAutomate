$Windows2019SourcePath = "\\oct-adc-001\share\WindowsServer2019\sources"
$ExchangePrereqPath = "\\oct-adc-001\share\ExchangePrereqs"
$ExchangePath = "\\oct-adc-001\share\Exchange"
$TargetExchangePath = 'E:\PExchange\V15'
$ExchangeOrgName = "OTC"
###------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
###
###    Alvin Chen
###    Install Exchange 2019
###    Prerequisites, a file share, AD joined, IP addressed, Schema Admins, Enterprise Admins, Exchange Drive
###
###    Prerequisties as of 7/15/2022
###         https://docs.microsoft.com/en-us/exchange/plan-and-deploy/prerequisites?view=exchserver-2019
###         Download .net Framework 4.8:  
###                  https://go.microsoft.com/fwlink/?linkid=2088631
###             See   https://support.microsoft.com/en-us/topic/microsoft-net-framework-4-8-offline-installer-for-windows-9d23f658-3b97-68ab-d013-aa3c3e7495e0
###         Download Visual C++ Redistributable for Visual Studio 2012 Update 4: 
###                  https://www.microsoft.com/download/details.aspx?id=30679
###         Download Visual C++ Redistributable Package for Visual Studio 2013
###                  https://aka.ms/highdpimfc2013x64enu 2013, rename to 
###             See https://support.microsoft.com/en-us/topic/update-for-
###         Download URL Rewrite Module 2.1: 
###                  https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi
###             See   https://www.iis.net/downloads/microsoft/url-rewrite#additionalDownloads
###         Download Unified Communications Managed API 4.0 Runtime 
###                  https://www.microsoft.com/en-us/download/details.aspx?id=34992 visual-c-2013-redistributable-package-d8ccd6a5-4e26-c290-517b-8da6cfdf4f10
###         Download Latest Exchange 
###             See   https://docs.microsoft.com/en-us/exchange/new-features/build-numbers-and-release-dates?view=exchserver-2019#exchange-server-2019
###                   Place in Updates Folder under Exchange Server Source
###------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

###write-host "Installing .net Framework 4.8" -Foregroundcolor green
###start-process $ExchangePrereqPath"\ndp48-x86-x64-allos-enu" -Wait -Argumentlist "/q /norestart"
###write-host "Installing Visual C++ Redistributable for Visual Studio 2012 Update 4" -Foregroundcolor green
###start-process $ExchangePrereqPath"\vcredist_x64.exe" -Wait -Argumentlist "-silent"
###write-host "Installing Visual C++ Redistributable Package for Visual Studio 2013" -Foregroundcolor green
###start-process $ExchangePrereqPath"\vcredist_x64_2013.exe" -Wait -Argumentlist "-silent"
###write-host "Installing URL Rewrite Module 2.1" -Foregroundcolor green
###start-process msiexec.exe -Wait -Argumentlist " /i $ExchangePrereqPath\rewrite_amd64_en-US.msi /qn"
write-host "Installing Unified Communications Managed API 4.0 Runtime" -Foregroundcolor green
start-process $ExchangePrereqPath"\UcmaRuntimeSetup.exe" -Wait -Argumentlist "/passive /norestart"
###write-host "Installing Windows Server Prerequisites" -Foregroundcolor green
###Install-WindowsFeature Server-Media-Foundation, NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation, RSAT-ADDS -Source $Windows2019SourcePath
###write-host "Extending Active Directory Schema" -Foregroundcolor green
###start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /ps"
###write-host "Pausing for Schema replication" -Foregroundcolor green
###Start-Sleep -seconds 300
###write-host "Preparing Active Directory" -Foregroundcolor green
###start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /PrepareAD /OrganizationName:$ExchangeOrgName"
###write-host "Pausing for Active Directory replication" -Foregroundcolor green
###Start-Sleep -seconds 300
write-host "Installing Exchange 2019" -Foregroundcolor green
start-process $ExchangePath"\setup.exe" -Wait -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /TargetDir:$TargetExchangePath /CustomerFeedbackEnabled:False /Mode:install /Roles:mb"
Get-Command Exsetup.exe | ForEach {$_.FileVersionInfo}