# Task Sequence
See https://github.com/alvinchen1/OTCMDTAutomate/blob/main/Control/TaskSequences.docx for MDT TS export catalog to correlate scripted MDT flow in the XML

Tip: TS ID in doc corresponds to folder name in the Control folder where one can see the flow in the XML
     
Each subfolder should have a ts.xml that contains the logical flow of the TS

Inside each ts.xml, relevant areas are lines with:

     <action>cmd.exe /c start /wait powershell.exe -executionpolicy bypass -File "%SCRIPTROOT%\USS-*.ps1"</action>

### Hyper-V Admin Server: USS-PA-01
- USS-OS-PREP-1.ps1
- Reboot
- USS-ADM-CONFIG-1.ps1
- Reboot
- USS-ADM-CONFIG-2.ps1
- Reboot
- USS-ADM-CONFIG-3.ps1

### DC1: USS-SRV-50
- USS-OS-PREP-1.ps1
- Reboot
- USS-AD-CONFIG-1.ps1
- Reboot
- USS-AD-CONFIG-2.ps1
- Reboot
- USS-AD-CONFIG-3.ps1
- Reboot
- USS-OS-Install-CoreFeatures.ps1
- USS-OS-Set-SecurityProviders.ps1
- Reboot
- USS-DC-Import-ADMXs.ps1
- USS-DC-Install-LAPS-AD.ps1
- USS-DC-Config-DNS.ps1

### Hyper-V node 1: USS-PV-01
- USS-OS-PREP-1.ps1
- Reboot
- USS-S2D-CONFIG-1.ps1
- Reboot
- USS-S2D-CONFIG-2.ps1
- Reboot

### Hyper-V node 2: USS-PV-02
- USS-OS-PREP-1.ps1
- Reboot
- USS-S2D-CONFIG-1.ps1
- Reboot
- USS-S2D-CONFIG-2.ps1
- Reboot
- USS-S2D-CONFIG-3.ps1
- USS-S2D-CONFIG-4.ps1

### We may be able to run the rest in parallel. Need to check if 17/18 and 22/23 have dependencies

### DC2: USS-SRV-51
- USS-OS-PREP-1.ps1
- Reboot
- USS-AD-CONFIG-4.ps1
- Reboot
- USS-OS-Install-CoreFeatures.ps1
- USS-OS-Set-SecurityProviders.ps1
- Reboot
- USS-DC-Import-ADMXs.ps1
- USS-DC-Install-LAPS-AD.ps1

### MECM: USS-SRV-52
- USS-OS-PREP-1.ps1
- Reboot
- USS-MECM-CONFIG-1.ps1
- Reboot
- USS-MECM-CONFIG-2.ps1
- Reboot
- USS-MECM-CONFIG-3.ps1
- Reboot
- USS-MECM-CONFIG-4.ps1
- Reboot
- USS-MECM-CONFIG-5.ps1
- Reboot

### DHCP: USS-SRV-53
- USS-OS-PREP-1.ps1
- Reboot
- USS-DHCP-CONFIG-1.ps1

### WSUS/CDP: USS-SRV-54
- USS-OS-PREP-1.ps1
- Reboot
- USS-WSUS-CONFIG-1.ps1
- Reboot
- USS-WSUS-CONFIG-2.ps1
- Reboot
- USS-OS-Install-CoreFeatures.ps1
- USS-OS-Set-SecurityProviders.ps1
- Reboot
- USS-CA-CDP-New-CDP.ps1
- USS-OS-Install-LAPS.ps1

### Root CA: USS-SRV-55
- USS-OS-PREP-1.ps1
- Reboot
- USS-CA-CONFIG-1.ps1
- Reboot
- USS-OS-Install-CoreFeatures.ps1
- USS-OS-Set-SecurityProviders.ps1
- USS-CA-Install-PSPKI.ps1
- Reboot
- USS-CA-Root-NewCA.ps1

### Issuing CA: USS-SRV-56
- USS-OS-PREP-1.ps1
- Reboot
- USS-CA-CONFIG-1.ps1
- Reboot
- USS-OS-Install-CoreFeatures.ps1
- USS-OS-Set-SecurityProviders.ps1
- USS-CA-Install-PSPKI.ps1
- USS-CA-Install-ADCSTemplate.ps1
- Reboot
- USS-CA-Sub-New-IssuingCA.ps1
- USS-CA-Sub-Publish-ADCSTemplates.ps1
- USS-CA-Sub-Update-ADCSTemplateACLs.ps1
- USS-OS-Install-LAPS.ps1
- USS-CA-Sub-Config-AD.ps1
- Reboot

### Skype: USS-SRV-57
- USS-OS-PREP-1.ps1
- Reboot
- USS-SKYPE-CONFIG-1.ps1
- Reboot
- USS-OS-Install-DotNetFramework-v3.5.ps1
- USS-OS-Install-DotNetFramework-v4.8.ps1
- Reboot
- USS-OS-Install-CoreFeatures.ps1
- USS-OS-Set-SecurityProviders.ps1
- Reboot
- USS-SKYPE-CONFIG-2.ps1
- Reboot
- USS-SKYPE-CONFIG-3.ps1
- USS-SKYPE-CONFIG-4.ps1
- Reboot
- USS-SKYPE-CONFIG-5.ps1
- Reboot
- USS-SKYPE-CONFIG-6.ps1
- Reboot
- USS-SKYPE-CONFIG-7.ps1
- USS-OS-Install-LAPS.ps1
- Reboot

### DPM: USS-SRV-58
- USS-OS-PREP-1.ps1
- Reboot
- USS-DPM-CONFIG-1.ps1
- Reboot
- USS-DPM-CONFIG-2.ps1
- Reboot
- USS-DPM-CONFIG-3.ps1
- Reboot
- USS-DPM-CONFIG-4.ps1
- Reboot

### Exchange: USS-SRV-59
- USS-OS-PREP-1.ps1
- Reboot
- USS-EXCHG-CONFIG-1.ps1
- Reboot
- USS-OS-Install-DotNetFramework-v4.8.ps1
- USS-OS-Install-CoreFeatures.ps1
- USS-OS-Set-SecurityProviders.ps1
- Reboot
- USS-EXCHG-CONFIG-2.ps1
- Reboot
- USS-EXCHG-CONFIG-3.ps1
- USS-OS-Install-LAPS.ps1
- Reboot

### SolarWinds DB: USS-SRV-60
- USS-OS-PREP-1.ps1
- Reboot
- USS-SOLAR-CONFIG-1.ps1
- Reboot
- USS-SOLAR-CONFIG-2.ps1
- Reboot

### SolarWinds DB: USS-SRV-61
- USS-OS-PREP-1.ps1
- Reboot
- USS-SOLAR-CONFIG-3.ps1
- Reboot

### KIWI/WEC: USS-SRV-62
- USS-OS-PREP-1.ps1
- Reboot
- USS-KIWI-CONFIG-1.ps1

### NIFI: USS-SRV-63
- USS-OS-PREP-1.ps1
- Reboot
- USS-NIFI-CONFIG-1.ps1

### CARDEALER: USS-SRV-64
- USS-OS-PREP-1.ps1
- Reboot
- USS-CARD-CONFIG-1.ps1
