Import-Module AdmPwd.PS
$machineOUs = "T0-Devices","T0-Servers","T1-Devices","T2-Devices","Computer Quarantine","Devices","Tier 1 Servers"
ForEach ($ou in $machineOUs) {
	Set-AdmPwdComputerSelfPermission -OrgUnit $ou
}
$Tier0OUs = "T0-Devices","T0-Servers"
$Tier1OUs = "T1-Devices","Tier 1 Servers"
$Tier2OUs = "T2-Devices","Devices","Computer Quarantine"

ForEach ($T0OU in $Tier0OUs) {
    Set-AdmPwdReadPasswordPermission -Identity $T0OU -AllowedPrincipals "Tier0Admins"
    Set-AdmPwdResetPasswordPermission -Identity $T0OU -AllowedPrincipals "Tier0Admins"
}
ForEach ($T1OU in $Tier1OUs) {
    Set-AdmPwdReadPasswordPermission -Identity $T1OU -AllowedPrincipals "Tier1Admins","Tier0Admins"
    Set-AdmPwdResetPasswordPermission -Identity $T1OU -AllowedPrincipals "Tier1Admins","Tier0Admins"
}
ForEach ($T2OU in $Tier2OUs) {
    Set-AdmPwdReadPasswordPermission -Identity $T2OU -AllowedPrincipals "Tier2Admins","Tier0Admins"
    Set-AdmPwdResetPasswordPermission -Identity $T2OU -AllowedPrincipals "Tier2Admins","Tier0Admins"
}