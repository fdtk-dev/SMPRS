  <#PSScriptInfo
.VERSION 8.0.0
.DATE December 2nd 2025
.AUTHOR bryano@semperis.com
.COMPANYNAME Semperis 
.COPYRIGHT Semperis 
.NAME DSP Health-Check v8 
The goal of this script is to provide an overview of your DSP Server Health 

Requirement to run this script : 
- Run this script on the DSP MS, if not you need to specify the path in the prompt
- Run this script with a DSP User that has product manager right

This script is not provided and supported by Semperis. This script has only read access and cannot perform any action on your behalf on the DSP MS.
In case you face any issue please contact the owner Bryan Ohana (bryano@semperis.com).
#>
Param(
    [string]$Path,
    [ValidateSet("US", "EMEA")]
    [string]$Date = "US",
    [string]$Username,
    [SecureString]$Password,
    [switch]$Open,
    
    # Email Parameters
    [switch]$SendEmail,
    [string]$SmtpServer,
    [int]$SmtpPort = 25,
    [string]$From,
    [string[]]$To,
    [string[]]$Cc,
    [PSCredential]$Credential,
    [switch]$UseSSL,
    [string]$Subject = "DSP Health-Check Report - $(Get-Date -Format 'yyyy-MM-dd')"
)
## Defined Function for API ##
Write-Host "████████╗    ██████╗    ██████╗ " -ForegroundColor Blue
Write-Host "██╔═══██║   ██╔════╝   ██╔══██╗" -ForegroundColor Blue
Write-Host "██║   ██║   ██████╗    ██████╔╝" -ForegroundColor Blue
Write-Host "██║   ██║   ╚════██╗   ██╔═══╝ " -ForegroundColor Blue
Write-Host "██████╔═╝██╗██████╔╝██╗██║     " -ForegroundColor Blue
Write-Host "╚═════╝  ╚═╝╚═════╝ ╚═╝╚═╝     " -ForegroundColor Blue
Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkCyan
# Check 1: Validate that the script is run as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "ERROR: This script must be run as Administrator. Please run PowerShell as Administrator and try again." -ErrorAction Stop
    exit 1
}
Write-Host "✓ Administrator privileges confirmed" -ForegroundColor Green
Write-Host ""

#####
if ($Path) {
    $outputFile = [System.IO.Path]::Combine($Path, "DSP_Health-Check-V8.html")
} else {
    $outputFile = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), "DSP_Health-Check-V8.html")
}
# Retrieve Semperis Management Server Version from Registry
$semperisSoftware = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, `
                                     HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* `
                     | Where-Object { $_.DisplayName -match "Semperis Management Server" }

# Store the version in a variable
$semperisVersion = if ($semperisSoftware) { $semperisSoftware.DisplayVersion } else { "Not Installed" }

# Retrieve Semperis Management Server Version from Registry
$semperisHFSoftware = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, `
                                     HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* `
                     | Where-Object { $_.DisplayName -match "Semperis Hotfix" }
# Store the version in a variable
$semperisHFVersion = if ($semperisHFSoftware) { $semperisSoftware.DisplayVersion } else { "Not Installed" }


#$outputFile = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), "DSP_Health-Check-V6.html")# Suppress output of the connection command
#Gather DATA from Xml files
[xml]$XmlData = Get-Content -Path "C:\ProgramData\Semperis\ForestAgentsInfo.xml"
[xml]$XmlDspData = Get-Content -Path "C:\ProgramData\Semperis\General\ADSMConfiguration.xml"
$ForestDataInfo = $XmlData.ForestAgentsInfo.ADForest
$AdsmData = $XmlDspData.AdsmConfiguration
$dsp_ServerFQDN = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName
##### API Connection
Write-Host "Disclaimer:" -ForegroundColor Red
Write-Host " - This script is NOT an official Semperis product." -ForegroundColor  DarkRed
Write-Host " - It is not supported by Semperis Support Team." -ForegroundColor DarkRed
Write-Host " - It performs READ-ONLY actions and will not modify your ADFR Management Server in any way." -ForegroundColor DarkRed
Write-Host ""
Write-Host "For assistance, please contact:" -ForegroundColor DarkRed
Write-Host " Bryan Ohana  | Principal Solutions Architect | Semperis | bryano@semperis.com" -ForegroundColor DarkRed
Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "Detected DSP Server on this machine : $dsp_ServerFQDN" -ForegroundColor Green
# Credentials prompt
if (-not $Username) {
    Write-Host "=== Please provide credentials for DSP Admin Console ===" -ForegroundColor DarkRed
    $dsp_AdminConsoleUserName = Read-Host "--> Username (format: DOMAIN\Username)"
} else {
    $dsp_AdminConsoleUserName = $Username
    Write-Host "Using provided username from parameter: $Username" -ForegroundColor Green
}

if (-not $Password) {
    $dsp_AdminConsolePassword = Read-Host "--> Password" -AsSecureString
} else {
    $dsp_AdminConsolePassword = $Password
    Write-Host "Using provided password from parameter" -ForegroundColor Green
}
Write-Host ""
# Convert the SecureString to plain text for API auth
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dsp_AdminConsolePassword)
)
$dspServerFQDN = "$dsp_ServerFQDN"
$dspServerConsole = "https://$dspServerFQDN/DSP"
$subPathApiLogin = "/api/Login"
$subPathVerificationToken = "/api/Login/GetToken"
$subPathMainGetParams = "/api/Main/GetParams"

# Get token
$resultVerificationToken = Invoke-RestMethod -Uri "$dspServerConsole$subPathVerificationToken" -SessionVariable webSession
$verificationToken = $resultVerificationToken.input.value

# Login body for API calls
$loginBody = @{
    __RequestVerificationToken   = $verificationToken
    username                     = $dsp_AdminConsoleUserName
    password                     = $plainPassword
    UseIntegratedWindowsAuthentication = $false
}

[void](Invoke-RestMethod -Uri "$dspServerConsole$subPathApiLogin" -Method POST -Body $loginBody -WebSession $webSession)
#List of API calls shortcuts
$script:dspServerConsole                      = "https://$dspServerFQDN/DSP"
$script:subPathApiAdsn                        = "/api/Adsn"
$script:subPathApiAdsnGetCollectors           = "/api/Adsn/GetCollectors"
$script:subPathAgentsMngmnt                   = "/api/AgentsManagement"
$script:subPathAgentsMngmntGetInstallVersion  = "/api/AgentsManagement/GetInstallerVersion"
$script:subPathBackgroundActionsStatus        = "/api/BackgroundActions/Status"
$script:subPathDomains                        = "/api/Domains"
$script:subPathApiLogin                       = "/api/Login"
$script:subPathVerificationToken              = "/api/Login/GetToken"
$script:subPathLoginGetParams                 = "/api/Login/GetParams"
$script:subPathMainGetParams                  = "/api/Main/GetParams"
$script:subPathNotificationsGetAlertCount     = "/api/Notifications/GetAlertCount"
$script:subPathPortationGetActionStatus       = "/api/Portation/GetActionStatus"
$script:subPathRBACAddSamlRole                = "/api/Rbac/AddSamlRole"
$script:subPathRBACDeleteSamlIdentities       = "/api/Rbac/DeleteSamlIdentities"
$script:subPathRBACGetIdentities              = "/api/Rbac/GetIdentities"
$script:subPathRBACGetSamlIdentities          = "/api/Rbac/GetSamlIdentities"
$script:subPathRBACPersonas                   = "/api/Rbac/Personas"
$script:subPathRBACUpdateSamlRole             = "/api/Rbac/UpdateSamlRole"
$script:subPathSAML                           = "/api/SAML"
$script:subPathSAMLApplyMetadataFile          = "/api/SAML/ApplyMetadataFile"
$script:subPathSAMLApplyMetadataUrl           = "/api/SAML/ApplyMetadataUrl"
$script:subPathSAMLDownloadSPMetadata         = "/api/SAML/DownloadSPMetadata"
$script:subPathSAMLEnabledStatusChanged       = "/api/SAML/EnabledStatusChanged"
$script:subPathSAMLReadIdPMetadataFile        = "/api/SAML/ReadIdPMetadataFile"
$script:subPathSAMLReadIdPMetadataUrl         = "/api/SAML/ReadIdPMetadataUrl"
$script:subPathSAMLResetReceivedData          = "/api/SAML/ResetReceivedData"
$script:subPathSAMLResetRequiredData          = "/api/SAML/ResetRequiredData"
$script:subPathSAMLSaveIdPName                = "/api/SAML/SaveIdPName"
$script:subPathSAMLSaveReceivedData           = "/api/SAML/SaveReceivedData"
$script:subPathSAMLSaveRequiredData           = "/api/SAML/SaveRequiredData"
$script:subPathSyncMngmntGetPartitionsInfo    = "/api/SyncManagement/GetPartitionsInfo"
$script:subPathSyncMngmntGetSyncState         = "/api/SyncManagement/GetSyncState"
$script:subPathUserSettings                   = "/api/UserSettings"
$script:subPathMyProfile                      = "/api/UserSettings/MyProfile"
$script:subPathLogin                          = "/Login"
# Get parameters
$resultParams = Invoke-RestMethod -Uri "$dspServerConsole$subPathMainGetParams" -Method GET -WebSession $webSession
$tabId = $resultParams.TabID
#####Invoke Calls
$ForestData = Invoke-RestMethod -Uri "$script:dspServerConsole$script:subPathBackgroundActionsStatus" -WebSession $script:webSession -Method Get
$ForestName = $ForestData.ForestAppFrame.forestName
$dspVersion = $semperisVersion
$existingdomains = $ForestDataInfo.Domains.ADDomainInfo.DnsDomainName
# Safe parse to major.minor
$parts = @()
if ($dspVersion) { $parts = $dspVersion -split '\.' }
$major = 0; $minor = 0
if ($parts.Count -ge 1) { [void][int]::TryParse($parts[0], [ref]$major) }
if ($parts.Count -ge 2) { [void][int]::TryParse($parts[1], [ref]$minor) }

$current   = [version]"$major.$minor.0.0"
$threshold = [version]"5.0.0.0"

$ADSNAgents = @()

if ($current -lt $threshold) {
    # =========================
    # DSP < 5.0  (OLD API)  — batch & unwrap defensively
    # =========================
    if (-not $existingDomains -or $existingDomains.Count -eq 0) {
        Write-Warning "existingDomains is empty for 4.x; no ADSN calls will be made."
    } else {
        $batchSize = 40  # reduce if URI > ~2000 chars

        for ($i = 0; $i -lt $existingDomains.Count; $i += $batchSize) {
            $chunk = $existingDomains[$i..([Math]::Min($i + $batchSize - 1, $existingDomains.Count - 1))]

            # Build URI (try encoded ';' first)
            $joined       = ($chunk -join ';')
            $domainParam1 = [System.Web.HttpUtility]::UrlEncode($joined)
            $ts           = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
            $oldUri1      = "$script:dspServerConsole/api/Adsn?domain=$domainParam1&_=$ts"

            # (Optional quick debug)
            # Write-Host "Batch $i: domains=$($chunk.Count) uriLen=$($oldUri1.Length)"

            $respRaw = $null
            try {
                $respRaw = Invoke-RestMethod -Uri $oldUri1 -WebSession $script:WebSession -Method Get -ErrorAction Stop
            } catch {
                # fallback: some servers want *plain* ';' (no %3B)
                $oldUri2 = "$script:dspServerConsole/api/Adsn?domain=$joined&_=$ts"
                try {
                    $respRaw = Invoke-RestMethod -Uri $oldUri2 -WebSession $script:WebSession -Method Get -ErrorAction Stop
                } catch {
                    Write-Warning "Old ADSN batch $i failed. Encoded+plain both failed: $($_.Exception.Message)"
                    continue
                }
            }
            # Unwrap common containers; ensure array
            $respArr = @()
            if ($null -ne $respRaw) {
                if ($respRaw.PSObject.Properties.Name -contains 'value')      { $respArr = @($respRaw.value) }
                elseif ($respRaw.PSObject.Properties.Name -contains 'data')   { $respArr = @($respRaw.data) }
                elseif ($respRaw.PSObject.Properties.Name -contains 'items')  { $respArr = @($respRaw.items) }
                elseif ($respRaw.PSObject.Properties.Name -contains 'results'){ $respArr = @($respRaw.results) }
                else                                                          { $respArr = @($respRaw) }
            }
            # Accumulate
            $ADSNAgents += $respArr
        }
    }
}
else {
    # DSP >= 5.0  (NEW API)
    $ADSNAgents = Invoke-RestMethod -Uri "$script:dspServerConsole$script:subPathApiAdsn" -WebSession $script:WebSession -Method Get
    $ADSNAgents = @($ADSNAgents)
}

