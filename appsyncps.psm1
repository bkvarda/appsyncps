#Appsyncps
#Author: Brandon Kvarda

#####Global Var#######
$Global:cookie = $null
$Global:server =$null
$Global:baseuri=$null
$Global:secpassword=$null
$Global:username=$null
######################

#Starts a new session (logs into cas server and stores cookie as $session)
function New-AppSyncSession{

[cmdletbinding()]

Param (
    [parameter()]
    [string]$server,

    [parameter()]
    [string]$username,
    
    [parameter()]
    [string]$password,

    [parameter()]
    [string]$credspath

  )

#This bypasses cert validation
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    #if we're using secure credential files, unencrypt creds for login to cas-server
    if($credspath){
        
        $pwdlocation = $credspath + "\appsyncpwd.txt"
        $userlocation = $credspath + "\appsyncuser.txt"
        
        $username = Get-Content $userlocation
        $secpassword = Get-Content $pwdlocation | ConvertTo-SecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secpassword)
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }

     else{
    
    $username = Read-Host -Prompt "Enter AppSync username"
    $password = Read-Host -Prompt "Enter password" -AsSecureString
    }  
     
    
    $baseuri = "https://"+$server+':8445'+"/appsync/rest"
    $loginuri = "https://"+$server+":8444/cas-server/login?TARGET=https://"+$server+":8445/appsync/" 
    

    #go to login url, grab cookie
    $request = Invoke-WebRequest -Uri $loginuri -SessionVariable session

    $form = $request.Forms[0]
    $form.Fields["username"] = $username
    $form.Fields["password"] = $password

    #login to login url
    $auth = Invoke-RestMethod -Uri $loginuri -WebSession $session -Method Post -Body $form.Fields

    #store server info and session info for further calls
    $Global:cookie = $session
    $Global:server = $server
    $Global:baseuri = $baseuri
    $Global:secpassword = $secpassword
    $Global:username = $username
}
#############################
#Service Plan Commands
#############################

#Gets list of Service Plans
function Get-ServicePlans(){

    <#
     .DESCRIPTION
      Returns a list of defined service plans 
      
      .EXAMPLE
      Get-ServicePlans
  #>
  [cmdletbinding()]
  
  Param()

 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/types/servicePlan/instances"
 
 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry

}
#Gets a Service Plan
function Get-ServicePlan{

[cmdletbinding()]
Param (
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$id,

    [parameter()]
    [string]$spid

  )
 
 if($id){$spid = $id}
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/instances/servicePlan::$spid"

 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry

}

#Runs Service Plans, can take full Service Plan id from pipeline or specified uuid <$spid>
function Run-ServicePlan {
  Param (
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$id,

    [parameter()]
    [string]$spid

  )

    <#
     .DESCRIPTION
      Runs a Service plan. Can pipe full URI id from Get-ServicePlans or used the unique identifier spid 
      
      .PARAMETER $id
      Full URI passed from Get-ServicePlans. This can be piped directly from Get-ServicePlans
      .PARAMETER $spid
      Unique Service Plan ID (looks like 89c8ee2a-835d-4c68-bd4f-e36f60440d9a)
      .EXAMPLE
      Run-ServicePlan -spid 89c8ee2a-835d-4c68-bd4f-e36f60440d9a
      .EXAMPLE
      Get-ServicePlans | Where title -eq "serviceplan sql bronze"| Run-ServicePlan
  #>
  
  $session = $Global:cookie
  $baseuri = $Global:baseuri
  if($id){
  $uri = "$id/action/run"
  }
  else{
  $uri = "$baseuri/instances/servicePlan::$spid/action/run"
  }
  $data = Invoke-RestMethod -Uri $uri -Method Post -WebSession $session
  
  return $data.feed.entry
}

#########################
#Run Repurpose Workflows#
#########################


