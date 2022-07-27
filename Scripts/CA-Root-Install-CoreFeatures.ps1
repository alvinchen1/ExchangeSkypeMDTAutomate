<#
NAME
    Install-CoreFeatures.ps1

SYNOPSIS
    Installs core features on Windows Servers supporting the solution

SYNTAX
    .\$ScriptName
 #>

Start-Transcript

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path –Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path –Parent
$RootDir = Split-Path $ScriptDir –Parent
$ConfigFile = "$RootDir\config.xml"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) 
{
    Write-Host "Missing configuration file $ConfigFile" -ForegroundColor Red
    Stop-Transcript
    Exit
}
$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$IssuingCA = ($PKI | ? {($_.Name -eq "IssuingCA")}).Value

# =============================================================================
# FUNCTIONS
# =============================================================================

Function Install-CoreComponents
{
    Write-Verbose "----- Entering Install-CoreComponents function -----"
    
    # Enable network file and print:
    Set-NetFirewallRule -DisplayGroup "File And Printer Sharing" -Enabled False -Profile Any 

    # Enable WinRM:
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/enable-psremoting?view=powershell-7.1
    Enable-PSRemoting -Force
    winrm quickconfig -Force
    
    # Disable MapsBroker service that is not needed
    Set-Service -Name "MapsBroker" -Status Stopped -StartupType Disabled
    #Get-Service MapsBroker | Select-Object -Property Name, StartType, Status
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

Install-CoreComponents
Install-WindowsFeature -Name BitLocker,SNMP-Service,SNMP-WMI-Provider,ADCS-Cert-Authority -IncludeManagementTools

# Enable WinRM from Issuing CA
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $IssuingCA -Concatenate -Force

# Restart-Computer >> MDT restart in Task Sequence

Stop-Transcript