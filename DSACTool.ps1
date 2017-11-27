
$manager = "dsm.domain.local"
$Port = "4119"
$managerUri="https://" + $manager + ":" + $port + "/rest/"
$authUri = $managerUri + "authentication/login/primary"
$headers = @{'Content-Type'='application/json'}
$ReportFile	= "$PSScriptRoot\DSACTool_AC_Global_Rulesets.csv"
$AddSourceFile = "$PSScriptRoot\DSACTool_AC_Global_AddSourceList.txt"
$DelSourceFile = "$PSScriptRoot\DSACTool_AC_Global_DelSourceList.txt"

$ErrorActionPreference = 'SilentlyContinue'
$PSVersionRequired = "3"

$MenuList = @"
	1: Search for a Rule by Hash Value.
	2: List AC Global Ruleset to Screen.
	3: Export AC Global Ruleset to a File.
	
	4: Add a New Block Rule.
	5: Add New Rules by Answer File.
	
	6: Delete a Rule by ID.
	7: Delete a Rule by Hash.
	8: Delete Rules by Answer File.
	
	Q: Quit.
"@

Function MyLog { 
    param (	[parameter(Mandatory=$true)] $OutputFile,
			[parameter(Mandatory=$true)] $msg	) 
			
		Write-Output "$msg" | Out-File $OutputFile -append
} 


Function Connect-DSM {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback={$true}
		
	$DSM_Cred	= Get-Credential -Message "Enter DSM Credentials"
	$DSM_ID		= $DSM_Cred.GetNetworkCredential().UserName
	$DSM_PASS	= $DSM_Cred.GetNetworkCredential().Password
	
	$creds = @{
		dsCredentials = @{
			userName = $DSM_ID
	    	password = $DSM_PASS
			}
	}
	$AuthData = $creds | ConvertTo-Json			
	
	try{
		$Global:sID = Invoke-RestMethod -Uri $authUri -Method Post -Body $AuthData -Headers $headers 		
	}
	catch{
		echo "[ERROR]	Failed to logon to DSM.	$_"
		echo "An error occurred during authentication. Verify username and password and try again. `nError returned was: $($_.Exception.Message)"
		Exit 
	}
	
	$cookie = new-object System.Net.Cookie
	$cookie.name = "sID"
	$cookie.value =  $sID
	$cookie.domain = $manager
	$Global:WebSession = new-object Microsoft.PowerShell.Commands.WebRequestSession
	$WebSession.cookies.add($cookie)	
}

function ListRules {
$URI = $managerUri + "rulesets/global"
$RulesObj = Invoke-RestMethod -Uri $URI -Method Get -WebSession $WebSession
$MyRules = $RulesObj.DescribeGlobalRulesetResponse.ruleset

$MyRules1 = $MyRules | ConvertTo-Json
Write-Host $MyRules1
}

function ExportRules {
	$URI = $managerUri + "rulesets/global"
	$RulesObj = Invoke-RestMethod -Uri $URI -Method Get -WebSession $WebSession
	$MyRules = $RulesObj.DescribeGlobalRulesetResponse.ruleset
	$RuleCount = $MyRules.rules.Count
	MyLog -OutputFile $ReportFile -msg "RuleID	SHA256	Action	Description"
	$i = 0
	Do {		
		$RuleID = $MyRules.rules[$i].ruleID
		$SHA256 = $MyRules.rules[$i].sha256
		$Action = $MyRules.rules[$i].action
		$Description = $MyRules.rules[$i].description

		$DRSData = "$RuleID	$SHA256	$Action	$Description"
		#echo $DRSData
		MyLog -OutputFile $ReportFile -msg $DRSData
		$i++
	} While ($i -lt $RuleCount)
	Write-Host "Global Rulesets has been exported"
	pause 
	clear
}

