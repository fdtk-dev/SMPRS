[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = (Join-Path $env:TEMP ("SMPRS-AuditDiagnostics-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

$ErrorActionPreference = 'Stop'
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
$logPath = Join-Path $OutputPath 'diagnostic.log'
$csvOutputPath = Join-Path $OutputPath 'audit-csv'
New-Item -Path $csvOutputPath -ItemType Directory -Force | Out-Null

function Write-DiagnosticLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    $line | Tee-Object -FilePath $logPath -Append
}

try {
    Write-DiagnosticLog 'Starting independent SMPRS audit.csv diagnostics.'
    Write-DiagnosticLog "ComputerName: $env:COMPUTERNAME"
    Write-DiagnosticLog "User: $env:USERDOMAIN\$env:USERNAME"
    Write-DiagnosticLog "PowerShell: $($PSVersionTable.PSVersion)"
    Write-DiagnosticLog "Culture: $((Get-Culture).Name)"
    Write-DiagnosticLog "UICulture: $((Get-UICulture).Name)"

    $domain = $env:USERDNSDOMAIN
    if ([string]::IsNullOrWhiteSpace($domain)) {
        $domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
    }
    if ([string]::IsNullOrWhiteSpace($domain)) {
        throw 'Unable to determine the DNS domain name.'
    }

    $sysvolRoot = "\\$domain\SYSVOL\$domain\Policies"
    Write-DiagnosticLog "Domain: $domain"
    Write-DiagnosticLog "SYSVOL policies path: $sysvolRoot"

    $auditFiles = @(Get-ChildItem -Path $sysvolRoot -Directory -ErrorAction Stop | ForEach-Object {
        $candidate = Join-Path $_.FullName 'Machine\Microsoft\Windows NT\Audit\audit.csv'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            Get-Item -LiteralPath $candidate
        }
    })

    Write-DiagnosticLog "Found audit.csv files: $($auditFiles.Count)"
    $index = 0

    foreach ($auditFile in $auditFiles) {
        $index++
        $policyGuid = $auditFile.Directory.Parent.Parent.Parent.Parent.Name
        $safeName = '{0:D3}-{1}-audit.csv' -f $index, $policyGuid
        $copiedCsv = Join-Path $csvOutputPath $safeName
        Copy-Item -LiteralPath $auditFile.FullName -Destination $copiedCsv -Force

        $hash = Get-FileHash -LiteralPath $auditFile.FullName -Algorithm SHA256
        $bytes = [System.IO.File]::ReadAllBytes($auditFile.FullName)
        $encodingHint = if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            'UTF-16 LE BOM'
        }
        elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            'UTF-8 BOM'
        }
        else {
            'No recognized BOM'
        }

        Write-DiagnosticLog "[$index] Source: $($auditFile.FullName)"
        Write-DiagnosticLog "[$index] Copy: $copiedCsv"
        Write-DiagnosticLog "[$index] SHA256: $($hash.Hash)"
        Write-DiagnosticLog "[$index] Encoding hint: $encodingHint"
        Write-DiagnosticLog "[$index] First five raw lines begin below."
        Get-Content -LiteralPath $auditFile.FullName -TotalCount 5 |
            ForEach-Object { "[$index] RAW: $_" | Tee-Object -FilePath $logPath -Append }

        try {
            $rows = @(Import-Csv -LiteralPath $auditFile.FullName -ErrorAction Stop)
            $propertyNames = @()
            if ($rows.Count -gt 0) {
                $propertyNames = @($rows[0].PSObject.Properties.Name)
            }
            Write-DiagnosticLog "[$index] Import-Csv row count: $($rows.Count)"
            Write-DiagnosticLog "[$index] Import-Csv property names: $($propertyNames -join ' | ')"
            if ($rows.Count -gt 0) {
                $rows[0].PSObject.Properties |
                    ForEach-Object {
                        Write-DiagnosticLog "[$index] First row property [$($_.Name)] = [$($_.Value)]"
                    }
            }
        }
        catch {
            Write-DiagnosticLog "[$index] Import-Csv ERROR: $($_.Exception.Message)"
        }
    }

    Write-DiagnosticLog 'Diagnostics completed successfully.'
    Write-Host "Diagnostic folder: $OutputPath"
    Write-Host "Log file: $logPath"
    Write-Host "Copied audit.csv files: $csvOutputPath"
}
catch {
    Write-DiagnosticLog "FATAL ERROR: $($_.Exception.Message)"
    throw
}
