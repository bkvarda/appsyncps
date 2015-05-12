

$numservers = @('1','2','3','4','5')
$dbid = "a363fe64-d960-4d7a-9ce9-ed6991faa1c0"

New-AppSyncSession -server msappsync -credspath C:\temp

Write-Host "Creating our single G1 copy"
$g1 = (New-AppSyncGen1DBCopy -dbid $dbid -Verbose)



Write-Host "Creating 5 G2 copies"

workflow Test-Worflow
{
[cmdletbinding()]
param([PSObject]$gen1)


    ForEach -Parallel ($server in $numservers){

         New-AppSyncGen2DBCopy -dbid $gen1.dbid -spid $gen1.spid -Verbose

    }
}
Test-Worflow -gen1 $g1 -Verbose