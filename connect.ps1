# Via Microsoft Exchange Online Powershell Module (run as admin)
Connect-IPPSSession -UserPrincipalName user@contoso.com

#Connect Msol service
Connect-MsolService -Credential $UserCredential

#Connect Azure AD
Connect-AzureAD -Credential $UserCredential

#Create Exchange Online Session
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
Import-PSSession $Session

#Connect SPOnline
Connect-SPOService -Url https://symbiota-admin.sharepoint.com -Credential $UserCredential
