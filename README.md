# Task Sequence
See https://github.com/alvinchen1/OTCMDTAutomate/blob/main/Control/TaskSequences.docx for MDT TS export catalog to correlate scripted MDT flow in the XML
Tip: TS ID in doc corresponds to folder name in the Control folder where one can see the flow in the XML
     
     Each subfolder should have a ts.xml that contains the logical flow of the TS
     
     Inside each ts.xml, relevant areas are lines with:
     
     <action>cmd.exe /c start /wait powershell.exe -executionpolicy bypass -File "%SCRIPTROOT%\USS-*.ps1"</action>

The rest of this README needs to be updated accordingly and server names as roles have changed over time

## Every server needs USS-OS-PREP-1.ps1

### USS-PA-01
- USS-ADM-CONFIG-1.ps1
- USS-ADM-CONFIG-2.ps1
- USS-ADM-CREATE-VMs.ps1

### USS-SRV-50
- USS-AD-CONFIG-1.ps1
- USS-AD-CONFIG-2.ps1
- USS-AD-CONFIG-3.ps1

### USS-PV-01
- USS-S2D-CONFIG-1.ps1
- USS-S2D-CONFIG-2.ps1

### USS-PV-02
- USS-S2D-CONFIG-1.ps1
- USS-S2D-CONFIG-2.ps1
- USS-S2D-CONFIG-3.ps1
- USS-S2D-CREATE-VMs.ps1

### We may be able to run the rest in parallel. Need to check if 17/18 and 22/23 have dependencies

### USS-SRV-51
- USS-AD-CONFIG-4.ps1

### USS-SRV-14
- USS-EXCHG-CONFIG-1.ps1
- USS-MECM-CONFIG-1.ps1
- USS-MECM-CONFIG-2.ps1
- USS-MECM-CONFIG-3.ps1
- USS-MECM-CONFIG-5.ps1
- USS-MECM-CONFIG-6.ps1
- USS-MECM-POST-1.ps1

### USS-SRV-15
- USS-DHCP-CONFIG-1.ps1

### USS-SRV-54
- USS-WSUS-CONFIG-1.ps1
- USS-WSUS-CONFIG-2.ps1

### USS-SRV-17
- USS-CA-CONFIG-1.ps1
- USS-CA-CONFIG-2.ps1

### USS-SRV-18
- USS-CA-CONFIG-3.ps1
- USS-CA-CONFIG-4.ps1

### USS-SRV-19
- USS-SKYPE-CONFIG-1
- USS-SKYPE-CONFIG-2

### USS-SRV-20
- USS-DPM-CONFIG-1.ps1
- USS-DPM-CONFIG-2.ps1

### USS-SRV-21
- USS-EXCHG-01
- USS-EXCHG-02

### USS-SRV-22
- USS-SW-CONFIG-01
- USS-SW-CONFIG-02

### USS-SRV-23
- USS-SW-CONFIG-03
- USS-SW-CONFIG-04
