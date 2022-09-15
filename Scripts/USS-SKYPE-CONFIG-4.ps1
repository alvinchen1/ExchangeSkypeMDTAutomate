<#
NAME
    SKYPE-CONFIG-4.ps1

SYNOPSIS
    Configures Skype For Business

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
$DomainName = ($WS | ? {($_.Name -eq "DomainName")}).Value
$DomainDnsName = ($WS | ? {($_.Name -eq "DomainDnsName")}).Value
$InstallShare = ($WS | ? {($_.Name -eq "InstallShare")}).Value
$Skype4BusinessPath = "$InstallShare\SkypeForBusiness\OCS_Eval"
$SkypeForBusiness = ($XML.Component | ? {($_.Name -eq "SkypeForBusiness")}).Settings.Configuration
$CSShareName = ($SkypeForBusiness | ? {($_.Name -eq "CSShareName")}).Value
$CSShareNamePath = ($SkypeForBusiness | ? {($_.Name -eq "CSShareNamePath")}).Value
$CertTemplate = "$DomainName Web Server"

Import-Module ActiveDirectory
$DC = (Get-ADDomainController -Filter * | Select-Object Name | Sort-Object Name | Select-Object -First 1).Name
$SkypeFQDN = ([System.Net.DNS]::GetHostByName($env:computerName)).hostname

