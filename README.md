# SMPRS Utilities & Health Check Scripts

本 Repository 收錄與 Semperis 產品相關的健康檢查、環境驗證、稽核設定及 Alert Rule 匯入工具，方便顧問、系統管理員與客戶快速檢查及部署環境。

Repository:

https://github.com/fdtk-dev/SMPRS

---

# Quick Start

## 執行 PowerShell Script

若系統限制未簽署腳本執行，可先於 PowerShell 執行：

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

下載後執行：

```powershell
.\ScriptName.ps1
```

或直接從 GitHub 執行：

```powershell
irm https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/SMPRS-ReadinessChecker.ps1 | iex
```

---

# Available Scripts

## SMPRS-ReadinessChecker.ps1

檢查 SMPRS 環境是否符合安裝與部署需求。

### Download

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/SMPRS-ReadinessChecker.ps1 -OutFile .\SMPRS-ReadinessChecker.ps1
```

### Direct Run

```powershell
irm https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/SMPRS-ReadinessChecker.ps1 | iex
```

---

## Health-Check_DSP-v8.ps1

執行 Directory Services Protector (DSP) 健康檢查。

### Download

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Health-Check_DSP-v8.ps1 -OutFile .\Health-Check_DSP-v8.ps1
```

---

## Health-Check_ADFR-v8.ps1

執行 Active Directory Forest Recovery (ADFR) 健康檢查。

### Download

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Health-Check_ADFR-v8.ps1 -OutFile .\Health-Check_ADFR-v8.ps1
```

---

## SMPRS-DSPAuditChecker.ps1

檢查 DSP 所需的 Audit Policy 設定是否完整。

### Download

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/SMPRS-DSPAuditChecker.ps1 -OutFile .\SMPRS-DSPAuditChecker.ps1
```

---

## setAuditGPO.ps1

建立或套用 DSP 需要的 Audit GPO 設定。

### Download

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/setAuditGPO.ps1 -OutFile .\setAuditGPO.ps1
```

---

## Get-smprsSupportData.22.ps1

收集系統與產品診斷資訊，協助 Support 進行問題分析。

### Download

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Get-smprsSupportData.22.ps1 -OutFile .\Get-smprsSupportData.22.ps1
```

---

## Get-ADDomainAndForestInfo.ps1

取得 AD Domain 與 Forest 相關資訊（含 Domain SID 及 Root Forest SID SHA256 Hash）。

### Download

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Get-ADDomainAndForestInfo.ps1 -OutFile .\Get-ADDomainAndForestInfo.ps1
```

---

## Semperis-Import-DSPAlertAndResponseRules.ps1

匯入 DSP Alert & Response Rules。

### Download

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Semperis-Import-DSPAlertAndResponseRules.ps1 -OutFile .\Semperis-Import-DSPAlertAndResponseRules.ps1
```

---

## Semperis-Import-DSPAlertAndResponseRules-NoIAS.ps1

匯入 DSP Alert & Response Rules（不含 IAS 設定）。

### Download

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Semperis-Import-DSPAlertAndResponseRules-NoIAS.ps1 -OutFile .\Semperis-Import-DSPAlertAndResponseRules-NoIAS.ps1
```

---

## Semperis-Import-DSPAlertAndResponseRules-Template-Default-AD-Chinese.json

DSP 預設中文 Alert & Response Rule Template。

### Download

```powershell
iwr https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Semperis-Import-DSPAlertAndResponseRules-Template-Default-AD-Chinese.json -OutFile .\Semperis-Import-DSPAlertAndResponseRules-Template-Default-AD-Chinese.json
```

---

# Download URLs

| File                                                                      | URL                                                                                                                             |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Get-ADDomainAndForestInfo.ps1                                             | https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Get-ADDomainAndForestInfo.ps1                                             |
| Get-smprsSupportData.22.ps1                                               | https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Get-smprsSupportData.22.ps1                                               |
| Health-Check_ADFR-v8.ps1                                                  | https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Health-Check_ADFR-v8.ps1                                                  |
| Health-Check_DSP-v8.ps1                                                   | https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Health-Check_DSP-v8.ps1                                                   |
| SMPRS-DSPAuditChecker.ps1                                                 | https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/SMPRS-DSPAuditChecker.ps1                                                 |
| SMPRS-ReadinessChecker.ps1                                                | https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/SMPRS-ReadinessChecker.ps1                                                |
| Semperis-Import-DSPAlertAndResponseRules-NoIAS.ps1                        | https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Semperis-Import-DSPAlertAndResponseRules-NoIAS.ps1                        |
| Semperis-Import-DSPAlertAndResponseRules-Template-Default-AD-Chinese.json | https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Semperis-Import-DSPAlertAndResponseRules-Template-Default-AD-Chinese.json |
| Semperis-Import-DSPAlertAndResponseRules.ps1                              | https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/Semperis-Import-DSPAlertAndResponseRules.ps1                              |
| setAuditGPO.ps1                                                           | https://raw.githubusercontent.com/fdtk-dev/SMPRS/main/setAuditGPO.ps1                                                           |

---

# Disclaimer

請先於測試環境驗證腳本功能後，再部署至正式環境。

使用前請確認：

- 已使用 Administrator 權限執行 PowerShell
- 已符合 Semperis 官方版本需求
- 已完成必要備份
- 已確認 Execution Policy 設定
