#Appsync API STUFFzzzzz
$Global:cookie = $null
$Global:username =$null
$Global:password =$null
$Global:server =$null
$Global:baseuri=$null


function New-AppSyncSession([string]$server,[string]$username,[string]$password){
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
    
    $baseuri = "https://$server"+':8445'+"/appsync/rest"
    $loginuri = "https://"+$server+":8444/cas-server/login?TARGET=https://"+$server+":8445/appsync/" 
    $body = @{Username = $username; Password = $password}

    $request = Invoke-WebRequest -Uri $loginuri -SessionVariable session

    $form = $request.Forms[0]
    $form.Fields["username"] = $username
    $form.Fields["password"] = $password

    $auth = Invoke-RestMethod -Uri $loginuri -WebSession $session -Method Post -Body $form.Fields

    $Global:cookie = $session
    $Global:username = $username
    $Global:password = $password
    $Global:server = $server
    $Global:baseuri = $baseuri
}

#Gets list of Service Plans
function Get-ServicePlans(){
 $session = $Global:cookie
 $baseuri = $Global:baseuri
 $uri = "$baseuri/types/servicePlan/instances"
 
 $data = Invoke-RestMethod -Uri $uri -Method Get -WebSession $session

 return $data.feed.entry

}

#Runs Service Plans, can take Service Plan id from pipeline or specified full URI id
function Run-ServicePlan {
  Param (
    [parameter(ValueFromPipelineByPropertyName)]
    [string[]]$id

  )
  $session = $Global:cookie
  $baseuri = $Global:baseuri
  $uri = "$id/action/run"
  $data = Invoke-RestMethod -Uri $uri -Method Post -WebSession $session
  
  return $data.feed.entry
}

