#########SET VARIABLES #########
#Distribution Group Name:
$group = ""

#License to add:
#EG: Contoso:ENTERPRISEPACK, Contoso:ATP_ENTERPRISE
$license = ""
###############################

#Decrypt secure password and create credential object
$username = "admin@contoso.com"
$securePwd = (Get-Content "C:\temp\admin.txt") | ConvertTo-SecureString
$UserCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePwd

Connect-MsolService -Credential $UserCredential
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
Import-PSSession $Session -AllowClobber

#Get all $group members and assign $license
Get-DistributionGroupMember -Identity "$group" | % {Get-MsolUser -UserPrincipalName $_.PrimarySmtpAddress} | Where-Object { $_.isLicensed -eq "True"} | % {Set-MsolUserLicense -UserPrincipalName $_.UserPrincipalName -AddLicenses "$license"} | Export-Csv C:\Temp\groupmem.csv

#Assign License (individual)
#Set-MsolUserLicense -UserPrincipalName "user@company.com" -AddLicenses "Contoso:ATP_ENTERPRISE"