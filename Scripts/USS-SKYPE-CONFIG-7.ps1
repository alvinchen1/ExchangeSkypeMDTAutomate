<#
NAME
    SKYPE-CONFIG-7.ps1

SYNOPSIS
    Upgrades SQL Express 2016 to 2019 and applies latest SQL CU in support of SfB
    (requires reboot after each SQL instance)

    Imports Skype GPO and moves Skype for Business server to OU to receive new policies

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
$SQLServer2019Path = "$InstallShare\SQLServer2019"
$SQLServer2019CU = "$InstallShare\SQLServer2019\CU"
$SQLServer2019CUVer = "15.0.4249.2" # Patched SQL version with CU; see https://support.microsoft.com/help/4518398
$GPOZipFileSkype = "$InstallShare\Import-GPOs\Skype.zip"
$LocalDir = "C:\temp\Skype\$DTG"
 
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

Function Upgrade-SQLInstance ($SQLInstance)
{
    Write-Verbose "----- Entering Upgrade-SQLInstance ($SQLInstance) function -----"
    
    $SQLVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$SQLInstance\MSSQLServer\CurrentVersion").CurrentVersion
    If (!($SQLVersion))  {Throw "Unable to determine SQL CurrentVersion for $SQLInstance"}
    If ($SQLVersion -lt "$SQLServer2019CUVer") # SQL Server 2019 RTM
    {
        If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}
        Write-Host "Upgrading SQL instance $SQLInstance to SQL Server 2019" -Foregroundcolor Green
        Test-FilePath ("$SQLServer2019Path\Express\SETUP.EXE")
        Stop-CsWindowsService
        $service = Get-Service | Where-Object {$_.Name -eq "w3svc"}
        If ($service.Status -eq "Running") {Stop-Service w3svc}
 
        $FilePath = "$SQLServer2019Path\Express\SETUP.EXE"
        $Args = @(
        "/QS"
        "/IACCEPTSQLSERVERLICENSETERMS"
        "/ERRORREPORTING=0"
        "/ACTION=Upgrade"
        "/INSTANCENAME=`"$SQLInstance`""
        "/UPDATEENABLED=True"
        "/UpdateSource=`"$SQLServer2019Path`""
        )
        Start-Process -FilePath $FilePath -ArgumentList $Args -Wait
    }
    Else
    {
        Write-Host "SQL instance $SQLInstance already upgraded to SQL Server 2019" -Foregroundcolor Green
    }
}

Function Update-SQLInstance ($SQLInstance)
{
    Write-Verbose "----- Entering Update-SQLInstance ($SQLInstance) function -----"

    $SQLPatchLevel = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL15.$SQLInstance\Setup" -ErrorAction "SilentlyContinue").PatchLevel
    If (!($SQLPatchLevel))  {Throw "Unable to determine SQL PatchLevel for $SQLInstance"}
    If ($SQLPatchLevel -lt "$SQLServer2019CUVer") 
    {
        If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}
        Write-Host "Applying CU ($SQLServer2019CUVer) to SQL Server 2019 instance $SQLInstance" -Foregroundcolor Green
        Test-FilePath ("$SQLServer2019CU\SETUP.EXE")
        Stop-CsWindowsService
        $service = Get-Service | Where-Object {$_.Name -eq "w3svc"}
        If ($service.Status -eq "Running") {Stop-Service w3svc}
        Start-Process "$SQLServer2019CU\SETUP.EXE" -Wait -Argumentlist " /QS /ACTION=Patch /IACCEPTSQLSERVERLICENSETERMS /ALLINSTANCES /ERRORREPORTING=0"
    }
    Else
    {
        Write-Host "SQL Server 2019 CU ($SQLServer2019CUVer) already applied to instance $SQLInstance" -Foregroundcolor Green
    }
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

