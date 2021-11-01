reg load "hku\Default" "C:\Users\Default\NTUSER.DAT"
reg add "hkey_users\default\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" /v "PeopleBand" /t "REG_DWORD" /d "0" /f
reg unload "hku\Default"
$users = (Get-ChildItem -path c:\users).name
foreach($user in $users)
    {
        reg load "hku\$user" "C:\Users\$user\NTUSER.DAT"
        reg add "hkey_current_user\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" /v "PeopleBand" /t "REG_DWORD" /d "0" /f
        reg unload "hku\$user"
    }  
