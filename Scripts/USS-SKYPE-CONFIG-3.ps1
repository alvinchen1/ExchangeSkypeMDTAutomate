<#
NAME
    USS-SKYPE-CONFIG-2.ps1

SYNOPSIS
    Installs Skype For Business in the AD domain

SYNTAX
    .\$ScriptName
 #>

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path -Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$DTG = Get-Date -Format yyyyMMddTHHmm
$RootDir = Split-Path $ScriptDir -Parent
$ConfigFile = "$RootDir\config.xml"

Start-Transcript -Path "$RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log"
Start-Transcript -Path "$env:WINDIR\Temp\$env:COMPUTERNAME-$DTG-$ScriptName.log"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) {Throw "ERROR: Unable to locate $ConfigFile Exiting..."}
$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value
$Skype4BusinessPath = "$InstallShare\SkypeForBusiness\OCS_Eval"
$SkypeForBusiness = ($XML.Component | ? {($_.Name -eq "SkypeForBusiness")}).Settings.Configuration
$CSShareName = ($SkypeForBusiness | ? {($_.Name -eq "CSShareName")}).Value
$CSShareNamePath = ($SkypeForBusiness | ? {($_.Name -eq "CSShareNamePath")}).Value

Import-Module ActiveDirectory
$LDAPDomain = (Get-ADRootDSE).defaultNamingContext
$DC = (Get-ADDomainController -Filter * | Select-Object Name | Sort-Object Name | Select-Object -First 1).Name

# =============================================================================
# FUNCTIONS
# =============================================================================

Function Test-FilePath ($File)
{
    If (!(Test-Path -Path $File)) {Throw "ERROR: Unable to locate $File"} 
}

Function Check-PendingReboot
{
    If (!(Get-Module -ListAvailable -Name PendingReboot)) 
    {
        Test-FilePath ("$InstallShare\Install-PendingReboot\PendingReboot")
        Copy-Item -Path "$InstallShare\Install-PendingReboot\PendingReboot" -Destination "C:\Program Files\WindowsPowerShell\Modules" -Recurse -Force
    }

    Import-Module PendingReboot
    [bool] (Test-PendingReboot -SkipConfigurationManagerClientCheck).IsRebootPending
}

Function Test-ADObject ($DN)
{
    Write-Host "Checking existence of $DN"
    Try 
    {
        Get-ADObject "$DN"
        Write-Host "True"
    }
    Catch 
    {
        $null
        Write-Host "False"
    }
}

Function Install-SfBCore
{
    Write-Verbose "----- Entering Install-SfBCore function -----"
    
    $BootStrapCore = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Core Components"}
    If ($BootStrapCore.count -eq '0') 
    {
        Write-Host "Installing Skype for Business Server Core" -Foregroundcolor Green
        Test-FilePath ("$Skype4BusinessPath\Setup\amd64\setup.exe")
        Start-Process "$Skype4BusinessPath\Setup\amd64\setup.exe" -Wait -Argumentlist "/bootstrapcore"
    }
    Else 
    {
        Write-Host "Skype for Business Server Core Components detected, skipping bootstrap core" -Foregroundcolor Green
    }
}

Function Set-SfBADSchema
{
    Write-Verbose "----- Entering Set-SfBADSchema function -----"
    
    If (!(Test-ADObject ("CN=ms-RTC-SIP-SchemaVersion,CN=Schema,CN=Configuration,$LDAPDomain"))) 
    {
        Write-Host "Extending Active Directory Schema for Skype for Business 2019" -Foregroundcolor Green
        Import-Module "C:\Program Files\Common Files\Skype for Business Server 2019\Modules\SkypeForBusiness\SkypeForBusiness.psd1"
        Install-CSAdServerSchema -Confirm:$false
        Write-Host "Pausing for Schema replication" -Foregroundcolor Green
        Start-Sleep -seconds 300
    }
    Else 
    {
        $ADSchemaLocation = 'AD:\CN=Schema,CN=Configuration,'+$LDAPDomain
        $SkypeSchemaLocation = 'AD:\CN=ms-RTC-SIP-SchemaVersion,CN=Schema,CN=Configuration,'+$LDAPDomain
        $ADSchema = Get-ItemProperty $SkypeSchemaLocation -Name rangeUpper
        If ($ADSchema.rangeUpper -lt '1149') 
        {
            Write-Host "Extending Active Directory Schema for Skype for Business 2019" -Foregroundcolor Green
            Install-CSAdServerSchema -Confirm:$false
            Write-Host "Pausing for Schema replication" -Foregroundcolor Green
            Start-Sleep -seconds 300
        }
        Else 
        {
            Write-Host "Active Directory Schema already extended for Skype for Business 2019" -ForegroundColor Green
        }
    }
}

