<#
NAME
    Set-LAPS-Logging.ps1

SYNOPSIS
    Configures logging for Local Administrator Password Solution (LAPS) on a managed machine.
    Events are written to the "Application" Event Log on a managed machine with an Event Source of "AdmPwd".

SYNTAX
    .\$ScriptName
#>


# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path –Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path –Parent

<#
Configure log level:
    0 = [Default] Silent mode where only errors are logged.
    1 = Log errors and warnings.
    2 = Verbose mode where everything is logged. Be sure to revert this setting after troubleshooting is complete!
#>
$LogLevel = 0

# =============================================================================
# FUNCTIONS
# =============================================================================

Function Check-Role()
{
   param (
    [Parameter(Mandatory=$false, HelpMessage = "Enter what role you want to check for. Default check is for 'Administrator'")]
    [System.Security.Principal.WindowsBuiltInRole]$role = [System.Security.Principal.WindowsBuiltInRole]::Administrator
   )

    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object 'System.Security.Principal.WindowsPrincipal' $windowsIdentity

    return $windowsPrincipal.IsInRole($role)
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Ensure script is run elevated
If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}

$AdmPwdReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions\{D76B9641-3288-4f75-942D-087DE603E3EA}"
If (!($AdmPwdReg)) {Throw "Unable to locate LAPS Client Side Extension"}

If (!($AdmPwdReg.ExtensionDebugLevel))
{
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions\{D76B9641-3288-4f75-942D-087DE603E3EA}" -Name "ExtensionDebugLevel" -PropertyType Dword -Value $LogLevel -Force
    Write-Host "CSE logging level is now set to $LogLevel"
}
Else
{
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions\{D76B9641-3288-4f75-942D-087DE603E3EA}" -Name "ExtensionDebugLevel" -Type Dword -Value $LogLevel -Force
    Write-Host "CSE logging level has been updated to $LogLevel"
}


Write-Host "`n$ScriptName Complete.`n" -ForeGround "yellow" -back "black"
