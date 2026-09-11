#Requires -Modules GroupPolicy, ActiveDirectory
<#
    Create GPO for DSP Advanced Audit Policy Configuration
    Link to Domain Controllers OU
    Requires Domain Admin privileges
    Must run on a Domain Controller
#>

param(
    [string]$GPOName = 'Semperis DSP Audit Policy',
    [switch]$IncludeIRP,
    [switch]$DryRun
)

# === Audit subcategories to enable ===
# Base Audit (DSP Required) - all Success
$baseAudit = @(
    @{ GUID = '{0CCE9230-69AE-11D9-BED3-505054503030}'; Name = 'Authentication Policy Change';      Success = $true;  Failure = $false }
    @{ GUID = '{0CCE9235-69AE-11D9-BED3-505054503030}'; Name = 'User Account Management';           Success = $true;  Failure = $false }
    @{ GUID = '{0CCE9236-69AE-11D9-BED3-505054503030}'; Name = 'Computer Account Management';       Success = $true;  Failure = $false }
    @{ GUID = '{0CCE9237-69AE-11D9-BED3-505054503030}'; Name = 'Security Group Management';         Success = $true;  Failure = $false }
    @{ GUID = '{0CCE9238-69AE-11D9-BED3-505054503030}'; Name = 'Distribution Group Management';     Success = $true;  Failure = $false }
    @{ GUID = '{0CCE9239-69AE-11D9-BED3-505054503030}'; Name = 'Application Group Management';      Success = $true;  Failure = $false }
    @{ GUID = '{0CCE923A-69AE-11D9-BED3-505054503030}'; Name = 'Other Account Management Events';   Success = $true;  Failure = $false }
    @{ GUID = '{0CCE923C-69AE-11D9-BED3-505054503030}'; Name = 'Directory Service Changes';         Success = $true;  Failure = $false }
)

# IRP Additional Audit (Optional)
$irpAudit = @(
    @{ GUID = '{0CCE9215-69AE-11D9-BED3-505054503030}'; Name = 'Logon';                              Success = $true;  Failure = $true  }
    @{ GUID = '{0CCE923F-69AE-11D9-BED3-505054503030}'; Name = 'Credential Validation';              Success = $false; Failure = $true  }
    @{ GUID = '{0CCE9240-69AE-11D9-BED3-505054503030}'; Name = 'Kerberos Service Ticket Operations'; Success = $false; Failure = $true  }
    @{ GUID = '{0CCE9242-69AE-11D9-BED3-505054503030}'; Name = 'Kerberos Authentication Service';    Success = $false; Failure = $true  }
)

$auditSettings = $baseAudit
if ($IncludeIRP) {
    $auditSettings += $irpAudit
}

# === Get Domain Info ===
$domain = Get-ADDomain
$domainDN = $domain.DistinguishedName
$domainDNS = $domain.DNSRoot
$dcOU = "OU=Domain Controllers,$domainDN"

Write-Host "Domain: $domainDNS" -ForegroundColor Cyan
Write-Host "Domain Controllers OU: $dcOU" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host '[DryRun] Would create/update GPO and configure audit settings:' -ForegroundColor Yellow
    foreach ($a in $auditSettings) {
        $s = ''
        if ($a.Success) { $s += 'Success' }
        if ($a.Failure) { if ($s) { $s += ' and Failure' } else { $s = 'Failure' } }
        Write-Host ('  {0,-45} = {1}' -f $a.Name, $s) -ForegroundColor White
    }
    Write-Host "[DryRun] Would link GPO '$GPOName' to $dcOU" -ForegroundColor Yellow
    return
}

# === Step 1: Backup current local audit policy ===
Write-Host 'Step 1: Backing up current local audit policy...' -ForegroundColor Cyan
$backupFile = Join-Path $env:TEMP 'auditpol_backup.csv'
$null = auditpol /backup /file:$backupFile
if (-not (Test-Path $backupFile)) {
    Write-Host 'ERROR: Failed to backup current audit policy. Are you running as Administrator on a DC?' -ForegroundColor Red
    return
}

# === Step 2: Set desired audit policy locally (temporary) ===
Write-Host 'Step 2: Temporarily setting desired audit policy locally...' -ForegroundColor Cyan
foreach ($a in $auditSettings) {
    $successFlag = if ($a.Success) { '/success:enable' } else { '/success:disable' }
    $failureFlag = if ($a.Failure) { '/failure:enable' } else { '/failure:disable' }
    $null = auditpol /set /subcategory:$($a.GUID) $successFlag $failureFlag
    $s = ''
    if ($a.Success) { $s += 'Success' }
    if ($a.Failure) { if ($s) { $s += '+Failure' } else { $s = 'Failure' } }
    Write-Host ('  Set: {0,-45} = {1}' -f $a.Name, $s) -ForegroundColor White
}

# === Step 3: Create or get GPO ===
Write-Host 'Step 3: Creating/getting GPO...' -ForegroundColor Cyan
$gpo = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if ($gpo) {
    Write-Host "GPO '$GPOName' already exists, will update" -ForegroundColor Yellow
} else {
    $gpo = New-GPO -Name $GPOName -Comment 'Semperis DSP Advanced Audit Policy'
    Write-Host "Created GPO: $GPOName" -ForegroundColor Green
}

