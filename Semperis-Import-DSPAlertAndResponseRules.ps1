
<#
.SYNOPSIS
    Imports or exports Semperis DSP Alert and Response Rules for Active Directory and Entra ID.

.DESCRIPTION
    This script connects to the Semperis DSP Management Console, verifies licensing and system health,
    and allows for backup (export) or import of alert and response rules for Active Directory or Entra ID.
    It supports error handling, logging, and conditional import options.

.PARAMETER Server
    Target server name of the DSP Management Console.

.PARAMETER Credential
    Credentials in the format domain\username for authentication.

.PARAMETER Mode
    Operation mode: 'export' to backup rules, 'import' to import rules.

.PARAMETER ImportFilePath
    File path for rules to import (required for import mode), must be a valid JSON file.

.PARAMETER Type
    Type of rules: 'ActiveDirectory' or 'EntraID' (required for import mode).

.PARAMETER ContinueOnImportError
    Continue importing rules if an error occurs (default: $false), this allows the script to skip rules that fail to import such as DN not found.

.PARAMETER DomainDN
    Domain Distinguished Name, when specified the scrip will replace the default DN in the rule template of "DC=ad,DC=dsp-dev,DC=net" with the provided value. If not specified, the script will import the rules as is.

.PARAMETER EmailAddress
    Email address to use for notification rules, if not specified the email address from the rule will be used.

.EXAMPLE
    .\Semperis-Import-DSPAlertAndResponseRules.ps1 -Server dsp-dev-ms01.ad.dsp-dev.net -Mode export -Credential (Get-Credential) 

.EXAMPLE
    .\Semperis-Import-DSPAlertAndResponseRules.ps1 -Server dsp-dev-ms01.ad.dsp-dev.net -Mode import -Credential (Get-Credential)  -ImportFilePath "C:\rules.json" -Type ActiveDirectory

.EXAMPLE
    .\Semperis-Import-DSPAlertAndResponseRules.ps1 -Server dsp-dev-ms01.ad.dsp-dev.net -Mode import -Credential (Get-Credential) -ImportFilePath C:\rules.json -Type ActiveDirectory -ContinueOnImportError $True -DomainDN "DC=ad,DC=dsp-dev,DC=net" -EmailAddress "dsp-alerts@ad.dsp-dev.net"

.EXAMPLE
.\Semperis-Import-DSPAlertAndResponseRules.ps1 -Server dsp-dev-ms01.ad.dsp-dev.net -Mode import -Credential (Get-Credential) -ImportFilePath C:\rules.json -Type EntraID -ContinueOnImportError $True -EmailAddress "dsp-alerts@ad.dsp-dev.net"


.NOTES
    Author: krisss@semperis.com
    Requires: PowerShell 5.1+, Semperis DSP Management Console API access
    Updates: 
        2025-08-22 - Changed Entra ID/IAS logic check
        2025-08-26 - Email import/update verification logic changed
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Target server name or IP address")]
    [string]$Server,
    
    [Parameter(Mandatory = $true, HelpMessage = "Enter credentials in the format domain\username")]
    [System.Management.Automation.PSCredential]$Credential,
    
    [Parameter(Mandatory = $true, HelpMessage = "Operation mode: backup or import")]
    [ValidateSet("export", "import")]
    [string]$Mode,
    
    [Parameter(Mandatory = $false, HelpMessage = "File path (required when mode is import)")]
    [string]$ImportFilePath,
    
    [Parameter(Mandatory = $false, HelpMessage = "Type: ad or eid")]
    [ValidateSet("ActiveDirectory", "EntraID")]
    [string]$Type,

    [Parameter(Mandatory = $false)]
    [ValidateSet($true, $false)]
    [bool]$ContinueOnImportError = $false,
    
    [Parameter(Mandatory = $false, HelpMessage = "Domain Distinguished Name")]
    [string]$DomainDN,
    
    [Parameter(Mandatory = $false, HelpMessage = "Email address")]
    [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string]$EmailAddress
)

if($null -eq $Credential){
    Write-Host "Invalid credentials provided, exiting." -ForegroundColor Red
    break
}
else{
    $Username = $Credential.UserName
    $Password = [System.Net.NetworkCredential]::new("", $Credential.Password).Password
}

