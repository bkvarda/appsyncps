
$numservers = 5
$dbid = "ca4ff8f0-7348-4540-b8d5-ac3d1c411a98"

New-AppSyncSession -server msappsync -credspath C:\temp

Write-Host "Creating our single G1 copy"
$g1 = (New-AppSyncGen1DBCopy -dbid $dbid)



Write-Host "Creating 5 G2 copies"
for($i = 0; $i -lt $numservers; $i++){

 New-AppSyncGen2DBCopy -dbid $g1.dbid -spid $g1.spid

}