$gpoId = $gpo.Id.ToString('B').ToUpper()
$auditDir = "\\$domainDNS\SYSVOL\$domainDNS\Policies\$gpoId\Machine\Microsoft\Windows NT\Audit"

# Create audit directory in SYSVOL
if (-not (Test-Path $auditDir)) {
    New-Item -Path $auditDir -ItemType Directory -Force | Out-Null
    Write-Host "Created: $auditDir" -ForegroundColor Green
}

# === Step 4: Export audit policy to GPO location ===
Write-Host 'Step 4: Exporting audit policy to GPO...' -ForegroundColor Cyan
$auditCsvPath = Join-Path $auditDir 'audit.csv'
$null = auditpol /backup /file:$auditCsvPath
if (Test-Path $auditCsvPath) {
    Write-Host "Written: $auditCsvPath" -ForegroundColor Green
} else {
    Write-Host 'ERROR: Failed to export audit policy to SYSVOL' -ForegroundColor Red
}

# === Step 5: Restore original local audit policy ===
Write-Host 'Step 5: Restoring original local audit policy...' -ForegroundColor Cyan
$null = auditpol /restore /file:$backupFile
Remove-Item $backupFile -Force -ErrorAction SilentlyContinue
Write-Host 'Restored original audit policy' -ForegroundColor Green

# === Step 6: Update GPT.INI and AD GPO object ===
Write-Host 'Step 6: Registering CSE in GPO...' -ForegroundColor Cyan

# CSE GUIDs for Advanced Audit Policy Configuration
# {F3BC9527-9206-11D0-8CB6-00A0C9A06E05} = Audit Policy CSE
# {D02B1F72-3407-48AE-BA88-E8213C6761F1} = Advanced Audit MMC Extension
$cseEntry = '[{F3BC9527-9206-11D0-8CB6-00A0C9A06E05}{D02B1F72-3407-48AE-BA88-E8213C6761F1}]'

# --- Update GPT.INI in SYSVOL ---
$gptIniPath = "\\$domainDNS\SYSVOL\$domainDNS\Policies\$gpoId\GPT.INI"

if (Test-Path $gptIniPath) {
    $gptContent = Get-Content $gptIniPath -Raw
} else {
    $gptContent = "[General]`r`nVersion=0`r`n"
}

$needsGptUpdate = $false
if ($gptContent -notmatch 'F3BC9527') {
    if ($gptContent -match 'gPCMachineExtensionNames=') {
        $replacement = '$1$2' + $cseEntry
        $gptContent = $gptContent -replace '(gPCMachineExtensionNames=)(.*)', $replacement
    } else {
        $insertLine = 'gPCMachineExtensionNames=' + $cseEntry
        $gptContent = $gptContent -replace '(\[General\])', ('$1' + "`r`n" + $insertLine)
    }
    $needsGptUpdate = $true
}

# Increment machine version (upper 16 bits)
if ($gptContent -match 'Version=(\d+)') {
    $curVer = [int]$Matches[1]
    $newVersion = $curVer + 65536
    $gptContent = $gptContent -replace 'Version=\d+', "Version=$newVersion"
    $needsGptUpdate = $true
}

if ($needsGptUpdate) {
    $gptContent | Set-Content -Path $gptIniPath -Encoding ASCII -Force
    Write-Host 'Updated GPT.INI' -ForegroundColor Green
}

# --- Update AD GPO object ---
$gpoDN = "CN=$gpoId,CN=Policies,CN=System,$domainDN"
$adGpo = Get-ADObject -Identity $gpoDN -Properties gPCMachineExtensionNames, versionNumber

$currentExt = $adGpo.gPCMachineExtensionNames
if (-not $currentExt) { $currentExt = '' }

if ($currentExt -notmatch 'F3BC9527') {
    $newExt = $currentExt + $cseEntry
    Set-ADObject -Identity $gpoDN -Replace @{ gPCMachineExtensionNames = $newExt }
    Write-Host 'Updated AD gPCMachineExtensionNames' -ForegroundColor Green
}

$curAdVer = [int]$adGpo.versionNumber
$newAdVer = $curAdVer + 65536
Set-ADObject -Identity $gpoDN -Replace @{ versionNumber = $newAdVer }
Write-Host "Updated AD versionNumber: $curAdVer -> $newAdVer" -ForegroundColor Green

# === Step 7: Link GPO to Domain Controllers OU ===
Write-Host 'Step 7: Linking GPO...' -ForegroundColor Cyan
$existingLink = Get-GPInheritance -Target $dcOU |
    Select-Object -ExpandProperty GpoLinks |
    Where-Object { $_.DisplayName -eq $GPOName }

if ($existingLink) {
    Write-Host "GPO already linked to $dcOU" -ForegroundColor Yellow
} else {
    New-GPLink -Name $GPOName -Target $dcOU -LinkEnabled Yes
    Write-Host "Linked GPO to: $dcOU" -ForegroundColor Green
}

# === Done ===
Write-Host ''
Write-Host '===== Done =====' -ForegroundColor Green
Write-Host 'Next steps:'
Write-Host '  1. Run on all DCs: gpupdate /force'
Write-Host '  2. Verify in GPMC: the GPO should show audit settings now'
Write-Host '  3. Verify: .\SMPRS-DSPAuditChecker.ps1 -Inspect GroupPolicy, AuditPolicy'