# --- normalize fields so your table can use .Id consistently ---
$ADSNAgents = $ADSNAgents | ForEach-Object {
    if ($null -eq $_) { return }
    [pscustomobject]@{
        Id            = $_.ID
        Domain        = $_.Domain
        IsResponding  = [bool]$_.IsResponding
        Version       = $_.Version
        StoreLocation = $_.StoreLocation
    }
}
$DspAgents = Invoke-RestMethod -Uri "$script:dspServerConsole$script:subPathAgentsMngmnt" -WebSession $script:WebSession -Method Get
$licenseInfo = Invoke-RestMethod -Uri "$script:dspServerConsole/api/License/GetLicenseInfo" -WebSession $script:WebSession -Method Get
$Hflist = $licenseInfo.Hotfixes

$flags = $licenseInfo.DSPInstalledModules | ForEach-Object { $_.Flag }
# Module Badge
$modulesBadges = $flags | ForEach-Object {
    "<span style='display: inline-block; background: #fafbfc; color: #24292e; padding: 6px 12px; margin: 2px; border-radius: 6px; font-size: 12px; font-weight: 500; border: 1px solid #e1e4e8; border-left: 3px solid #0366d6;'>$_</span>"
}
$DSPModules = $modulesBadges -join " "
$DSPLicenseType = "<span style='display: inline-block; background: #fafbfc; color: #24292e; padding: 6px 12px; margin: 2px; border-radius: 6px; font-size: 12px; font-weight: 500; border: 1px solid #e1e4e8; border-left: 3px solid #0366d6;'>$($licenseInfo.ProductName)</span>"
$GetADPartition = Invoke-RestMethod -Uri "$script:dspServerConsole/api/SyncManagement/GetPartitionsInfo?tabId=$tabId" -WebSession $script:webSession -Method Get
$timestamp = [int][double]::Parse((Get-Date -UFormat %s)) * 1000

# Retention Data
$GPOBackup = Invoke-RestMethod -Uri "$script:dspServerConsole/api/GPSM/GetBackupSettings?_=$timestamp" -WebSession $script:webSession -Method Get
$GPOBackupPath = $GPOBackup.Location
$GPORetention = $GPOBackup.Retention
$AuditLogs = Invoke-RestMethod -Uri "$script:dspServerConsole/api/OperationLog/GetSettings?_=$timestamp" -WebSession $script:webSession -Method Get
$AuditLog = $AuditLogs.Retention
$DBSettings = Invoke-RestMethod -Uri "$script:dspServerConsole/api/General/GetAdsmSettings?_=$timestamp" -WebSession $script:webSession -Method Get
$IASstatus = Invoke-RestMethod -Uri "$script:dspServerConsole/api/AAD/GetHIPSettings?_=$timestamp&tabId=$tabID" -WebSession $script:webSession -Method Get
$RetentionUndoActions = $DBSettings.JobStatusRetentionPolicyDays


$tabId = $script:tabId  # this should already be set from earlier
$scoreData = Invoke-RestMethod -Uri "$script:dspServerConsole/api/SecurityDashboard/GetScoreData?securityPostureScoreAlgorithm=ImpactOrientedAlgorithm&tabId=$tabId" -WebSession $script:webSession -Method Get
#IAS APIs
$IASFreespace = Invoke-RestMethod -Uri "$script:dspServerConsole/api/Monitor/GetDSPHealthAlertHSSettings?tabId=$tabID" -WebSession $script:WebSession -Method Get
$IaSServices = Invoke-RestMethod -Uri "$script:dspServerConsole/api/AAD/GetHSHealthUnifiedResult?tabId=$tabID" -WebSession $script:WebSession -Method Get
$IaSHealth = $IaSServices.results 
$IndicatorsList = Invoke-RestMethod -Uri "$script:dspServerConsole/api/SecurityDashboard/GetIndicators?sortForOverview=false&serviceAccountResults=false&tabId=$tabID" -WebSession $script:WebSession -Method Get
## Get Graph Data from Dashboard
$endDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
$startDate = (Get-Date).AddMonths(-1).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$graphData = Invoke-RestMethod -Uri "$script:dspServerConsole/api/Monitor/GetGraphData?partitionId=1&start=$startDate&end=$endDate&tabId=$tabId" -WebSession $script:webSession -Method Get

    # Filter last 7 days and sum up activity metrics
    $sevenDaysAgo = (Get-Date).AddDays(-7)
    $last7DaysData = $graphData | Where-Object { [DateTime]$_.Id -ge $sevenDaysAgo }

    $last7DaysSummary = [PSCustomObject]@{
    	Created   = ($last7DaysData | Measure-Object -Property Created -Sum).Sum
    	Deleted   = ($last7DaysData | Measure-Object -Property Deleted -Sum).Sum
    	Modified  = ($last7DaysData | Measure-Object -Property Modified -Sum).Sum
    	Moved     = ($last7DaysData | Measure-Object -Property Moved -Sum).Sum
    	Restored  = ($last7DaysData | Measure-Object -Property Restored -Sum).Sum
    }

    # Filter last 30 days and sum up activity metrics
    $thirtyDaysAgo = (Get-Date).AddDays(-30)
    $last30DaysData = $graphData | Where-Object { [DateTime]$_.Id -ge $thirtyDaysAgo }

    $last30DaysSummary = [PSCustomObject]@{
        Created   = ($last30DaysData | Measure-Object -Property Created -Sum).Sum
        Deleted   = ($last30DaysData | Measure-Object -Property Deleted -Sum).Sum
        Modified  = ($last30DaysData | Measure-Object -Property Modified -Sum).Sum
        Moved     = ($last30DaysData | Measure-Object -Property Moved -Sum).Sum
        Restored  = ($last30DaysData | Measure-Object -Property Restored -Sum).Sum
    }




if ($IASFreespace.DiskSpaceThresholdGB) {
    $IASdiskspacebelow = "$($IASFreespace.DiskSpaceThresholdGBValue)GB"
} else {
    $IASdiskspacebelow = "Not active"
}

if ($IASFreespace.DiskSpaceThresholdPercent) {
    $IASdiskPercent = "$($IASFreespace.DiskSpaceThresholdPercentValue)%"
} else {
    $IASdiskPercent = "Not active"
}

### Indicator round in header
$scoreValue = $scoreData.TotalScore
$scoreGrade = $scoreData.TotalGrade -replace 'Plus$', '+' -replace 'Minus$', '-'
$percentage = [math]::Min([math]::Max($scoreValue, 0), 100)

# IIS Binding check
$siteName = "SemperisSite"
$expectedBindingInfo = "8791:*"
$tcpStatus = "<span class='custom-fail'></span> Not Configured"

# 1. Try with IIS:\ drive
if (Get-Module -ListAvailable WebAdministration) {
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    if (Test-Path "IIS:\Sites\$siteName") {
        $site = Get-Item "IIS:\Sites\$siteName"
        $netTcpBinding = $site.Bindings.Collection | Where-Object {
            $_.protocol -eq "net.tcp" -and $_.bindingInformation -eq $expectedBindingInfo
        }
        if ($netTcpBinding) {
            $tcpStatus = "<span class='custom-check'></span> net.tcp binding present ($expectedBindingInfo)"
        }
    }
}
$remoteRegService = (Get-CimInstance -ClassName Win32_Service -Filter "Name='RemoteRegistry'").StartMode

##IRP Checks
#Get-Attack Cards
$IRPAttackCards = Invoke-RestMethod -Uri "$script:dspServerConsole/api/AttackTypes/GetAttackTypeCardsData?tabId=$tabID" -WebSession $script:webSession -Method Get
$IRPAttacksCount = $IRPAttackCards.TotalCount 
$IRPAttacks = $IRPAttackCards.AttackTypes 
foreach ($IRPAttack in $IRPAttacks) {
    $IRPAttackName = $IRPAttack.Name
    $IRPAttackID = $IRPAttack.ID
    $IRPAttackUniqueID = $IRPAttack.UniqueID
    $IRPAttackSeverity = $IRPAttack.Severity
    $IRPAttackIncidentCount = $IRPAttack.IncidentsCount 
    $IRPAttackType = $IRPAttack.Type
    $IRPAttackTags = ($IRPAttack.Tags | ForEach-Object { "$($_.label) ($($_.children -join ', '))" }) -join " | "
}   

#Get-AttackType metadata
$IRPAttackTypeMetadata = Invoke-RestMethod -Uri "$script:dspServerConsole/api/AttackTypes/GetAttackTypeMetadata?attackTypeId=cc3856d7-d91b-4391-a105-59bfa1b9b3d9&tabId=$tabID" -WebSession $script:webSession -Method Get
#Get-AttackTypeConfiguration
$IRPAttackTypeConfiguration = Invoke-RestMethod -Uri "$script:dspServerConsole/api/AttackTypes/GetAttackTypeUserConfiguration?attackTypeId=b475b993-fbff-46cc-af94-7f2772d47068&tabId=$tabID" -WebSession $script:webSession -Method Get
#Get-AttackTypeAuditLog
$IRPAttackTypeAuditLog = Invoke-RestMethod -Uri "$script:dspServerConsole/api/AttackTypes/GetAttackTypeAuditLog?AttackTypeDefinitionId=156&tabId=$tabID" -WebSession $script:webSession -Method Get
#Get-IncidentListFileters
$IRPIncidentListFileters = Invoke-RestMethod -Uri "$script:dspServerConsole/api/Incidents/GetIncidentsListFilters?tabId=$tabID" -WebSession $script:webSession -Method Get
$test = Invoke-RestMethod -Uri "$script:dspServerConsole/api/Incidents/GetIncidentsListFilters?tabId=$tabID" -WebSession $script:webSession -Method Get


# Get updated verification token for POST requests
$irpParams = Invoke-RestMethod -Uri "$script:dspServerConsole/DSP/security/identity_runtime_protection/incidents" -Method GET -WebSession $script:webSession
$irpTokenInput = $irpParams | Select-String -Pattern 'name="__RequestVerificationToken"[^>]*value="([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value }

# If that doesn't work, try getting it from the main params endpoint
if (-not $irpTokenInput) {
    $resultParams = Invoke-RestMethod -Uri "$script:dspServerConsole/DSP/Main/GetParams" -Method GET -WebSession $script:webSession
    $inputString = $resultParams.__RequestVerificationToken
    $pattern = 'value="([^"]+)"'
    $irpTokenInput = $inputString | Select-String -Pattern $pattern | ForEach-Object { $_.Matches.Groups[1].Value }
}