function AddRule {
	param (	[parameter(Mandatory=$true)] $SHA,
			[parameter(Mandatory=$true)] $Description,
			[parameter(Mandatory=$true)] $Action	) 

	$GlobalRule = @{
		AddGlobalRulesetRulesRequest = @{
			rules = @{
					sha256 = $SHA
					action = $Action
					description = $Description
				}
		}
	}

	$RuleID = LookupRuleID -Hash $SHA
	if ($RuleID -ne $Null) {
		write-Host "Rule with the following Hash already exist: $SHA"	
	} Else {
		write-Host "Adding new rule."	
		$GlobalRuleJSON = $GlobalRule | ConvertTo-Json
		$URI = $managerUri + "rulesets/global/rules"
		try{
			$RulesObj = Invoke-RestMethod -Uri $URI -Method Post -WebSession $WebSession -Body $GlobalRuleJSON -Headers $headers		
		}
		catch{
			echo "[ERROR]	Failed to create rule.	$_"
			echo "An error occurred during rule creation. Error returned was: $($_.Exception.Message)"
		}
	}
}

function AddBlockRule {
	$Hash = Read-Host "Please Enter The sha256 Hash Value"
	$description = Read-Host "Please Enter The Rule Description"
	$action = "block"
	AddRule -SHA $Hash -Description $Description -Action $Action
	write-Host "Adding new rule Completed."
	pause
	clear
}

Function AddRulesList {
	$RulesList = IMPORT-CSV $AddSourceFile
	FOREACH ($Entry in $RulesList) {
		$Hash = $Entry.Hash
		$Description = $Entry.Description
		$Action = "block"
		AddRule -SHA $Hash -Description $Description -Action $Action

		}
	Write-Host "Adding new rule Completed."
}

function DelRule {
	param (	[parameter(Mandatory=$true)] $RuleID	) 

	$URI = $managerUri + "rulesets/global/rules/" + $RuleID
	try{
		$RulesObj = Invoke-RestMethod -Uri $URI -Method Delete -WebSession $WebSession -Headers $headers	
	}
	catch{
		echo "[ERROR]	Failed to Delete rule.	$_"
		echo "An error occurred during rule creation. Error returned was: $($_.Exception.Message)"
	}
}

function DelRuleByID {
	$RuleID = Read-Host "Please enter the RuleID number"
	DelRule -RuleID $RuleID
	Write-Host "Rule ID $RuleID has been deleted"
	Pause
	Clear
}

function DelRuleByHash {
	$SHA256 = Read-Host "Please Enter The SHA256 Hash Value"
	$RuleID = LookupRuleID -Hash $SHA256
	
	If ($RuleID -eq $Null) {
		Write-Host "Hash does not exist"	
	} Else {
		DelRule -RuleID $RuleID
		Write-Host "Rule ID $RuleID has been deleted"
	}	
	Pause
	Clear
}

function DelRuleList {
	$HashList = Get-Content $DelSourceFile
	Foreach ($Hash in $HashList) {
		$RuleID = LookupRuleID -Hash $Hash		
		If ($RuleID -eq $Null) {
			Write-Host "Hash does not exist"	
		} Else {
			DelRule -RuleID $RuleID
			Write-Host "Rule ID $RuleID has been deleted"
		}
	}
	Pause
	Clear
}

function SearchRules {
	$SHA256 = Read-Host "Please Enter The SHA256 Hash Value"
	$RuleID = LookupRuleID -Hash $SHA256
	
	If ($RuleID -eq $Null) {
		Write-Host "Hash does not exist"	
	} Else {	
		Write-Host "Your Rule ID is: $RuleID"
	}
}

Function LookupRuleID {
	param (	[parameter(Mandatory=$true)] $Hash ) 
	$URI = $managerUri + "rulesets/global"
	$RulesObj = Invoke-RestMethod -Uri $URI -Method Get -WebSession $WebSession
	$Ruleset = $RulesObj.DescribeGlobalRulesetResponse.ruleset
	$RuleCount = $Ruleset.rules.Count
	$i = 0
	Do {
		$Existing_SHA256 = $Ruleset.rules[$i].sha256
		if ($Existing_SHA256 -eq $Hash){
			$Existing_RuleID = $Ruleset.rules[$i].RuleID
			return $Existing_RuleID
			}
		$i++
	} While ($i -lt $RuleCount)
	return $null
}

Clear
Connect-DSM

do {
	 $input = Read-Host $MenuList
     switch ($input)
     {
			'1' {	SearchRules	}
			'2' {	ListRules	}
			'3' {	ExportRules	}
			'4' {	AddBlockRule	}
			'5' {	AddRulesList	}
			'6' {	DelRuleByID	}
			'7' {	DelRuleByHash	}
			'8' {	DelRuleList	}
			'q' {	return}
     }
} Until ($input -eq 'q')
