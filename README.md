# AppSyncPS

AppSyncPS wraps AppSync REST API calls into PowerShell functions. This is currently intended for SQL workflows. 

## Installation

Place all contents into your [PowerShell Module folder](https://msdn.microsoft.com/en-us/library/dd878350%28v=vs.85%29.aspx), or use [Import-Module](https://technet.microsoft.com/en-us/library/hh849725.aspx)

##Usage
Once imported start the session:
```
New-AppSyncSession -user <appsync username> -password <password> -server <appsync server name or IP, no ports>
```
If you want to script this completely with secure credentials, do this first (one time per user, per host):
```
New-AppSyncSecureCreds -path <path where you want to store encrypted creds, IE C:\temp>
```
Then you can do this in your script:
```
New-AppSyncSession -server <appsync server name or IP, no ports> -credspath <place you stored creds, IE C:\temp>
```
You can get all service plans like this:
```
Get-ServicePlans
```
You can run service plans like this:
```
Run-ServicePlan -spid <service plan unique identifier IE 89c8ee2a-835d-4c68-bd4f-e36f60440d9a>
```
Piping service plan IDs also works:
```
Get-ServicePlans | Where title -eq "serviceplan sql bronze" | Run-ServicePlan
```
This runs all service plans:
```
Get-ServicePlans | ForEach-Object { Run-ServicePlan -id $_.id }
```
This returns info about all hosts:
```
Get-AppSyncHosts
```
This returns info about all SQL Instances:
```
Get-AppSyncSQLInstances
```
This returns info about all SQL Databases:
```
Get-AppSyncSQLDatabases
```
This creates a 1st Generation copy of a DB
```
New-AppSyncGen1DBCopy -dbid <ID of DB you want to copy>
```
This creates a 2nd Generation copy of a DB
```
New-AppSyncGen2DBCopy -spid <ID of 1st Generation Copy Service Plan> -dbid <ID of DB you want to copy>
```
You can query a source DB, grab the ID, create a 1st gen copy, create a 2nd gen copy of it, and mount it like this:
```
Get-AppSyncSQLDatabases | Where Name -eq "POC" | New-AppSyncGen1DBCopy | New-AppSyncGen2DBCopy | Mount-AppSyncCopy -mounthost "Host1" -mountpath "Default Path" -accesstype "readonly"
```
You can refresh a DB copy like this:
```
Get-AppSyncSQLDatabaseCopies | Where Name -eq "POC01" | Refresh-AppSyncDatabaseCopy
```
You can unmount all mounted Gen 2 DB copies like this:
```
Get-AppSyncSQLDatabaseCopies | Where Generation -eq "2" -and Mount_Status -eq "Mounted" | Unmount-AppSyncCopy 
```
You can orderly refresh all Gen 1 and Gen 2 databases associated with a gold/primary DB (takes care of unmounts and remounts as well):
```
Get-AppSyncSQLDatabases | Where Name -eq "POC" | Refresh-AllAppSyncDatabaseCopies 
```

More to come...maybe

##Licensing
Licensed under the Apache License, Version 2.0 (the .License.); you may not use this file except in compliance with the License. You may 
obtain a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an .AS IS. 
BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions
and limitations under the License.