#Get-IncidentID
$incidentBody = @{
    __RequestVerificationToken = $irpTokenInput
    SearchFilter = ""
    ToDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    "FilterByStatus[0]" = "New"
    "FilterByStatus[1]" = "InProgress"
    "FilterByStatus[2]" = "Closed"
    SortBy = ""
    SortAsc = "true"
    tabId = $tabID
}
$IRPIncidentID = Invoke-RestMethod -Uri "$script:dspServerConsole/api/Incidents/GetIncidentIds" `
    -WebSession $script:webSession `
    -Method Post `
    -Body $incidentBody
#Set current date for header
if ($Date -eq "EMEA") {
    $currentdate = "$(Get-Date -Format 'dd-MM-yyyy') at $(Get-Date -Format 'HH:mm')"
} else {
    $currentdate = "$(Get-Date -Format 'MM-dd-yyyy') at $(Get-Date -Format 'HH:mm')"
}
# Initialize an HTML content string
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>DSP Health Check Report - V8</title>
    <style>
        /* ===== DSP v8 CSS - ADFR Style ===== */
        :root {
            --primary-dark: #111d2c;
            --primary-navy: #1a2d42;
            --sidebar-dark: #0d1520;
            --bg-light: #f5f7fa;
            --bg-white: #ffffff;
            --text-primary: #333333;
            --text-secondary: #6c757d;
            --text-muted: #8898aa;
            --success-green: #4caf50;
            --success-light: #e8f5e9;
            --error-red: #e53935;
            --error-light: #ffebee;
            --warning-orange: #ff9800;
            --warning-light: #fff3e0;
            --info-blue: #2196f3;
            --border-light: #e9ecef;
            --dsp-accent: #4a90e2;
        }
        
        body { 
            background-color: var(--bg-light); 
            font-family: 'Segoe UI', Roboto, Arial, sans-serif;
            font-size: 14px;
            line-height: 1.5;
            color: var(--text-primary);
            margin: 0;
            padding: 0;
        }
        
        h1, h2, h3 { text-align: center; color: #333; margin: 5px 0; }
        
        /* ===== TABLES - DSP Style ===== */
        table { 
            width: 100%; 
            border-collapse: collapse;
            background: white;
            margin-bottom: 16px;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        }
        
        th { 
            background: linear-gradient(135deg, #3d4f61 0%, #4a5d72 100%);
            color: #ffffff;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 12px;
            letter-spacing: 0.8px;
            padding: 14px 16px;
            text-align: left;
            border-bottom: none;
        }
        
        td { 
            padding: 12px 16px; 
            border-bottom: 1px solid var(--border-light);
            text-align: left;
            vertical-align: middle;
        }
        
        tbody tr:hover { background-color: #fafbfc; }
        tbody tr:last-child td { border-bottom: none; }
        
        /* ===== SECTION BADGE ===== */
        .section-badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: linear-gradient(135deg, #3d4f61 0%, #4a5d72 100%);
            color: white;
            padding: 8px 16px;
            border-radius: 16px;
            font-size: 13px;
            font-weight: 500;
            margin: 12px 0 10px 0;
            box-shadow: 0 2px 6px rgba(0,0,0,0.12);
        }
        
        /* ===== STATUS CELLS - DSP Style ===== */
        .ok { 
            background-color: var(--success-light) !important; 
            color: #2e7d32 !important;
        }
        .warning { 
            background-color: var(--warning-light) !important; 
            color: #e65100 !important;
        }
        .ko { 
            background-color: var(--error-light) !important; 
            color: #c62828 !important;
        }
        .IOEOrange {
            background: #fff3e0;
            color: #e65100;
            font-weight: bold;
        }
        
        /* ===== COLLAPSIBLE SECTIONS - DSP Card Style ===== */
        .collapsible {
            background: linear-gradient(135deg, #3d4f61 0%, #4a5d72 100%);
            color: white;
            cursor: pointer;
            padding: 13px 20px;
            width: 100%;
            border: 1px solid var(--border-light);
            text-align: left;
            outline: none;
            font-size: 15px;
            font-weight: 600;
            margin-bottom: 0;
            border-radius: 8px 8px 0 0;
            transition: all 0.2s ease;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        
        .collapsible:not(.active) {
            border-radius: 8px;
            margin-bottom: 12px;
        }
        
        .collapsible:after {
            content: '▼';
            font-size: 10px;
            color: rgba(255,255,255,0.7);
            transition: transform 0.3s ease;
        }
        
        .collapsible.active:after {
            transform: rotate(180deg);
        }
        
        .collapsible:hover {
            background: linear-gradient(135deg, #1a2d42 0%, #243b53 100%);
        }
        
        .content {
            padding: 0;
            display: none;
            overflow: hidden;
            background-color: var(--bg-white);
            border: 1px solid var(--border-light);
            border-top: none;
            border-radius: 0 0 8px 8px;
            margin-bottom: 12px;
        }
        
        .content.show {
            display: block;
            padding: 20px;
        }
        
        /* ===== HEADER - DSP Style ===== */
        .header { 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
            background: var(--primary-dark);
            padding: 16px 24px; 
            color: white;
            border-radius: 0;
            box-shadow: 0 2px 8px rgba(0,0,0,0.15);
            margin-bottom: 0;
        }
        
        .header img { 
            height: 40px;
        }
        
        /* ===== VERSION CARDS ===== */
        .version-card {
            background: white;
            padding: 20px 30px;
            border-radius: 4px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        
        .version-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        
        /* ===== SECURITY SCORE CARD ===== */
        .score-card {
            background: white;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            transition: transform 0.2s ease;
        }
        
        .score-card:hover {
            transform: translateY(-2px);
        }
        
        .score-value {
            font-size: 48px;
            font-weight: 700;
            line-height: 1;
        }
        
        .score-grade {
            font-size: 18px;
            font-weight: 600;
            margin-top: 5px;
        }
        
        /* Blinking effect using CSS animation */
        @keyframes blink {
            0% { opacity: 1; }
            50% { opacity: 0; }
            100% { opacity: 1; }
        }

        .blinking-icon {
            animation: blink 2s infinite;
        }
        
        /* Custom Gradient Circle Success Icons */
        .custom-check {
            display: inline-block;
            width: 18px;
            height: 18px;
            background: linear-gradient(45deg, #28a745, #20c997);
            border-radius: 50%;
            position: relative;
            margin-right: 5px;
            vertical-align: middle;
        }
        
        .custom-check:after {
            content: '✓';
            color: white;
            font-weight: bold;
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 11px;
        }
        
        /* Custom Gradient Circle Fail Icons */
        .custom-fail {
            display: inline-block;
            width: 18px;
            height: 18px;
            background: linear-gradient(45deg, #dc3545, #c82333);
            border-radius: 50%;
            position: relative;
            margin-right: 5px;
            vertical-align: middle;
        }
        
        .custom-fail:after {
            content: '✕';
            color: white;
            font-weight: bold;
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 11px;
        }
        
        /* Custom Gradient Circle Warning Icons */
        .custom-warning {
            display: inline-block;
            width: 18px;
            height: 18px;
            background: linear-gradient(45deg, #ffc107, #e0a800);
            border-radius: 50%;
            position: relative;
            margin-right: 5px;
            vertical-align: middle;
        }
        
        .custom-warning:after {
            content: '!';
            color: white;
            font-weight: bold;
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 12px;
        }
        
        /* Expand/Collapse Icons */
        .expand-icon, .collapse-icon {
            display: inline-block;
            width: 12px;
            height: 12px;
            margin-right: 6px;
            position: relative;
        }
        .expand-icon::before, .expand-icon::after {
            content: '';
            position: absolute;
            background: white;
        }
        .expand-icon::before {
            width: 12px;
            height: 2px;
            top: 5px;
            left: 0;
        }
        .expand-icon::after {
            width: 2px;
            height: 12px;
            top: 0;
            left: 5px;
        }
        .collapse-icon::before {
            content: '';
            position: absolute;
            width: 12px;
            height: 2px;
            top: 5px;
            left: 0;
            background: white;
        }
        
        /* Scrollable table container */
        .table-scroll {
            max-height: 400px;
            overflow-y: auto;
            border: 1px solid #ddd;
            border-radius: 4px;
        }
        
        .table-scroll table {
            margin-bottom: 0;
        }
        
        .table-scroll th {
            position: sticky;
            top: 0;
            z-index: 1;
        }
        
        /* DSP Agent Grid */
        .dsp-agent-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
        }
        
        .dsp-agent-grid span {
            display: block;
            padding: 4px 8px;
            border-radius: 6px;
            font-weight: 500;
        }
        
        .dsp-agent-grid .ok {
            background-color: #e8f5e9;
            color: #2e7d32;
        }
        
        .dsp-agent-grid .ko {
            background-color: #ffebee;
            color: #c62828;
        }
        
        /* ===== IOE SUMMARY CARDS ===== */
        .ioe-summary-container {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            padding: 20px 0;
        }
        
        .ioe-summary-bar {
            background: white;
            border-radius: 8px;
            padding: 15px 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            min-width: 200px;
        }
        
        .ioe-summary-bar h4 {
            margin: 0 0 10px 0;
            font-size: 14px;
            color: #333;
        }
        
        .ioe-progress-bar {
            display: flex;
            height: 8px;
            border-radius: 4px;
            overflow: hidden;
            background: #e9ecef;
        }
        
        .ioe-progress-bar .passed {
            background: linear-gradient(90deg, #28a745, #20c997);
        }
        
        .ioe-progress-bar .not-evaluated {
            background: #6c757d;
        }
        
        .ioe-progress-bar .ioe-found {
            background: linear-gradient(90deg, #dc3545, #e74c3c);
        }
        
        .ioe-legend {
            display: flex;
            gap: 15px;
            margin-top: 8px;
            font-size: 11px;
            color: #666;
        }
        
        .ioe-legend span {
            display: flex;
            align-items: center;
            gap: 4px;
        }
        
        .ioe-legend .dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
        }
        
        .ioe-legend .dot.passed { background: #28a745; }
        .ioe-legend .dot.not-evaluated { background: #6c757d; }
        .ioe-legend .dot.ioe-found { background: #dc3545; }
        
        /* IOE Category Cards */
        .ioe-categories-container {
            display: flex;
            flex-wrap: wrap;
            gap: 16px;
            padding: 10px 0;
        }
        
        .ioe-category-card {
            background: white;
            border-radius: 12px;
            padding: 16px;
            min-width: 180px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
            display: flex;
            align-items: center;
            gap: 16px;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        
        .ioe-category-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.12);
        }
        
        .ioe-circle {
            width: 60px;
            height: 60px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 18px;
            font-weight: 700;
            position: relative;
        }
        
        .ioe-circle::before {
            content: '';
            position: absolute;
            width: 100%;
            height: 100%;
            border-radius: 50%;
            border: 4px solid #e9ecef;
        }
        
        .ioe-circle.grade-a { 
            color: #28a745; 
            border: 4px solid #28a745;
            background: rgba(40, 167, 69, 0.1);
        }
        .ioe-circle.grade-b { 
            color: #20c997; 
            border: 4px solid #20c997;
            background: rgba(32, 201, 151, 0.1);
        }
        .ioe-circle.grade-c { 
            color: #ffc107; 
            border: 4px solid #ffc107;
            background: rgba(255, 193, 7, 0.1);
        }
        .ioe-circle.grade-d { 
            color: #fd7e14; 
            border: 4px solid #fd7e14;
            background: rgba(253, 126, 20, 0.1);
        }
        .ioe-circle.grade-f { 
            color: #dc3545; 
            border: 4px solid #dc3545;
            background: rgba(220, 53, 69, 0.1);
        }
        .ioe-circle.grade-na { 
            color: #6c757d; 
            border: 4px solid #6c757d;
            background: rgba(108, 117, 125, 0.1);
        }
        
        .ioe-category-info {
            display: flex;
            flex-direction: column;
            gap: 2px;
        }
        
        .ioe-category-info .name {
            font-weight: 600;
            font-size: 13px;
            color: #333;
        }
        
        .ioe-category-info .stats {
            font-size: 11px;
            color: #666;
        }
        
        .ioe-category-info .stats .ioe-count {
            color: #dc3545;
            font-weight: 600;
        }
        
        /* ===== SECURITY POSTURE GAUGE ===== */
        .ioe-summary-wrapper {
            display: flex;
            gap: 30px;
            align-items: stretch;
            padding: 20px 0;
        }
        
        .ioe-summary-left {
            flex: 1;
        }
        
        .security-gauge-card {
            background: white;
            border-radius: 12px;
            padding: 20px 30px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-width: 200px;
        }
        
        .security-gauge-card h4 {
            margin: 0 0 15px 0;
            font-size: 14px;
            color: #333;
            text-align: center;
        }
        
        .gauge-container {
            position: relative;
            width: 140px;
            height: 140px;
        }
        
        .gauge-circle {
            width: 100%;
            height: 100%;
            border-radius: 50%;
            background: conic-gradient(
                var(--gauge-color, #dc3545) calc(var(--gauge-percent, 0) * 3.6deg),
                #e9ecef calc(var(--gauge-percent, 0) * 3.6deg)
            );
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .gauge-inner {
            width: 110px;
            height: 110px;
            background: white;
            border-radius: 50%;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
        }
        
        .gauge-value {
            font-size: 32px;
            font-weight: 700;
            line-height: 1;
        }
        
        .gauge-label {
            font-size: 11px;
            color: #666;
            margin-top: 4px;
        }
        
        .gauge-grade {
            position: absolute;
            top: 5px;
            right: 5px;
            font-size: 18px;
            font-weight: 700;
        }
        
        /* ===== ACTIVITY METRICS WIDGET ===== */
        .activity-container {
            display: flex;
            gap: 20px;
            justify-content: center;
            flex-wrap: wrap;
            padding: 15px;
        }
        .period-card {
            background: white;
            border-radius: 12px;
            padding: 10px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
            min-width: 320px;
            border-left: 4px solid #4a90e2;
        }
        .period-card.thirty-days {
            border-left-color: #28a745;
        }
        .period-card h3 {
            margin: 0 0 16px 0;
            color: #333;
            font-size: 15px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 12px;
        }
        .metric-item {
            text-align: center;
            padding: 12px 8px;
            background: #f8f9fa;
            border-radius: 8px;
        }
        .metric-value {
            font-size: 20px;
            font-weight: 700;
            color: #333;
        }
        .metric-label {
            font-size: 11px;
            color: #666;
            text-transform: uppercase;
            margin-top: 4px;
        }
        .metric-item.created .metric-value { color: #4a90e2; }
        .metric-item.deleted .metric-value { color: #dc3545; }
        .metric-item.modified .metric-value { color: #28a745; }
        .metric-item.moved .metric-value { color: #6c757d; }
        .metric-item.restored .metric-value { color: #17a2b8; }
        
        /* ===== HOTFIX MODAL ===== */
        .hf-clickable {
            cursor: pointer;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .hf-clickable:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        .hf-count-badge {
            display: inline-block;
            background: #28a745;
            color: white;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
            margin-left: 6px;
        }
        .modal-overlay {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            z-index: 1000;
            justify-content: center;
            align-items: center;
        }
        .modal-overlay.show {
            display: flex;
        }
        .modal-content {
            background: white;
            border-radius: 12px;
            padding: 24px;
            max-width: 700px;
            width: 90%;
            max-height: 80vh;
            overflow-y: auto;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            animation: modalSlide 0.3s ease;
        }
        @keyframes modalSlide {
            from { transform: translateY(-20px); opacity: 0; }
            to { transform: translateY(0); opacity: 1; }
        }
        .modal-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 12px;
            border-bottom: 2px solid #e9ecef;
        }
        .modal-header h3 {
            margin: 0;
            color: #333;
            font-size: 18px;
        }
        .modal-close {
            background: none;
            border: none;
            font-size: 24px;
            cursor: pointer;
            color: #666;
            padding: 0;
            line-height: 1;
        }
        .modal-close:hover {
            color: #333;
        }
        .hf-table {
            width: 100%;
            border-collapse: collapse;
        }
        .hf-table th, .hf-table td {
            padding: 10px 12px;
            text-align: left;
            border-bottom: 1px solid #e9ecef;
        }
        .hf-table th {
            background: linear-gradient(135deg, #3d4f61, #4a5d72);
            color: white;
            font-weight: 600;
            font-size: 12px;
            text-transform: uppercase;
        }
        .hf-table tr:hover {
            background: #f8f9fa;
        }
        
        /* ===== FLOATING ISSUES BUBBLE ===== */
        .issues-bubble {
            position: fixed;
            bottom: 30px;
            right: 30px;
            z-index: 999;
            cursor: pointer;
        }
        .bubble-btn {
            width: 55px;
            height: 55px;
            border-radius: 50%;
            background: linear-gradient(135deg, #3d4f61, #4a5d72);
            border: none;
            color: white;
            font-size: 22px;
            cursor: pointer;
            box-shadow: 0 4px 15px rgba(61, 79, 97, 0.4);
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
        }
        .bubble-btn.no-issues {
            background: linear-gradient(135deg, #28a745, #20c997);
            box-shadow: 0 4px 15px rgba(40, 167, 69, 0.4);
        }
        .bubble-count {
            position: absolute;
            top: -5px;
            right: -5px;
            background: #ffc107;
            color: #333;
            font-size: 12px;
            font-weight: 700;
            min-width: 22px;
            height: 22px;
            border-radius: 11px;
            display: flex;
            align-items: center;
            justify-content: center;
            border: 2px solid white;
        }
        .issues-panel {
            position: fixed;
            bottom: 100px;
            right: 30px;
            width: 350px;
            max-height: 400px;
            background: white;
            border-radius: 12px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            z-index: 998;
            display: none;
            flex-direction: column;
            overflow: hidden;
            animation: panelSlide 0.3s ease;
        }
        .issues-panel.show {
            display: flex;
        }
        @keyframes panelSlide {
            from { transform: translateY(20px); opacity: 0; }
            to { transform: translateY(0); opacity: 1; }
        }
        .panel-header {
            background: linear-gradient(135deg, #3d4f61, #4a5d72);
            color: white;
            padding: 15px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .panel-header h4 {
            margin: 0;
            font-size: 14px;
            font-weight: 600;
        }
        .panel-close {
            background: none;
            border: none;
            color: white;
            font-size: 20px;
            cursor: pointer;
            padding: 0;
            line-height: 1;
        }
        .panel-stats {
            display: flex;
            gap: 15px;
            padding: 12px 20px;
            background: #f8f9fa;
            border-bottom: 1px solid #e9ecef;
        }
        .stat-item {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 13px;
            font-weight: 600;
        }
        .stat-item.warnings { color: #856404; }
        .stat-item.errors { color: #721c24; }
        .stat-icon {
            width: 20px;
            height: 20px;
            border-radius: 4px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 11px;
        }
        .stat-icon.warning-icon { background: #fff3cd; color: #856404; }
        .stat-icon.error-icon { background: #f8d7da; color: #721c24; }
        .panel-body {
            flex: 1;
            overflow-y: auto;
            max-height: 280px;
        }
        .issue-item {
            padding: 10px 20px;
            border-bottom: 1px solid #e9ecef;
            cursor: pointer;
            transition: background 0.2s ease;
            display: flex;
            align-items: flex-start;
            gap: 10px;
        }
        .issue-item:hover {
            background: #f8f9fa;
        }
        .issue-item:last-child {
            border-bottom: none;
        }
        .issue-badge {
            flex-shrink: 0;
            width: 24px;
            height: 24px;
            border-radius: 4px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 12px;
        }
        .issue-badge.warning { background: #fff3cd; color: #856404; }
        .issue-badge.error { background: #f8d7da; color: #721c24; }
        .issue-text {
            flex: 1;
            font-size: 13px;
            color: #333;
            line-height: 1.4;
        }
        .issue-section {
            font-size: 11px;
            color: #6c757d;
            margin-top: 2px;
        }
        .no-issues-msg {
            padding: 30px 20px;
            text-align: center;
            color: #28a745;
        }
        .no-issues-msg .check-icon {
            font-size: 40px;
            margin-bottom: 10px;
        }
    </style>
    <script>
        document.addEventListener("DOMContentLoaded", function() {
            var coll = document.getElementsByClassName("collapsible");
            for (var i = 0; i < coll.length; i++) {
                coll[i].addEventListener("click", function() {
                    this.classList.toggle("active");
                    var content = this.nextElementSibling;
                    content.classList.toggle("show");
                });
            }
            
            // Expand All functionality
            document.getElementById("expandAll").addEventListener("click", function() {
                var coll = document.getElementsByClassName("collapsible");
                for (var i = 0; i < coll.length; i++) {
                    coll[i].classList.add("active");
                    var content = coll[i].nextElementSibling;
                    content.classList.add("show");
                }
            });
            
            // Collapse All functionality
            document.getElementById("collapseAll").addEventListener("click", function() {
                var coll = document.getElementsByClassName("collapsible");
                for (var i = 0; i < coll.length; i++) {
                    coll[i].classList.remove("active");
                    var content = coll[i].nextElementSibling;
                    content.classList.remove("show");
                }
            });
            
            // Hotfix Modal functionality
            var hfCard = document.getElementById("hfCard");
            var hfModal = document.getElementById("hfModal");
            var hfClose = document.getElementById("hfClose");
            
            if (hfCard && hfModal) {
                hfCard.addEventListener("click", function() {
                    hfModal.classList.add("show");
                });
                hfClose.addEventListener("click", function() {
                    hfModal.classList.remove("show");
                });
                hfModal.addEventListener("click", function(e) {
                    if (e.target === hfModal) {
                        hfModal.classList.remove("show");
                    }
                });
            }
            
            // ===== FLOATING ISSUES BUBBLE =====
            var issuesBubble = document.getElementById("issuesBubble");
            var issuesPanel = document.getElementById("issuesPanel");
            var panelClose = document.getElementById("panelClose");
            var panelBody = document.getElementById("panelBody");
            var bubbleBtn = document.querySelector(".bubble-btn");
            var bubbleCount = document.getElementById("bubbleCount");
            var warningCount = document.getElementById("warningCount");
            var errorCount = document.getElementById("errorCount");
            
            // Collect all warnings and errors
            var warnings = document.querySelectorAll("td.warning");
            var errors = document.querySelectorAll("td.ko");
            var totalIssues = warnings.length + errors.length;
            
            // Update bubble count
            if (bubbleCount) {
                bubbleCount.textContent = totalIssues;
                if (totalIssues === 0) {
                    bubbleCount.style.display = "none";
                    bubbleBtn.classList.add("no-issues");
                    bubbleBtn.innerHTML = "✓";
                }
            }
            
            // Update panel stats
            if (warningCount) warningCount.textContent = warnings.length;
            if (errorCount) errorCount.textContent = errors.length;
            
            // Build issues list
            if (panelBody) {
                if (totalIssues === 0) {
                    panelBody.innerHTML = '<div class="no-issues-msg"><div class="check-icon">✓</div><div>All checks passed!</div></div>';
                } else {
                    var issuesHtml = "";
                    
                    // Helper function to find section name
                    function getSectionName(el) {
                        var section = el.closest(".content");
                        if (section) {
                            var sectionBtn = section.previousElementSibling;
                            return sectionBtn ? sectionBtn.textContent.trim() : "Check Settings";
                        }
                        // Check if inside main table (Check Settings)
                        var table = el.closest("table");
                        if (table) {
                            var th = table.querySelector("th");
                            if (th && th.textContent.trim() === "Check Settings") {
                                return "⚙️ Check Settings";
                            }
                        }
                        return "Check Settings";
                    }
                    
                    // Process warnings
                    warnings.forEach(function(el, index) {
                        var row = el.closest("tr");
                        var checkName = row ? row.querySelector("td:first-child") : null;
                        var checkText = checkName ? checkName.textContent.trim() : "Warning " + (index + 1);
                        var sectionName = getSectionName(el);
                        
                        el.setAttribute("data-issue-id", "warning-" + index);
                        issuesHtml += '<div class="issue-item" data-target="warning-' + index + '">';
                        issuesHtml += '<div class="issue-badge warning">⚠</div>';
                        issuesHtml += '<div class="issue-text">' + checkText + '<div class="issue-section">' + sectionName + '</div></div>';
                        issuesHtml += '</div>';
                    });
                    
                    // Process errors
                    errors.forEach(function(el, index) {
                        var row = el.closest("tr");
                        var checkName = row ? row.querySelector("td:first-child") : null;
                        var checkText = checkName ? checkName.textContent.trim() : "Error " + (index + 1);
                        var sectionName = getSectionName(el);
                        
                        el.setAttribute("data-issue-id", "error-" + index);
                        issuesHtml += '<div class="issue-item" data-target="error-' + index + '">';
                        issuesHtml += '<div class="issue-badge error">✗</div>';
                        issuesHtml += '<div class="issue-text">' + checkText + '<div class="issue-section">' + sectionName + '</div></div>';
                        issuesHtml += '</div>';
                    });
                    
                    panelBody.innerHTML = issuesHtml;
                    
                    // Add click handlers to scroll to issues
                    var issueItems = panelBody.querySelectorAll(".issue-item");
                    issueItems.forEach(function(item) {
                        item.addEventListener("click", function() {
                            var targetId = this.getAttribute("data-target");
                            var targetEl = document.querySelector('[data-issue-id="' + targetId + '"]');
                            if (targetEl) {
                                // Expand the section if collapsed
                                var section = targetEl.closest(".content");
                                if (section && !section.classList.contains("show")) {
                                    var btn = section.previousElementSibling;
                                    if (btn) btn.click();
                                }
                                // Scroll to element
                                setTimeout(function() {
                                    targetEl.scrollIntoView({ behavior: "smooth", block: "center" });
                                    // Highlight briefly
                                    targetEl.style.transition = "background 0.3s ease";
                                    targetEl.style.background = "#ffe066";
                                    setTimeout(function() {
                                        targetEl.style.background = "";
                                    }, 2000);
                                }, 300);
                            }
                            issuesPanel.classList.remove("show");
                        });
                    });
                }
            }
            
            // Toggle panel
            if (issuesBubble) {
                issuesBubble.addEventListener("click", function(e) {
                    if (!e.target.closest(".issues-panel")) {
                        issuesPanel.classList.toggle("show");
                    }
                });
            }
            
            // Close panel
            if (panelClose) {
                panelClose.addEventListener("click", function(e) {
                    e.stopPropagation();
                    issuesPanel.classList.remove("show");
                });
            }
            // CSV Export button handler
            var csvBtn = document.getElementById('csvExportBtn');
            if (csvBtn) {
                csvBtn.addEventListener('click', function() {
                    var base64Data = this.getAttribute('data-csv');
                    var csvContent = atob(base64Data);
                    var blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
                    var link = document.createElement('a');
                    link.href = URL.createObjectURL(blob);
                    link.download = 'SecurityIndicators.csv';
                    document.body.appendChild(link);
                    link.click();
                    document.body.removeChild(link);
                });
            }
        });
    </script>

</head>
<body>

<!-- HEADER - DSP v8 Style -->
<div class="header">
    <div style="display: flex; align-items: center; gap: 16px;">
        <img src="https://www.semperis.com/wp-content/uploads/images-icons/product/dsp/icon-3d-directory-services-protector-300x293.png" style="height:65px" alt="DSP Logo">
        <div>
            <div style="font-size: 23px; font-weight: 600;">Directory Services Protector</div>
            <div style="font-size: 14px; color: #8898aa;">Health Check Report v8 - Generated $currentdate</div>
        </div>
    </div>
    
    <div style="display: flex; align-items: center; gap: 16px;">
        <img src="https://www.semperis.com/wp-content/uploads/images-logos/main-logo.svg" style="height:30px; filter: brightness(0) invert(1);">
    </div>
</div>

<div style="width: 100%; padding: 20px; box-sizing: border-box;">
    
    <table>
        <tr>
            <th>Check Settings</th>
"@


# Add version info as bordered cards with left accent - ADFR v8 Style
$domainCount = @($existingdomains).Count
$hfCount = @($Hflist).Count

# Build Hotfix table rows for modal
$hfTableRows = ""
if ($Hflist -and $hfCount -gt 0) {
    foreach ($hf in $Hflist) {
        $hfName = $hf.Name
        $hfVersion = $hf.Version
        $installDate = if ($hf.InstallDate) { ([DateTime]$hf.InstallDate).ToString("yyyy-MM-dd HH:mm") } else { "N/A" }
        $hfTableRows += "<tr><td>$hfName</td><td>$installDate</td><td>$hfVersion</td></tr>`n"
    }
}