# id = unique identifier of DB
function New-AppSyncGen1DBCopy{
  [cmdletbinding()]
  Param (
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$id,
    [string]$dbid
)

  if($id){
   $dbid = $id
  }
  $session = $Global:cookie
  $baseuri = $Global:baseuri
  $result =  New-Object PSObject

  $db = (Invoke-RestMethod -Uri "$baseuri/instances/sqlServerDatabase::$dbid" -Method Get -WebSession $session).feed.entry.content.sqlServerDatabase
  
  $dbinstance = (Invoke-RestMethod -Uri "$baseuri/instances/sqlServerDatabase::$dbid/relationships/sqlServerInstance" -Method Get -WebSession $session).feed.entry.content.sqlServerInstance
  
  $instanceid = $dbinstance.id
 
  $dbhost = (Invoke-RestMethod -Uri "$baseuri/instances/sqlServerInstance::$instanceid/relationships/host" -Method Get -WebSession $session).feed.entry.content.host
  
  
  #change content of template to new name of Gen1
  $time = Get-Date -UFormat "%Y %M %D %H %S %p"
  $g1xml = [xml](Get-Content "$PSScriptRoot\g1.xml")
  $g1xml.servicePlan.name.'#text' = $db.name+" $time "+"1.1" 
  $g1xml.servicePlan.displayName.'#text' = $db.name+" $time "+"1.1"


  
  #generate XML payloud for new service plan
  $body = ($g1xml.OuterXml)
  
  $uri = "$baseuri/types/servicePlan/instances"
  
  #create the new 'service plan' for the g1
  $data = (Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/xml" -WebSession $session)

  

  #new service plan data
  $sp = $data.feed.entry
  $spid = $sp.content.servicePlan.id

  #change content of dataset template
  $dsxml = [xml](Get-Content "$PSScriptRoot\dataset.xml") 
  $dsxml.dataset.options.option[0].value = ($dbhost.name).toString()
  $dsxml.dataset.options.option[1].value = ($dbinstance.name).toString()
  $dsxml.dataset.options.option[2].value = ($db.name).toString()

  #generate XML payload for new dataset tied to new service plan
  $body = ($dsxml.OuterXml)


  $dsuri = "$baseuri/types/dataset/instances?servicePlan=$spid"

  #create the new dataset tied to new service plan
  $ds = (Invoke-RestMethod -Uri $dsuri -Method Post -Body $body -ContentType "application/xml" -WebSession $session)
  


  #run the service plan 
  $process = ($sp |Run-ServicePlan)
  
  Write-Host "Gen1 Copy Initiated..."
  $limit = New-TimeSpan -Minutes 2
  $timer = [diagnostics.stopwatch]::StartNew()

  while($timer.Elapsed -lt $limit){
  $status=($process | Get-PhaseStatus)
  if($status.overallState -eq "Complete"){
      Write-Host "Process complete with status:"$status.overallStatus
      Re-Auth
      break
  }
  Start-Sleep -Seconds 5

 }
  $copyuri = "$baseuri/instances/servicePlan::$spid/relationships/copies"
  $data =  (Invoke-RestMethod -Uri $copyuri -Method Get -WebSession $session).feed.entry.content.sqlServerDatabase
  $copyid = $data.id
  $result | Add-Member NoteProperty –Name dbid –Value $copyid
  $result | Add-Member NoteProperty –Name spid –Value $spid
  return $result

 
}

function New-AppSyncGen2DBCopy{

[cmdletbinding()]

Param (
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$dbid,
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$spid
)
  
  $session = $Global:cookie
  $baseuri = $Global:baseuri
  $result =  New-Object PSObject

  $db = (Invoke-RestMethod -Uri "$baseuri/instances/sqlServerDatabase::$dbid" -Method Get -WebSession $session).feed.entry.content.sqlServerDatabase
  
  $dbinstance = (Invoke-RestMethod -Uri "$baseuri/instances/sqlServerDatabase::$dbid/relationships/sqlServerInstance" -Method Get -WebSession $session).feed.entry.content.sqlServerInstance
  
  $instanceid = $dbinstance.id
 
  $dbhost = (Invoke-RestMethod -Uri "$baseuri/instances/sqlServerInstance::$instanceid/relationships/host" -Method Get -WebSession $session).feed.entry.content.host

  $next2g = (Invoke-RestMethod -Uri "$baseuri/instances/servicePlan::$spid/action/next2ndGenName" -Method Post -WebSession $session).feed.entry.content.servicePlan
 
  
  #change content of template to new name of Gen2
  $time = Get-Date -UFormat "%Y %M %D %H %S %p"
  $g2xml = [xml](Get-Content "$PSScriptRoot\g2.xml")
  $g2xml.servicePlan.name.'#text' = ($next2g.name.'#text').toString()
  $g2xml.servicePlan.displayName.'#text' = ($next2g.displayName.'#text').toString()
  
  #generate XML payload for new service plan
  $body = ($g2xml.OuterXml)
  
  $uri = "$baseuri/types/servicePlan/instances"
  
  #create the new 'service plan' for the g2
  $data = (Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/xml" -WebSession $session)

  #new service plan data
  $sp = $data.feed.entry
  $spid = $sp.content.servicePlan.id

  #change content of dataset template
  $dsxml = [xml](Get-Content "$PSScriptRoot\dataset.xml") 
  $dsxml.dataset.options.option[0].value = ($dbhost.name).toString()
  $dsxml.dataset.options.option[1].value = ($dbinstance.name).toString()
  $dsxml.dataset.options.option[2].value = ($db.name).toString()

  #generate XML payload for new dataset tied to new service plan
  $body = ($dsxml.OuterXml)


  $uri = "$baseuri/types/dataset/instances?servicePlan=$spid"

  #create the new dataset tied to new service plan
  $ds = (Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/xml" -WebSession $session)


  #run the service plan 
  $process = ($sp |Run-ServicePlan)
  
  Write-Host "Gen2 Copy Initiated..."
  $limit = New-TimeSpan -Minutes 1
  $timer = [diagnostics.stopwatch]::StartNew()

 
  #monitor the progress
  while($timer.Elapsed -lt $limit){
  $status=($process | Get-PhaseStatus)
  if($status.overallState -eq "Complete"){
      Write-Host "Process complete with status:"$status.overallStatus
      Re-Auth
      break
  }
  Start-Sleep -Seconds 5

 }
 #return the service plan id and the new copy id aka dbid
  $copyuri = "$baseuri/instances/servicePlan::$spid/relationships/copies"
  $data =  (Invoke-RestMethod -Uri $copyuri -Method Get -WebSession $session).feed.entry.content.sqlServerDatabase
  $copyid = $data.id
  $result | Add-Member NoteProperty –Name dbid –Value $copyid
  $result | Add-Member NoteProperty –Name spid –Value $spid
  return $result


}

function Mount-AppsyncCopy{

[cmdletbinding()]

Param (
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$dbid,
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$spid,
    [string]$mounthost,
    [string]$mountpath,
    [string]$accesstype

)
  $session = $Global:cookie
  $baseuri = $Global:baseuri

  #format the mount XML payload
  $mountxml = [xml](Get-Content "$PSScriptRoot\mount.xml") 
  $mountxml.servicePlan.phase.options.option[0].value = $mounthost
  $mountxml.servicePlan.phase.options.option[1].value = $mountpath
  $mountxml.servicePlan.phase.options.option[2].value = $accesstype
  $mountxml.servicePlan.dataset.options.option.value = $dbid

  $body = ($mountxml.OuterXml)

  
  $pituri = "$baseuri/instances/sqlServerDatabase::$dbid/relationships/replicationPhasepit"

  $date = (Invoke-RestMethod -Uri $pituri -Method Get -WebSession $session)

  $pitid = $date.feed.entry.content.phasepit.id

  #get the PID to execute mount against
  $uri = "$baseuri/instances/phasepit::$pitid/action/run?StartPhaseName=Mount-Copy"

  #mount the copy to the given host
  $phaseid = (Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/xml" -WebSession $session).feed.entry


    Write-Host "Mount Phase Initiated..."
  $limit = New-TimeSpan -Minutes 10
  $timer = [diagnostics.stopwatch]::StartNew()

   while($timer.Elapsed -lt $limit){
  $status=($phaseid | Get-PhasePitStatus)
  if($status.state -eq "Complete"){
      Write-Host -ForeGroundColor Green "Process complete with status:"$status.status
      Re-Auth
      break
  }
  Start-Sleep -Seconds 10

 }

 $status.status


}
#need a DBID/ID of DB copy
function Unmount-AppSyncCopy{

[cmdletbinding()]

Param(
[parameter()]
[string]$dbid


)

$baseuri = $Global:baseuri
$session = $Global:cookie

$uri = "$baseuri/instances/sqlServerDatabase::$dbid/relationships/mountPhasepit"

#Get the mount status of the copy/db, save the phasepit ID for use in unmount operation. 

$phasepitid = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session).feed.entry.content.phasepit.id


#build the xml payload and request
$uri = "$baseuri/instances/phasepit::$phasepitid/action/run"
$unmountxml = [xml](Get-Content "$PSScriptRoot\unmount.xml")
$body = ($unmountxml.OuterXml)

#initiate the unmount
$phaseid = (Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/xml" -WebSession $session).feed.entry
  
  #Monitor unmount status
  Write-Host "Unmount Phase Initiated..."
  $limit = New-TimeSpan -Minutes 15
  $timer = [diagnostics.stopwatch]::StartNew()

   while($timer.Elapsed -lt $limit){
  $status=($phaseid | Get-PhasePitStatus)
  if($status.state -eq "Complete"){
      Write-Host -ForeGroundColor Green "Process complete with status:"$status.status
      Re-Auth
      break
  }
  Start-Sleep -Seconds 10

 }
 $status.status
}




function Expire-AppSyncSQLDatabaseCopy{

[cmdletbinding()]

Param (
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$id


)
$baseuri = $Global:baseuri
$session = $Global:cookie

$uri = "$baseuri/instances/sqlServerDatabase::$id/action/expire"

Write-Host "Expiring $id"

$data = (Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/xml" -WebSession $session)

$data


}

#Creates a G1 and X number of G2s depending on hostlist and mounts to specified location 
function New-AppSyncMassGen2{

[cmdletbinding()]

Param(
    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName)]
    [string]$id,
    [parameter(Mandatory=$true)]
    [string]$list
)

$summary = @()
$baseuri = $Global:baseuri
$session = $Global:cookie

$hostlist = Import-CSV $list 

#Create a G1 copy 
$g1 = (New-AppSyncGen1DBCopy -id $id)

#If the G1 succeeded, asynchronously make X # of G2s based on the host list
if($g1.dbid){

  #Make a bunch of G2s
  Foreach ($server in $hostlist){
   $result =  New-Object PSObject
   $result | Add-Member NoteProperty -Name Host -Value $server.Hostname
   $result | Add-Member NoteProperty -Name Mount_Path -Value $server.Mount_Path
   $result | Add-Member NoteProperty -Name Access_Type -Value $server.Access_Type

   $g2 = (New-AppSyncGen2DBCopy -dbid $g1.dbid -spid $g1.spid)
      #if the creation succeeded
      if($g2.dbid){
        $result | Add-Member NoteProperty -Name Last_Snap -Value "Success"
        Start-Sleep -Seconds 10

        $mountstatus = (Mount-AppsyncCopy -dbid $g2.dbid -spid $g2.spid -mounthost $server.Hostname -mountpath $server.Mount_Path -accesstype $server.Access_Type)
        $result | Add-Member NoteProperty -Name Last_Mount -Value $mountstatus

      }
      else{

        $result | Add-Member NoteProperty -Name Last_Snap -Value "Failed"

      }
    $summary += $result

  }

  return $summary

 }
}


#Cleans up all existing copies for a given DB
function Remove-AllCopies{

[cmdletbinding()]

Param(
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$id
)

$baseuri = $Global:baseuri
$session = $Global:cookie

$copydata = (Get-AppSyncSQLDatabaseCopies -dbid $id)

$g1data = $copydata | Where Generation -eq "1" | Select-Object
$g2data = $copydata | Where Generation -eq "2" | Select-Object

    foreach ($g2 in $g2data){
        $unmountstatus = "Success"

        if($g2.Mount_Status -eq "Mounted"){
        $unmountstatus = Unmount-AppSyncCopy -dbid $g2.ID
        }
         if($unmountstatus -eq "Success"){
            Expire-AppSyncSQLDatabaseCopy -id $g2.ID
         }
     Re-Auth
    }

    foreach($g1 in $g1data){
        $unmountstatus = "Success"

        if($g1.Mount_Status -eq "Mounted"){
        $unmountstatus = Unmount-AppSyncCopy -dbid $g1.ID
        }
        if($unmountstatus -eq "Success"){
            Expire-AppSyncSQLDatabaseCopy -id $g1.ID
         }
      Re-Auth
    }

    Write-Host "Done"




}

function Get-RepurposeServicePlans{

[cmdletbinding()]

Param()

$baseuri = $Global:baseuri
$session = $Global:cookie

$uri = "$baseuri/types/servicePlan/instances?application=sql&planType=Repurposing"

$data = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session).feed.entry

$sps = $data | Where title -NotLike "*UNUSED*" | Select-Object

return $sps



}

function Get-AppSyncMountInfo{

[cmdletbinding()]

Param(
[parameter()]
[string]$dbid

)
$baseuri = $Global:baseuri
$session = $Global:cookie

$uri = "$baseuri/instances/sqlServerDatabase::$dbid/relationships/mountPhasepit"

$options = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session).feed.entry.content.phasepit.phase.options.option

$hash = @{}

  foreach ($option in $options){
    
    $hash.Add($option.name,$option.value)

  }
$hash

}

#Given root database ID, returns all copies 
function Get-AppSyncSQLDatabaseCopies{

[cmdletbinding()]

Param (
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$ID,
    [string]$dbid
)

if($ID){
$dbid = $ID}

$baseuri = $Global:baseuri
$session = $Global:cookie

$output =  @()

$uri = "$baseuri/instances/sqlServerDatabase::$dbid/relationships/copies?GUI=true&CATALOGONLY=false"

$data = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session).feed.entry.content.sqlServerDatabase

    $data | ForEach-Object {
         $result =  New-Object PSObject

         $result | Add-Member NoteProperty -Name Name -Value $_.name
         $result | Add-Member NoteProperty -Name Last_Modified -Value $_.lastModifiedFormatted
         $result | Add-Member NoteProperty -Name ID -Value $_.id
         $result | Add-Member NoteProperty –Name Generation –Value $_.copyRepurposeGeneration
         $result | Add-Member NoteProperty –Name Parent_ID –Value $_.copyRepurposeParentCopy
         $result | Add-Member NoteProperty –Name Mount_Status –Value $_.copyMountStatus
         $result | Add-Member NoteProperty –Name Host –Value $_.host
         $result | Add-Member NoteProperty –Name Instance –Value $_.instanceName

         $output += $result

    }

 return $output

}



