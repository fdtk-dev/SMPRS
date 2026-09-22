# Win AD Utilities & GPO setting Scripts

本 Repository 收錄與 Windows AD 相關的SID，NTDS size 及 GPO 設定工具，方便顧問、系統管理員與客戶快速檢查及部署環境。

Repository:

[SMPRS GitHub Repository](https://github.com/fdtk-dev/SMPRS)

---

## Quick Start

## 執行 PowerShell Script

若系統限制未簽署腳本執行，可先於 PowerShell 執行：

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

下載後執行：

```powershell
curl.exe -O https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Get-ADDomainAndForestInfo.ps1
.\Get-ADDomainAndForestInfo.ps1
```

或直接從 GitHub 執行：

```powershell
irm https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/setAuditGPO.ps1 | iex
```

---

## Available Scripts

## setAuditGPO.ps1

建立或套用 DSP 需要的 Audit GPO 設定。

### Download setAuditGPO.ps1

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/setAuditGPO.ps1 -OutFile .\setAuditGPO.ps1
```

### Direct Run setAuditGPO.ps1

```powershell
irm https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/setAuditGPO.ps1 | iex
```

---

## Get-ADDomainAndForestInfo.ps1

取得 AD Domain 與 Forest 相關資訊（含 Domain SID 及 Root Forest SID SHA256 Hash）。

### Download Get-ADDomainAndForestInfo.ps1

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Get-ADDomainAndForestInfo.ps1 -OutFile .\Get-ADDomainAndForestInfo.ps1
```

### Direct Run Get-ADDomainAndForestInfo.ps1

```powershell
irm https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Get-ADDomainAndForestInfo.ps1 | iex
```

---

## Get-NTDSAndSYSVOLSize.ps1

取得 NTDS 與 SYSVOL 資料夾大小資訊。

### Download & Run Get-NTDSAndSYSVOLSize.ps1

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Get-NTDSAndSYSVOLSize.ps1 -OutFile .\Get-NTDSAndSYSVOLSize.ps1
.\Get-NTDSAndSYSVOLSize.ps1
```

---

## Download URLs

| File                          | URL                                                                                             |
| ----------------------------- | ----------------------------------------------------------------------------------------------- |
| Get-ADDomainAndForestInfo.ps1 | [Download](https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Get-ADDomainAndForestInfo.ps1) |
| Get-NTDSAndSYSVOLSize.ps1     | [Download](https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Get-NTDSAndSYSVOLSize.ps1)     |
| setAuditGPO.ps1               | [Download](https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/setAuditGPO.ps1)               |

---

## Disclaimer

請先於測試環境驗證腳本功能後，再部署至正式環境。

使用前請確認：

- 已使用 Administrator 權限執行 PowerShell
- 已完成必要備份
- 已確認 Execution Policy 設定
