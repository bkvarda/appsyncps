# AppSyncPS

AppSyncPS wraps AppSync REST API calls into PowerShell functions

## Installation

Place all contents into your PowerShell Module folder, or use Import-Module

##Usage
Once imported start the session:
```
New-AppSyncSession -user <appsync username> -password <password> -server <appsync server name or IP, no ports>
```
You can get all service plans like this:
```
Get-ServicePlans
```
You can run service plans like this:
```
Run-ServicePlan -id <full service plan id uri>
```
Piping service plan IDs also works:
```
Get-ServicePlans | Where title -eq "serviceplan sql bronze" | Run-ServicePlan
```
This runs all service plans:
```
Get-ServicePlans | ForEach-Object { Run-ServicePlan -id $_.id }
```
More to come...maybe

##Licensing
Licensed under the Apache License, Version 2.0 (the .License.); you may not use this file except in compliance with the License. You may 
obtain a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an .AS IS. 
BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions
and limitations under the License.