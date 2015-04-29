#Appsync API STUFFzzzzz

#####Global Var#######
$Global:cookie = $null
$Global:server =$null
$Global:baseuri=$null
$Global:secpassword=$null
$Global:username=$null
######################

#Starts a new session (logs into cas server and stores cookie as $session)
function New-AppSyncSession([string]$server,[string]$username,[string]$password, [string]$credspath){

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
    
    $baseuri = "https://$server"+':8445'+"/appsync/rest"
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
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/types/servicePlan/instances"
 
 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry

}
#Gets a Service Plan
function Get-ServicePlan{

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
function New-AppSyncGen1DBCopy($dbid){
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
  $limit = New-TimeSpan -Minutes 1
  $timer = [diagnostics.stopwatch]::StartNew()

  while($timer.Elapsed -lt $limit){
  $status=($process | Get-PhaseStatus)
  if($status.overallState -eq "Complete"){
      Write-Host -ForeGroundColor Green "Process complete with status:"$status.overallStatus
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
  
  #generate XML payloud for new service plan
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

 

  while($timer.Elapsed -lt $limit){
  $status=($process | Get-PhaseStatus)
  if($status.overallState -eq "Complete"){
      Write-Host -ForeGroundColor Green "Process complete with status:"$status.overallStatus
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

function Mount-AppsyncCopy{
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

 


}
#need a DBID/ID of DB copy
function Unmount-AppSyncCopy([string] $dbid){

$baseuri = $Global:baseuri
$session = $Global:cookie

$uri = "$baseuri/instances/sqlServerDatabase::$dbid/relationships/mountPhasepit"

#Get the mount status of the copy/db, save the phasepit ID for use in unmount operation. 

$phasepitid = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session).feed.entry.content.phasepit.id



$uri = "$baseuri/instances/phasepit::$phasepitid/action/run"
$unmountxml = [xml](Get-Content "$PSScriptRoot\unmount.xml")
$body = ($unmountxml.OuterXml)

$phaseid = (Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/xml" -WebSession $session).feed.entry

    Write-Host "Unmount Phase Initiated..."
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

}




function Get-RepurposeServicePlans(){
$baseuri = $Global:baseuri
$session = $Global:cookie

$uri = "$baseuri/types/servicePlan/instances?application=sql&planType=Repurposing"

$data = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session).feed.entry

$sps = $data | Where title -NotLike "*UNUSED*" | Select-Object

return $sps



}

#Given root database ID, returns all copies 
function Get-AppSyncSQLDatabaseCopies([string] $dbid){

$baseuri = $Global:baseuri
$session = $Global:cookie

$uri = "$baseuri/instances/sqlServerDatabase::$dbid/relationships/copies"

$data = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session).feed.entry

return $data | Sort-Object -Property updated -Descending

}



###########################
##SQL Related Commands#####
###########################
function Get-AppSyncSQLDatabases(){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/types/sqlServerDatabase/instances"
 
 $data = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session)

 return $data.feed.entry.content.sqlServerDatabase


}

function Get-AppSyncSQLInstances(){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/types/sqlServerInstance/instances"
 
 $data = (Invoke-RestMethod -Uri $uri -Method Get -WebSession $session)

 return $data.feed.entry.content.sqlServerInstance


}

function Get-AppSyncHosts(){
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
Write-Host -ForegroundColor Yellow "Current state is : $state"
Write-Host -ForegroundColor Yellow "Current status is : $status"

$data

}

function Get-PhasePitStatus{
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
Write-Host -ForegroundColor Yellow "Current state is : $state"
Write-Host -ForegroundColor Yellow "Current status is : $status"

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

