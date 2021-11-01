################# MSOL 
# Connect MSOL
Connect-MsolService

# values: DisplayName, UserPrincipalName, PhoneNumber

# Export licensed and UNblocked users
Get-MsolUser -All | ? {(($_.isLicensed -eq $true) -and ($_.BlockCredential -eq $false))} | Select-Object DisplayName, UserPrincipalName | Export-Csv C:\Temp\allusers.csv

# Export Licensed users and MFA state
Get-MsolUser -All | ? {$_.isLicensed -eq "True"} | Select-Object DisplayName, UserPrincipalName, @{N='MFA State';E={($_.StrongAuthenticationRequirements.State)}} | Export-Csv C:\Temp\Report_Dec.csv

# Get all active, non-external or non-resource accounts
Get-MsolUser -all | ? {($_.UserPrincipalName -notin ({Get-UnifiedGroup | Select PrimarySmtpAddress})) -and ($_.UserPrincipalName -notin ({Get-Mailbox -ResultSize unlimited | ? {($_.IsResource -eq $true)} | Select PrimarySmtpAddress})) -and ($_.UserPrincipalName -notmatch "#EXT#") -and ($_.isLicensed -eq $true) -and ($_.BlockCredential -eq $false)}

# All External
Get-MsolUser -All | ? {$_.UserPrincipalName -match "#EXT#"}

# All Blocked & Licensed
Get-MsolUser -All | ? {($_.BlockCredential -eq $true) -and ($_.isLicensed -eq $true)} | Select-Object DisplayName, UserPrincipalName | Export-Csv -NoTypeInformation ('C:\Temp\Blocked_Licensed.csv')

# Count All users (active/inactive/deactivated)
Get-MsolUser -All | measure | select Count

# Count All currently licensed
Get-MsolUser -All | ? {$_.isLicensed -eq "True"} | measure | select Count


################# AZURE

Connect-AzureAD

# Get all managers
(Get-AzureADUser -All $true) | % {Get-AzureADUserManager -ObjectId $_.ObjectId} | Export-Csv -Path C:\Temp\allusermanagers.csv

# All Contractors
Get-AzureAdUser -All $true | ? {$_.ObjectId -notin $AzureUsers.ObjectId} | Select DisplayName,UserPrincipalName | ? {($_.UserPrincipalName -notmatch "#EXT#") -or ($_.UserPrincipalName -notmatch "-admin") -and ($_.AccountEnabled -eq $true) -and ($_.ObjectType -eq "User")} | Export-CSV 'C:\Temp\NonFTEUsers.csv' -NoTypeInformation

# All users
Get-AzureAdUser -All $true | ? {$_.ObjectId -in $AzureUsers.ObjectId}  | Select DisplayName,UserPrincipalName | Export-CSV 'C:\Temp\FTEUsers.csv' -NoTypeInformation


################# Exchange Online

$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/ -Credential $LiveCred -AllowRedirection

# Get last login time
Get-MsolUser -All | Where {$_.isLicensed -eq $true} | % {Get-Mailbox -Identity $_.UserPrincipalName} | % {Get-MailboxStatistics $_.Identity | Select DisplayName, LastLogonTime} | Export-CSV $Home\Desktop\LastLogonDate.csv

# Get Individual mailbox delegates
Get-Mailbox -Identity "email@contoso.com" -RecipientType 'UserMailbox' | % {Get-MailboxPermission -Identity $_.Identity | ? {$_.User -match "@"} | Select @{Expression={$_.Identity};label='PrimaryUser'},@{Expression={$_.User};label='Delegate'}}

# Get All Mailboxes and Delegates
Get-Mailbox -ResultSize Unlimited -RecipientType 'UserMailbox' | % {Get-MailboxPermission -Identity $_.Identity | ? {$_.User -match "@"} | Select @{Expression={$_.Identity};label='PrimaryUser'},@{Expression={$_.User};label='Delegate'}} | Export-CSV C:\Temp\maildelegates.csv