# Validate conditional mandatory parameters
if ($Mode -eq "import") {
    if ([string]::IsNullOrEmpty($Type)) {
        throw "Type parameter is mandatory when Mode is 'import'"
    }
    if ([string]::IsNullOrEmpty($ImportFilePath)) {
        throw "Import file path parameter is mandatory when Mode is 'import'"
    }

    #if (-not $PSBoundParameters.ContainsKey('ContinueOnImportError')) {
        #throw "ContinueOnImportError parameter is mandatory when Mode is 'import' (`$true or `$false)."
    #}
}

#this is the DN of the forest the rules were exported from
$ExampleDN = "DC=ad,DC=dsp-dev,DC=net"

#this is the default script path and the folder will be precreated
$currentDate = Get-Date -Format yyyy-MM-dd_hhmmss

#current path for logs and backups
$currentPath = $PSScriptRoot

$fExportPath = "$currentPath\Export"
if(!(Test-Path -Path $fExportPath)){ New-Item -Path $fExportPath -ItemType Directory | Out-Null}

$fLogFilePath = "$currentPath\Logs"
if(!(Test-Path -Path $fLogFilePath)){ New-Item -Path $fLogFilePath -ItemType Directory | Out-Null }
$fLogFilePath = "$fLogFilePath\Semperis-DSPAlertAndResponseRules-Log-$currentDate.log"

Start-Transcript -Path $fLogFilePath 


#endpoints
$uriServerConsole = "https://$server/DSP"
$uriLogin						= "$uriServerConsole/api/Login"
$uriLoginGetToken              	= "$uriServerConsole/api/Login/GetToken"
$uriLoginGetParams              = "$uriServerConsole/api/Main/GetParams"
$uriLicenseGetLicenseInfo 		= "$uriServerConsole/api/License/GetLicenseInfo"
$uriBackgroundActionsStatus 	= "$uriServerConsole/api/BackgroundActions/Status"
$uriNotificationsGetRulesAD 	= "$uriServerConsole/api/Notifications/GetRules"
$uriNotificationsSaveRuleAD 	= "$uriServerConsole/api/Notifications/SaveRule"
$uriNotificationsGetRulesEID 	= "$uriServerConsole/api/Notifications/GetAadRules"
$uriNotificationsSaveRuleEID 	= "$uriServerConsole/api/Notifications/SaveAadRule"

#self signed certificate warnings
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

##functions

Function Show-DSPBanner {
    Write-Host "================================================================================" 
    Write-Host "    ___  __    ___     __       _                                               " 
    Write-Host "   /   \/ _\  / _ \   /__\_   _| | ___  /\/\   ____ _ __   __ _  __ _  ___ _ __ " 
    Write-Host "  / /\ /\ \  / /_)/  / \// | | | |/ _ \/    \ / _' | '_ \ / _' |/ _' |/ _ \ '__|" 
    Write-Host " / /_// _\ \/ ___/  / _  \ |_| | |  __/ /\/\ \ (_| | | | | (_| | (_| |  __/ |   " 
    Write-Host "/____/  \__/\/      \/ \_/\__,_|_|\___\/    \/\__,_|_| |_|\__,_|\__, |\___|_|   " 
    Write-Host "                                                                |___/           " 
    Write-Host "krisss@semperis.com                                                             "  -ForegroundColor Magenta
    Write-Host "================================================================================" 
}

