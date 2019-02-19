# DSACTool
AUTHOR		: Yanni Kashoqa

TITLE		: Deep Security Application Control Block by Hash

VERSION		: 0.6

DESCRIPTION	: This Powershell script will perform the addition and deletion of Global Block Hashes in Deep Security.

FEATURES
The ability to perform the following:-
- Add a Block rule, verify if rule exist
- Add entries from an answer file, verify if rule exist
- Delete via a single hash
- Delete hashes via answer file
- list/search via hash

REQUIRMENTS
- Supports Deep Security as a Service
- PowerShell 3.0 and higher
- Login name and password with role "Full Access" assigned to it
- Create a DS-Config.json in the same folder with the following content making sure to fill the Tenant information.
{
    "MANAGER": "app.deepsecurity.trendmicro.com",
    "PORT": "443",
    "TENANT": ""
}

PS. SourceList files include sample data.  Please update to include actual data.
