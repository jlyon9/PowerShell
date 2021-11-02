Add-Type -AssemblyName System.web
Import-Module -Name PSGSuite

function connectMS{
    #Credentials
    $username = "offboard@contoso.com"
    $securePwd = Get-Content "C:\crds\offboard.txt" | ConvertTo-SecureString
    $UserCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePwd

    #Connections
    Connect-MsolService -Credential $UserCredential
    Connect-AzureAD -Credential $UserCredential
    Connect-SPOService -Url https://contoso-admin.sharepoint.com -Credential $UserCredential
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
    Import-PSSession $Session -AllowClobber
}

function evalterm{
param ( [string]$tdate )

    #current date
    #https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-date?view=powershell-6
    $cdate = Get-Date -UFormat "%Y-%m-%d %R"
    $tdate = $tdate + " 18:29"
    if ($tdate -le $cdate) {
        return $true
    }
    else {
        return $false
    }
}

function blockacct {
param( [object[]]$uobj, $logfile )
    #Set GSuite username
    $uname = $uobj.UserPrincipalName.Split("@")[0]
    $gsuser = "$uname@contoso.com"
    #Suspend GSuite User
    Update-GSUser -User $gsuser -Suspended -Confirm:$false
    #Kill sessions
    Revoke-SPOUserSession -User $uobj.UserPrincipalName -Confirm:$false
    Get-AzureAdUser -SearchString $uobj.DisplayName | Revoke-AzureADUserAllRefreshToken
    #Block Sign-in
    Set-MsolUser -UserPrincipalName $uobj.UserPrincipalName -BlockCredential $true
    #generate new random password
    $newpass = [system.web.security.membership]::GeneratePassword(10,3)
    #Set random password
    Set-MsolUserPassword -UserPrincipalName $uobj.UserPrincipalName -NewPassword $newpass
    #Conver mailbox to shared
    Get-Mailbox -identity $uobj.UserPrincipalName | set-mailbox -type “Shared”
    #Set mailbox hidden
    Set-Mailbox -Identity $uobj.UserPrincipalName -HiddenFromAddressListsEnabled $true
    #Search for and block associated Guest accountss
    Get-AzureADUser -SearchString $uobj.DisplayName | ? {$_.UserType -eq "Guest"} | % {if ($_) {Set-AzureADUser -ObjectId $_.ObjectId -AccountEnabled $False}}
    if((Get-MsolUser -UserPrincipalName $uobj.UserPrincipalName | Select BlockCredential) -eq $true){
    Return $true}
    Else {Return $false}
}

function removegroups {
param ( [object[]]$uobj, $logfile )
    ####################
    #Identify and remove ownerships
    $allazgroupown = Get-AzureAdUserOwnedObject -ObjectId $uobj.UserPrincipalName | Select ObjectId, DisplayName, Description
    if ($allazgroupown) {
        $uobj.userprincipalname + " Group Ownerships:" | Out-File $logfile -Append
        $allazgroupown | Select ObjectId,DisplayName,Description | Out-File $logfile -Append
        }
    #O365 Groups
    $allazgroupown | % {Get-UnifiedGroup -Identity $_.DisplayName -ErrorAction 'SilentlyContinue'} | % {Remove-UnifiedGroupLinks -Identity $_.DisplayName -LinkType Owners -Links $uobj -Confirm:$false}
    #Security Groups
    $allazgroupown | ? Mail -eq $null | Select ObjectId,DisplayName | % {Remove-MsolGroupMember -GroupObjectId $_.ObjectId -GroupMemberObjectId $uobj.ObjectId}
    #Exchange Groups
    $exown = Get-DistributionGroup | ? {$_.ManagedBy -eq ($uobj.UserPrincipalName.Split("@")[0])} | % {Set-DistributionGroup -Identity $_.DisplayName -ManagedBy @{Remove=$uobj.UserPrincipalName} -BypassSecurityGroupManagerCheck}

    #####################
    #Identify and remove memberships
    #Get All Groups:
    $allgroupmem = Get-AzureAdUserMembership -ObjectId $uobj.ObjectId | Select ObjectId, DisplayName, Description
    if($allgroupmem) {
        $uobj.userprincipalname + " Group Memberships:" | Out-File $logfile -append
        $allgroupmem | Select ObjectId,DisplayName,Description | Out-File $logfile -append
        }
    #O365 Groups
    $allgroupmem | % {Get-UnifiedGroup -Identity $_.DisplayName -ErrorAction 'SilentlyContinue'} | % {Remove-UnifiedGroupLinks -Identity $_.DisplayName -LinkType Members -Links $uobj.UserPrincipalName -Confirm:$false}
    #Security Groups
    $allgroupmem | ? Mail -eq $null | Select ObjectId,DisplayName | % {Remove-MsolGroupMember -GroupObjectId $_.ObjectId -GroupMemberObjectId $uobj.ObjectId}
    #Exchange Groups
    $allgroupmem | ? {($_.DisplayName -notin $o365groups.DisplayName) -and ($_.DisplayName -notin $secgroups.DisplayName)} | % {Remove-DistributionGroupMember -Identity $_.DisplayName -Member $uobj.UserPrincipalName -Confirm:$false -BypassSecurityGroupManagerCheck}
    #Mail-Enabled Security Groups - Consolidated to "Exchange Groups" above
    #$mesgroups = $allgroupmem | Where-Object {($_.MailEnabled -eq $True) -and ($_.SecurityEnabled -eq $True)}
    Return $true
}