$TopoXML = @"
<Topology xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.Topology.2008" Signature="bd39024c-6b05-49e9-9388-d45e4f6d5ea5">
  <InternalDomains AllowAllDomains="false" DefaultDomain="$DomainDnsName">
    <InternalDomain Name="$DomainDnsName" Authoritative="false" AllowSubDomains="false" />
  </InternalDomains>
  <Sites>
    <CentralSite SiteId="1">
      <Name>$DomainName</Name>
      <Location />
    </CentralSite>
  </Sites>
  <Clusters>
    <Cluster RequiresReplication="true" RequiresSetup="true" Fqdn="$SkypeFQDN">
      <ClusterId SiteId="1" Number="1" />
      <Machine OrdinalInCluster="1" Fqdn="$SkypeFQDN" FaultDomain="$SkypeFQDN" UpgradeDomain="$SkypeFQDN">
        <NetInterface InterfaceSide="Primary" InterfaceNumber="1" IPAddress="0.0.0.0" />
        <NetInterface InterfaceSide="External" InterfaceNumber="1" IPAddress="0.0.0.0" />
      </Machine>
    </Cluster>
  </Clusters>
  <SqlInstances>
    <SqlInstance>
      <SqlInstanceId Name="rtc">
        <ClusterId SiteId="1" Number="1" />
      </SqlInstanceId>
    </SqlInstance>
  </SqlInstances>
  <Services>
    <Service RoleVersion="2" ServiceVersion="8">
      <ServiceId SiteId="1" RoleName="UserServices" Instance="1" />
      <DependsOn>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="UserStore" Instance="1" />
        </Dependency>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="FileStore" Instance="1" />
        </Dependency>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="ConfServices" Instance="1" />
        </Dependency>
      </DependsOn>
      <InstalledOn>
        <ClusterId SiteId="1" Number="1" />
      </InstalledOn>
      <Ports xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008">
        <Port Owner="urn:component:McuFactory" Usage="WebServer" InterfaceSide="Primary" InterfaceNumber="1" Port="444" Protocol="Mtls" UrlPath="/LiveServer/McuFactory/" AuthorizesRequests="false" />
        <Port Owner="urn:component:PresenceFocus" Usage="UserPinManagement" InterfaceSide="Primary" InterfaceNumber="1" Port="443" Protocol="Https" UrlPath="/LiveServer/UserPinManagement/" AuthorizesRequests="false" />
        <Port Owner="urn:component:McuFactory" Usage="WcfServer" InterfaceSide="Primary" InterfaceNumber="1" Port="9001" Protocol="Tcp" UrlPath="/LiveServer/ConfDirMgmt/" AuthorizesRequests="false" />
      </Ports>
    </Service>
    <Service RoleVersion="2" ServiceVersion="8" Type="Microsoft.Rtc.Management.Deploy.Internal.ServiceRoles.RegistrarService">
      <ServiceId SiteId="1" RoleName="Registrar" Instance="1" />
      <DependsOn>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="UserServices" Instance="1" />
        </Dependency>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="WebServices" Instance="1" />
        </Dependency>
      </DependsOn>
      <InstalledOn>
        <ClusterId SiteId="1" Number="1" />
      </InstalledOn>
      <Ports xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008">
        <Port Owner="urn:component:Registrar" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5061" Protocol="Mtls" UrlPath="/" AuthorizesRequests="true" GruuType="HomeServer" />
        <Port Owner="urn:component:Registrar" Usage="WebServer" InterfaceSide="Primary" InterfaceNumber="1" Port="444" Protocol="Mtls" UrlPath="/LiveServer/Focus/" AuthorizesRequests="false" />
        <Port Owner="urn:component:WinFab" Usage="WinFabFederation" InterfaceSide="Primary" InterfaceNumber="1" Port="5090" Protocol="Tcp" UrlPath="/" AuthorizesRequests="false" />
        <Port Owner="urn:component:WinFab" Usage="WinFabLeaseAgent" InterfaceSide="Primary" InterfaceNumber="1" Port="5091" Protocol="Tcp" UrlPath="/" AuthorizesRequests="false" />
        <Port Owner="urn:component:WinFab" Usage="WinFabClientConnection" InterfaceSide="Primary" InterfaceNumber="1" Port="5092" Protocol="Tcp" UrlPath="/" AuthorizesRequests="false" />
        <Port Owner="urn:component:WinFab" Usage="WinFabIPC" InterfaceSide="Primary" InterfaceNumber="1" Port="5093" Protocol="Tcp" UrlPath="/" AuthorizesRequests="false" />
        <Port Owner="urn:component:WinFab" Usage="WinFabReplication" InterfaceSide="Primary" InterfaceNumber="1" Port="5094" Protocol="Tcp" UrlPath="/" AuthorizesRequests="false" />
        <Port Owner="urn:component:QoE" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5061" Protocol="Mtls" UrlPath="/LiveServer/QoE/" AuthorizesRequests="true" GruuType="QoS" />
        <Port Owner="urn:component:Lyss" Usage="WcfMtls" InterfaceSide="Primary" InterfaceNumber="1" Port="5077" Protocol="Mtls" UrlPath="/" AuthorizesRequests="false" />
        <Port Owner="urn:component:XmppFederation" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5098" Protocol="Mtls" UrlPath="/" AuthorizesRequests="true" GruuType="XmppFederation" />
      </Ports>
      <RegistrarService xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008" IsDirector="false" IsPoolEnabledForSAOnEdge="false" />
    </Service>
    <Service RoleVersion="1" ServiceVersion="8">
      <ServiceId SiteId="1" RoleName="UserStore" Instance="1" />
      <DependsOn />
      <InstalledOn>
        <SqlInstanceId Name="rtc">
          <ClusterId SiteId="1" Number="1" />
        </SqlInstanceId>
      </InstalledOn>
      <Ports xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008" />
    </Service>
    <Service RoleVersion="1" ServiceVersion="8" Type="Microsoft.Rtc.Management.Deploy.Internal.ServiceRoles.FileStoreService">
      <ServiceId SiteId="1" RoleName="FileStore" Instance="1" />
      <DependsOn />
      <InstalledOn>
        <ClusterId SiteId="1" Number="1" />
      </InstalledOn>
      <Ports xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008" />
      <FileStoreService xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008" ShareName="$CSShareName" />
    </Service>
    <Service RoleVersion="1" ServiceVersion="8" Type="Microsoft.Rtc.Management.Deploy.Internal.ServiceRoles.WebService">
      <ServiceId SiteId="1" RoleName="WebServices" Instance="1" />
      <DependsOn>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="FileStore" Instance="1" />
        </Dependency>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="UserServices" Instance="1" />
        </Dependency>
      </DependsOn>
      <InstalledOn>
        <ClusterId SiteId="1" Number="1" />
      </InstalledOn>
      <Ports xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008">
        <Port Owner="urn:component:OCSWebSite" Usage="WebSite" InterfaceSide="External" InterfaceNumber="1" Port="8080" Protocol="Http" UrlPath="/" AuthorizesRequests="false" ConfiguredPort="80" />
        <Port Owner="urn:component:OCSWebSite" Usage="WebSite" InterfaceSide="External" InterfaceNumber="1" Port="4443" Protocol="Https" UrlPath="/" AuthorizesRequests="false" ConfiguredPort="443" />
        <Port Owner="urn:component:OCSWebSite" Usage="WebSite" InterfaceSide="Primary" InterfaceNumber="1" Port="80" Protocol="Http" UrlPath="/" AuthorizesRequests="false" />
        <Port Owner="urn:component:OCSWebSite" Usage="WebSite" InterfaceSide="Primary" InterfaceNumber="1" Port="443" Protocol="Https" UrlPath="/" AuthorizesRequests="false" />
        <Port Owner="urn:component:Reach" Usage="PsomServer" InterfaceSide="Primary" InterfaceNumber="1" Port="8060" Protocol="Mtls" UrlPath="/" AuthorizesRequests="false" />
        <Port Owner="urn:component:Reach" Usage="PsomServer" InterfaceSide="External" InterfaceNumber="1" Port="8061" Protocol="Mtls" UrlPath="/" AuthorizesRequests="false" />
        <Port Owner="urn:component:MediaComp" Usage="AppSharingCommunication" InterfaceSide="Primary" InterfaceNumber="1" Port="49152" Protocol="TcpOrUdp" UrlPath="/" AuthorizesRequests="false" Range="16383" />
        <Port Owner="urn:component:McxService" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5086" Protocol="Mtls" UrlPath="/" AuthorizesRequests="true" GruuType="McxInternal" />
        <Port Owner="urn:component:McxServiceExternal" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5087" Protocol="Mtls" UrlPath="/" AuthorizesRequests="true" GruuType="McxExternal" />
        <Port Owner="urn:component:PersistentChatWebManager" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5095" Protocol="Mtls" UrlPath="/" AuthorizesRequests="true" GruuType="PersistentChatRMWebInternal" />
        <Port Owner="urn:component:PersistentChatWebManagerExternal" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5096" Protocol="Mtls" UrlPath="/" AuthorizesRequests="true" GruuType="PersistentChatRMWebExternal" />
        <Port Owner="urn:component:UcwaService" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5088" Protocol="Mtls" UrlPath="/" AuthorizesRequests="true" GruuType="UcwaInternal" />
        <Port Owner="urn:component:UcwaServiceExternal" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5089" Protocol="Mtls" UrlPath="/" AuthorizesRequests="true" GruuType="UcwaExternal" />
        <Port Owner="urn:component:PlatformService" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="6008" Protocol="Mtls" UrlPath="/" AuthorizesRequests="true" GruuType="PlatformServiceInternal" />
      </Ports>
      <WebService xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008">
        <ExternalSettings Host="$SkypeFQDN">
          <OverrideUrls />
        </ExternalSettings>
        <WebComponents xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.WebServices.2011">
          <Component ComponentName="ABHandler" />
          <Component ComponentName="ABFiles" />
          <Component ComponentName="AutodiscoverService" />
          <Component ComponentName="CAHandler" />
          <Component ComponentName="CAHandlerAnon" />
          <Component ComponentName="CollabContent" />
          <Component ComponentName="Cscp" />
          <Component ComponentName="DataCollabWeb" />
          <Component ComponentName="DeviceUpdateDownload" />
          <Component ComponentName="DeviceUpdateStore" />
          <Component ComponentName="Dialin" />
          <Component ComponentName="DLExpansion" />
          <Component ComponentName="LIService" />
          <Component ComponentName="Lwa" />
          <Component ComponentName="McxService" />
          <Component ComponentName="Meet" />
          <Component ComponentName="OnlineAuth" />
          <Component ComponentName="PowerShell" />
          <Component ComponentName="Reach" />
          <Component ComponentName="RgsAgentService" />
          <Component ComponentName="StoreWeb" />
          <Component ComponentName="UcwaService" />
          <Component ComponentName="WebScheduler" />
          <Component ComponentName="WebTicket" />
          <Component ComponentName="PersistentChatWeb" />
          <Component ComponentName="PersistentChatWebManager" />
          <Component ComponentName="HybridConfigService" />
        </WebComponents>
        <UpaSeparator xmlns="urn:schema:Microsoft.Rtc.Management.BaseTypes.2008" />
      </WebService>
    </Service>
    <Service RoleVersion="1" ServiceVersion="8" Type="Microsoft.Rtc.Management.Deploy.Internal.ServiceRoles.ConfService">
      <ServiceId SiteId="1" RoleName="ConfServices" Instance="1" />
      <DependsOn>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="FileStore" Instance="1" />
        </Dependency>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="WebServices" Instance="1" />
        </Dependency>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="UserServices" Instance="1" />
        </Dependency>
      </DependsOn>
      <InstalledOn>
        <ClusterId SiteId="1" Number="1" />
      </InstalledOn>
      <Ports xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008">
        <Port Owner="urn:component:IMConf" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5062" Protocol="Mtls" UrlPath="/" AuthorizesRequests="false" GruuType="chat" />
        <Port Owner="urn:component:IMConf" Usage="WebServer" InterfaceSide="Primary" InterfaceNumber="1" Port="444" Protocol="Mtls" UrlPath="/LiveServer/IMMcu/" AuthorizesRequests="false" />
        <Port Owner="urn:component:DataConf" Usage="PsomClient" InterfaceSide="Primary" InterfaceNumber="1" Port="8057" Protocol="Tls" UrlPath="/" AuthorizesRequests="false" />
        <Port Owner="urn:component:AVConf" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5063" Protocol="Mtls" UrlPath="/" AuthorizesRequests="false" GruuType="audio-video" />
        <Port Owner="urn:component:AppSharingConf" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5065" Protocol="Mtls" UrlPath="/" AuthorizesRequests="false" GruuType="applicationsharing" />
        <Port Owner="urn:component:DataConf" Usage="WebServer" InterfaceSide="Primary" InterfaceNumber="1" Port="444" Protocol="Mtls" UrlPath="/LiveServer/DataMcu/" AuthorizesRequests="false" />
        <Port Owner="urn:component:AVConf" Usage="WebServer" InterfaceSide="Primary" InterfaceNumber="1" Port="444" Protocol="Mtls" UrlPath="/LiveServer/AVMcu/" AuthorizesRequests="false" />
        <Port Owner="urn:component:AppSharingConf" Usage="WebServer" InterfaceSide="Primary" InterfaceNumber="1" Port="444" Protocol="Mtls" UrlPath="/LiveServer/ASMcu/" AuthorizesRequests="false" />
        <Port Owner="urn:component:MediaComp" Usage="AudioCommunication" InterfaceSide="Primary" InterfaceNumber="1" Port="49152" Protocol="TcpOrUdp" UrlPath="/" AuthorizesRequests="false" Range="8348" />
        <Port Owner="urn:component:MediaComp" Usage="VideoCommunication" InterfaceSide="Primary" InterfaceNumber="1" Port="57501" Protocol="TcpOrUdp" UrlPath="/" AuthorizesRequests="false" Range="8034" />
        <Port Owner="urn:component:MediaComp" Usage="AppSharingCommunication" InterfaceSide="Primary" InterfaceNumber="1" Port="49152" Protocol="TcpOrUdp" UrlPath="/" AuthorizesRequests="false" Range="16383" />
      </Ports>
      <ConfService xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008">
        <MCUs>
          <MCU ComponentName="IMConf" Vendor="Microsoft" />
          <MCU ComponentName="DataConf" Vendor="Microsoft" MinSupportedMode="14" />
          <MCU ComponentName="AppSharingConf" Vendor="Microsoft" />
          <MCU ComponentName="AVConf" Vendor="Microsoft" />
        </MCUs>
      </ConfService>
    </Service>
    <Service RoleVersion="1" ServiceVersion="8" Type="Microsoft.Rtc.Management.Deploy.Internal.ServiceRoles.ApplicationServerService">
      <ServiceId SiteId="1" RoleName="ApplicationServer" Instance="1" />
      <DependsOn>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="Registrar" Instance="1" />
        </Dependency>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="FileStore" Instance="1" />
        </Dependency>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="ApplicationStore" Instance="1" />
        </Dependency>
      </DependsOn>
      <InstalledOn>
        <ClusterId SiteId="1" Number="1" />
      </InstalledOn>
      <Ports xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008">
        <Port Owner="urn:application:testbot" Usage="SipServer" InterfaceSide="Primary" InterfaceNumber="1" Port="5076" Protocol="Mtls" UrlPath="/" AuthorizesRequests="true" GruuType="Microsoft.Rtc.Applications.TestBot" />
        <Port Owner="urn:component:MediaComp" Usage="AudioCommunication" InterfaceSide="Primary" InterfaceNumber="1" Port="49152" Protocol="TcpOrUdp" UrlPath="/" AuthorizesRequests="false" Range="8348" />
        <Port Owner="urn:component:MediaComp" Usage="VideoCommunication" InterfaceSide="Primary" InterfaceNumber="1" Port="57501" Protocol="TcpOrUdp" UrlPath="/" AuthorizesRequests="false" Range="8034" />
        <Port Owner="urn:component:MediaComp" Usage="AppSharingCommunication" InterfaceSide="Primary" InterfaceNumber="1" Port="49152" Protocol="TcpOrUdp" UrlPath="/" AuthorizesRequests="false" Range="16383" />
      </Ports>
      <ApplicationServerService xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008" />
    </Service>
    <Service RoleVersion="1" ServiceVersion="8">
      <ServiceId SiteId="1" RoleName="ApplicationStore" Instance="1" />
      <DependsOn />
      <InstalledOn>
        <SqlInstanceId Name="rtc">
          <ClusterId SiteId="1" Number="1" />
        </SqlInstanceId>
      </InstalledOn>
      <Ports xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008" />
    </Service>
    <Service RoleVersion="1" ServiceVersion="8" Type="Microsoft.Rtc.Management.Deploy.Internal.ServiceRoles.CentralMgmtService">
      <ServiceId SiteId="1" RoleName="CentralMgmt" Instance="1" />
      <DependsOn>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="CentralMgmtStore" Instance="1" />
        </Dependency>
        <Dependency Usage="Default">
          <ServiceId SiteId="1" RoleName="FileStore" Instance="1" />
        </Dependency>
      </DependsOn>
      <InstalledOn>
        <ClusterId SiteId="1" Number="1" />
      </InstalledOn>
      <Ports xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008" />
      <CentralMgmtService xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008" IsActive="true" />
    </Service>
    <Service RoleVersion="1" ServiceVersion="8">
      <ServiceId SiteId="1" RoleName="CentralMgmtStore" Instance="1" />
      <DependsOn />
      <InstalledOn>
        <SqlInstanceId Name="rtc">
          <ClusterId SiteId="1" Number="1" />
        </SqlInstanceId>
      </InstalledOn>
      <Ports xmlns="urn:schema:Microsoft.Rtc.Management.Deploy.ServiceRoles.2008" />
    </Service>
  </Services>