$htmlContent += @"
<div style="display: flex; justify-content: center; gap: 16px; padding: 10px 0; background: #f8f9fa; flex-wrap: wrap;">
    <div class="version-card" style="border-left: 4px solid $(if ($semperisVersion -ne 'Not Installed') { '#28a745' } else { '#dc3545' });">
        <div style="font-size: 14px; color: #6c757d; text-transform: uppercase; font-weight: bold;">DSP MS Version</div>
        <div style="font-size: 17px; font-weight: 600; color: #111d2c;">$(if ($semperisVersion -ne 'Not Installed') { $semperisVersion } else { 'Not Installed' })</div>
    </div>
    <div id="hfCard" class="version-card hf-clickable" style="border-left: 4px solid $(if ($hfCount -gt 0) { '#28a745' } else { '#ffc107' });">
        <div style="font-size: 14px; color: #6c757d; text-transform: uppercase; font-weight: bold;">Hotfixes <span class="hf-count-badge">$hfCount</span></div>
        <div style="font-size: 13px; color: #666;">Click to view details</div>
    </div>
    <div class="version-card" style="border-left: 4px solid #4a90e2;">
        <div style="font-size: 14px; color: #6c757d; text-transform: uppercase; font-weight: bold;">Forest</div>
        <div style="font-size: 17px; font-weight: 600; color: #111d2c;">$ForestName</div>
    </div>
    <div class="version-card" style="border-left: 4px solid #17a2b8;">
        <div style="font-size: 14px; color: #6c757d; text-transform: uppercase;">Domains</div>
        <div style="font-size: 17px; font-weight: 600; color: #111d2c;">$domainCount Monitored</div>
    </div>
    <div class="score-card" style="border-left: 4px solid $(if ($percentage -ge 90) { '#28a745' } elseif ($percentage -ge 70) { '#ff9800' } else { '#dc3545' }); min-width: 120px;">
        <div style="font-size: 14px; color: #6c757d; text-transform: uppercase;">Security Posture</div>
        <div class="score-value" style="color: $(if ($percentage -ge 90) { '#28a745' } elseif ($percentage -ge 70) { '#ff9800' } else { '#dc3545' });">$scoreValue%</div>
        <div class="score-grade" style="color: $(if ($percentage -ge 90) { '#28a745' } elseif ($percentage -ge 70) { '#ff9800' } else { '#dc3545' });">Grade: $scoreGrade</div>
    </div>