Function Export-DSPAlertAndResponseRules {
    param (
        [string]$fExportPath,
        [System.Boolean]$licensedEntraID
    )

    $exportDate = Get-Date -Format yyyy-MM-dd_hhmmss

    $fRuleExportPathAD = $fExportPath + "\DSP-AlertAndResponseRules-AD-$exportDate.json"
    $fRuleExportPathEID = $fExportPath + "\DSP-AlertAndResponseRules-EID-$exportDate.json"

    try{
       $responseRulesAD = Invoke-RestMethod -UseBasicParsing -Uri $uriNotificationsGetRulesAD -WebSession $session -Method Get

    }
    catch {
        Write-Host "AD rules could not be retrieved: $uriNotificationsGetRulesAD" -ForegroundColor Red
        Stop-Transcript
        break 
    }

    if($null -ne $responseRulesAD){
        $responseRulesAD | ForEach-Object { $_ | Add-Member -NotePropertyName "Import" -NotePropertyValue $true -Force }        
        
        
        try{
            $responseRulesAD | ConvertTo-Json -Depth 100 | Out-File -FilePath $fRuleExportPathAD -Encoding utf8 -Force
            Write-Host "+ AD rules exported: $fRuleExportPathAD"
        }
        catch{
            Write-Host "AD rules could not be exported: $fRuleExportPathAD" -ForegroundColor Red
            Stop-Transcript
            break
        }
    }
    elseif($null -eq $responseRulesAD){
        Write-Host "~ no AD rules returned: $uriNotificationsGetRulesAD" -ForegroundColor Yellow
    }

    #Entra ID rules
    if($licensedEntraID -eq $true){
        try{
           $responseRulesEID = Invoke-RestMethod -UseBasicParsing -Uri $uriNotificationsGetRulesEID -WebSession $session -Method Get

        }
        catch {
            Write-Host "Entra ID rules could not be retrieved: $$uriNotificationsGetRulesEID" -ForegroundColor Red
            Stop-Transcript
            break 
        }

        if($null -ne $responseRulesAD){
            $responseRulesEID | ForEach-Object { $_ | Add-Member -NotePropertyName "Import" -NotePropertyValue $true -Force }        
                
            try{
                $responseRulesEID | ConvertTo-Json -Depth 100 | Out-File -FilePath $fRuleExportPathEID -Encoding utf8 -Force
                Write-Host "+ Entra ID rules exported: $fRuleExportPathAD"
            }
            catch{
                Write-Host "Entra ID rules could not be exported: $fRuleExportPathEID" -ForegroundColor Red
                Stop-Transcript
                break
            }
        }
        elseif($null -eq $responseRulesAD){
            Write-Host "~ no Entra ID rules returned: $uriNotificationsGetRulesEID" -ForegroundColor Yellow
        }
    }
}