###########################
##SQL Related Commands#####
###########################
function Get-AppSyncSQLDatabases{
 
 [cmdletbinding()]

 Param()
 
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $output =  @()
 $uri = "$baseuri/types/sqlServerDatabase/instances"
 
 $data = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session).feed.entry.content.sqlServerDatabase


    $data | ForEach-Object {
         $result =  New-Object PSObject

         $currentid = $_.id
         $uri = "$baseuri/instances/sqlServerDatabase::$currentid/relationships/sqlServerInstance"
         $instance = (Invoke-RestMethod -Method Get -Uri $uri -WebSession $session).feed.entry.content.sqlServerInstance.name
          
         $result | Add-Member NoteProperty -Name Name -Value $_.name
         $result | Add-Member NoteProperty -Name Last_Modified -Value $_.lastModifiedFormatted
         $result | Add-Member NoteProperty -Name ID -Value $_.id
         $result | Add-Member NoteProperty –Name DB_Status –Value $_.databaseStatus
         $result | Add-Member NoteProperty -Name Instance_Name -Value $instance

         $output += $result

    }

 $output


}

function Get-AppSyncSQLInstances{
 
 [cmdletbinding()]

 Param()
 
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/types/sqlServerInstance/instances"
 
 $data = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session)

 return $data.feed.entry.content.sqlServerInstance


}