</div>

"@

# Build Hotfix Modal HTML (will be added at end of body)
$hfModalHtml = "<div id='hfModal' class='modal-overlay'>"
$hfModalHtml += "<div class='modal-content'>"
$hfModalHtml += "<div class='modal-header'><h3>🔧 Installed Hotfixes ($hfCount)</h3><button id='hfClose' class='modal-close'>&times;</button></div>"
$hfModalHtml += "<table class='hf-table'><tr><th>Name</th><th>Install Date</th><th>Version</th></tr>"
$hfModalHtml += $hfTableRows
$hfModalHtml += "</table></div></div>"

##### Activity Metrics Widget (DSP 5.x+ only) #####
if ([version]$semperisVersion -ge [version]"5.0.0.0") {
    # Helper function to format large numbers
    function Format-Number {
        param([int64]$num)
        if ($num -ge 1000000) { return "{0:N1}M" -f ($num / 1000000) }
        elseif ($num -ge 1000) { return "{0:N0}K" -f ($num / 1000) }
        else { return $num.ToString() }
    }
    
    $htmlContent += @"
<div class='activity-container'>
    <div class='period-card'>
        <h3>📅 Last 7 Days Activity</h3>
        <div class='metrics-grid'>
            <div class='metric-item created'><div class='metric-value'>$(Format-Number $last7DaysSummary.Created)</div><div class='metric-label'>Created</div></div>
            <div class='metric-item modified'><div class='metric-value'>$(Format-Number $last7DaysSummary.Modified)</div><div class='metric-label'>Modified</div></div>
            <div class='metric-item deleted'><div class='metric-value'>$(Format-Number $last7DaysSummary.Deleted)</div><div class='metric-label'>Deleted</div></div>
            <div class='metric-item moved'><div class='metric-value'>$(Format-Number $last7DaysSummary.Moved)</div><div class='metric-label'>Moved</div></div>
            <div class='metric-item restored'><div class='metric-value'>$(Format-Number $last7DaysSummary.Restored)</div><div class='metric-label'>Restored</div></div>
        </div>
    </div>
    <div class='period-card thirty-days'>
        <h3>📆 Last 30 Days Activity</h3>
        <div class='metrics-grid'>
            <div class='metric-item created'><div class='metric-value'>$(Format-Number $last30DaysSummary.Created)</div><div class='metric-label'>Created</div></div>
            <div class='metric-item modified'><div class='metric-value'>$(Format-Number $last30DaysSummary.Modified)</div><div class='metric-label'>Modified</div></div>
            <div class='metric-item deleted'><div class='metric-value'>$(Format-Number $last30DaysSummary.Deleted)</div><div class='metric-label'>Deleted</div></div>
            <div class='metric-item moved'><div class='metric-value'>$(Format-Number $last30DaysSummary.Moved)</div><div class='metric-label'>Moved</div></div>
            <div class='metric-item restored'><div class='metric-value'>$(Format-Number $last30DaysSummary.Restored)</div><div class='metric-label'>Restored</div></div>
        </div>
    </div>
</div>
"@
}
##### End Activity Metrics Widget #####
# Add Forest names as table headers
$htmlContent += "<th>$($ForestName)</th>"
$htmlContent += "</tr>"
### Starting CHECKS
### Check 1 : DSP License Type
$htmlContent += "<tr><td><b>DSP License Type</b></td>"
$htmlContent +=  "<td> $DSPLicenseType </td>"
$htmlContent += "</tr>"
### Check 2: DSP For Entra ID
$htmlContent += "<tr><td><b>DSP Modules</b></td>"
$htmlContent +=  "<td> $DSPModules </td>"
$htmlContent += "</tr>"

### START Check 3: Export Settings
$ExportSettingsData = Invoke-RestMethod -Uri "$script:dspServerConsole/api/General/GetGeneralConfiguration?_=$timestamp" -WebSession $script:WebSession -Method Get 
$ExportSettings = $ExportSettingsData.IsRunScheduledSettingsExport
$htmlContent += "<tr><td><b>DSP Export Settings</b></td>"
if ( $ExportSettings -eq $true ){
    $htmlContent += "<td class='ok'> <span class='custom-check'></span> Configured</td>"
    }
else {
    $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-fail'></span>Not Configured</span></td>"
    }
$htmlContent += "</tr>"

### END Check 3: Export Settings
### START Check 4: SMTP Enabled
$SMTPDATA = Invoke-RestMethod -Uri "$script:dspServerConsole/api/SMTP?tabId=$tabID" -WebSession $script:WebSession -Method Get 
$smtp = $SMTPDATA.Data
$htmlContent += "<tr><td><b>SMTP Enabled and Verified</b></td>"
$SMTPEnabled = $smtp.EnableSmtp
$SMTPVerified = $smtp.Verified
if ($SMTPEnabled -eq $true -and $SMTPVerified -eq $true) {
    $htmlContent += "<td class='ok'> <span class='custom-check'></span> Configured</td>"
}
elseif ($SMTPEnabled -eq $true -and $SMTPVerified -ne $true) {
    $htmlContent += "<td class='warning'> <span class='custom-fail'></span> Not Verified</td>"
}
else {
    $htmlContent += "<td class='ko'> SMTP Not Configured</td>"
}
$htmlContent += "</tr>"
### END Check 4: SMTP Settings
### START Check 5: SAML

