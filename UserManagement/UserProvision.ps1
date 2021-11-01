# Assumes .xml with corresponding user details

#Get Script Dir
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
cd $ScriptDir

#Create credential object
$UserCredential = Get-Credential

Import-Module MSOnline

#Connect Msol service
Connect-MsolService -Credential $UserCredential

#Connect Azure AD
Connect-AzureAD -Credential $UserCredential

#Create Exchange Online Session
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
Import-PSSession $Session

#get list of xml files in directory
$xmlfiles = Get-ChildItem -Path $ScriptDir *.xml

#CreateMFA Object
#$st = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
#$st.RelyingParty = "*"
#$st.State = â€œEnforcedâ€
#$sta = @($st)

foreach ($xml in $xmlfiles) {[xml]$user = Get-Content $xml.name

#PRESETS
$AccountSkuId = "Contoso:ENTERPRISEPACK"
$Password = "[password]"

#Get Employee Type
$EmpType = $user.myFields."Empl-EmplType"

#Get Full Name
$Displayname = $user.myFields."Empl-Name"

#Split First and Last Name(s)
$FName = $user.myFields."Empl-Name".Split()[0]
$LNameAr = $user.myFields."Empl-Name".Split()[1..2]
$LName = "$LnameAr"

#Get Email Address
$Email = $user.myFields."Empl-EmailAddr"

#Hiring Manager Name to Email
$hmgrFI = $user.myFields."Empl-HiringMgr".Split()[0].Substring(0,1).ToLower()
$hmgrLN = $user.myFields."Empl-HiringMgr".Split()[1..2].ToLower()
$mgrEM = "$hmgrFI$hmgrLN@contoso.com"

#Title
$Title = $user.myFields."EmplTitle"

#Mobile
$Mobile = $user.myFields."Personal-Mobile"

#Department
$Departmemlnt = $user.myFields."Empl-Dept"."#text"

#Office
#1 = New York, 2 = Los Angeles, 5 = Remote
$Offices = @('Blank','New York','Los Angeles','Remote')
$Office = $user.myFields."Empl-Office"
$Office = $Offices[$Office]

#Set Country from office location
If ($Office -eq '1') {
$Country = 'United States'
} ElseIf ($Office -eq '5') {
$Country = 'New Zealand'
} Else {$Country = 'United States'}

# Set UsageLocation from office location
If ($Office -eq '1') {
$Country = 'United States'
} ElseIf ($Office -eq '5') {
$Country = 'New Zealand'
} Else {$Country = 'United States'}

New-MsolUser -DisplayName $Displayname -FirstName $FName -LastName $LName -UserPrincipalName $Email -UsageLocation $UsageLocation -Title $Title -LicenseAssignment $AccountSkuId -Password $Password -ForceChangePassword $false -PhoneNumber $Mobile -Department $Department -Office $Office -Country $Country | Export-Csv -Path $ScriptDir\importlog.csv

#Timer
Start-Sleep -s 180

#Add to groups
$userOID = Import-Csv -Path $ScriptDir\importlog.csv | select -ExpandProperty ObjectId

#MS Project Resources
Add-MsolGroupMember -GroupObjectId 2xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -GroupMemberType User -GroupMemberObjectId $UserOID

#Indigo-SSO
Add-MsolGroupMember -GroupObjectId 2xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -GroupMemberType User -GroupMemberObjectId $UserOID

#Zoom-SSO
Add-MsolGroupMember -GroupObjectId 2xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -GroupMemberType User -GroupMemberObjectId $UserOID

#Password Reset Enabled
Add-MsolGroupMember -GroupObjectId 2xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -GroupMemberType User -GroupMemberObjectId $UserOID

#Atlassian-SSO
Add-MsolGroupMember -GroupObjectId 2xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -GroupMemberType User -GroupMemberObjectId $UserOID

#Intune for Windows PC users, Rapid7, and Cisco Umbrella
If (($Compbrand -eq "Windows PC") -or ($Compbrand -eq "Surface"))
{
Set-MsolUserLicense -UserPrincipalName $email -AddLicenses "Contoso:EMSPREMIUM" 
Add-MsolGroupMember -GroupObjectId 2xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -GroupMemberType User -GroupMemberObjectId $UserOID
}

#Add to Consultants Group
If ($EmpType -eq "Consultant")
{
Add-MsolGroupMember -GroupObjectId 2xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -GroupMemberType User -GroupMemberObjectId $UserOID
}

#Import created user email addresses
$userEmails = Import-Csv -Path $ScriptDir\importlog.csv | select -ExpandProperty SignInName

#Enforce MFA
#Set-MsolUser -UserPrincipalName $Email -StrongAuthenticationRequirements $sta

#Set User Manger in Exchange
Set-User -Identity $Email -Manager $mgrEM

$DistGroups = $user.myFields."MultiSelectionFields"."Conf-EmailGroupList"
$DistGroups | % {Add-DistributionGroupMember -Identity $_ -Member $Email} | ? {"" -ne $_}}

Move-Item -Path .\*.xml -Destination .\complete

Remove-PSSession $Session