</Topology>
"@

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

Function Set-SfB-CentralMgmtStore
{
    Write-Verbose "----- Entering Set-SfB-CentralMgmtStore function -----"
    
    # Install CentralMgmtStore
    Write-Host "Installing Central Management Store (CMS) - database" -ForegroundColor Green
    Install-CsDatabase -CentralManagementDatabase -SqlServerFqdn "$SkypeFQDN" -SqlInstanceName Rtc -Report "$env:TEMP\Install-CsDatabase-RTC-$DTG.html"

    # Set the Service Control Point for the CentralMgmtStore in AD
    If (!((Get-CsConfigurationStoreLocation).BackEndServer -eq "$SkypeFQDN\rtc"))
    {
        Write-Host "Setting the Service Control Point for the CentralMgmtStore in AD:" -ForegroundColor Green
        Set-CsConfigurationStoreLocation -SqlServerFqdn "$SkypeFQDN" -SqlInstanceName Rtc -Force -Report "$env:TEMP\Set-CsConfigurationStoreLocation-$DTG.html"
        (Get-CsConfigurationStoreLocation).BackEndServer
    }
}

Function Set-SfB-Topology
{
    Write-Verbose "----- Entering Set-SfB-Topology function -----"
    
    # Publish and Enable Topology
    If ((Get-CsTopology | Select-Object -ExpandProperty Sites).Name -ne $DomainName)
    {
        Write-Host "Publishing and Enabling Topology" -ForegroundColor Green
        $TopoXML | Out-File "$env:TEMP\CsTopology-$DTG.xml" -Force
        Publish-CsTopology -FileName "$env:TEMP\CsTopology-$DTG.xml" -Force -Report "$env:TEMP\Publish-CsTopology-$DTG.html"
        Enable-CsTopology -Report "$env:TEMP\Enable-CsTopology-$DTG.html"
    }
    Else 
    {
        Write-Host "Topology already Published and Enabled" -ForegroundColor Green
        Get-CsTopology
    }
}