$SAMLDATA = Invoke-RestMethod -Uri "$script:dspServerConsole/api/SAML?tabId=$tabID" -WebSession $script:WebSession -Method Get 
$htmlContent += "<tr><td><b>SAML Enabled and Configured</b></td>"
$SAMLConfigured = $SAMLDATA.Status
if ($SAMLConfigured -eq "Configured"){
    $htmlContent += "<td class='ok'> <span class='custom-check'></span> Configured </td>"
}
else {
        $htmlContent += "<td> Not Configured</td>"

}
$htmlContent += "</tr></table>"
##-- End of CHECKS
#############################

# Add Expand All / Collapse All buttons - ADFR v8 Style
$htmlContent += @"
<div style="text-align: right; margin: 10px 0;">
    <button id="expandAll" style="background: linear-gradient(135deg, #111d2c 0%, #1a2d42 100%); color: white; border: none; padding: 6px 15px; margin: 0 5px; border-radius: 5px; cursor: pointer; font-size: 14px; transition: all 0.3s ease;" onmouseover="this.style.background='linear-gradient(135deg, #1a2d42 0%, #243b53 100%)';" onmouseout="this.style.background='linear-gradient(135deg, #111d2c 0%, #1a2d42 100%)';">
        <span class="expand-icon"></span>Expand All
    </button>
    <button id="collapseAll" style="background: linear-gradient(135deg, #111d2c 0%, #1a2d42 100%); color: white; border: none; padding: 6px 15px; margin: 0 5px; border-radius: 5px; cursor: pointer; font-size: 14px; transition: all 0.3s ease;" onmouseover="this.style.background='linear-gradient(135deg, #1a2d42 0%, #243b53 100%)';" onmouseout="this.style.background='linear-gradient(135deg, #111d2c 0%, #1a2d42 100%)';">
        <span class="collapse-icon"></span>Collapse All
    </button>
</div>
"@

###### START SECTION: DSP & SQL Server Info 
$htmlContent += "<button class='collapsible'>🧩 DSP & SQL Server Information</button><div class='content'>"

# === DSP Server Info Table ===
$htmlContent += "<div class='section-badge'>📡 DSP Management Server Info</div>"
# Get server name
$dspServer = $env:COMPUTERNAME
# Get OS info
$osInfo = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
# Check if IIS is installed and running
$w3svc = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
if ($w3svc) {
    $iisStatus = if ($w3svc.Status -eq 'Running') { "<span class='custom-check'></span> Running" } else { "<span class='custom-fail'></span> Installed but not running" }
} else {
    $iisStatus = "<span class='custom-fail'></span> Not Installed"
}
# Disk layout
$drives = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }

$diskList = $drives | ForEach-Object {
    $label = $_.DeviceID
    $free = "{0:N0} GB" -f ($_.FreeSpace / 1GB)
    "$label = $free"
}
$diskInfo = $diskList -join "<br>"
## Check Service Account ###
$DSPSvcAccount = $DBSettings.AuthenticationAccountName

# Table layout
$htmlContent += "<table><tr>
    <th>Hostname</th>
    <th>OS</th>
    <th>IIS Status</th>
    <th>DSP Service Account</th>
    <th>Disk Layout</th>
    <th>Net.TcP Binding</th>
    <th>Remote Registry</th>
</tr><tr>
    <td>$dspServer</td>
    <td>$osInfo</td>
    <td>$iisStatus</td>
    <td>$DSPSvcAccount</td>
    <td>$diskInfo</td>
    <td>$tcpStatus</td>
    <td>$remoteRegService</td>
    
</tr></table>"
#Partition Check
$htmlContent += "<div class='section-badge'>🔄 AD Partition Synchronized</div>"
$htmlContent += "<table>
<tr>
    <th> Partition Name</th>
    <th>Status</th>
    <th>Error (If any)</th>
</tr>"

foreach ($partition in $GetADPartition) {
    $ldapName  = $partition.LdapPartitionName
    $statusVal = $partition.Status
    $errorMsg  = $partition.ErrorMessage

    if ($statusVal -eq 3) {
        $status = "<td style='background-color: #d4edda;'>Sync</td>"  # green
    }
    elseif ($statusVal -eq 8) {
        $status = "<td class='warning'>NOT SYNC</td>"  # warning class (orange)
    }
    else {
        $status = "<td>$statusVal</td>"  # fallback
    }

    $htmlContent += "<tr>
        <td>$ldapName</td>
        $status
        <td>$errorMsg</td>
    </tr>"
}
$htmlContent += "</table>"

# === SQL TABLE ===
$htmlContent += "<div class='section-badge'>🗄️ SQL Server Information</div>"

# Parse values from AdsmData XML
$SqlRaw = $AdsmData.ChildNodes | Where-Object { $_.Name -like "Sql*" }
$SqlMap = @{}
foreach ($node in $SqlRaw) {
    $SqlMap[$node.Name] = $node.'#text'
}
# Define display order and labels
$sqlColumns = @("SqlServer", "SqlDomain", "SqlDb", "SqlAuth", "SqlUser", "SqlPort")
$sqlHeaders = @("Server Name", "Server Domain", "Database Name", "Authentication Type", "SQL User", "SQL Port")
# Start SQL table
$htmlContent += "<table><tr>"
# Header row
foreach ($header in $sqlHeaders) {
    $htmlContent += "<th>$header</th>"
}
$htmlContent += "</tr><tr>"
# Value row
foreach ($key in $sqlColumns) {
    $value = $SqlMap[$key]
    if (-not $value) { $value = "N/A" }
    $htmlContent += "<td>$value</td>"
}
$htmlContent += "</tr></table>"  # Properly close SQL table
$htmlContent += "</div>"  # Close collapsible content block

###### END SECTION: DSP & SQL Server Info 
#------------------------------------------------------
#### START SECTION: IRP SECTION
if ($flags -contains "DSP_IRP") {
    # Sort IRP attacks: incidents > 0 first, then by name
    $sortedIRPAttacks = $IRPAttacks | Sort-Object @{Expression={if ($_.IncidentsCount -gt 0) { 0 } else { 1 }}}, Name
    
    $htmlContent += "<button class='collapsible'>🎯 IRP Indicators</button><div class='content'>"
    $htmlContent += "<div class='table-scroll'>"
    $htmlContent += "<table><tr>
        <th>Attack Name</th>
        <th>Severity</th>
        <th>Incident Count</th>
        <th>Type</th>
        <th>Tags</th>
    </tr>"
    
    foreach ($IRPAttack in $sortedIRPAttacks) {
        $IRPAttackName = $IRPAttack.Name
        $IRPAttackSeverity = $IRPAttack.Severity
        $IRPAttackIncidentCount = $IRPAttack.IncidentsCount 
        $IRPAttackType = $IRPAttack.Type
        $IRPAttackTags = ($IRPAttack.Tags | ForEach-Object { "$($_.label) ($($_.children -join ', '))" }) -join " | "
        
        # Set cell class based on incident count (td.ko is detected by issues bubble)
        $cellClass = if ($IRPAttackIncidentCount -gt 0) { " class='ko'" } else { "" }
        
        $htmlContent += "<tr>
            <td$cellClass>$IRPAttackName</td>
            <td>$IRPAttackSeverity</td>
            <td>$IRPAttackIncidentCount</td>
            <td>$IRPAttackType</td>
            <td>$IRPAttackTags</td>
        </tr>"
    }
    
    $htmlContent += "</table></div>"
    $htmlContent += "</div>"
}
#### END SECTION IRP SECTION
#------------------------------------------------------
##### START SECTION: Security Indicators Summary #####
$htmlContent += "<button class='collapsible'>🛡️ Security Indicators Summary</button><div class='content'>"
# Calculate totals for IOE Summary bar
$totalPassed = ($scoreData.Categories | Measure-Object -Property PassedCount -Sum).Sum
$totalIOEFound = ($scoreData.Categories | Measure-Object -Property IOEFoundCount -Sum).Sum
$totalIndicators = $totalPassed + $totalIOEFound
if ($totalIndicators -eq 0) { $totalIndicators = 1 }
$passedPercent = [math]::Round(($totalPassed / $totalIndicators) * 100)
$ioeFoundPercent = [math]::Round(($totalIOEFound / $totalIndicators) * 100)

# IOE Summary Progress Bar
$htmlContent += "<div class='ioe-summary-container'><div class='ioe-summary-bar' style='flex: 1;'>"
$htmlContent += "<h4>📊 IOE Summary</h4>"
$htmlContent += "<div class='ioe-progress-bar'><div class='passed' style='width: $passedPercent%;'></div><div class='ioe-found' style='width: $ioeFoundPercent%;'></div></div>"
$htmlContent += "<div class='ioe-legend'><span><div class='dot passed'></div> Passed ($passedPercent%)</span><span><div class='dot ioe-found'></div> IOE Found ($ioeFoundPercent%)</span></div></div></div>"

# IOE AD Categories Cards
$htmlContent += "<h4 style='margin: 20px 0 10px 0; color: #333;'>📁 IOE AD Categories</h4>"
$htmlContent += "<div class='ioe-categories-container'>"
foreach ($category in $scoreData.Categories) {
    $grade = $category.Grade -replace 'Plus$', '+' -replace 'Minus$', '-'
    $score = $category.Score
    $evaluated = $category.PassedCount + $category.IOEFoundCount
    $ioeFound = $category.IOEFoundCount
    $gradeClass = switch -Regex ($grade) { '^A' { 'grade-a' } '^B' { 'grade-b' } '^C' { 'grade-c' } '^D' { 'grade-d' } '^F' { 'grade-f' } default { 'grade-na' } }
    $htmlContent += "<div class='ioe-category-card'><div class='ioe-circle $gradeClass'>$score%</div>"
    $htmlContent += "<div class='ioe-category-info'><div class='name'>$($category.Name)</div>"
    $htmlContent += "<div class='stats'>Evaluated: $evaluated</div><div class='stats'>IOE's found: <span class='ioe-count'>$ioeFound</span></div></div></div>"
}
$htmlContent += "</div>"

# IOE Entra ID Categories Cards (if available)
if ($scoreData.AADCategories -and $scoreData.AADCategories.Count -gt 0) {
    $htmlContent += "<h4 style='margin: 20px 0 10px 0; color: #333;'>☁️ IOE Entra ID Categories</h4>"
    $htmlContent += "<div class='ioe-categories-container'>"
    foreach ($category in $scoreData.AADCategories) {
        $grade = $category.Grade -replace 'Plus$', '+' -replace 'Minus$', '-'
        $score = $category.Score
        $evaluated = $category.PassedCount + $category.IOEFoundCount
        $ioeFound = $category.IOEFoundCount
        $gradeClass = switch -Regex ($grade) { '^A' { 'grade-a' } '^B' { 'grade-b' } '^C' { 'grade-c' } '^D' { 'grade-d' } '^F' { 'grade-f' } default { 'grade-na' } }
        $htmlContent += "<div class='ioe-category-card'><div class='ioe-circle $gradeClass'>$score%</div>"
        $htmlContent += "<div class='ioe-category-info'><div class='name'>$($category.Name)</div>"
        $htmlContent += "<div class='stats'>Evaluated: $evaluated</div><div class='stats'>IOE's found: <span class='ioe-count'>$ioeFound</span></div></div></div>"
    }
    $htmlContent += "</div>"
}
$htmlContent += "</div>"
##### END SECTION #####
################################################

