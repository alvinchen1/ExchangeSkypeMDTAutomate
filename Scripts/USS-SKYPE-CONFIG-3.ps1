<#
NAME
    SKYPE-CONFIG-3.ps1

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

Function Install-SfB-Core
{
    Write-Verbose "----- Entering Install-SfB-Core function -----"
    
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

Function Set-SfB-ADSchema
{
    Write-Verbose "----- Entering Set-SfB-ADSchema function -----"
    
    Import-Module "C:\Program Files\Common Files\Skype for Business Server 2019\Modules\SkypeForBusiness\SkypeForBusiness.psd1"
    If (!(Test-ADObject ("CN=ms-RTC-SIP-SchemaVersion,CN=Schema,CN=Configuration,$LDAPDomain"))) 
    {
        Write-Host "Extending Active Directory Schema for Skype for Business 2019" -Foregroundcolor Green
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
            Write-Host "Active Directory Schema already extended for Skype for Business 2019." -ForegroundColor Green
        }
    }
}

Function Set-SfB-ADPrep
{
    Write-Verbose "----- Entering Set-SfB-ADPrep function -----"
    
    # Prepare Forest
    Import-Module "C:\Program Files\Common Files\Skype for Business Server 2019\Modules\SkypeForBusiness\SkypeForBusiness.psd1"
    $CSAdminsObj = Get-ADGroup -LDAPFilter "(SAMAccountName=CSAdministrator)"
    $BootStrapCore = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Core Components"}
    If ($BootStrapCore.count -eq '1') 
    {
        If ($CSAdminsObj -eq $null)
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

    # Prepare Domain
    $ADDomainPrep = Get-CsAdDomain 
    If ($ADDomainPrep -ne "LC_DOMAINSETTINGS_STATE_READY")
    { 
        Write-Host "Preparing Domain for Skype For Business." -ForegroundColor Green
        Enable-CSAdDomain -Verbose -Confirm:$false
        Write-Host "Domain prepared for Skype For Business." -ForegroundColor Green
    }
    Else 
    {
        Write-Host "Domain already prepared for Skype For Business." -Foregroundcolor Green
    }

    # Add DOMAIN\Administrator to CSAdministrators and RTCUniversalServerAdmins
    $CSAdminsObj = Get-ADGroup -LDAPFilter "(SAMAccountName=CSAdministrator)"
    If ($CSAdminsObj -ne $null) 
    {
        $CSAdminsMembers = Get-ADGroupMember -Identity CSAdministrator -Recursive | Select -ExpandProperty Name
        If ($CSAdminsMembers -contains $env:UserName)
        {
            Write-Host $env:UserName "already in CSAdministrator Group." -Foregroundcolor Green
        }
        Else
        {
            Add-AdGroupMember -identity "CSAdministrator" -members $env:UserName
            Write-Host $env:UserName "added to CSAdministrator.  Logoff and Logon may be needed before proceeding." -Foregroundcolor Red
        }
    }

    $RTCUniversalServerAdminsobj = Get-ADGroup -LDAPFilter "(SAMAccountName=RTCUniversalServerAdmins)"
    If ($RTCUniversalServerAdminsobj -ne $null) 
    {
        $RTCUniversalServerAdminsMembers = Get-ADGroupMember -Identity RTCUniversalServerAdmins -Recursive | Select -ExpandProperty Name
        If ($RTCUniversalServerAdminsMembers -contains $env:UserName)
        {
            Write-Host $env:UserName "already in RTCUniversalServerAdmins Group." -Foregroundcolor Green
        }
        Else 
        {
            Add-AdGroupMember -identity "RTCUniversalServerAdmins" -members $env:UserName
            Write-Host $env:UserName "added to RTCUniversalServerAdmins.  Logoff and Logon may be needed before proceeding." -Foregroundcolor Red
        }
    }
}

Function Install-SfB-AdminTools
{
    Write-Verbose "----- Entering Install-SfB-AdminTools function -----"
    
    $AdminTools  = Get-Package | where {$_.Name -like "Skype for Business Server 2019, Administrative Tools*"}
    If ($AdminTools.count -eq '1') 
    {
        Write-Host "Skype for Business Server 2019, Administrative Tools already installed." -ForegroundColor Green
    }
    Else 
    {
        Write-Host "Installing Skype for Business Server 2019, Administrative Tools" -Foregroundcolor Green
        Test-FilePath ("$Skype4BusinessPath\Setup\amd64\Setup\admintools.msi")
        Start-Process msiexec.exe -Wait -Argumentlist " /i $Skype4BusinessPath\Setup\amd64\Setup\admintools.msi /qn"
    }
}

Function New-SfB-CSShare
{
    Write-Verbose "----- Entering New-SfB-CSShare function -----"
    
    If ((Get-FileShare | ? {$_.Name -eq $CSShareName}).count -eq "0") 
    {
        Write-Host "Creating $CSShareName" -Foregroundcolor Green
        If (!(Test-Path $CSShareNamePath)) {New-Item $CSShareNamePath -ItemType Directory}
        New-SMBShare -Name $CSShareName -Path $CSShareNamePath -FullAccess "Authenticated Users" -CachingMode None
    }
    Else {
         Write-Host "$CSShareName already exists." -ForegroundColor Green
    }
}

Function New-SfB-RTC
{
    Write-Verbose "----- Entering New-SfB-RTC function -----"
    
    If ((Get-Service | Where {$_.Name -eq 'MSSQL$RTC'}).count -eq 0) 
    {
        Write-Host "Installing Central Management Store (CMS) - SQL Express Instance" -ForegroundColor Green
        Test-FilePath ("C:\Program Files\Skype for Business Server 2019\Deployment\Bootstrapper.exe")
        Test-FilePath ("$Skype4BusinessPath\Setup\amd64") 
        $FilePath = "C:\Program Files\Skype for Business Server 2019\Deployment\Bootstrapper.exe"
        $Args = @(
        '/BootstrapSQLExpress'
        '/SourceDirectory'
        "$Skype4BusinessPath\Setup\amd64"
        )
        Start-Process -FilePath $FilePath -ArgumentList $Args -Wait        
        
        If (!(Get-NetFirewallRule -DisplayName 'SQL RTC Access' -ErrorAction SilentlyContinue))
        {
            New-NetFirewallRule -DisplayName 'SQL RTC Access' -Action Allow -Direction Inbound -Protocol Any -Name 'SQL RTC Access' -Profile Any -Program "C:\Program Files\Microsoft SQL Server\MSSQL13.RTC\MSSQL\Binn\sqlservr.exe" | Out-Null

        }
        If (!(Get-NetFirewallRule -DisplayName 'SQL Browser' -ErrorAction SilentlyContinue))
        {
            New-NetFirewallRule -DisplayName 'SQL Browser' -Action Allow -Direction Inbound -Protocol UDP -LocalPort 1434 -Name 'SQL Browser' -Profile Any | Out-Null
        }
    }
    Else 
    {
        Write-Host "Central Management Store (CMS) - SQL Express Instance already exists." -ForegroundColor Green
    }
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Check pending reboot
If (Check-PendingReboot) {Throw "Exiting due to pending reboot on $env:COMPUTERNAME"}

Install-SfB-Core
Set-SfB-ADSchema
Set-SfB-ADPrep
Install-SfB-AdminTools
New-SfB-CSShare
New-SfB-RTC

If ((Get-ADGroup "Web Servers").ObjectClass -eq "group") 
{
    Write-Host "Adding $env:COMPUTERNAME$ computer account to Web Servers security group" -ForegroundColor Green
    Get-ADGroup "Web Servers" | Add-AdGroupMember -Members $env:COMPUTERNAME$
}

Stop-Transcript
