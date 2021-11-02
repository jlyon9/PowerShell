# Remove all Azure users from local administrator (for Azure-joined machines)

# Get all local admins
$administrators = @(
([ADSI]"WinNT://./Administrators").psbase.Invoke('Members') | % { 
    $_.GetType().InvokeMember('AdsPath','GetProperty',$null,$($_),$null) 
    }
) -match '^WinNT';

#Formatting
$administrators = $administrators -replace "WinNT://","" -replace  "AzureAD/","AzureAD\"

# Remove all Azure users (keep local users intact) from Admin Group
$administrators | % {
    if ($_ -like "$env:COMPUTERNAME/*" -or $_ -like "AzureAd/*") {
    continue;
    }
    Remove-LocalGroupMember -group "administrators" -member $administrator
}

# reference:
# https://superuser.com/questions/1131901/get-localgroupmember-generates-error-for-administrators-group
