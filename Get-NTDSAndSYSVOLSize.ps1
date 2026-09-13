<#
.SYNOPSIS
    取得本機 Active Directory NTDS.dit 與 SYSVOL 資料夾的路徑與大小資訊。
.DESCRIPTION
    從登錄檔讀取 NTDS 與 SYSVOL 的路徑設定，並計算 NTDS.dit 檔案及 SYSVOL 目錄的大小。
#>

$ntdsPath = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters')."DSA Working Directory"
$ntdsFile = Get-Item (Join-Path $ntdsPath 'ntds.dit') -ErrorAction SilentlyContinue

if ($ntdsFile) {
	$ntdsSizeGB = [math]::Round($ntdsFile.Length / 1GB, 2)
	Write-Host "NTDS.dit path: $($ntdsFile.FullName)"
	Write-Host "NTDS.dit size: $ntdsSizeGB GB ($($ntdsFile.Length) Bytes)"
}

$sysvolPath = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -ErrorAction SilentlyContinue).sysvol

if ($sysvolPath -and (Test-Path -Path $sysvolPath)) {
	$sysvolFiles = @(Get-ChildItem -Path $sysvolPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer -and $_.Length -ne $null })
	if ($sysvolFiles.Count -gt 0) {
		$sysvolSize = ($sysvolFiles | Measure-Object -Property Length -Sum).Sum
	}
	else {
		$sysvolSize = 0
	}

	$sysvolSizeGB = [math]::Round($sysvolSize / 1GB, 2)
	$sysvolSizeMB = [math]::Round($sysvolSize / 1MB, 2)
	Write-Host "SYSVOL path: $sysvolPath"
	Write-Host "SYSVOL size: $sysvolSizeGB GB ($sysvolSizeMB MB)"
}
