#get azure ad joined devices
$devices = Get-MsolDevice -All -ReturnRegisteredOwners

#export devices list
$devices | Export-csv "C:\Temp\AzureDevices.csv"

#current users
$currentusers = Get-MsolUser -All | Where-Object { $_.isLicensed -eq "True"} | Select-Object DisplayName, UserPrincipalName

$devices | Select RegisteredOwners,DisplayName | ? {$_.RegisteredOwners -in $currentusers.UserPrincipalName}

#devices with current users
$devices | Select @{n="RegisteredOwners";e={$_.RegisteredOwners}},DisplayName,DeviceOsType,DeviceOsVersion,DeviceTrustType,DeviceTrustLevel | ? {$_.RegisteredOwners -in $currentusers.UserPrincipalName} | Export-Csv "C:\Temp\DeviceReport.csv" -NoTypeInformation

$devices | Select DeviceTrustType | ? {($_.RegisteredOwners -in $currentusers.UserPrincipalName) -and ($_.DeviceTrustType -eq "Azure AD Joined")} | Measure