##### START SECTION: Detailed Security Indicators #####
# Pre-process indicators to determine status and sort KO first
$processedIndicators = @()
foreach ($indicator in $IndicatorsList) {
    $indicatorName = $indicator.Name
    
    $targets = if ($indicator.Targets) {
        ($indicator.Targets -join ", ")
    } else {
        "N/A"
    }
    
    $lastRunFormatted = "Never"
    $rowClass = ""
    $lastRunDateTime = $null
    $sortOrder = 2  # Default: no status (middle)
    
    if ($indicator.LastEvaluated) {
        try {
            $lastRunDateTime = [DateTime]::Parse($indicator.LastEvaluated)
            $lastRunDateTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($lastRunDateTime, [System.TimeZoneInfo]::Local)
            $lastRunFormatted = $lastRunDateTime.ToString("yyyy-MM-dd / HH:mm")
        } catch {
            $lastRunFormatted = "Never"
        }
    }
    
    $schedule = if ($indicator.General.Schedule) {
        $indicator.General.Schedule
    } else {
        "N/A"
    }
    
    # Determine row class and sort order
    if ($lastRunDateTime -and $schedule -ne "N/A") {
        $timeSinceLastRun = (Get-Date) - $lastRunDateTime
        
        switch ($schedule) {
            "Every 1 hour" {
                if ($timeSinceLastRun.TotalHours -gt 1) {
                    $rowClass = " class='ko'"; $sortOrder = 0
                } else {
                    $rowClass = " class='ok'"; $sortOrder = 3
                }
            }
            "Every Day" {
                if ($timeSinceLastRun.TotalHours -gt 24) {
                    $rowClass = " class='ko'"; $sortOrder = 0
                } else {
                    $rowClass = " class='ok'"; $sortOrder = 3
                }
            }
            "Every Week" {
                if ($timeSinceLastRun.TotalDays -gt 7) {
                    $rowClass = " class='ko'"; $sortOrder = 0
                } else {
                    $rowClass = " class='ok'"; $sortOrder = 3
                }
            }
        }
    } elseif ($lastRunFormatted -eq "Never") {
        $rowClass = " class='ko'"; $sortOrder = 0
    }
    
    $processedIndicators += [PSCustomObject]@{
        Name = $indicatorName
        Targets = $targets
        LastRun = $lastRunFormatted
        Schedule = $schedule
        RowClass = $rowClass
        SortOrder = $sortOrder
    }
}

# Sort: KO first (0), then no status (2), then OK (3)
$sortedIndicators = $processedIndicators | Sort-Object SortOrder, Name

# Build CSV data for download - use base64 encoding to avoid escaping issues
$csvLines = [System.Collections.ArrayList]@()
[void]$csvLines.Add("Indicator Name,Targets,Last Run,Schedule")
foreach ($ind in $sortedIndicators) {
    [void]$csvLines.Add("`"$($ind.Name)`",`"$($ind.Targets)`",`"$($ind.LastRun)`",`"$($ind.Schedule)`"")
}
$csvFullContent = $csvLines -join [Environment]::NewLine
$csvBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($csvFullContent))

$htmlContent += "<button class='collapsible'>📊 Security Indicators Scheduler </button><div class='content'>"
$htmlContent += "<div style='margin-bottom: 10px; text-align: right;'><button id='csvExportBtn' data-csv='$csvBase64' style='background: linear-gradient(135deg, #1a2332, #2d3a4d); color: white; border: none; padding: 8px 16px; border-radius: 6px; cursor: pointer; font-size: 13px;'>📥 Export CSV</button></div>"
$htmlContent += "<div class='table-scroll'>"
$htmlContent += "<table><tr>
    <th>Indicator Name</th>
    <th>Targets</th>
    <th>Last Run</th>
    <th>Schedule</th>
</tr>"

# Output sorted indicators
foreach ($ind in $sortedIndicators) {
    $htmlContent += "<tr$($ind.RowClass)>
        <td>$($ind.Name)</td>
        <td>$($ind.Targets)</td>
        <td>$($ind.LastRun)</td>
        <td>$($ind.Schedule)</td>
    </tr>"
}

$htmlContent += "</table></div></div>"
##### END SECTION: Detailed Security Indicators #####
################################################
###### START SECTION: IAS Information
$htmlContent += "<button class='collapsible'>🐧 Identity Analytics Server </button><div class='content'>"
$htmlContent += "<table>
<tr>
    <th>IAS Paired</th>
    <th>IAS IP</th>
    <th>IAS Version</th>
    <th>Health Alert Disk Free Space</th>
    <th>Health Alert % Free Space</th>
</tr>
<tr>
    <td>$($IASstatus.hsConnectionSettings.HipPairingStatus)</td>
    <td>$($IASstatus.hsConnectionSettings.HsAddress)</td>
    <td>$($IASstatus.hsConnectionSettings.HsVersion)</td>
    <td$(if ($IASdiskspacebelow -eq "1GB") { " class='warning'" })>$IASdiskspacebelow$(if ($IASdiskspacebelow -eq "1GB") { " (Default)" })</td>
    <td$(if ($IASdiskPercent -eq "5%") { " class='warning'" })>$IASdiskPercent$(if ($IASdiskPercent -eq "5%") { " (Default)" })</td>
</tr>
</table>"

# Start the table
$htmlContent += "<div class='section-badge'>🏥 IAS Health-Check</div>
<table>
<tr>
    <th>IAS Service</th>
    <th>Service Health</th>
</tr>
"

# Add each row from $IaShealth with status formatting
foreach ($item in $IaShealth) {
    $statusText = $item.status
    $cssClass = ""
    
    if ($statusText -eq "HEALTHY") {
        $statusText = "Healthy `<span class='custom-check'></span>"   # Add check mark
        $cssClass = " class='ok'"          # Add CSS class
    }

    $htmlContent += "<tr>
        <td>$($item.displayName)</td>
        <td$cssClass>$statusText</td>
    </tr>"
}

# Close the table
$htmlContent += "</table>"

$htmlContent += "</div>"

###### END SECTION: IAS Information
#------------------------------------------------------

###### START SECTION : DSP Retention Settings
$htmlContent += "<button class='collapsible'>🧾 DSP Retention Settings</button><div class='content'>"

# Calculate retention period with appropriate time unit
switch ($dbsettings.DataRetentionResolution) {
    30 { 
        $retentionPeriod = "$($dbsettings.DataRetentionAmount) Month$(if($dbsettings.DataRetentionAmount -ne 1){'s'})"
    }
    7 { 
        $retentionPeriod = "$($dbsettings.DataRetentionAmount) Week$(if($dbsettings.DataRetentionAmount -ne 1){'s'})"
    }
    365 { 
        $retentionPeriod = "$($dbsettings.DataRetentionAmount) Year$(if($dbsettings.DataRetentionAmount -ne 1){'s'})"
    }
    default { 
        $retentionPeriod = "$($dbsettings.DataRetentionAmount) Day$(if($dbsettings.DataRetentionAmount -ne 1){'s'})"
    }
}


# Now $retentionPeriod contains the formatted string like "6 Months", "2 Weeks", "1 Year", etc.
$RetentionIndicators = $XmlDspData.AdsmConfiguration.HSSettings.IoeIocRetentionPeriodInDays
$htmlContent += "<table>
<tr>
    <th>AD Changes Retention (Days)</th>
    <th>GPO Changes Retention (Days)</th>
    <th>GPO Backup Location</th>
    <th>Indicators Result (Days)</th>
    <th>Undo Actions (Days)</th>
    <th>Audit Log (Days)</th>
</tr>

<tr>
    <td$(if ($retentionPeriod -eq "2 Weeks") { " class='warning'" })>$($retentionPeriod)$(if ($retentionPeriod -eq "2 Weeks") { " (Default)" })</td>
    <td$(if ($GPORetention -eq 14) { " class='warning'" })>$($GPORetention)$(if ($GPORetention -eq 14) { " (Default)" })</td>
    <td>$($GPOBackupPath)</td>
    <td>$($RetentionIndicators)</td>
    <td>$($RetentionUndoActions)</td>
    <td>$($AuditLog)</td>
</tr>
</table>"

$htmlContent += "</div>"


###### END SECTION: DSP Retention Settings
#------------------------------------------------------
##### START SECTION : Domain Controller Information #####
$htmlContent += "<button class='collapsible'>🆓 DSP & Audit Agents</button><div class='content'>"

### === DSP Agents Table ===
$dspAgentCount = @($DspAgents).Count
$htmlContent += "<div class='section-badge'>🖥️ DSP Agents ($dspAgentCount)</div>"
$htmlContent += "<div class='table-scroll'>
<table><tr>
    <th>DC Name</th>
    <th>Domain</th>
    <th>Agent Status</th>
    <th>Version</th>
    <th>Enrolled</th>
    <th>OS Version</th>
</tr>"

foreach ($agent in ($DspAgents | Sort-Object Domain)) {
    $agentStatus = if ($agent.IsResponding -eq $true) { 
        "<span class='custom-check'></span>" 
    } elseif ($agent.IsInstalled -eq $true) { 
        "<span class='custom-fail'></span>" 
    } else { 
        "<span class='custom-warning'></span>" 
    }
    $domainStatus = if ($agent.Domain) { " $($agent.Domain)" } else { "<span class='custom-fail'></span>" }
    $enrolled = if ($agent.IsAgentEnrolledToLocalManagement -eq $true) { "<span class='custom-check'></span>" } else { "<span class='custom-fail'></span>" }

    $htmlContent += "<tr>
    <td>$($agent.Id)</td>
    <td>$domainStatus</td>
    <td>$agentStatus</td>
    <td>$($agent.Version)</td>
    <td>$enrolled</td>
    <td>$($agent.OsVersion)</td>
    </tr>"
}
$htmlContent += "</table></div>"
### === Audit Agents Table ===
$auditAgentCount = @($ADSNAgents).Count
$htmlContent += "<div class='section-badge'>📋 Audit Agents ($auditAgentCount)</div>"
$htmlContent += "<div class='table-scroll'>
<table><tr>
    <th>DC Name</th>
    <th>Domain</th>
    <th>Agent Status</th>
    <th>Version</th>
    <th>Audit Store Location</th>
</tr>"

foreach ($agent in ($ADSNAgents | Sort-Object Domain)) {
    $agentStatus = if ($agent.IsResponding -eq $true) { "<span class='custom-check'></span>" } else { "<span class='custom-fail'></span>" }
    $domainStatus = if ($agent.Domain) { " $($agent.Domain)" } else { "<span class='custom-fail'></span>" }

    $htmlContent += "<tr>
    <td>$($agent.Id)</td>
    <td>$domainStatus</td>
    <td>$agentStatus</td>
    <td>$($agent.Version)</td>
    <td>$($agent.StoreLocation)</td>
    </tr>"
}
$htmlContent += "</table></div>"

$htmlContent += "</div>"
##### END SECTION #####
#------------------------------------------------------
##### START SECTION : ENTRA ID
if ($XmlDspData.AdsmConfiguration.TenantConfigurations.TenantConfiguration.TenantRegistrationStatus -eq 'Registered') {
    $htmlContent += "<button class='collapsible'>☁️ Entra ID Data Connection</button><div class='content'>"
    $htmlContent += "<table>
    <tr>
        <th>Tenant Connected</th>
        <th>Tenant ID</th>
        <th>Tenant Name</th>
        <th>Event Hub Namespace</th>
        <th>Event Hub Name</th>
        </tr>
    <tr>
        <td><span class='custom-check'></span> Registered</td>
        <td>$($XmlDspData.AdsmConfiguration.TenantConfigurations.TenantConfiguration.TenantId)</td>
        <td>$($XmlDspData.AdsmConfiguration.TenantConfigurations.TenantConfiguration.DisplayName)</td>
        <td>$($XmlDspData.AdsmConfiguration.TenantConfigurations.TenantConfiguration.EventHubNamespace)</td>
        <td>$($XmlDspData.AdsmConfiguration.TenantConfigurations.TenantConfiguration.EventHubName)</td>
    </tr>
    </table>"
    $htmlContent += "</div>"
}

