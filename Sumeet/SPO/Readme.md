# PowersShell Script to remove user permission from SPO tenant
This script will be used to remove user or log user permission in your SPO tenant 

## Pre-requisite 
1. Need to run using tenant admin credentials
2. SharePoint Client SDK it can be downloaded from (https://www.microsoft.com/en-in/download/details.aspx?id=42038)


## Parameters
1. **TenantAdminUrl**: = Provide tenant admin url.
2. **Username**: Provide tenant administrator username.
3. **password**: Provide tenant admistrator password.
4. **loginName**: Provide login name for the user which needs to be deleted or whose permission log needs to be generated.
5. **DeleteUser**: This is a parameter flag which will be set to "Yes" if the user needs to be removed else provide "No".
6. **NavigateItemLevel**: This is a parameter flag which will be set to "Yes" if item level permission check is needed. Not suggestable if the farm is big. Choose "No" if not needed.

## Instruction for running script

### **Please follow the below steps to execute the script**. 
1. Download "siteexclusion.csv","Load-CSOMProperties.ps1" and "Sumeet_CSOMPermission.ps1"  in a folder on your system. 
2. Change the .dll path if SharePoint Client Component SDK is not installed using the MSI file from the above given url 
3. Include all the site collection url which needs to be exculeded in this process. If all sites needs for this process then delete this file.
4. Open PowersShell Console with "Run as Administrator"
5. Change directory using cd to the path where above files were downloaded
6. Run script using the below command
`.\Sumeet_CSOMPermission.ps1`
7. Provide all the parameter value once the powershell prompt for the same 


## OutPut 
All the running output will be logged on powershell console. Once the script running is completed it will create a csv file with reports on permission 