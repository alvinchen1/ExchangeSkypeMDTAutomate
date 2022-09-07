<#
NAME
    Install-CoreFeatures.ps1

SYNOPSIS
    Installs core features on Windows Servers supporting the solution

SYNTAX
    .\$ScriptName -Server SERVERNAME
 #>

# Declare Variables
# -----------------------------------------------------------------------------
$ScriptName = Split-Path $MyInvocation.MyCommand.Path –Leaf
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path –Parent
$DTG = Get-Date -Format yyyyMMddTHHmm
$RootDir = Split-Path $ScriptDir –Parent
$ConfigFile = "$RootDir\config.xml"

Start-Transcript -Path "$RootDir\LOGS\$env:COMPUTERNAME\$ScriptName.log"
Start-Transcript -Path "$env:WINDIR\Temp\$env:COMPUTERNAME-$DTG-$ScriptName.log"

# Load variables from config.xml
If (!(Test-Path -Path $ConfigFile)) {Throw "ERROR: Unable to locate $ConfigFile Exiting..."} 
$XML = ([XML](Get-Content $ConfigFile)).get_DocumentElement()
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$Features = $WS | ? {($_.Type -eq "Features") -and ($_.Name -ne "")}
If ($Server.Length -eq 0) {$Server = $Env:COMPUTERNAME}

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

Function Check-Prereqs
{
    Write-Verbose "----- Entering Check-Prereqs function -----"
    
    # Ensure script is run elevated
    If (!(Check-Role)) {Throw "Script is NOT running elevated. Be sure the script runs under elevated conditions."}
    
    # Verify target server matches XML
    Write-Verbose "Verifying targeted server name matches XML configuration..."
    $TargetServer = $Features | ? {($_.Name -eq $Server)}
    Write-Verbose "TargetServer: $TargetServer"
    If (!($TargetServer))
    {
        Throw "Unable to continue, target server name does not match actual server name"
    }
}

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

Function Install-ServerFeatures
{
    Write-Verbose "----- Entering Install-Features function -----"
    
    $TargetServerFeatures = ($Features | ? {($_.Name -eq $Server)}).Value.Split(",")
    #Install-WindowsFeature -Name $TargetServerFeatures -Source $SxSStore -IncludeManagementTools
    Install-WindowsFeature -Name $TargetServerFeatures -IncludeManagementTools
}


# =============================================================================
# MAIN ROUTINE
# =============================================================================

Check-Prereqs
Install-CoreComponents
Install-ServerFeatures

#Restart-Computer

Stop-Transcript
