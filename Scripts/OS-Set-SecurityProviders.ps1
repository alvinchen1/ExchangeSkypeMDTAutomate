<# ############################################################################

TITLE:       Set-SecurityProviders.ps1

USAGE:       Elevated PowerShell prompt

REFERENCES:  https://docs.microsoft.com/en-us/system-center/scom/plan-security-tls12-config?view=sc-om-2019#configure-windows-to-only-use-tls-12-protocol
             https://docs.microsoft.com/en-US/troubleshoot/windows-server/windows-security/restrict-cryptographic-algorithms-protocols-schannel
             https://www.nartac.com/Products/IISCrypto/Download

############################################################################ #>

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
$WS = ($XML.Component | ? {($_.Name -eq "WindowsServer")}).Settings.Configuration
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value
$PkgDir = "$InstallShare\Applications\Set-SecurityProviders"

# =============================================================================
# MAIN ROUTINE
# =============================================================================

& REG.exe IMPORT "$PkgDir\PCI32.reg"

Stop-Transcript
