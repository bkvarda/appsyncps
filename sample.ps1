
$numservers = 5
$dbid = "a0e171ed-e723-4dfb-8ba4-04cf1afab0fa"

New-AppSyncSession -server lrma109 -credspath C:\temp

Write-Host "Creating our single G1 copy"
$g1 = (New-AppSyncGen1DBCopy -dbid $dbid)



Write-Host "Creating 5 G2 copies"
for($i = 0; $i -lt $numservers; $i++){

 New-AppSyncGen2DBCopy -dbid $g1.dbid -spid $g1.spid

}