#### END SECTION : ENTRA ID
#------------------------------------------------------
###### START SECTION: Object List
if ([version]$semperisVersion -ge [version]"5.0.0.0") {

    $htmlContent += "<button class='collapsible'>📋Object List + Security Context </button><div class='content'>"
    ### Object List####
    $resultParams = Invoke-RestMethod -Uri "$dspServerConsole$subPathMainGetParams" -Method GET -WebSession $webSession
    $inputString = $resultParams.__RequestVerificationToken
    $pattern = 'value="([^"]+)"'
    #updated verification token
    $uVerificationToken = $inputString | Select-String -Pattern $pattern | ForEach-Object { $_.Matches.Groups[1].Value }
    $uTabId = $resultParams.TabID
    $objectListQuery = @{
    __RequestVerificationToken = $uVerificationToken
    tabId = $uTabId
    SortAsc = "true"
    Offset = "0"
    PageSize = "50"
    }
    
    $objectLists = Invoke-RestMethod -Uri "$script:dspServerConsole/api/ObjectLists/GetObjectLists" -Method POST -Body $objectListQuery -WebSession $webSession -UseBasicParsing
    $Assets = $objectLists.ObjectLists
    $AssetsRules = $Assets.RulesData.Rules
    $AssetsCount = $Assets.RulesData.Count

    # ---- AD Rules Table ----
    $htmlContent += "<div class='section-badge'>📋 Object Lists</div><table><tr>
        <th>Object List Name</th>
        <th>Object List Count</th>
        <th>Service Account Object List </th>
        <th>Rule using this object</th>
    </tr>"

    foreach ($asset in $Assets) {
            $objectCount = 0

    foreach ($objectType in $asset.ObjectTypes) {
        $objectCount += $objectType.Count
    }
    $htmlContent += "<tr>
    <td style='text-align: left;'>$($asset.Name)</td>
    <td>$($objectCount)</td>
    <td>$($asset.IsServiceAccount)</td>
    <td>$($asset.RulesData.Rules.Name)</td>
    </tr>"
    }
    $htmlContent += "</table><br>"
    $htmlContent += "</div>" 
}

### END SECTION OBJECT LIST
#------------------------------------------------------
##### START SECTION: Notification Rule
$htmlContent += "<button class='collapsible'>📢 Notification Rules</button><div class='content'>"

$ADRules = Invoke-RestMethod -Uri "$script:dspServerConsole/api/Notifications/GetRules?tabId=$tabID" -WebSession $script:WebSession -Method Get
$EIDRules = Invoke-RestMethod -Uri "$script:dspServerConsole/api/Notifications/GetAadRules?tabId=$tabID" -WebSession $script:WebSession -Method Get
$LogOnRules = Invoke-RestMethod -Uri "$script:dspServerConsole/api/Notifications/GetADLogonRules?tabId=$tabID" -WebSession $script:WebSession -Method Get

$htmlContent += "<div class='section-badge'>📁 Active Directory Rules ($(@($ADRules).Count))</div>
<div class='table-scroll'>
<table><tr>
    <th>Rule Name</th>
    <th>Active</th>
    <th>Auto Undo</th>
    <th>Automated Actions</th>
</tr>"

foreach ($rule in $ADRules) {
    $htmlContent += "<tr>
        <td>$($rule.Name)</td>
        <td>$($rule.IsEnabled)</td>
        <td>$($rule.IsAutoUndo)</td>
        <td>$($rule.AutomatedActions -join ', ')</td>
    </tr>"
}
$htmlContent += "</table></div><br>"
# ---- EID Rules Table ----
if ($XmlDspData.AdsmConfiguration.TenantConfigurations.TenantConfiguration.TenantRegistrationStatus -eq 'Registered') {

$htmlContent += "<div class='section-badge'>☁️ Entra ID Rules ($(@($EIDRules).Count))</div><div class='table-scroll'><table><tr>
    <th>Rule Name</th>
    <th>Active</th>
    <th>Auto Undo</th>
    <th>Automated Actions</th>
</tr>"

foreach ($rule in $EIDRules) {
    $htmlContent += "<tr>
        <td>$($rule.Name)</td>
        <td>$($rule.IsEnabled)</td>
        <td>$($rule.IsAutoUndo)</td>
        <td>$($rule.AutomatedActions -join ', ')</td>
    </tr>"
}
$htmlContent += "</table></div><br>"
}
# ---- Logon Rules Table ----
$htmlContent += "<div class='section-badge'>🔐 AD Logon Rules ($(@($LogOnRules).Count))</div><div class='table-scroll'><table><tr>
    <th>Rule Name</th>
    <th>Active</th>
    <th>Auto Undo</th>
    <th>Automated Actions</th>
</tr>"

foreach ($rule in $LogOnRules) {
    $htmlContent += "<tr>
        <td>$($rule.Name)</td>
        <td>$($rule.IsEnabled)</td>
        <td>$($rule.IsAutoUndo)</td>
        <td>$($rule.AutomatedActions -join ', ')</td>
    </tr>"
}
$htmlContent += "</table></div><br>"

$htmlContent += "</div>"  #  Close collapsible content block
#------------------------------------------------------

### Start Check of Registry Keys
# --- Semperis Registry Overview ---
$htmlContent += "<button class='collapsible'>🛠️ Semperis Registry Configuration</button><div class='content'>"

# Define registry paths and the value names
$registryChecks = @(
    @{ Name = "LogLevel"; Path = "HKLM:\SOFTWARE\Semperis" },
    @{ Name = "ManagementServerID"; Path = "HKLM:\SOFTWARE\Semperis" },
    @{ Name = "Backups Target Directory"; Path = "HKLM:\SOFTWARE\Semperis\Gpsm" },
    @{ Name = "AdsmIgnoreTimeShiftValidation"; Path = "HKLM:\SOFTWARE\Semperis\ASDM\Server" }
)

# Start table
$htmlContent += "<table><tr>"
# Header row
foreach ($item in $registryChecks) {
    $htmlContent += "<th>$($item.Name)</th>"
}
$htmlContent += "</tr><tr>"
# Value row
foreach ($item in $registryChecks) {
    try {
        $value = (Get-ItemProperty -Path $item.Path -Name $item.Name -ErrorAction Stop).$($item.Name)
    } catch {
        $value = "N/A"
    }
    # Check for LogLevel default value (4)
    $cellClass = ""
    $defaultText = ""
    if ($item.Name -eq "LogLevel" -and $value -eq 4) {
        $cellClass = " class='warning'"
        $defaultText = " (Default)"
    }
    $htmlContent += "<td$cellClass>$value$defaultText</td>"
}

$htmlContent += "</tr></table></div>"
### End Check of Registry Keys
##################################
## START Check Semperis Services 
$semperisServices = Get-Service | Where-Object { $_.DisplayName -match "Semperis" }
$htmlContent += "<button class='collapsible'>⚙️ Semperis Services Status</button><div class='content'>"
$htmlContent += "<table><tr>"

# First row: service names as table headers
foreach ($service in $semperisServices) {
    $htmlContent += "<th>$($service.DisplayName)</th>"
}
$htmlContent += "</tr><tr>"
# Second row: status of each service
foreach ($service in $semperisServices) {
    if ($service.Status -eq 'Running') {
        $htmlContent += "<td class='ok'><span class='custom-check'></span> Ok</td>"
    } else {
        $htmlContent += "<td class='ko'><span class='custom-fail'></span> KO</td>"
    }
}
$htmlContent += "</tr></table></div>"
## END Check Semperis Services
######----------------------------------------
#--- End of Script
# Close the main container div
$htmlContent += "</div>"
# Add Hotfix Modal at end of body (must be outside main content for proper overlay)
$htmlContent += $hfModalHtml

# Add Floating Issues Bubble
$htmlContent += @"
<!-- Floating Issues Bubble -->
<div id="issuesBubble" class="issues-bubble">
    <button class="bubble-btn">
        ⚠
        <span id="bubbleCount" class="bubble-count">0</span>
    </button>
    <div id="issuesPanel" class="issues-panel">
        <div class="panel-header">
            <h4>🔍 Issues Summary</h4>
            <button id="panelClose" class="panel-close">&times;</button>
        </div>
        <div class="panel-stats">
            <div class="stat-item warnings">
                <div class="stat-icon warning-icon">⚠</div>
                <span id="warningCount">0</span> Warnings
            </div>
            <div class="stat-item errors">
                <div class="stat-icon error-icon">✗</div>
                <span id="errorCount">0</span> Errors
            </div>
        </div>
        <div id="panelBody" class="panel-body">
            <!-- Issues will be populated by JavaScript -->
        </div>
    </div>
</div>
"@

$htmlContent += "</body></html>"
$htmlContent | Out-File -FilePath $outputFile -Encoding UTF8

if ($Open) {
    Write-Host "Opening HTML report in default browser..." -ForegroundColor Cyan
    Start-Process $outputFile
}

Write-Host ""
Write-Host "Reports generated:" -ForegroundColor Green
Write-Host "  HTML: $outputFile" -ForegroundColor Gray

# --- EMAIL SENDING LOGIC ---
if ($SendEmail) {
    Write-Host ""
    Write-Host "Sending email report..." -ForegroundColor Cyan
    
    # Validate required email parameters
    if (-not $SmtpServer) {
        Write-Error "ERROR: -SmtpServer is required when using -SendEmail" -ErrorAction Stop
        exit 1
    }
    if (-not $From) {
        Write-Error "ERROR: -From is required when using -SendEmail" -ErrorAction Stop
        exit 1
    }
    if (-not $To -or $To.Count -eq 0) {
        Write-Error "ERROR: -To is required when using -SendEmail" -ErrorAction Stop
        exit 1
    }
    
    try {
        # Build forest list for email
        $forestList = ""
        foreach ($forest in $ForestDataInfo) {
            $forestList += "- $($forest.ForestDnsName)`n"
        }
        
        # Create plain text email body
        $emailBody = @"
Hello,

Please find attached the DSP Health-Check Report generated on $(Get-Date -Format 'yyyy-MM-dd') at $(Get-Date -Format 'HH:mm').

Protected Forest:
$ForestName
This automated report provides a comprehensive overview of your Directory Services Protector environment, including:
- Management Server status and configuration
- Forest and domain health checks
- Agent status monitoring (DSP & Audit Agents)
- Service status monitoring
- Indicator of Exposure (IOE) summary

Please review the attached HTML report for detailed information.

Best regards,
Bryan Ohana
"@
        
        # Create email message
        $mailParams = @{
            From = $From
            To = $To
            Subject = $Subject
            Body = $emailBody
            BodyAsHtml = $false
            SmtpServer = $SmtpServer
            Port = $SmtpPort
        }
        
        # Add CC if provided
        if ($Cc -and $Cc.Count -gt 0) {
            $mailParams.Add('Cc', $Cc)
        }
        
        # Add attachment
        $mailParams.Add('Attachments', $outputFile)
        
        # Add credentials if provided (authenticated SMTP)
        if ($Credential) {
            $mailParams.Add('Credential', $Credential)
        } else {
            Write-Host "  Using anonymous SMTP..." -ForegroundColor Gray
        }
        
        # Add SSL if requested
        if ($UseSSL) {
            $mailParams.Add('UseSsl', $true)
        }
        
        # Send the email
        Send-MailMessage @mailParams -ErrorAction Stop
        
        Write-Host "✓ Email sent successfully to: $($To -join ', ')" -ForegroundColor Green
        if ($Cc -and $Cc.Count -gt 0) {
            Write-Host "  CC: $($Cc -join ', ')" -ForegroundColor Gray
        }
        
    } catch {
        Write-Error "ERROR: Failed to send email. Error details: $($_.Exception.Message)" -ErrorAction Continue
        Write-Host "  SMTP Server: $SmtpServer" -ForegroundColor Yellow
        Write-Host "  SMTP Port: $SmtpPort" -ForegroundColor Yellow
        Write-Host "  From: $From" -ForegroundColor Yellow
        Write-Host "  To: $($To -join ', ')" -ForegroundColor Yellow
    }
}

Write-Host "Thank you for using the DSP Health-Check Report on your DSP MS!" -ForegroundColor Green
Write-Host "For any support assistance, contact bryano@semperis.com" -ForegroundColor Green
 
