<#
NAME
    Install-CoreFeatures.ps1

SYNOPSIS
    Installs core features on Windows Servers supporting the solution

SYNTAX
    .\$ScriptName
 #>

Start-Transcript

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
Install-WindowsFeature -Name ADCS-Cert-Authority,RSAT-AD-PowerShell,BitLocker,SNMP-Service,SNMP-WMI-Provider -IncludeManagementTools

# Restart-Computer >> MDT restart in Task Sequence

Stop-Transcript