Function Import-DSPAlertAndResponseRulesAD {
    param (        
        [boolean]$ContinueOnImportError,
        [string]$ImportFilePath,
        [string]$DomainDN,
        [string]$EmailAddress
    )

    if(Test-Path -Path $ImportFilePath){
        try{
            $rulesToImport = Get-Content -Path $ImportFilePath | ConvertFrom-JSON        
        }
        catch{
            Write-Host "Rules could not be imported from file: $ImportFilePath" -ForegroundColor Red
            Stop-Transcript
            break
        }

        if($null -eq $rulesToImport){
            Write-Error "Import file empty: $ImportFilePath"
            Stop-Transcript
            break
        }

        $dataSource = "ad"

        #check the first rule to check the datasource          
        if($rulesToImport[0].DataSource -ne $dataSource){
            Write-Host "Rule import mismatch, attempting to import ActiveDirectory rules with an Entra ID rule file?" -ForegroundColor Red                
            Stop-Transcript
            break
        }

        #start the import
        
        $countRuleImportFailed = 0
        $countRuleImportSuccess = 0
        $countRuleImportSkipped = 0

        #unix timestamp required for API POST requests
        $unixTimeStamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
        
        #format the url for import depending on type
        $uriNotificationsGetRulesFormatted = $uriNotificationsGetRulesAD + "/?_"+$unixTimeStamp+"&tabId="+$tabId                       
    
        try{
            $existingRules = Invoke-RestMethod -UseBasicParsing -Uri $uriNotificationsGetRulesFormatted -WebSession $Session -Method GET
        }
        catch{
            Write-Host "Could not obtain rules from DSP: $uriNotificationsGetRulesFormatted" -ForegroundColor Red
            Stop-Transcript
            break        
        }

        $ruleCount = "{0:00}" -f $($rulesToImport.Count)

        Write-Host "+ Starting Alert and respone rule import: $uriNotificationsSaveRuleAD"
        Write-Host "+ Alert and Response rules to import: $ruleCount "

        #require DN swamp
        if(($Mode -eq "import") -and ($Type -eq "ActiveDirectory")){
            if ([string]::IsNullOrEmpty($DomainDN)) {
                Write-Host "+ DomainDN not specified as a parameter, will import as is."
            }
        }


        $i = 0        
     

        foreach($rule in $rulesToImport){
            $i++
            $index = "{0:00}" -f $i

            $ruleImport = $false

            #check right datasource
            if(!($rule.DataSource -eq $dataSource)){
                Write-Host "  [$index/$ruleCount ] Skipped: $($rule.Name) [wrong datasource]" -ForegroundColor Yellow
                $countRuleImportSkipped++
                $ruleImport = $false
            }

            #check datasource and skip if import is false
            if(($rule.DataSource -eq $dataSource) -and ($rule.Import -eq $false)){
                Write-Host "  [$index/$ruleCount ] Skipped: $($rule.Name) [import set to false]" -ForegroundColor Yellow
                $countRuleImportSkipped++
                $ruleImport = $false
            }

            $existingRuleCheck = $null
            $existingRuleCheck = $existingRules | Where-Object {$_.Name -eq $rule.Name}   

            #check if right datasource and import is true and if the rule already exists
            if(($rule.DataSource -eq $dataSource) -and ($rule.Import -eq $true) -and ($null -ne $existingRuleCheck)){
                Write-Host "  [$index/$ruleCount ] Skipped: $($rule.Name) [already exists]" -ForegroundColor Yellow
                $countRuleImportSkipped++
                $ruleImport = $false
            }

            #import rule
            if(($rule.DataSource -eq $dataSource) -and ($rule.Import -eq $true) -and ($null -eq $existingRuleCheck)){                
                $ruleImport = $true                                                
            }

            if($ruleImport -eq $true){

                if ($null -ne $rule.DistinguishedName){
                    if (-not [string]::IsNullOrEmpty($DomainDN)) {
                        $ruleDN = $rule.DistinguishedName.Replace($ExampleDN, $DomainDN)
                    }
                    else {
                        $ruleDN = $rule.DistinguishedName
                    }
                }

                $ruleFilter = ConvertTo-Json -InputObject $rule.Filter -Compress -Depth 100
                $ruleActions = ConvertTo-Json -InputObject $rule.ActionsNotification -Compress -Depth 100

                #create post body
                [hashtable]$postBody = @{    
                    "__RequestVerificationToken" = $updatedVerificationToken
                    tabID  = $tabId
                    RuleID            = "temp"
                    Severity          = "$($rule.Severity)"                    
                    DistinguishedName = "$ruleDN"
                    Filter            = $ruleFilter             
                    IsAlertRecipients = "$($rule.IsAlertRecipients)"
                    CriteriaToggle    = "$($rule.CriteriaToggle)"
                    IsAutoUndo        = "False"
                    IsEnabled         = "True" 
                    IsSecurityEvent   = "$($rule.IsSecurityEvent)"
                    Name              = "$($rule.Name)"
                    Datasource        = "$($rule.DataSource)"
                    ObjectSearch      = "$($rule.ObjectSearch)"
                    IsOU              = "$($rule.isOU)"
                    "ActionsNotification[]" = "$ruleActions"              
                }

                #check if the rule is mail enabled                
                if($rule.Recipients.Count -gt 0){
                    # Update email address only if EmailAddress has a meaningful value
                    if(-not [string]::IsNullOrWhiteSpace($EmailAddress)){
                        $ruleRecipients = $EmailAddress
                    }
                    else{
                        $ruleRecipients = $rule.Recipients 
                    }
                }

                #changed in DSP 5.0
                if($rule.Recipients.Count -gt 0){
                    if($licenseCheck.Version -like "4.*"){
                          $postBody.Add("Recipients[]", "$ruleRecipients")
                    }    
                    if($licenseCheck.Version -like "5.*"){
                          $postBody.Add("Recipients[0]", "$ruleRecipients")
                    }    
                }
                
                #used for troubleshooting
                #$postBody  


                #prior to saving a rule, query the latest rule list
                try {
                     Invoke-RestMethod -UseBasicParsing -Uri $uriNotificationsGetRulesFormatted -WebSession $Session -Method GET | Out-Null
                }
                catch {
                    Write-Host "Could not obtain latest notification rule list, try again" -ForegroundColor Red
                    Stop-Transcript
                    break
                }  
                
              
                #try to import the rule
                try {                
                    Invoke-RestMethod -UseBasicParsing -Uri $uriNotificationsSaveRuleAD -WebSession $session -Headers $headers -Body $postBody -Method POST  | Out-Null 
                                    
                    #wait for rule to be created
                    Start-Sleep -Seconds 2

                    #get rules and check if it exists or not
                    $ruleCheck = $null

                    try{
                        $ruleCheck = Invoke-RestMethod -UseBasicParsing -Uri $uriNotificationsGetRulesFormatted -WebSession $Session -Method GET 
                    }
                    catch{
                        $ruleCheck = $null
                    }

                    if($ruleCheck | Where-Object {$_.Name -eq $rule.Name}){    
                        if($($rule.IsAutoUndo) -eq $true){
                            Write-Host "  [$index/$ruleCount ] Imported: $($rule.Name) [imported as AutoUndo DISABLED]" -ForegroundColor Yellow
                        }
                        else{
                            Write-Host "  [$index/$ruleCount ] Imported: $($rule.Name)"
                        }
                        $countRuleImportSuccess++
                    }
                    else{ 
                        Write-Host "  [$index/$ruleCount ] Failed: $($rule.Name) [could not import]" -ForegroundColor Red
                        $countRuleImportFailed++

                        if($ContinueOnImportError -eq $false){
                            Write-Host "Continue on import error is set to false, exiting" -ForegroundColor Red
                            Stop-Transcript
                            break
                        }
                    }
                }
                catch{
                    Write-Host "  [$index/$ruleCount ] Failed: $($rule.Name) [could not import]" -ForegroundColor Red
                    
                    if($ContinueOnImportError -eq $false){                        
                        Write-Host "  Continue on import error is set to false, exiting" -ForegroundColor Red
                        Write-Host "  Check the following DSP logs:" -ForegroundColor Red
                        Write-Host "  C:\ProgramData\Semperis\Logs\Semperis.BrokerSvcHost.Log" -ForegroundColor Red
                        Write-Host "  C:\ProgramData\Semperis\Logs\w3wp.Log" -ForegroundColor Red
                        Stop-Transcript
                        break
                    }
                } 
            }
        }

        Write-Host "+ Rule import complete"
        Write-Host "+ Imported($countRuleImportSuccess), skipped($countRuleImportSkipped), failed($countRuleImportFailed)"  
        Write-Host ""
        
        if($countRuleImportFailed -gt 0){
            Write-Host "- One or more rules could not be imported." -ForegroundColor Red
            Write-Host "- Check the following DSP logs:" -ForegroundColor Red
            Write-Host "- C:\ProgramData\Semperis\Logs\Semperis.BrokerSvcHost.Log" -ForegroundColor Red
            Write-Host "- C:\ProgramData\Semperis\Logs\w3wp.Log" -ForegroundColor Red
        }
    }
    else{
        Write-Host "Import file not found: $ImportFilePath" -ForegroundColor Red
        Stop-Transcript
        break
    }
}

