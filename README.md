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
You can unmount all mounted Gen 2 DB copies like this:
```
Get-AppSyncSQLDatabaseCopies | Where Generation -eq "2" -and Mount_Status -eq "Mounted" | Unmount-AppSyncCopy 
```
You can create a series of gen2 copies and mount them to specified hosts/paths like this (use the hostlist.csv in this repo as a template):
```
Get-AppSyncSQLDatabases | Where Name -eq "POC" | New-AppSyncMassGen2 -list C:\code\appsyncps\hostlist.csv 
```
You can clean up all copies of specified database (unmount and expire) like this:
```
Get-AppSyncSQLDatabases | Where Name -eq "POC" | Remove-AllCopies
```
You can see all the calls by adding the -Verbose flag to everything

More to come...maybe

##Support
Please file bugs and issues at the Github issues page. For more general discussions you can contact the EMC Code team at <https://groups.google.com/forum/#!forum/emccode-users>. The code and 
documentation are released with no warranties or SLAs and are intended to be supported through a community driven process.  

##Licensing
The MIT License (MIT)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.