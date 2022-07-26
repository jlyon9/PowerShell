#AUTHOR: James Lyon
#Version: 0.5
#Date: 7/26/22

If ($null -eq $Connection) {$Connection = Connect-AzAccount}

Write-Host @"
Do you want to create a firewall rule for:
    [1] A single sql server
    [2] All servers in a resource group
    [3] All servers in a subscription
"@

$grouptype = Read-Host "    Enter a number for your selection [1-3]"

Switch ($grouptype) {
    1 {$grouptype = 'Server'}
    2 {$grouptype = 'ResourceGroup'}
    3 {$grouptype = 'Subscription'}
    }

$rulename = Read-Host 'Enter the new Firewall rule name'
$rulestart = Read-Host 'Enter the starting IP address'
$ruleend = Read-Host 'Enter the ending IP address'
$fwrule = @{
Name = $rulename
StartIp = $rulestart
EndIp = $ruleend
}

Switch ($grouptype) {
 'Server' {
            $selectflow1 = Read-Host "Enter the server name if you know it or type 'search' for a list"
                    
                    Switch ($selectflow1) {

                        {$selectflow1.ToLower() -ne "search"} {
                            $selectflow1 = $servername                            
#Find sql server
                            $selectserver = Get-AzSqlServer | ? {$_.ServerName -eq $servername}
                            $newrule = New-AzSqlServerFirewallRule -ServerName $selectserver.ServerName -ResourceGroupName $selectserver.ResourceGroupName -FirewallRuleName $fwrule.Name -StartIpAddress $fwrule.StartIp -EndIpAddress $fwrule.EndIp
                            Write-Host 'Rule created:'
                            $newrule
                        }

                        {"search".ToLower()} {
#select subscription of server
                            $allsubs = Get-AzSubscription | Select Name,Id
                            $n=0
                            $allsubs | % {
                            $n = $n+1
                            Write-Host "[$n]" $_.Name}
                            $n = Read-Host "Enter a number to select the subscription the SQL server is located in"
                            $selectsub = $allsubs[($n-1 -as [int])]
                            $context = Set-AzContext -Subscription $selectsub.Id
                            
#Find sql server
                            $allservers = Get-AzSqlServer | Select ServerName,ResourceGroupName
                            $ns=0
                            $allservers | % {
                            $ns = $ns+1
                            Write-Host "[$ns]" $_.ServerName}
                            $ns = Read-Host "Enter a number for the SQL server you wish to create a firewall permit rule for"
                            $selectserver = $allservers[($ns-1 -as [int])]
#Create rule on server
                            $newrule = New-AzSqlServerFirewallRule -ServerName $selectserver.ServerName -ResourceGroupName $selectserver.ResourceGroupName -FirewallRuleName $fwrule.Name -StartIpAddress $fwrule.StartIp -EndIpAddress $fwrule.EndIp
                            Write-Host 'Rule created:'
                            $newrule
                            }
                    }
 }

'ResourceGroup' {
 #Select subscription
                    $allsubs = Get-AzSubscription | Select Name,Id
                    $n=0
                    $allsubs | % {
                    $n = $n+1
                    Write-Host "[$n]" $_.Name}
                    $n = Read-Host "Enter a number for the subscription you wish to create a SQL Server firewall permit rule for"
                    $selectsub = $allsubs[($n-1 -as [int])]
                    #$selectsub = $allsubs | ? {$_.Name -eq $subscription[$n].Name}
                    $context = Set-AzContext -Subscription $selectsub.Id
#Get resource groups
                    $allrg = Get-AzResourceGroup | Select ResourceGroupName
                    $n=0
                    $allrg | % {
                    $n = $n+1
                    Write-Host "[$n]" $_.ResourceGroupName}
                    $n = Read-Host "Enter a corresponding resource group number to create a firewall permit rule for ALL SQL Servers in the resource group"
                    $selectrg = $allrg[($n-1 -as [int])]
                    $allrgservers = Get-AzSqlServer -ResourceGroupName $selectrg.ResourceGroupName | Select ServerName,ResourceGroupName
#Create rule on all servers in RG
                    $allrgservers | % {
                        $newrule = New-AzSqlServerFirewallRule -ServerName $_.ServerName -ResourceGroupName $_.ResourceGroupName -FirewallRuleName $fwrule.Name -StartIpAddress $fwrule.StartIp -EndIpAddress $fwrule.EndIp
                        Write-Host 'Rule created:'
                        $newrule
                        }
 }

'Subscription' {
#Get and set subscription & all servers in subscription
                    $allsubs = Get-AzSubscription | Select Name,Id
                    $n=0
                    $allsubs | % {
                    $n = $n+1
                    Write-Host "[$n]" $_.Name}
                    $n = Read-Host "Enter a number for the subscription you wish to create firewall permit rule for ALL SQL Servers in"
                    $selectsub = $allsubs[($n-1 -as [int])]
                    $context = Set-AzContext -Subscription $selectsub.Id
                    $allsubservers = Get-AzSqlServer | Select ServerName,ResourceGroupName
#Create rule on all servers in sub                   
                    $allsubservers | % {
                        $newrule = New-AzSqlServerFirewallRule -ServerName $_.ServerName -ResourceGroupName $_.ResourceGroupName -FirewallRuleName $fwrule.Name -StartIpAddress $fwrule.StartIp -EndIpAddress $fwrule.EndIp}
                        Write-Host 'Rule created:'
                        $newrule
                    }
}