function Get-AppSyncHosts{
 
 [cmdletbinding()]

 Param()
 
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/types/host/instances"
 
 $data = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session)

 return $data.feed.entry.content.host


}

###########################
###Error Handling/Status###
###########################

function Get-PhaseStatus{
[cmdletbinding()]
Param (
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$id
)

$baseuri = $Global:baseuri
$session = $Global:cookie
$uri = "$id/relationships/phaseStatus"
 

$data = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session).feed.entry.content.phaseStatus
$status = ($data.overallStatus)
$state = ($data.overallState)
Write-Verbose "Current state is : $state"
Write-Verbose "Current status is : $status"

$data

}

function Get-PhasePitStatus{
[cmdletbinding()]
Param (
    [parameter(ValueFromPipelineByPropertyName)]
    [string]$id
)

$baseuri = $Global:baseuri
$session = $Global:cookie
$uri = "$id"
 

$data = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session).feed.entry.content.phasepit
$status = ($data.phase.phaseProgressLabel)
$state = ($data.state)
Write-Verbose "Current state is : $state"
Write-Verbose "Current status is : $status"

$data

}



######################
#Helpers##############
######################

function New-AppSyncSecureCreds([string] $path)
{

   <#
     .DESCRIPTION
      Creates secure credential files so that passwords are not stored in plain text in scripting environments. Only have to do this once per user/account per host. 
      
      .PARAMETER $path
      Specifies the location of stored credentials made using the New-AppSyncSecureCreds function. Do not put trailing '\'
      .EXAMPLE
      New-AppSyncSecureCreds -path C:\temp
  #>

  $pwdpath = $path + "\appsyncpwd.txt"
  $unamepath = $path + "\appsyncuser.txt"
  $creds = Get-Credential
  $creds.Username | Set-Content $unamepath
  $creds.Password | ConvertFrom-SecureString | Set-Content $pwdpath 

  Write-Host -ForegroundColor Green "Secure credentials set in directory $path"

}
function Re-Auth(){

    [cmdletbinding()]

    $server = $Global:server
    $secpassword = $Global:secpassword
    $username = $Global:username

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secpassword)
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    
    $loginuri = "https://"+$server+":8444/cas-server/login?TARGET=https://"+$server+":8445/appsync/" 
    

    #go to login url, grab cookie
    $request = Invoke-WebRequest -Uri $loginuri -SessionVariable session

    $form = $request.Forms[0]
    $form.Fields["username"] = $username
    $form.Fields["password"] = $password

    #login to login url
    $auth = Invoke-RestMethod -Uri $loginuri -WebSession $session -Method Post -Body $form.Fields

    #store server info and session info for further calls
    $Global:cookie = $session

}

