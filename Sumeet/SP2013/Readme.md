# PowersShell Script to remove user permission from SP 2013/2016 farm
This script will be used to remove user or log user permission 

## Pre-requisite 
1. Need to run using farm admin credential
2. Need to run from one of the farm server


## Parameters
1. **$Userid**: Provide login name for the user which needs to be deleted or whose permission log needs to be generated.
2. **$ReportPath**: Provide complete path where the reports will reside e.g. "C:\testfoler\report.csv".
3. **$ReportPath**: This is a parameter flag which will be set to "Yes" if the user needs to be removed else provide "No"

## Instruction for running script

### **Please follow the below steps to execute the script**. 
1. Download "User Access Remove.ps1" in a folder on your system. 
2. Open PowersShell Console with "Run as Administrator"
3. Change directory using cd to the path where above files were downloaded
4. Run script using the below command
`.\User Access Remove.ps1.ps1`
5. Provide all the parameter value once the powershell prompt for the same 


## OutPut 
All the running output will be logged on powershell console. Once the script running is completed it will create a csv file with reports on permission 