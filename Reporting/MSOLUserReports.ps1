#Create credential object
#$UserCredential = Get-Credential

#Connect MSOL
Connect-MsolService #-Credential $UserCredential

#values: DisplayName, UserPrincipalName, PhoneNumber

#Export licensed and UNblocked users
Get-MsolUser -All | ? {(($_.isLicensed -eq $true) -and ($_.BlockCredential -eq $false))} | Select-Object DisplayName, UserPrincipalName | Export-Csv C:\Temp\allusers.csv

#Export Licensed users and MFA state
Get-MsolUser -All | ? {$_.isLicensed -eq "True"} | Select-Object DisplayName, UserPrincipalName, @{N='MFA State';E={($_.StrongAuthenticationRequirements.State)}} | Export-Csv C:\Temp\Report_Dec.csv

#Get all active, non-external or non-resource accounts
#Connect to MSOL and EXOnline
Get-MsolUser -all | ? {($_.UserPrincipalName -notin ({Get-UnifiedGroup | Select PrimarySmtpAddress})) -and ($_.UserPrincipalName -notin ({Get-Mailbox -ResultSize unlimited | ? {($_.IsResource -eq $true)} | Select PrimarySmtpAddress})) -and ($_.UserPrincipalName -notmatch "#EXT#") -and ($_.isLicensed -eq $true) -and ($_.BlockCredential -eq $false)}

#All External
Get-MsolUser -All | ? {$_.UserPrincipalName -match "#EXT#"}

#All Blocked & Licensed
Get-MsolUser -All | ? {($_.BlockCredential -eq $true) -and ($_.isLicensed -eq $true)} | Select-Object DisplayName, UserPrincipalName | Export-Csv -NoTypeInformation ('C:\Temp\Blocked_Licensed.csv')