Function Set-SfB-ADGPO
{
    Write-Verbose "----- Entering Set-SfB-ADGPO function -----"
    
    Import-Module ActiveDirectory
    $DomainDN = (Get-ADRootDSE).defaultNamingContext

    # Create OU
    If (!(Test-ADObject ("OU=SBS,OU=T0-Servers,OU=Tier 0,OU=Admin,$DomainDN"))) 
    {New-ADOrganizationalUnit -Name "SBS" -Path "OU=T0-Servers,OU=Tier 0,OU=Admin,$DomainDN"}

    # Import GPO(s)
    Test-FilePath ($GPOZipFileSkype)
    Expand-Archive -LiteralPath $GPOZipFileSkype -DestinationPath $LocalDir -Force
    cd $LocalDir

    # Get SID from local SQLServer2005SQLBrowserUser group and update "SVR-WS2019-Skype" GPO
    $SID = (Get-LocalGroup "SQLServer2005SQLBrowserUser`$$env:COMPUTERNAME").SID.Value

$GPOContent = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeImpersonatePrivilege = *S-1-5-6,*S-1-5-20,*S-1-5-19,*S-1-5-32-568,*S-1-5-32-544
SeIncreaseQuotaPrivilege = *S-1-5-80-222769447-1394508743-2213623259-1325592828-254710710,*S-1-5-80-190842187-2267349914-839701133-1290966990-2809265229,*S-1-5-80-1094019117-3566251947-3097930021-2852158916-3731536285,*S-1-5-80-3666644418-3269667695-1811689446-1428244707-3445174170,*S-1-5-80-738439556-2051660123-3810543246-728388836-3128272706,*S-1-5-80-1672378860-2536812654-1211888354-1565925247-2214056979,*S-1-5-20,*S-1-5-19,*S-1-5-82-3006700770-424185619-1745488364-794895919-4004696415,*S-1-5-82-1036420768-1044797643-1061213386-2937092688-4282445334,*S-1-5-82-3876422241-1344743610-1729199087-774402673-2621913236,*S-1-5-82-271721585-897601226-2024613209-625570482-296978595,*S-1-5-82-4068219030-1673637257-3279585211-533386110-4122969689,*S-1-5-82-3682073875-1643277370-2842298652-3532359455-2406259117,*S-1-5-32-544
SeChangeNotifyPrivilege = *S-1-5-32-545,*S-1-5-80-222769447-1394508743-2213623259-1325592828-254710710,*S-1-5-80-190842187-2267349914-839701133-1290966990-2809265229,*S-1-5-80-1094019117-3566251947-3097930021-2852158916-3731536285,*S-1-5-80-3666644418-3269667695-1811689446-1428244707-3445174170,*S-1-5-80-738439556-2051660123-3810543246-728388836-3128272706,*S-1-5-80-1672378860-2536812654-1211888354-1565925247-2214056979,*S-1-5-20,*S-1-5-19,*S-1-1-0,*S-1-5-32-551,*S-1-5-32-544
SeAuditPrivilege = *S-1-5-20,*S-1-5-19,*S-1-5-82-3006700770-424185619-1745488364-794895919-4004696415,*S-1-5-82-1036420768-1044797643-1061213386-2937092688-4282445334,*S-1-5-82-3876422241-1344743610-1729199087-774402673-2621913236,*S-1-5-82-271721585-897601226-2024613209-625570482-296978595,*S-1-5-82-4068219030-1673637257-3279585211-533386110-4122969689,*S-1-5-82-3682073875-1643277370-2842298652-3532359455-2406259117
SeBatchLogonRight = *S-1-5-32-559,*S-1-5-32-568,*S-1-5-32-551,*S-1-5-32-544
SeServiceLogonRight = *S-1-5-80-4154698541-1986608954-4250640213-2620366321-3369633232,*S-1-5-80-3860463631-3632126151-2031222817-650323509-2027299658,*S-1-5-80-2403812259-25050481-1088410715-3235804346-1779410794,*S-1-5-80-222769447-1394508743-2213623259-1325592828-254710710,*S-1-5-80-190842187-2267349914-839701133-1290966990-2809265229,*S-1-5-80-1094019117-3566251947-3097930021-2852158916-3731536285,*S-1-5-80-3666644418-3269667695-1811689446-1428244707-3445174170,*S-1-5-80-738439556-2051660123-3810543246-728388836-3128272706,*S-1-5-80-1672378860-2536812654-1211888354-1565925247-2214056979,*S-1-5-80-0,*S-1-5-20,*S-1-5-82-3006700770-424185619-1745488364-794895919-4004696415,*S-1-5-82-1036420768-1044797643-1061213386-2937092688-4282445334,*S-1-5-82-3876422241-1344743610-1729199087-774402673-2621913236,*S-1-5-82-271721585-897601226-2024613209-625570482-296978595,*S-1-5-82-4068219030-1673637257-3279585211-533386110-4122969689,*S-1-5-82-3682073875-1643277370-2842298652-3532359455-2406259117,*$SID
SeAssignPrimaryTokenPrivilege = *S-1-5-80-222769447-1394508743-2213623259-1325592828-254710710,*S-1-5-80-190842187-2267349914-839701133-1290966990-2809265229,*S-1-5-80-1094019117-3566251947-3097930021-2852158916-3731536285,*S-1-5-80-3666644418-3269667695-1811689446-1428244707-3445174170,*S-1-5-80-738439556-2051660123-3810543246-728388836-3128272706,*S-1-5-80-1672378860-2536812654-1211888354-1565925247-2214056979,*S-1-5-20,*S-1-5-19,*S-1-5-82-3006700770-424185619-1745488364-794895919-4004696415,*S-1-5-82-1036420768-1044797643-1061213386-2937092688-4282445334,*S-1-5-82-3876422241-1344743610-1729199087-774402673-2621913236,*S-1-5-82-271721585-897601226-2024613209-625570482-296978595,*S-1-5-82-4068219030-1673637257-3279585211-533386110-4122969689,*S-1-5-82-3682073875-1643277370-2842298652-3532359455-2406259117
"@

    Test-FilePath ("$LocalDir\GPO\{AF834434-1F64-4539-A4D7-E5356ADAB8B7}\DomainSysvol\GPO\Machine\microsoft\windows nt\SecEdit\GptTmpl.inf")
    $GPOContent | Out-File "$LocalDir\GPO\{AF834434-1F64-4539-A4D7-E5356ADAB8B7}\DomainSysvol\GPO\Machine\microsoft\windows nt\SecEdit\GptTmpl.inf" -Force

    Import-Module GroupPolicy
    $GPOs = @('SVR-WS2019-Skype')
    foreach ($GPO in $GPOs) 
    {
        Write-Host "Importing $GPO" -Foregroundcolor Green
        Import-GPO -BackupGpoName $GPO -TargetName $GPO -Path "$LocalDir\GPO" -CreateIfNeeded
    }

    # Link GPO(s)
    New-GPLink -Name "SVR-WS2019-Skype" -Target "OU=SBS,OU=T0-Servers,OU=Tier 0,OU=Admin,$DomainDN" -LinkEnabled Yes -Order 1 -ErrorAction SilentlyContinue

    # Move server to OU to apply GPOs upon restart
    Write-Host "Moving $env:COMPUTERNAME to new OU to receive Group Policy"  -Foregroundcolor Green
    Get-ADComputer $env:COMPUTERNAME | Move-ADObject -TargetPath "OU=SBS,OU=T0-Servers,OU=Tier 0,OU=Admin,$DomainDN" -Verbose
    (Get-ADComputer $env:COMPUTERNAME).DistinguishedName
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Check pending reboot
If (Check-PendingReboot) {Write-Host "WARNING: Pending reboot on $env:COMPUTERNAME" -ForegroundColor Yellow}

# Upgrade SQL Server 2016 instances to SQL Server 2019 and apply latest CU to instance (reboots required)
#Upgrade-SQLInstance ("RTC")
#Upgrade-SQLInstance ("RTCLOCAL")
Upgrade-SQLInstance ("LYNCLOCAL")

# Import GPO and place server in production OU
Set-SfB-ADGPO

Stop-Transcript
