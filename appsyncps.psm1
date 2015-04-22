#Appsync API STUFFzzzzz

#####Global Var#######
$Global:cookie = $null
$Global:server =$null
$Global:baseuri=$null
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
    $body = @{Username = $username; Password = $password}

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
function Get-ServicePlan([string] $spid){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/instances/servicePlan::$spid"

 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry

}

#Gets service plan datasets
function Get-ServicePlanDataSets([string] $spid){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/instances/servicePlan::$spid/relationships/datasets"

 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry

}

#Gets service plan apps
function Get-ServicePlanApplications([string] $spid){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/instances/servicePlan::$spid/relationships/applications"

 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry

}

#Gets service plan copies
function Get-ServicePlanCopies([string] $spid){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/instances/servicePlan::$spid/relationships/copies"

 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry

}

#Gets service plan log backups
function Get-ServicePlanLogBackups([string] $spid){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/instances/servicePlan::$spid/relationships/logBackups"

 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry

}

#Gets service plan users
function Get-ServicePlanUsers([string] $spid){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/instances/servicePlan::$spid/relationships/users"

 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry

}



#Gets service plan phases
function Get-ServicePlanPhases([string] $spid){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/instances/servicePlan::$spid/relationships/phases"

 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry

}

#Gets service plan phasepits
function Get-ServicePlanPhasePits([string] $spid){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/instances/servicePlan::$spid/relationships/phasepits"

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
#############################
#Phase Commands
#############################
function Get-PhaseCopies([string]$prid){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/instances/phase::$prid/relationships/copies"

 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry


}

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

