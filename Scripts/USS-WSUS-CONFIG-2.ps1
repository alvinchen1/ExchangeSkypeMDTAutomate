<#
NAME
    WSUS-CONFIG-2.ps1

SYNOPSIS
    Completes WSUS installation and configuration

SYNTAX
    .\$ScriptName
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
$SCCMCONTENT = ($WS | ? {($_.Role -eq "WSUSCDP")}).Name
$MECMSRV = ($WS | ? {($_.Role -eq "MECM")}).Name
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value
$NETACCT = "SVC-CM-NAA"
$SCCMFOLDER = "D:\SCCMSHARE"
$WSUS_CONT_DRV = "E:\WSUS"

# =============================================================================
# MAIN ROUTINE
# =============================================================================

# Check to see if Dependent Server have finish building.
# Wait for MECM computer object in AD. Needed to set folder permissions below.
$FileName = "$RootDir\LOGS\$MECMSRV-READY.txt"

If (!(Test-Path $FileName)) {
    
    do {
    Write-Host -foregroundcolor Yellow "MECM Server Still Building...Sleeping for 20 Seconds..."
    Start-Sleep 20
    } until (Test-Path $FileName)
} Write-Host -foregroundcolor green "MECM Server Ready...Continuing Process this Script..."

# Copy WSUS/MECMSHARE folder to local drive
Write-Host -foregroundcolor green "Copying WSUS/SCCMShare folders to D:\ and E:\"
Copy-Item C:\WSUS_STAGING\WSUSImports -Destination D:\ -Recurse
Copy-Item $InstallShare\SCCMShare -Destination D:\ -Recurse

# Finish WSUS installation and configuation
Write-Host -foregroundcolor green "Configuring WSUS..."
& ‘C:\Program Files\Update Services\Tools\WsusUtil.exe’ postinstall content_dir=$WSUS_CONT_DRV

Write-Host -foregroundcolor green "Sleep for 30 Seconds..."
Start-Sleep -s 30

Write-Host -foregroundcolor green "Set WSUS Application Pool Maximum Private memory (4GB)..."
Set-WebConfiguration "/system.applicationHost/applicationPools/add[@name='WsusPool']/recycling/periodicRestart/@privateMemory" -Value 4000000

Write-Host -foregroundcolor green "Copying WSUSContent folders to E:\WSUS\WSUSContent"
Copy-Item $InstallShare\WsusContent\* -Destination E:\WSUS\WsusContent -Recurse

# Create the MECM Share Folders
Write-Host -foregroundcolor green "Creating the MECM SHARE folder..."

Get-Acl $SCCMFOLDER | Format-List

$acl = Get-Acl $SCCMFOLDER
$acl.SetAccessRuleProtection($True, $False)

# Applied to This Folder, Subfolders and Files
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the $NETACCT permissions to the SCCM folders.
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$NETACCT","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SCCM Content server ($SCCMCONTENT) computer account permissions to the SCCM folders.
# This is done to grant the SCCM Content server access to the SCCMshare if it is remote.
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$SCCMCONTENT`$","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Applied to This Folder, Subfolders and Files
# This group is used to grant the SCCM site server ($MECMSRV) computer account permissions to the SCCM folders.
# This is done to grant the SCCM site server access to the SCCMshare if it is remote.
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$MECMSRV`$","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Applied to This Folder, Subfolders and Files
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("System","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Apply the permision to the folder
Set-Acl $SCCMFOLDER $acl

# Share the folder... 
Write-Host -foregroundcolor green "Share MECM Folders..."
$FullAccessAccts = (“Administrators”,”$NETACCT”,"$SCCMCONTENT`$","$MECMSRV`$")
New-SMBShare –Name “SCCMSHARE” –Path “$SCCMFOLDER” –FullAccess $FullAccessAccts

# Install Visual C++ Redistributable for Visual Studio 2019 (x64)
C:\WSUS_STAGING\SQLCMD\VC_redist.x64.exe /passive /norestart
Start-Sleep -Seconds 15

# Install Microsoft ODBC Driver <17> for SQL Server
$argumentList = @(
  '/i'
  '"{0}"' -f "C:\WSUS_STAGING\SQLCMD\msodbcsql.msi"
  '/passive'
  '/norestart'
  'IACCEPTMSODBCSQLLICENSETERMS=YES'
  )

$startArgs = @{
  "FilePath" = "msiexec.exe"
  "ArgumentList" = $argumentList
  "Wait" = $true
}
Start-Process @startArgs

# Install Microsoft Command Line Utilies <15> for SQL Server
$argumentList = @(
  '/i'
  '"{0}"' -f "C:\WSUS_STAGING\SQLCMD\MsSqlCmdLnUtils.msi"
  '/passive'
  '/norestart'
  'IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES'
)

$startArgs = @{
  "FilePath" = "msiexec.exe"
  "ArgumentList" = $argumentList
  "Wait" = $true
}
Start-Process @startArgs

# Add Windows Defender exclusions for WSUS
Write-Host -foregroundcolor green "Adding Windows Defender exclusions for WSUS..."
Add-MpPreference -ExclusionPath "C:\WSUSMaint"
Add-MpPreference -ExclusionPath "C:\WSUSScripts"
Add-MpPreference -ExclusionPath "C:\WSUS_STAGING"
Add-MpPreference -ExclusionPath "$WSUS_CONT_DRV"
Add-MpPreference -ExclusionPath "D:\WSUSImports"
Add-MpPreference -ExclusionPath "D:\WSUSExports"
Add-MpPreference -ExclusionPath "C:\Windows\SoftwareDistribution\DataStore"
Add-MpPreference -ExclusionPath "C:\Windows\SoftwareDistribution\Download"
Add-MpPreference -ExclusionPath "C:\Windows\WID\Data"
Add-MpPreference -ExclusionExtension ".XML.GZ"
Add-MpPreference -ExclusionExtension ".CAB"
Add-MpPreference -ExclusionProcess "C:\Program Files\Update Services\Tools\WsusUtil.exe"
Add-MpPreference -ExclusionProcess "C:\Program Files\Update Services\Services\WsusService.exe"

Stop-Transcript