Function Import-DSPAlertAndResponseRulesEID {
    param (        
        [boolean]$ContinueOnImportError,
        [string]$ImportFilePath,
        [string]$EmailAddress
    )

    if(Test-Path -Path $ImportFilePath){
        try{
            $rulesToImport = Get-Content -Path $ImportFilePath | ConvertFrom-JSON        
        }
        catch{
            Write-Host "Rules could not be imported from file: $ImportFilePath" -ForegroundColor Red
            Stop-Transcript
            break
        }

        if($null -eq $rulesToImport){
            Write-Error "Import file empty: $ImportFilePath"
            Stop-Transcript
            break
        }

        $dataSource = "aad"

        #check the first rule to check the datasource          
        if($rulesToImport[0].DataSource -ne $dataSource){
            Write-Host "Rule import mismatch, attempting to import Entra ID rules with an ActiveDirectory rule file?" -ForegroundColor Red                
            Stop-Transcript
            break
        }

        #start the import        
        $countRuleImportFailed = 0
        $countRuleImportSuccess = 0
        $countRuleImportSkipped = 0

        #unix timestamp required for API POST requests
        $unixTimeStamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
        
        #format the url for import depending on type
        $uriNotificationsGetRulesFormatted = $uriNotificationsGetRulesEID + "/?_"+$unixTimeStamp+"&tabId="+$tabId                       
    
        try{
            $existingRules = Invoke-RestMethod -UseBasicParsing -Uri $uriNotificationsGetRulesFormatted -WebSession $Session -Method GET
        }
        catch{
            Write-Host "Could not obtain rules from DSP: $uriNotificationsGetRulesFormatted" -ForegroundColor Red
            Stop-Transcript
            break        
        }

        $ruleCount = "{0:00}" -f $($rulesToImport.Count)

        Write-Host "+ Starting Alert and respone rule import: $uriNotificationsSaveRuleAD"
        Write-Host "+ Alert and Response rules to import: $ruleCount "

        

        $i = 0        
        
        foreach($rule in $rulesToImport){
            $i++
            $index = "{0:00}" -f $i

            $ruleImport = $false

            #check right datasource
            if(!($rule.DataSource -eq $dataSource)){
                Write-Host "  [$index/$ruleCount ] Skipped: $($rule.Name) [wrong datasource]" -ForegroundColor Yellow
                $countRuleImportSkipped++
                $ruleImport = $false
            }

            #check datasource and skip if import is false
            if(($rule.DataSource -eq $dataSource) -and ($rule.Import -eq $false)){
                Write-Host "  [$index/$ruleCount ] Skipped: $($rule.Name) [import set to false]" -ForegroundColor Yellow
                $countRuleImportSkipped++
                $ruleImport = $false
            }

            $existingRuleCheck = $null
            $existingRuleCheck = $existingRules | Where-Object {$_.Name -eq $rule.Name}   

            #check if right datasource and import is true and if the rule already exists
            if(($rule.DataSource -eq $dataSource) -and ($rule.Import -eq $true) -and ($null -ne $existingRuleCheck)){
                Write-Host "  [$index/$ruleCount ] Skipped: $($rule.Name) [already exists]" -ForegroundColor Yellow
                $countRuleImportSkipped++
                $ruleImport = $false
            }

            #import rule
            if(($rule.DataSource -eq $dataSource) -and ($rule.Import -eq $true) -and ($null -eq $existingRuleCheck)){                
                $ruleImport = $true                                                
            }

            if($ruleImport -eq $true){

                $ruleFilter = ConvertTo-Json -InputObject $rule.Filter -Compress -Depth 100
                $ruleActions = ConvertTo-Json -InputObject $rule.ActionsNotification -Compress -Depth 100

                [hashtable]$postBody = @{
                    "__RequestVerificationToken" = "$updatedVerificationToken"
                    "RuleID" = ""
                    "Name" = "$($rule.Name)"
                    "DistinguishedName" = "$($rule.DistinguishedName)"
                    "DomainGPO" = "$($rule.DomainGPO)"
                    "IsOU" = "$($rule.IsOU)"
                    "Severity" = "$($rule.Severity)"
                    "IsEnabled" = "True" 
                    "IsAutoUndo" = "False"
                    "IsSecurityEvent" = "$($rule.IsSecurityEvent)"
                    "ObjectSearch" = "$($rule.ObjectSearch)"
                    "Filter" = "$ruleFilter"
                    "CreationDate" = ""
                    "CreatedBy" = ""
                    "DataSource" = "aad"
                    "ActionsNotification[]" = "$ruleActions"
                    "tabId" = "$tabId"
                }   

                #check if the rule is mail enabled                
                if($rule.Recipients.Count -gt 0){
                    # Update email address only if EmailAddress has a meaningful value
                    if(-not [string]::IsNullOrWhiteSpace($EmailAddress)){
                        $ruleRecipients = $EmailAddress
                    }
                    else{
                        $ruleRecipients = $rule.Recipients 
                    }
                }

                #changed in DSP 5.0
                if($rule.Recipients.Count -gt 0){
                    if($licenseCheck.Version -like "4.*"){
                          $postBody.Add("Recipients[]", "$ruleRecipients")
                    }    
                    if($licenseCheck.Version -like "5.*"){
                          $postBody.Add("Recipients[0]", "$ruleRecipients")
                    }    
                }
                
                #used for troubleshooting
                #$postBody  


                #prior to saving a rule, query the latest rule list
                try {
                    $uriNotificationsGetRulesFormattedAD = $uriNotificationsGetRulesAD + "/?_"+$unixTimeStamp+"&tabId="+$tabId  
                    Invoke-RestMethod -UseBasicParsing -Uri $uriNotificationsGetRulesFormattedAD -WebSession $Session -Method GET | Out-Null
                }
                catch {
                    Write-Host "Could not obtain latest AD notification rule list, try again" -ForegroundColor Red
                    Stop-Transcript
                    break
                }  
                
              
                #try to import the rule
                try {                
                    Invoke-RestMethod -UseBasicParsing -Uri $uriNotificationsSaveRuleEID -WebSession $session -Headers $headers -Body $postBody -Method POST  | Out-Null 
                                    
                    #wait for rule to be created
                    Start-Sleep -Seconds 2

                    #get rules and check if it exists or not
                    $ruleCheck = $null

                    try{
                        $ruleCheck = Invoke-RestMethod -UseBasicParsing -Uri $uriNotificationsGetRulesFormatted -WebSession $Session -Method GET 
                    }
                    catch{
                        $ruleCheck = $null
                    }

                    if($ruleCheck | Where-Object {$_.Name -eq $rule.Name}){    
                        if($($rule.IsAutoUndo) -eq $true){
                            Write-Host "  [$index/$ruleCount ] Imported: $($rule.Name) [imported as AutoUndo DISABLED]" -ForegroundColor Yellow
                        }
                        else{
                            Write-Host "  [$index/$ruleCount ] Imported: $($rule.Name)"
                        }
                        $countRuleImportSuccess++
                    }
                    else{ 
                        Write-Host "  [$index/$ruleCount ] Failed: $($rule.Name) [could not import]" -ForegroundColor Red
                        $countRuleImportFailed++

                        if($ContinueOnImportError -eq $false){
                            Write-Host "Continue on import error is set to false, exiting" -ForegroundColor Red
                            Stop-Transcript
                            break
                        }
                    }
                }
                catch{
                    Write-Host "  [$index/$ruleCount ] Failed: $($rule.Name) [could not import]" -ForegroundColor Red
                    
                    if($ContinueOnImportError -eq $false){                        
                        Write-Host "  Continue on import error is set to false, exiting" -ForegroundColor Red
                        Write-Host "  Check the following DSP logs:" -ForegroundColor Red
                        Write-Host "  C:\ProgramData\Semperis\Logs\Semperis.BrokerSvcHost.Log" -ForegroundColor Red
                        Write-Host "  C:\ProgramData\Semperis\Logs\w3wp.Log" -ForegroundColor Red
                        Stop-Transcript
                        break
                    }
                } 
            }
        }

        Write-Host "+ Rule import complete"
        Write-Host "+ Imported($countRuleImportSuccess), skipped($countRuleImportSkipped), failed($countRuleImportFailed)"  
        Write-Host ""
        
        if($countRuleImportFailed -gt 0){
            Write-Host "- One or more rules could not be imported." -ForegroundColor Red
            Write-Host "- Check the following DSP logs:" -ForegroundColor Red
            Write-Host "- C:\ProgramData\Semperis\Logs\Semperis.BrokerSvcHost.Log" -ForegroundColor Red
            Write-Host "- C:\ProgramData\Semperis\Logs\w3wp.Log" -ForegroundColor Red
        }
    }
    else{
        Write-Host "Import file not found: $ImportFilePath" -ForegroundColor Red
        break
    }
}