Function New-SfB-RTCLOCAL
{
    Write-Verbose "----- Entering New-SfB-RTCLOCAL function -----"
    
    If ((Get-Service | Where {$_.Name -eq 'MSSQL$RTCLOCAL'}).count -eq 0) 
    {
        Write-Host "Installing Local Configuration Store - SQL Express Instance" -ForegroundColor Green
        Test-FilePath ("C:\Program Files\Skype for Business Server 2019\Deployment\Bootstrapper.exe")
        $FilePath = "C:\Program Files\Skype for Business Server 2019\Deployment\Bootstrapper.exe"
        $Args = @(
        '/BootstrapLocalMgmt'
        )
        Start-Process -FilePath $FilePath -ArgumentList $Args -Wait  
    }
    Else 
    {
        Write-Host "Local Configuration Store - SQL Express Instance already exists." -ForegroundColor Green
    }
}

Function New-SfB-LYNCLOCAL
{
    Write-Verbose "----- Entering New-SfB-LYNCLOCAL function -----"
    
    If ((Get-Service | Where {$_.Name -eq 'MSSQL$LYNCLOCAL'}).count -eq 0) 
    {
        Write-Host "Installing LYNCLOCAL - SQL Express Instance" -ForegroundColor Green
        
        Test-FilePath ("$Skype4BusinessPath\Setup\amd64\SQLEXPR_x64.EXE")
        Start-Process -FilePath "$Skype4BusinessPath\Setup\amd64\SQLEXPR_x64.EXE" -ArgumentList "/x:$env:TEMP\SQLEXPRADV_x64_ENU /q /S" -Wait
        
        Test-FilePath ("$env:TEMP\SQLEXPRADV_x64_ENU\SETUP.EXE")
        $FilePath = "$env:TEMP\SQLEXPRADV_x64_ENU\SETUP.EXE"
        $Args = @(
        "/Q"
        "/IACCEPTSQLSERVERLICENSETERMS"
        "/UPDATEENABLED=0"
        "/ERRORREPORTING=0"
        "/ACTION=Install"
        "/FEATURES=SQLEngine,Tools"
        "/INSTANCENAME=LYNCLOCAL"
        "/INSTANCEDIR=`"C:\Program Files\Microsoft SQL Server`""
        "/ADDCURRENTUSERASSQLADMIN"
        "/SQLSYSADMINACCOUNTS=`"BUILTIN\Administrators`""
        "/SQLSVCACCOUNT=`"NT AUTHORITY\NETWORK SERVICE`""
        "/SQLSVCSTARTUPTYPE=Automatic"
        "/AGTSVCACCOUNT=`"NT AUTHORITY\NETWORK SERVICE`""
        "/AGTSVCSTARTUPTYPE=Disabled"
        "/BROWSERSVCSTARTUPTYPE=`"Automatic`""
        "/TCPENABLED=1"
        )
        Start-Process -FilePath $FilePath -ArgumentList $Args -Wait
    }
    Else 
    {
        Write-Host "SQL Express Instance (LYNCLOCAL) already exists." -ForegroundColor Green
    }
}

Function Set-SfB-ServerComponents
{
    Write-Verbose "----- Entering Set-SfB-ServerComponents function -----"

    #Write-Host "Setting up Skype for Business Server 2019 Server Components" -ForegroundColor Green

    # Install Local Configuration Store (replica of CMS) within RTCLOCAL
    Write-Host "Installing Local Configuration Store - database" -ForegroundColor Green
    Install-CsDatabase -ConfiguredDatabases -SqlServerFqdn "$SkypeFQDN" -Report "$env:TEMP\Install-CsDatabase-RTCLOCAL-$DTG.html"

    If (!(Test-CsDatabase -ConfiguredDatabases -SqlServerFqdn "$SkypeFQDN"))
    {
        #Install-CsDatabase -ConfiguredDatabases -SqlServerFqdn "$SkypeFQDN" -Report "$env:TEMP\Install-CsDatabase-RTCLOCAL-$DTG.html"
    }

    # Copy Topology to Local Configuration Store and Enable Replica
    $CsConfig = Export-CsConfiguration -AsBytes
    Import-CsConfiguration -ByteInput $CsConfig -LocalStore
    Enable-CsReplica -Report "$env:TEMP\Enable-CsReplica-$DTG.html"
    Start-CSwindowsService Replica -Report "$env:TEMP\Start-CSwindowsService-Replica-$DTG.html"
    Get-CsWindowsService Replica
}

Function Install-SfB-Certs
{
    Write-Verbose "----- Entering Install-SfB-Certs function -----"
    
    If (!(Test-SfB-Cert ("$CertTemplate"))) 
    {
        Write-Host "Installing certificate derived from $CertTemplate template" -ForegroundColor Green
        $Template = $CertTemplate.Replace(" ","")
        $Certificate = Get-Certificate -Template $Template -DNSName $SkypeFQDN,dialin.$DomainDnsName,meet.$DomainDnsName,lyncdiscoverinternal.$DomainDnsName,lyncdiscover.$DomainDnsName,sip.$DomainDnsName -CertStoreLocation cert:\LocalMachine\My -subjectname cn=$SkypeFQDN
    }

    If (Test-SfB-Cert ("$CertTemplate"))
    {
        Write-Host "Assigning certificates based on the defined Topology" -ForegroundColor Green
        $InstalledCert = Get-ChildItem Cert:\LocalMachine\My | ? {$_.Extensions.format(1)[0] -match "Template=$CertTemplate"}
        Set-CSCertificate -Type Default,WebServicesInternal,WebServicesExternal -Thumbprint $InstalledCert.Thumbprint -Confirm:$false -Report "$env:TEMP\Set-CSCertificate-$Template.html"
        $InstalledCert | fl
    }
}

Function Set-SfB-DNS
{
    Write-Verbose "----- Entering Set-SfB-DNS function -----"

    Import-Module DNSServer
    Write-Host "Configuring DNS for Skype for Business" -ForegroundColor Green

    $TestDNS1 = Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name dialin -RRType CName -ErrorAction "SilentlyContinue"
    If(!($TestDNS1)) 
    {
        Add-DnsServerResourceRecordCName -ZoneName $DomainDnsName -ComputerName $DC -Name dialin -HostNameAlias $SkypeFQDN -TimeToLive 00:05:00
        Write-Host "The following DNS CNAME record was successfully created:" -ForegroundColor Yellow
        Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name dialin -RRType CName
    }

    $TestDNS2 = Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name meet -RRType CName -ErrorAction "SilentlyContinue"
    If(!($TestDNS2)) 
    {
        Add-DnsServerResourceRecordCName -ZoneName $DomainDnsName -ComputerName $DC -Name meet -HostNameAlias $SkypeFQDN -TimeToLive 00:05:00
        Write-Host "The following DNS CNAME record was successfully created:" -ForegroundColor Yellow
        Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name meet -RRType CName
    }

    $TestDNS3 = Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name lyncdiscoverinternal -RRType CName -ErrorAction "SilentlyContinue"
    If(!($TestDNS3)) 
    {
        Add-DnsServerResourceRecordCName -ZoneName $DomainDnsName -ComputerName $DC -Name lyncdiscoverinternal -HostNameAlias $SkypeFQDN -TimeToLive 00:05:00
        Write-Host "The following DNS CNAME record was successfully created:" -ForegroundColor Yellow
        Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name lyncdiscoverinternal -RRType CName
    }

    $TestDNS4 = Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name lyncdiscover -RRType CName -ErrorAction "SilentlyContinue"
    If(!($TestDNS4)) 
    {
        Add-DnsServerResourceRecordCName -ZoneName $DomainDnsName -ComputerName $DC -Name lyncdiscover -HostNameAlias $SkypeFQDN -TimeToLive 00:05:00
        Write-Host "The following DNS CNAME record was successfully created:" -ForegroundColor Yellow
        Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name lyncdiscover -RRType CName
    }

    $TestDNS5 = Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name sip -RRType CName -ErrorAction "SilentlyContinue"
    If(!($TestDNS5)) 
    {
        Add-DnsServerResourceRecordCName -ZoneName $DomainDnsName -ComputerName $DC -Name sip -HostNameAlias $SkypeFQDN -TimeToLive 00:05:00
        Write-Host "The following DNS CNAME record was successfully created:" -ForegroundColor Yellow
        Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name sip -RRType CName
    }

    $TestDNS6 = Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name "_sipinternaltls._tcp" -RRType Srv -ErrorAction "SilentlyContinue"
    If(!($TestDNS6)) 
    {
        #Add-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name "_sipinternaltls._tcp" -Srv -DomainName "$SkypeFQDN" -Priority 0 -Weight 0 -Port 5060 -TimeToLive 00:05:00
        Add-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name "_sipinternaltls._tcp" -Srv -DomainName $DomainDnsName -Priority 0 -Weight 0 -Port 5060 -TimeToLive 00:05:00
        Write-Host "The following DNS SRV record was successfully created:" -ForegroundColor Yellow
        Get-DnsServerResourceRecord -ZoneName $DomainDnsName -ComputerName $DC -Name "_sipinternaltls._tcp" -RRType Srv
    }

    $URL1 = New-CsSimpleUrlEntry -Url "https://dialin.$DomainDnsName"
    $SimpleURL1 = New-CsSimpleUrl -Component "dialin" -Domain "*" -SimpleUrlEntry $URL1 -ActiveUrl "https://dialin.$DomainDnsName"
    $URL2 = New-CsSimpleUrlEntry -Url "https://meet.$DomainDnsName"
    $SimpleURL2 = New-CsSimpleUrl -Component "meet" -Domain "$DomainDnsName" -SimpleUrlEntry $URL2 -ActiveUrl "https://meet.$DomainDnsName"
    $URL3 = New-CsSimpleUrlEntry -Url "https://admin.$DomainDnsName"
    $SimpleURL3 = New-CsSimpleUrl -Component "Cscp" -Domain "*" -SimpleUrlEntry $URL3 -ActiveUrl "https://admin.$DomainDnsName"

    Remove-CsSimpleUrlConfiguration -Identity "Global"
    Set-CsSimpleUrlConfiguration -Identity "Global" -SimpleUrl @{Add=$SimpleURL1,$SimpleURL2,$SimpleURL3}
    Enable-CsComputer -Report "$env:TEMP\Enable-CsComputer-$DTG.html"
}

Function Test-SfB-Cert ($CertTemplate)
{
    Write-Host "Checking if certificate derived from $CertTemplate is in local store" -ForegroundColor Green
    $CertCheck = [bool] (Get-ChildItem Cert:\LocalMachine\My | ? {$_.Extensions.format(1)[0] -match "Template=$CertTemplate"})
    Write-Host $CertCheck
    return $CertCheck
}

Function Install-SfB-Certs
{
    Write-Verbose "----- Entering Install-SfB-Certs function -----"
    
    If (!(Test-SfB-Cert ("$CertTemplate"))) 
    {
        Write-Host "Installing certificate derived from $CertTemplate template" -ForegroundColor Green
        $Template = $CertTemplate.Replace(" ","")
        $Certificate = Get-Certificate -Template $Template -DNSName $SkypeFQDN,dialin.$DomainDnsName,meet.$DomainDnsName,lyncdiscoverinternal.$DomainDnsName,lyncdiscover.$DomainDnsName,sip.$DomainDnsName -CertStoreLocation cert:\LocalMachine\My -subjectname cn=$SkypeFQDN
    }

    If (Test-SfB-Cert ("$CertTemplate"))
    {
        Write-Host "Assigning certificates based on the defined Topology" -ForegroundColor Green
        $InstalledCert = Get-ChildItem Cert:\LocalMachine\My | ? {$_.Extensions.format(1)[0] -match "Template=$CertTemplate"}
        Set-CSCertificate -Type Default,WebServicesInternal,WebServicesExternal -Thumbprint $InstalledCert.Thumbprint -Confirm:$false -Report "$env:TEMP\Set-CSCertificate-$Template.html"
        $InstalledCert | fl
    }
}

# =============================================================================
# MAIN ROUTINE
# =============================================================================

Import-Module "C:\Program Files\Common Files\Skype for Business Server 2019\Modules\SkypeForBusiness\SkypeForBusiness.psd1"

Set-SfB-CentralMgmtStore
Set-SfB-Topology

# Install RTCLOCAL and LYNCLOCAL instances and databases
New-SfB-RTCLOCAL
New-SfB-LYNCLOCAL

# Set up server components (this still needs work to match SfB Deployment Wizard GUI)
Set-SfB-ServerComponents

# Create CNAMEs in DNS
Set-SfB-DNS

# Request and install certificate
Install-SfB-Certs

Stop-Transcript