function transferGSdata {
    param($logpath)
    $listfiles = Get-ChildItem -Path "$logpath\UserLists\*.csv" | ? {$_.CreationTime -lt ((Get-Date).AddDays(-7))} | Select Name
    $listfiles.Name | % {Import-CSV "$logpath\UserLists\$_" | % {
                                                                $gsuser = ($_.Email).Split("@")[0] + "$uname@contoso.com"
                                                                Start-GSDataTransfer -OldOwnerUserId $gsuser -NewOwnerUserId backup@contoso.com -ApplicationId 12345678901 -PrivacyLevel SHARED,PRIVATE
                                                                }
                        }
}

function removeGSlicense {
}

function removeO365license {
param( [object[]]$uobj, $logfile )
    $count = 5
    while (($null -eq $mail) -and ($count -gt 0)) {
                             $mail = Get-Mailbox -Identity $uobj.UserPrincipalName | ? {$_.RecipientTypeDetails -eq "SharedMailbox"}
                             $count = ($count -1)
                             if ($null -ne $mail) {$count = 0}
                             if ($null -eq $mail) {
                                                   Get-Mailbox -identity $uobj.UserPrincipalName | set-mailbox -type “Shared”
                                                   Start-Sleep -Seconds 30
                                                   #Set mailbox hidden
                                                   Set-Mailbox -Identity $uobj.UserPrincipalName -HiddenFromAddressListsEnabled $true
                                                  }
                             Write-Host $count
                             }
    if ($null -eq $mail) {"***NOTE: " + $uobj.UserPrincipalName + " could not be converted to shared mailbox, O365 license not removed" | Out-File $logfile -Append}
    if ($null -ne $mail) {(Get-MsolUser -UserPrincipalName $uobj.UserPrincipalName).licenses.AccountSkuID | % {Set-MsolUserLicense -UserPrincipalName $uobj.UserPrincipalName -RemoveLicenses $_}
                          Return $true}
}