##end functions

Show-DSPBanner

Start-Sleep -Seconds 1

Write-Host "+ DSP Management Console set to: $uriServerConsole"

#check if the site can be accessed
try{ 
    if((Invoke-WebRequest -UseBasicParsing -Uri $uriServerConsole).statuscode -ne "200"){ 
        Write-Host "DSP Management Console did not return status code 200: $uriServerConsole" -ForegroundColor Red
        Stop-Transcript
        break 
    } 
} 
catch { 
    Write-Host "DSP Management Console could not be reached: $uriServerConsole" -ForegroundColor Red
    Stop-Transcript
    break
}


Write-Host "+ Obtaining initial verification token: $uriLoginGetToken"

#retrieve anti forgery token
try{
    $responseLoginToken = Invoke-RestMethod -UseBasicParsing  -Uri $uriLoginGetToken  -SessionVariable "session"
}
catch{
    Write-Host "Verification token could not be retrieved: $uriLoginGetToken"  -ForegroundColor Red
    Stop-Transcript
    break    
}

if ($responseLoginToken.PSObject.Properties.Name -contains 'input') {
    $verificationToken = $responseLoginToken.input.value
}
else {
    Write-Host "Verification token not found in response: $uriLoginGetToken" -ForegroundColor Red
    Stop-Transcript
    break
}


