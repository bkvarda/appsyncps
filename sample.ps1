$dbname = "sandwich"

New-AppSyncSession -server msappsync -credspath C:\temp

Get-AppSyncSQLDatabases | Where name -eq $dbname | Remove-AllCopies -Verbose

Get-AppSyncSQLDatabases | Where name -eq $dbname | New-AppSyncMassGen2 -list C:\code\appsyncps\hostlist.csv -Verbose