#Process terminations
function processterminations{
param($xmlfiles, $logpath)

    foreach ($u in $xmlfiles) {

        #Read individual XML file contents
        [xml]$user = Get-Content $u.name
        $date = Get-Date -UFormat "%Y-%m-%d"
        $email = $user.myFields.EmployeeEmailLookup
        $uname = $user.myFields.EmployeeEmailLookup.Split("@")[0]
        $ulogfile = "$logpath\User\$uname" + "_$date.txt"
    
        #call function "evaluate user" (for termination date)
        $termcheck = evalterm -tdate $user.myFields.'Employee-TermDate'

        if ($termcheck -eq $true) {

            #get user
            $uobj = Get-MsolUser -UserPrincipalName $email

            if ($null -ne $uobj) {
                #call function "remove user access"
                $blockresult = blockacct -uobj ($uobj) -logfile $ulogfile

                #call function "remove group memberships"
                $rmgrpresult = removegroups -uobj ($uobj) -logfile $ulogfile

                #call "remove license"
                $rmO365license = removeO365license -uobj ($uobj) -logfile $ulogfile

                if ($blockresult) {"Account $uname blocked" | Out-File "$logpath\Process\TermLog_$date.txt" -Append
                                   #Append username to daily term csv
                                   if (![System.IO.File]::Exists("$logpath\UserLists\userlist_$date.csv")) {"Email" | Out-File "$logpath\UserLists\userlist_$date.csv" -Append}
                                   $uobj.UserPrincipalName | Out-File "$logpath\UserLists\userlist_$date.csv" -Append
                                  }
                else {"Account $uname not blocked" | Out-File "$logpath\Process\TermLog_$date.txt" -Append}
                
                if($rmO365license) {"Licenses removed from $uname" | Out-File "$logpath\Process\TermLog_$date.txt" -Append}
                else {"Licenses NOT removed from $uname" |Out-File "$logpath\Process\TermLog_$date.txt" -Append}

                if ($rmgrpresult) {"$uname removed from all groups" + "`n" | Out-File "$logpath\Process\TermLog_$date.txt" -Append}
                
                Move-Item -Path ($path + "\" + $u.Name) -Destination ($path + "\Complete\" + $user.myFields.EmployeeEmailLookup + ".xml") -Force
            }

            else {
                "$uname could not be found, Exit Checklist moved to error subfolder" + "`n" | Out-File "$logpath\Process\TermLog_$date.txt" -Append
                Move-Item -Path ($path + "\" + $u.Name) -Destination ($path + "\Error\" + $user.myFields.EmployeeEmailLookup + ".xml") -Force
            }
        }
    }
    Move-Item -Path "$logpath\Process\*.txt" -Destination "$logpath" -Force
}

#Archive log files on last day of each month
function archivelogs {
    param($logpath)
    if ([DateTime]::Today.AddDays(+1).ToString("dd") -eq "01") {
        $ym = [DateTime]::Today.ToString("yyyy-MM")
        #Process Main Termlogs
        $newpath = "$logpath\Archive\$ym"
        New-Item -Path "$newpath" -ItemType "directory" -Force
        Move-Item -Path "$logpath\*$ym*.txt" -Destination $newpath

        #Process User Termlogs
        $newusrpath = "$logpath\User\Archive\$ym"
        New-Item -Path "$newusrpath" -ItemType "directory" -Force
        Move-Item -Path "$logpath\User\*$ym*.txt" -Destination $newusrpath

        #Process UserLists
        $newlistpath = "$logpath\UserLists\Archive\$ym"
        New-Item -Path "$newlistpath" -ItemType "directory" -Force
        Move-Item -Path "$logpath\UserLists\*.csv" -Destination $newlistpath
    }
}

function checkterminated {
param($xmlfiles)
    foreach ($u in $xmlfiles) {
        $date = Get-Date -UFormat "%Y-%m-%d"
        [xml]$user = Get-Content $u.name
        $email = $user.myFields.EmployeeEmailLookup
        $uname = $user.myFields.EmployeeEmailLookup.Split("@")[0]
        Get-MsolUser -UserPrincipalName $email | Select UserPrincipalName,BlockCredential | ? {$_.BlockCredential -eq $false} | Out-File "C:\ExitChecklist\Reactivated\reactivated_accounts_$date.txt" -Append
    }
}

function checkterminatedGS {
param($xmlfiles)
    foreach ($u in $xmlfiles) {
        [xml]$user = Get-Content $u.name
        $email = $user.myFields.EmployeeEmailLookup
        $uname = $user.myFields.EmployeeEmailLookup.Split("@")[0]
        $uobj = Get-MsolUser -UserPrincipalName $email | Select UserPrincipalName
        $gsuname = $uobj.UserPrincipalName.Split("@")[0]
        $gsuser = "$gsuname@contoso.com"
        #Suspend GSuite User
        if ($null -ne {Get-GSUser -User $gsuser | ? {$_.Suspended -eq $false}}) {Write-Host "$gsuser"}
        }
}

function checkterminatedMailboxes {
param($xmlfiles)
    foreach ($u in $xmlfiles) {
        [xml]$user = Get-Content $u.name
        $email = $user.myFields.EmployeeEmailLookup
            if (($user.myFields.'Employee-TermDate') -ge $pdate) {
                $mail = Get-Mailbox -Identity $email | ? {$_.RecipientTypeDetails -eq 'Shared'}
                if ($null -eq $mail) {"$email" | Out-File C:\Temp\SMUsers.csv -Append}
            }
        }
}

connectServices

#Import XMLs
#$xmlfiles = Get-ChildItem -Path $path *.xml

$path = "C:\ExitChecklist\"
cd $path
#cd $path1
$logpath = "$path\Logs"

processterminations -xmlfiles (Get-ChildItem -Path $path *.xml) -logpath $logpath
archivelogs -logpath $logpath

Remove-Variable path
$path = "C:\ExitChecklist\Complete"
cd $path

#checkterminated -xmlfiles (Get-ChildItem -Path $path *.xml)
#checkterminatedGS -xmlfiles (Get-ChildItem -Path $path *.xml)
#checkterminatedMailboxes -xmlfiles (Get-ChildItem -Path $path *.xml)

Remove-PSSession $Session
email_message "terminate user script - completed"