Write-Host "+ Attempting login: $uriLogin"

#attempt logon
$bodyLogin = @{
    __RequestVerificationToken = $verificationToken
    username = "$Username"
    password = "$Password"
}


try{
    $loginCheck = Invoke-RestMethod -UseBasicParsing -Uri $uriLogin -WebSession $Session -Body $bodyLogin -Method "POST"
}
catch {
    Write-Host "Error occured attempting logon: $uriLogin" -ForegroundColor Red
    break 
}

if($null -eq $loginCheck.username){
    Write-Host "Could not logon to management console: wrong username/password?" -ForegroundColor Red
    Stop-Transcript
    break
}

Write-Host "+ Logged onto DSP console: $($loginCheck.username)"

#get updated logon parameters - tabId and verificationtoken
try {
    $updatedVerificationToken = Invoke-RestMethod -UseBasicParsing -Uri $uriLoginGetParams -WebSession $session -Method GET
}
catch {
    Write-Host "Updated verification token could not be retrieved: $uriLoginGetParams"  -ForegroundColor Red
    Stop-Transcript
    break   
}

if($null -eq $updatedVerificationToken){
    Write-Host "Updated verification token could not be retrieved: $uriLoginGetParams" -ForegroundColor Red
    Stop-Transcript
    break
}