Function Set-SfBADPrep
{
    Write-Verbose "----- Entering Set-SfBADPrep function -----"
    
    # Prepare AD Forest
    If (!(Test-ADObject ("CN=Microsoft Exchange System Objects,$LDAPDomain"))) 
    {
        write-host "Preparing Active Directory for Exchange 2019" -Foregroundcolor green
        Test-FilePath ("$ExchangePath\setup.exe")
        start-process "$ExchangePath\setup.exe" -Wait -NoNewWindow -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /PrepareAD /OrganizationName:$ExchangeOrgName"
        write-host "Pausing for Active Directory replication" -Foregroundcolor green
        Start-Sleep -seconds 300
    }
    Else
    {
        $ADSchemaLocation = 'AD:\CN=Schema,CN=Configuration,'+$LDAPDomain
        $ExchangeSchemaLocation = 'AD:\CN=ms-Exch-Schema-Version-Pt,CN=Schema,CN=Configuration,'+$LDAPDomain
        $ADSchema = Get-ItemProperty $ExchangeSchemaLocation -Name rangeUpper
        If ($ADSchema.rangeUpper -lt '16999') 
        {
            $ADExchangePrepped = "AD:\CN=Microsoft Exchange System Objects," + $LDAPDomain
            $ADExchangePreppedobjversion = Get-ItemProperty $ADExchangePrepped -Name objectVersion
            If ($ADExchangePreppedobjversion.objectVersion -gt '13230') {write-host "Active Directory already Prepared for Exchange 2019" -ForegroundColor Green}
            Else 
            {
                write-host "Preparing Active Directory for Exchange 2019" -Foregroundcolor green
                Test-FilePath ("$ExchangePath\setup.exe")
                start-process "$ExchangePath\setup.exe" -Wait -NoNewWindow -Argumentlist " /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /PrepareAD /OrganizationName:$ExchangeOrgName"
                write-host "Pausing for Active Directory replication" -Foregroundcolor green
                Start-Sleep -seconds 300
            }
        }
        If ($ADSchema.rangeUpper -ge '16999') {write-host "Active Directory already Prepared for Exchange 2019" -ForegroundColor Green}
    }
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Check pending reboot
If (Check-PendingReboot) {Throw "Exiting due to pending reboot on $env:COMPUTERNAME"}

Install-SfBCore
Set-SfBADSchema
Set-SfBADPrep


### Prepare Forest
###     TO DO: Check to see if Forest Already Prepared, Group CSAdministrators?
###            Check if member of Enteprise Admins
$CSAdminsobj = Get-ADGroup -LDAPFilter "(SAMAccountName=CSAdministrator)"
$BootStrapCore = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Core Components"}
If ($BootStrapCore.count -eq '1') 
{
    If ($CSAdminsobj -eq $null)
    {
        Write-Host "Preparing Forest for Skype for Business." -ForegroundColor Green
        Enable-CSAdForest  -Verbose -Confirm:$false
        Write-Host "Forest Prepared for Skype for Business." -ForegroundColor Green
        Write-Host "Pausing for Forest Prep replication." -Foregroundcolor Green
        Start-Sleep -seconds 300
    }
    Else 
    {
        Write-Host "Forest Already Prepared for Skype For Business 2019." -ForegroundColor Green
    }
}
Else 
{
    Write-Host "Skype for Business Server not detected, skipping forest prep." -Foregroundcolor Green
}

### Prepare Domain
$ADDomainPrep = get-csaddomain
If ($ADDomainPrep -ne "LC_DOMAINSETTINGS_STATE_READY") 
{ 
    write-host "Preparing Domain for Skype For Business." -ForegroundColor Green
    Enable-CSAdDomain -Verbose -Confirm:$false
    write-host "Domain Prepared for Skype For Business." -ForegroundColor Green
}
Else 
{
    write-host "Domain already prepared for Skype For Business." -Foregroundcolor green
}

###Add to  CSAdministrators and RTCUniversalServerAdmins
If ($CSAdminsobj -ne $null) 
{
    $CSAdminsMembers = Get-ADGroupMember -Identity CSAdministrator -Recursive | Select -ExpandProperty Name
    If ($CSAdminsMembers -contains $env:UserName)
    {
        write-host $env:UserName "already in CSAdministrator Group." -Foregroundcolor green
    }
    Else
    {
        Add-AdGroupMember -identity "CSAdministrator" -members $env:UserName
        write-host $env:UserName "added to CSAdministrator.  Logoff and Logon may be needed before proceeding." -Foregroundcolor red
    }
}


$RTCUniversalServerAdminsobj = Get-ADGroup -LDAPFilter "(SAMAccountName=RTCUniversalServerAdmins)"
IF ($RTCUniversalServerAdminsobj -ne $null) 
{
    $RTCUniversalServerAdminsMembers = Get-ADGroupMember -Identity RTCUniversalServerAdmins -Recursive | Select -ExpandProperty Name
    If ($RTCUniversalServerAdminsMembers -contains $env:UserName)
    {
        write-host $env:UserName "already in RTCUniversalServerAdmins Group." -Foregroundcolor green
    }
    Else 
    {
        Add-AdGroupMember -identity "RTCUniversalServerAdmins" -members $env:UserName
        write-host $env:UserName "added to RTCUniversalServerAdmins.  Logoff and Logon may be needed before proceeding." -Foregroundcolor red
    }
}

####Install Admin Tools
$AdminTools  = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Administrative Tools*"}
If ($AdminTools.count -eq '1') 
{
    write-host "Skype for Business Server 2019, Administrative Tools already installed." -ForegroundColor Green
}
Else 
{
    write-host "Installing Skype for Business Server 2019, Administrative Tools" -Foregroundcolor green
    Test-FilePath ("$Skype4BusinessPath\Setup\amd64\Setup\admintools.msi")
    start-process msiexec.exe -Wait -Argumentlist " /i $Skype4BusinessPath\Setup\amd64\Setup\admintools.msi /qn"
}

If ((get-fileshare | ? {$_.Name -eq $CSShareName}).count -eq "0") 
{
    write-host "Creating CSShare" -Foregroundcolor green
    [system.io.directory]::CreateDirectory($CSShareNamePath)
    New-SMBShare -Name $CSShareName -Path $CSShareNamePath -FullAccess "Authenticated Users" -CachingMode None
}
Else {
     Write-host "CSShare already exists." -ForegroundColor Green
}

If ((get-service | Where {$_.Name -eq 'MSSQL$RTC'}).count -eq 0) 
{
    Write-host "Creating CMS Database." -ForegroundColor Green
    Test-FilePath ("C:\Program Files\Skype for Business Server 2019\Deployment\Bootstrapper.exe")
    start-process "C:\Program Files\Skype for Business Server 2019\Deployment\Bootstrapper.exe" -Wait -Argumentlist " /BootstrapSQLExpress"
    start-process "netsh" -Wait -Argumentlist ' advfirewall firewall add rule name="SQL Browser" dir=in action=allow protocol=UDP localport=1434'
}
Else 
{
    Write-host "CMS Database already exists." -ForegroundColor Green
}

Write-host "Run Skype For Business Server Topology Builder, build new topology and successfully publish. See implementation guide for step-by-step instructions." -ForegroundColor Red

Stop-Transcript
