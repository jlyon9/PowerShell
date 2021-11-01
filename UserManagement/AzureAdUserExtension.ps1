#Get all extension objects
Get-AzureAdUser -SearchString "User Name" | % {Get-AzureADUserExtension -ObjectId $_.ObjectID}

#Get specific extension object ("createdDateTime")
Get-AzureAdUser -SearchString "User Name" | % {(Get-AzureADUserExtension -ObjectId $_.ObjectID).get_item("createdDateTime")}
Get-AzureAdUser -SearchString "User Name" | % {(Get-AzureADUserExtension -ObjectId $_.ObjectID).get_item("employeeId")}

#Get all azure users and their extension attribute (labelled as "employeeId)
Get-AzureAdUser -All $true | Select DisplayName,UserPrincipalName,@{name="employeeId";expression={(Get-AzureADUserExtension -ObjectId $_.ObjectID).get_item("employeeId")}} | Export-CSV "C:\Temp\empID.csv" -NoTypeInformation

#Set Azure extension attribute
Get-AzureAdUser -SearchString "User Name" | % {Set-azureADUserextension -objectID $_.objectID -extensionName employeeID -extensionValue "$id"}

#Remove extension attribute
Remove-AzureADUserExtension -ObjectId [userobjectid] -ExtensionName employeeId