$tabId = $updatedVerificationToken.TabID

#regex - yuck - pattern match on value=" and end on "
$inputString = $updatedVerificationToken.__RequestVerificationToken
$pattern = 'value="([^"]+)"'
$updatedVerificationToken = $inputString | Select-String -Pattern $pattern | ForEach-Object { $_.Matches.Groups[1].Value }

if (($null -eq $tabId) -or ($null -eq $updatedVerificationToken)){
    Write-Host "Either tabID updated verification token were null" -ForegroundColor Red
    Stop-Transcript
    break  
}

Write-Host "+ TabId and updated verification token retrieved: $uriLoginGetParams"


Write-Host "+ Validating DSP license: $uriLicenseGetLicenseInfo"

#check license - required for entra id rules
try {
    $licenseCheck = Invoke-RestMethod -UseBasicParsing -Uri $uriLicenseGetLicenseInfo -WebSession $Session -Method GET
        
    Write-Host "+ License product:   $($licenseCheck.ProductName)"
    Write-Host "+ License status:    $($licenseCheck.LicenseStatus)"   

    #$licenseCheck.DSPInstalledModules | ForEach-Object {
    #    Write-Host " + Licensed module: $($_.Flag)"
    #}   

    #check if licensed for entra id
    if ($licenseCheck.DSPInstalledModules | Where-Object {$_.Name -eq "Entra ID intelligence"}) {
        $licensedEntraID = $true
        Write-Host "+ License Entra ID:  True"          
    }
    else{
        Write-Host "+ License Entra ID:  False"
        $licensedEntraID = $false
    }

}
catch {
    Write-Host "~ Could not verify Entra ID license, only AD rules availe for backup/import." -ForegroundColor Yellow 
}

#check IAS status
try {
    $iasStatusCheck = Invoke-RestMethod -UseBasicParsing -Uri $uriBackgroundActionsStatus -WebSession $session -Method GET
}
catch {
    Write-Host "IAS status could not be verified, cannot continue." -ForegroundColor Red
    break 
}

Write-Host "+ Logged on to Management Console and all pre-checks complete"

if($Mode -eq "export"){
    Export-DSPAlertAndResponseRules -fExportPath $fExportPath -licensedEntraID $licensedEntraID
}
elseif($Mode -eq "import"){
    
    if($Type -eq "ActiveDirectory") {
        #import AD rules

        if($iasStatusCheck.HSSystemStatus.HsState -eq "ok"){
            Import-DSPAlertAndResponseRulesAD -ContinueOnImportError $true -ImportFilePath $ImportFilePath -DomainDN $DomainDN -EmailAddress $EmailAddress            
        }
        else{
            Write-Host " - IAS contains issues, cannot continue."
            Write-Host " - SystemState: " $iasStatusCheck.HSSystemStatus.HsState
            Stop-Transcript
            break
        }
        
    }
    elseif($Type -eq "EntraID"){
        #import Entra ID rules
        if(($iasStatusCheck.HSSystemStatus.HsState -eq "ok") -and ($iasStatusCheck.HSAppFrameStatus.status -eq "ok")) {
            Import-DSPAlertAndResponseRulesEID -ContinueOnImportError $false -ImportFilePath $ImportFilePath -EmailAddress $EmailAddress
        }
        else{
            Write-Host " - IAS contains issues, cannot continue."
            Write-Host " - SystemState: " $iasStatusCheck.HSSystemStatus.HsState
            Write-Host " - TenantState: " $iasStatusCheck.HSAppFrameStatus.status
            Stop-Transcript
            break   
        }
    }
}


Stop-Transcript | Out-Null

Write-Host "+ Log file: $fLogFilePath"