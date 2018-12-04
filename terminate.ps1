Add-Type -AssemblyName System.web

#Credentials
$username = "service@account.com"
$securePwd = Get-Content "D:\OD\OneDrive\Documents\Powershell\TerminateUser\service_account.txt" | ConvertTo-SecureString
$credObject = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePwd

#Connections
Connect-MsolService -Credential $credObject
Connect-AzureAD -Credential $credObject
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $credObject -Authentication Basic -AllowRedirection
Import-PSSession $Session -AllowClobber

$path = "D:\OD\OneDrive\Documents\Flow\ExitChecklist\"
cd $path

#Import XMLs
$xmlfiles = Get-ChildItem -Path $path *.xml

#Iterate
foreach ($u in $xmlfiles) {

[xml]$user = Get-Content $u.name

$email = $user.myFields."EmployeeEmailLookup"

$uid = Get-MsolUser -UserPrincipalName $email
$usercount = $uid.UserPrincipalName | Measure-Object | Select-Object -ExpandProperty Count

#ensure only one user selected
if ($usercount -eq 1) {

#get termination date
$tdate = ($user.myFields."Employee-TermDate" + " 17:00")

#check date
#https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-date?view=powershell-6
$cdate = Get-Date -UFormat "%Y-%m-%d %R"

if ($tdate -le $cdate) {

#check termination type (standard vs emergency)
$termtype = $user.myFields."ExitType"

#generate random password
$newpass = [system.web.security.membership]::GeneratePassword(8,2)

#Block Sign-in
Set-MsolUser -UserPrincipalName $uid.UserPrincipalName -BlockCredential $true
#Set random password
Set-MsolUserPassword -UserPrincipalName $uid.UserPrincipalName -NewPassword $newpass
#Conver mailbox to shared
Get-Mailbox -identity $uid.UserPrincipalName | set-mailbox -type “Shared”
#Set mailbox hidden
Set-Mailbox -Identity $uid.UserPrincipalName -HiddenFromAddressListsEnabled $true
#remove all licenses
(Get-MsolUser -UserPrincipalName $uid.UserPrincipalName).licenses.AccountSkuID | % {Set-MsolUserLicense -UserPrincipalName $uid.UserPrincipalName -RemoveLicenses $_}

#O365Groups
#Remove Ownerships
Get-AzureAdUserOwnedObject -ObjectId $uid.ObjectId | % {Get-UnifiedGroup -Identity $_.DisplayName | Select DisplayName} | % {Remove-UnifiedGroupLinks -Identity $_.DisplayName -LinkType Owners -Links $uid.UserPrincipalName -Confirm:$false}
#Remove Memberships
Get-AzureAdUserMembership -ObjectId $uid.ObjectId | % {Get-UnifiedGroup -Identity $_.DisplayName | Select DisplayName} | % {Remove-UnifiedGroupLinks -Identity $_.DisplayName -LinkType Members -Links $uid.UserPrincipalName -Confirm:$false}

#MSOL
Get-AzureADUserMembership -ObjectID $uid.ObjectId | Where-Object {$_.MailEnabled -ne "True"} | % {Remove-MsolGroupMember -GroupObjectId $_.ObjectId -GroupMemberObjectId $uid.ObjectId}

#Exchange
Get-AzureADUserMembership -ObjectID $uid.ObjectId | Where-Object {$_.MailEnabled -eq "True"} | % {Remove-DistributionGroupMember -Identity $_.DisplayName -Member $uid.UserPrincipalName -Confirm:$false}

Move-Item -Path ($path + $u.Name) -Destination ($path + "Complete\" + $email)

}}}

Remove-PSSession $Session
