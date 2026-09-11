<#PSScriptInfo
.VERSION 8.0.0
.DATE November 25th 2025
.AUTHOR bryano@semperis.com
.COMPANYNAME Semperis 
.COPYRIGHT Semperis 
.NAME Health-Check ADFR v8 - ADFR Style UI
.Supported ADFR Version 4.x 5.x
The goal of this script is to provide an overview of your ADFR Server Health and latest backup

Requirement to run this script : 
- Having ADFR POSH module installed the POSH module is provided with the ADFR Sources
- Run this script with a user that has ADFR Product Manager role

This script is not provided and supported by Semperis. This script has only read access and cannot perform any action on your behalf on the ADFR MS.
In case you face any issue please contact the owner Bryan Ohana (bryano@semperis.com).
#>

Param(
    [string]$Path,
    [ValidateSet("US", "EMEA")]
    [string]$Date = "US",
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
    [string]$Subject = "ADFR Health-Check Report - $(Get-Date -Format 'yyyy-MM-dd')"
)

Write-Host "     █████╗ ██████╗ ███████╗██████╗ " -ForegroundColor Green
Write-Host "    ██╔══██╗██╔══██╗██╔════╝██╔══██╗" -ForegroundColor Green
Write-Host "    ███████║██║  ██║█████╗  ██████╔╝" -ForegroundColor Green
Write-Host "    ██╔══██║██║  ██║██╔══╝  ██╔══██╗" -ForegroundColor Green
Write-Host "    ██║  ██║██████╔╝██║     ██║  ██║" -ForegroundColor Green   
Write-Host "    ╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝  ╚═╝" -ForegroundColor Green  

Write-Host "============================================================" -ForegroundColor Red
Write-Host ""
Write-Host "This script provides a summary of your ADFR server health and latest backup information" -ForegroundColor Green
Write-Host ""
Write-Host "Disclaimer:" -ForegroundColor Red
Write-Host " - This script is NOT an official Semperis product." -ForegroundColor  Red
Write-Host " - It is not supported by Semperis Support Team but only by the owner Bryan Ohana (bryano@semperis.com)" -ForegroundColor Red
Write-Host " - It performs READ-ONLY actions and will not modify your ADFR Management Server in any way." -ForegroundColor Red
Write-Host ""
Write-Host "For assistance, please contact:" -ForegroundColor Red
Write-Host " Bryan Ohana  | Principal Solution Architect | Semperis | bryano@semperis.com" -ForegroundColor Red
Write-Host ""
Write-Host "============================================================" -ForegroundColor Red
# ===== VALIDATION CHECKS to run the script =====
# Check 1: Validate that the script is run as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "ERROR: This script must be run as Administrator. Please run PowerShell as Administrator and try again." -ErrorAction Stop
    exit 1
}

# Check 2: Validate that ADFR PowerShell module is installed on the machine
try {
    # Check for the exact module name
    $adfrModule = Get-Module -ListAvailable -Name "Semperis.PoSh.ADFR" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $adfrModule) {
        Write-Host "Available modules containing 'Semperis' or 'ADFR':" -ForegroundColor Yellow
        $availableModules = Get-Module -ListAvailable | Where-Object { $_.Name -like "*Semperis*" -or $_.Name -like "*ADFR*" }
        if ($availableModules) {
            $availableModules | ForEach-Object { Write-Host "  - $($_.Name) (Version: $($_.Version))" -ForegroundColor Yellow }
        } else {
            Write-Host "  No modules found containing 'Semperis' or 'ADFR'" -ForegroundColor Yellow
        }
        Write-Error "ERROR: Semperis.PoSh.ADFR module is not installed on this machine. Please install the Semperis.PoSh.ADFR module before running this script." -ErrorAction Stop
        exit 1
    }
    Write-Host "✓ Semperis.PoSh.ADFR module found: $($adfrModule.Name) (Version: $($adfrModule.Version))" -ForegroundColor Green
}
catch {
    Write-Error "ERROR: Unable to check for Semperis.PoSh.ADFR module. Error details: $($_.Exception.Message)" -ErrorAction Stop
    exit 1
}

Write-Host "✓ Administrator privileges confirmed" -ForegroundColor Green
Write-Host "✓ All validation checks passed. Proceeding with the Health-Check..." -ForegroundColor Green
Write-Host ""
# ===== END VALIDATION CHECKS =====
if ($Path) {
    $outputFile = [System.IO.Path]::Combine($Path, "ADFR_Health-Check-V8.html")
} else {
    $outputFile = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), "ADFR_Health-Check-V8.html")
}

# Suppress output of the connection command
$null = Connect-ADFRServer localhost

# Display a custom message instead
Write-Host "Connection to ADFR MS...." -ForegroundColor DarkGreen
Write-Host "-------------------------------------" -ForegroundColor DarkGreen

# Get the list of ADFR forests (exclude deleted forests)
$forests = Get-ADFRForest | Where-Object { $_.IsDeleted -eq $false }
if ($Date -eq "EMEA") {
    $currentdate = "$(Get-Date -Format 'dd-MM-yyyy') at $(Get-Date -Format 'HH:mm')"
} else {
    $currentdate = "$(Get-Date -Format 'MM-dd-yyyy') at $(Get-Date -Format 'HH:mm')"
}
# Initialize an HTML content string with ADFR-style UI
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>ADFR Health Check Report</title>
    <style>
        /* ===== ADFR-STYLE CSS v8 ===== */
        :root {
            --primary-dark: #1a2332;
            --primary-navy: #2c3e50;
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
        
        /* ===== TABLES - ADFR Style ===== */
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
        
        /* ===== FOREST BADGE - ADFR Style ===== */
        .forest-badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: linear-gradient(135deg, var(--primary-dark), var(--primary-navy));
            color: white;
            padding: 10px 18px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: 500;
            margin: 16px 0 12px 0;
            box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        }
        .forest-badge::before { content: '🌲'; }
        
        /* ===== STATUS CELLS - ADFR Style ===== */
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
        
        /* ===== COLLAPSIBLE SECTIONS - ADFR Card Style ===== */
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
            color: var(--text-secondary);
            transition: transform 0.3s ease;
        }
        
        .collapsible.active:after {
            transform: rotate(180deg);
        }
        
        .collapsible:hover {
            background-color: #fafbfc;
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
        
        /* ===== HEADER - ADFR Style ===== */
        .header { 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
            background: var(--primary-dark);
            padding: 16px 24px; 
            color: white;
            border-radius: 0;
            box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        }
        
        .header img { 
            height: 40px;
        } 
        
        .header-center {
            display: flex;
            flex-direction: column;
            align-items: center;
            flex-grow: 1;
        }
        .header-date {
            background: rgba(255,255,255,0.1);
            padding: 4px 12px;
            border-radius: 15px;
            font-family: Rubik,Segoe UI,Maven Pro,sans-serif;
            color: #20c997;
            font-weight: 600;
            font-size: 13px;
            margin-top: 5px;
            border: 1px solid rgba(32, 201, 151, 0.3);
            backdrop-filter: blur(10px);
        }
        .header-title { 
            font-size: 26px; 
            text-align: center; 
            font-weight: 700;
            text-shadow: 0 2px 4px rgba(0,0,0,0.3);
            letter-spacing: 0.5px;
            }
        .header-name { 
            font-size: 18px; 
            text-align: right; 
            color: white;
            opacity: 0.9;
        }
        .header-name img {
            height: 35px;
            filter: brightness(0) invert(1) drop-shadow(0 2px 4px rgba(0,0,0,0.3));
        }
        .container { 
            width: 95%; 
            margin: auto; 
            background: rgba(255, 255, 255, 0.9); /* White box with slight transparency */
            padding: 20px; 
            border-radius: 10px; 
            box-shadow: 0px 0px 10px rgba(0, 0, 0, 0.1); 
            color: black;
        }
            /* Blinking effect using CSS animation */
        @keyframes blink {
            0% { opacity: 1; }
            50% { opacity: 0; }
            100% { opacity: 1; }
        }

        .blinking-icon {
            animation: blink 2s infinite;
            margin-top: 0px !important;
            margin-bottom: 0px !important;
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
        
        /* Version card hover effect */
        .version-card {
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .version-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        
        /* ===== FLOATING ISSUES BUBBLE ===== */
        .issues-bubble { position: fixed; bottom: 30px; right: 30px; z-index: 999; cursor: pointer; }
        .bubble-btn { width: 55px; height: 55px; border-radius: 50%; background: linear-gradient(135deg, #1a2332, #2d3a4d); border: none; color: white; font-size: 22px; cursor: pointer; box-shadow: 0 4px 15px rgba(26, 35, 50, 0.4); display: flex; align-items: center; justify-content: center; position: relative; }
        .bubble-btn.no-issues { background: linear-gradient(135deg, #28a745, #20c997); box-shadow: 0 4px 15px rgba(40, 167, 69, 0.4); }
        .bubble-count { position: absolute; top: -5px; right: -5px; background: #ffc107; color: #333; font-size: 12px; font-weight: 700; min-width: 22px; height: 22px; border-radius: 11px; display: flex; align-items: center; justify-content: center; border: 2px solid white; }
        .issues-panel { position: fixed; bottom: 100px; right: 30px; width: 350px; max-height: 400px; background: white; border-radius: 12px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); z-index: 998; display: none; flex-direction: column; overflow: hidden; }
        .issues-panel.show { display: flex; }
        .panel-header { background: linear-gradient(135deg, #1a2332, #2d3a4d); color: white; padding: 15px 20px; display: flex; justify-content: space-between; align-items: center; }
        .panel-header h4 { margin: 0; font-size: 14px; font-weight: 600; }
        .panel-close { background: none; border: none; color: white; font-size: 20px; cursor: pointer; padding: 0; line-height: 1; }
        .panel-stats { display: flex; gap: 15px; padding: 12px 20px; background: #f8f9fa; border-bottom: 1px solid #e9ecef; }
        .stat-item { display: flex; align-items: center; gap: 6px; font-size: 13px; font-weight: 600; }
        .stat-item.warnings { color: #856404; }
        .stat-item.errors { color: #721c24; }
        .stat-icon { width: 20px; height: 20px; border-radius: 4px; display: flex; align-items: center; justify-content: center; font-size: 11px; }
        .stat-icon.warning-icon { background: #fff3cd; color: #856404; }
        .stat-icon.error-icon { background: #f8d7da; color: #721c24; }
        .panel-body { flex: 1; overflow-y: auto; max-height: 280px; }
        .issue-item { padding: 10px 20px; border-bottom: 1px solid #e9ecef; cursor: pointer; transition: background 0.2s ease; display: flex; align-items: flex-start; gap: 10px; }
        .issue-item:hover { background: #f8f9fa; }
        .issue-item:last-child { border-bottom: none; }
        .issue-badge { flex-shrink: 0; width: 24px; height: 24px; border-radius: 4px; display: flex; align-items: center; justify-content: center; font-size: 12px; }
        .issue-badge.warning { background: #fff3cd; color: #856404; }
        .issue-badge.error { background: #f8d7da; color: #721c24; }
        .issue-text { flex: 1; font-size: 13px; color: #333; line-height: 1.4; }
        .issue-section { font-size: 11px; color: #6c757d; margin-top: 2px; }
        .no-issues-msg { padding: 30px 20px; text-align: center; color: #28a745; }
        .no-issues-msg .check-icon { font-size: 40px; margin-bottom: 10px; }
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
        });
        
        // CSV Download function
        function downloadCSV(filename, data) {
            var rows = ['Item'];
            for (var i = 0; i < data.length; i++) {
                // Clean up the item - remove emojis and extract useful info
                var item = data[i].replace(/[^\x00-\x7F]/g, '').trim();
                // Escape quotes for CSV
                item = item.replace(/"/g, '""');
                rows.push('"' + item + '"');
            }
            var csvContent = rows.join('\r\n');
            var blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
            var link = document.createElement('a');
            link.href = URL.createObjectURL(blob);
            link.download = filename;
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }
        
        // Recovery Requirements CSV Download function (base64 encoded)
        function downloadRecoveryCSV(forestName, base64Data) {
            var csvContent = atob(base64Data);
            var blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
            var link = document.createElement('a');
            link.href = URL.createObjectURL(blob);
            link.download = forestName + '_Recovery_Requirements.csv';
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }
        
        // Popup functionality for details - ADFR Style with CSV support
        function showGroupDetails(groupName, dcList) {
            var overlay = document.createElement('div');
            overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(255,255,255,0.3);z-index:1000;display:flex;justify-content:center;align-items:center;backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px);';
            
            var popup = document.createElement('div');
            popup.style.cssText = 'background:#fff;padding:0;border-radius:8px;max-width:550px;width:90%;max-height:75vh;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,0.4);position:relative;font-family:Segoe UI,Roboto,Arial,sans-serif;';
            
            // Parse DC list
            var dcArray = dcList.split(',');
            var cleanDcArray = [];
            for (var i = 0; i < dcArray.length; i++) {
                var dc = dcArray[i].replace(/^\s+|\s+$/g, '');
                if (dc) cleanDcArray.push(dc);
            }
            
            var totalCount = cleanDcArray.length;
            var maxDisplay = 50;
            var displayArray = cleanDcArray.slice(0, maxDisplay);
            
            // Build popup HTML
            var popupHTML = '<div style="background:linear-gradient(135deg,#1a2332,#2d3a4d);color:#fff;padding:20px 24px;position:relative;">';
            popupHTML += '<div style="font-size:11px;text-transform:uppercase;letter-spacing:1px;color:#8898aa;margin-bottom:6px;">Details</div>';
            popupHTML += '<div style="font-size:16px;font-weight:600;">' + groupName + '</div>';
            popupHTML += '<button onclick="this.closest(\'.popup-overlay\').remove()" style="position:absolute;top:16px;right:16px;background:rgba(255,255,255,0.1);border:none;color:#fff;width:32px;height:32px;border-radius:50%;cursor:pointer;font-size:18px;display:flex;align-items:center;justify-content:center;">&times;</button>';
            popupHTML += '</div>';
            
            // Content area
            popupHTML += '<div style="padding:20px 24px;max-height:calc(75vh - 120px);overflow-y:auto;">';
            
            if (displayArray.length > 0) {
                popupHTML += '<table style="width:100%;border-collapse:collapse;font-size:13px;">';
                popupHTML += '<thead><tr style="background:#f5f7fa;"><th style="text-align:left;padding:10px 12px;font-weight:600;color:#1a2332;border-bottom:2px solid #e9ecef;">Item</th></tr></thead>';
                popupHTML += '<tbody>';
                for (var j = 0; j < displayArray.length; j++) {
                    var rowBg = j % 2 === 0 ? '#fff' : '#fafbfc';
                    popupHTML += '<tr style="background:' + rowBg + ';"><td style="padding:12px;border-bottom:1px solid #e9ecef;color:#333;">' + displayArray[j] + '</td></tr>';
                }
                popupHTML += '</tbody></table>';
                
                // Show CSV download link if more than maxDisplay items
                if (totalCount > maxDisplay) {
                    popupHTML += '<div style="margin-top:15px;padding:12px;background:#fff3e0;border-radius:6px;border-left:4px solid #ff9800;font-size:13px;">';
                    popupHTML += '<strong>Showing ' + maxDisplay + ' of ' + totalCount + ' items</strong><br>';
                    popupHTML += '<a href="#" id="csvDownloadLink" style="color:#1a73e8;text-decoration:underline;cursor:pointer;">Download full list as CSV</a>';
                    popupHTML += '</div>';
                }
            } else {
                popupHTML += '<div style="text-align:center;padding:30px;color:#6c757d;">No items found</div>';
            }
            
            popupHTML += '</div>';
            
            // Footer with CSV download button always visible
            popupHTML += '<div style="background:#f5f7fa;padding:14px 24px;border-top:1px solid #e9ecef;display:flex;justify-content:space-between;align-items:center;">';
            popupHTML += '<span style="font-size:13px;color:#6c757d;">Total: <strong style="color:#1a2332;">' + totalCount + '</strong> item(s)</span>';
            popupHTML += '<div style="display:flex;gap:10px;">';
            popupHTML += '<button id="csvDownloadBtn" style="background:#fff;color:#1a2332;border:1px solid #dee2e6;padding:8px 16px;border-radius:6px;cursor:pointer;font-size:13px;font-weight:500;">Export CSV</button>';
            popupHTML += '<button onclick="this.closest(\'.popup-overlay\').remove()" style="background:linear-gradient(135deg,#1a2332,#2d3a4d);color:#fff;border:none;padding:8px 20px;border-radius:6px;cursor:pointer;font-size:13px;font-weight:500;">Close</button>';
            popupHTML += '</div></div>';
            
            popup.innerHTML = popupHTML;
            overlay.className = 'popup-overlay';
            overlay.appendChild(popup);
            
            // Close on overlay click
            overlay.onclick = function(e) { if (e.target === overlay) overlay.remove(); };
            
            document.body.appendChild(overlay);
            
            // Attach CSV download handler to footer button
            var csvBtn = document.getElementById('csvDownloadBtn');
            if (csvBtn) {
                csvBtn.onclick = function(e) {
                    e.preventDefault();
                    var filename = groupName.replace(/[^a-z0-9]/gi, '_') + '.csv';
                    downloadCSV(filename, cleanDcArray);
                };
            }
            
            // Also attach to inline link if exists (for >50 items message)
            var csvLink = document.getElementById('csvDownloadLink');
            if (csvLink) {
                csvLink.onclick = function(e) {
                    e.preventDefault();
                    var filename = groupName.replace(/[^a-z0-9]/gi, '_') + '.csv';
                    downloadCSV(filename, cleanDcArray);
                };
            }
        }

        // ===== FLOATING ISSUES BUBBLE =====
        document.addEventListener("DOMContentLoaded", function() {
            var issuesBubble = document.getElementById("issuesBubble");
            var issuesPanel = document.getElementById("issuesPanel");
            var panelClose = document.getElementById("panelClose");
            var panelBody = document.getElementById("panelBody");
            var bubbleBtn = document.querySelector(".bubble-btn");
            var bubbleCount = document.getElementById("bubbleCount");
            var warningCountEl = document.getElementById("warningCount");
            var errorCountEl = document.getElementById("errorCount");
            
            var warnings = document.querySelectorAll("td.warning");
            var errors = document.querySelectorAll("td.ko");
            var totalIssues = warnings.length + errors.length;
            
            if (bubbleCount) {
                bubbleCount.textContent = totalIssues;
                if (totalIssues === 0) {
                    bubbleCount.style.display = "none";
                    bubbleBtn.classList.add("no-issues");
                    bubbleBtn.innerHTML = "✓";
                }
            }
            
            if (warningCountEl) warningCountEl.textContent = warnings.length;
            if (errorCountEl) errorCountEl.textContent = errors.length;
            
            if (panelBody) {
                if (totalIssues === 0) {
                    panelBody.innerHTML = '<div class="no-issues-msg"><div class="check-icon">✓</div><div>All checks passed!</div></div>';
                } else {
                    var issuesHtml = "";
                    function getSectionName(el) {
                        var section = el.closest(".content");
                        if (section) {
                            var sectionBtn = section.previousElementSibling;
                            return sectionBtn ? sectionBtn.textContent.trim() : "Check Settings";
                        }
                        return "Check Settings";
                    }
                    warnings.forEach(function(el, index) {
                        var row = el.closest("tr");
                        var checkName = row ? row.querySelector("td:first-child") : null;
                        var checkText = checkName ? checkName.textContent.trim() : "Warning " + (index + 1);
                        var sectionName = getSectionName(el);
                        el.setAttribute("data-issue-id", "warning-" + index);
                        issuesHtml += '<div class="issue-item" data-target="warning-' + index + '"><div class="issue-badge warning">⚠</div><div class="issue-text">' + checkText + '<div class="issue-section">' + sectionName + '</div></div></div>';
                    });
                    errors.forEach(function(el, index) {
                        var row = el.closest("tr");
                        var checkName = row ? row.querySelector("td:first-child") : null;
                        var checkText = checkName ? checkName.textContent.trim() : "Error " + (index + 1);
                        var sectionName = getSectionName(el);
                        el.setAttribute("data-issue-id", "error-" + index);
                        issuesHtml += '<div class="issue-item" data-target="error-' + index + '"><div class="issue-badge error">✗</div><div class="issue-text">' + checkText + '<div class="issue-section">' + sectionName + '</div></div></div>';
                    });
                    panelBody.innerHTML = issuesHtml;
                    panelBody.querySelectorAll(".issue-item").forEach(function(item) {
                        item.addEventListener("click", function() {
                            var targetEl = document.querySelector('[data-issue-id="' + this.getAttribute("data-target") + '"]');
                            if (targetEl) {
                                var section = targetEl.closest(".content");
                                if (section && !section.classList.contains("show")) {
                                    var btn = section.previousElementSibling;
                                    if (btn) btn.click();
                                }
                                setTimeout(function() {
                                    targetEl.scrollIntoView({ behavior: "smooth", block: "center" });
                                    targetEl.style.transition = "background 0.3s ease";
                                    targetEl.style.background = "#ffe066";
                                    setTimeout(function() { targetEl.style.background = ""; }, 2000);
                                }, 300);
                            }
                            issuesPanel.classList.remove("show");
                        });
                    });
                }
            }
            if (issuesBubble) {
                issuesBubble.addEventListener("click", function(e) {
                    if (!e.target.closest(".issues-panel")) issuesPanel.classList.toggle("show");
                });
            }
            if (panelClose) {
                panelClose.addEventListener("click", function(e) {
                    e.stopPropagation();
                    issuesPanel.classList.remove("show");
                });
            }
        });

    </script>

    </head>
    <body>

    <!-- HEADER - ADFR Style -->
    <div class="header">
        <div style="display: flex; align-items: center; gap: 16px;">
            <img src="https://www.semperis.com/wp-content/uploads/images-icons/product/adfr/icon-3d-active-directory-forest-recovery-300x287.png" style="height:45px" alt="ADFR Logo">
            <div>
                <div style="font-size: 23px; font-weight: 600;">Active Directory Forest Recovery</div>
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
# Retrieve Semperis Management Server Version from Registry
$semperisSoftware = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, `
                                     HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* `
                     | Where-Object { $_.DisplayName -match "Semperis Management Server" }

# Store the version in a variable
$semperisVersion = if ($semperisSoftware) { $semperisSoftware.DisplayVersion } else { "Not Installed" }

# Retrieve Semperis Management Server Version from Registry
$semperisHFSoftware = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, `
                                     HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* `
                     | Where-Object { $_.DisplayName -like "Semperis Hotfix*" }
# Store the version in a variable
$semperisHFVersion = if ($semperisHFSoftware) { $semperisHFSoftware.DisplayVersion } else { "Not Installed" }
$semperisHFVersionNumber = if ($semperisHFSoftware) { $semperisHFSoftware.DisplayName } else { "Not Installed" }

# Count forests
$forestCount = $forests.Count

# Add version info as bordered cards with left accent (Option 2)
$htmlContent += @"
<div style="display: flex; justify-content: center; gap: 16px; padding-bottom: 16px; background: #f8f9fa; flex-wrap: wrap;">
    <div class="version-card" style="background: white; border-left: 4px solid $(if ($semperisVersion -ne 'Not Installed') { '#28a745' } else { '#dc3545' }); padding: 20px 30px; border-radius: 4px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
        <div style="font-size: 14px; color: #6c757d; text-transform: uppercase;">ADFR MS Version</div>
        <div style="font-size: 17px; font-weight: 600; color: #1a2332;">$(if ($semperisVersion -ne 'Not Installed') { $semperisVersion } else { 'Not Installed' })</div>
    </div>
    <div class="version-card" style="background: white; border-left: 4px solid $(if ($semperisHFVersion -ne 'Not Installed') { '#28a745' } else { '#ffc107' }); padding: 20px 30px; border-radius: 4px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
        <div style="font-size: 14px; color: #6c757d; text-transform: uppercase;">Hotfix</div>
        <div style="font-size: 17px; font-weight: 600; color: #1a2332;">$(if ($semperisHFVersion -ne 'Not Installed') { $semperisHFVersion } else { 'Not Installed' })</div>
    </div>
    <div class="version-card" style="background: white; border-left: 4px solid #17a2b8; padding: 20px 30px; border-radius: 4px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
        <div style="font-size: 14px; color: #6c757d; text-transform: uppercase;">Forests</div>
        <div style="font-size: 17px; font-weight: 600; color: #1a2332;">$forestCount Registered</div>
    </div>
</div>
"@

########## START of the Check Table 
# Add Forest names as table headers
foreach ($forest in $forests) {
    $htmlContent += "<th>$($forest.ForestDnsName)</th>"
}
$htmlContent += "</tr>"

# --- START CHECK 1: Most Recent Valid Backup in the Last 24h ---
$htmlContent += "<tr><td><b>Last Valid Backup Check</b></td>"
foreach ($forest in $forests) {
    $null = Select-ADFRForest $forest.ForestDnsName

    if ($forest.IsRunning -eq $true) {
        $last24Hours = (Get-Date).AddHours(-24)
        $latestBackupJob = Get-ADFRBackupJob | Where-Object { $_.EndDateTime -ge $last24Hours } | Select-Object -First 1

        if ($latestBackupJob) {
            # Check if backup is currently in progress
            if ($latestBackupJob.Status -eq "BackupInProgress") {
                $startBackup = $latestBackupJob.StartDateTime
                $htmlContent += "<td class='warning'>&#9881; Backup in Progress (Started: $startBackup)</td>"
            } else {
                $latestBackup = $latestBackupJob.EndDateTime
                $startBackup = $latestBackupJob.StartDateTime
                $duration = $latestBackup - $startBackup
                $formattedDuration = "{0:hh}:{0:mm}:{0:ss}" -f $duration

                $htmlContent += "<td class='ok'> $latestBackup (Duration: $formattedDuration)</td>"
            }
        } else {
            $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-warning'></span> No valid backup in 24h</span></td>"
        }
    } else {
        $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-warning'></span>Forest not running</span></td>"
    }
}
$htmlContent += "</tr>"
# --- END CHECK 1: Most Recent Valid Backup in the Last 24h ---

# --- START CHECK 2: Agent Responding Status ---
$htmlContent += "<tr><td><b>Agent Check</b></td>"
foreach ($forest in $forests) {
    $null = Select-ADFRForest $forest.ForestDnsName

    if ($forest.IsRunning -eq $true) {
        $agents = Get-ADFRAgent
        $totalAgents = $agents.Count

        # Categorize agents
        $nonRespondingAgents = @()
        $notInstalledCount = 0

        foreach ($agent in $agents) {
            if (-not $agent.Responding) {
                if ($agent.Installed) {
                    $nonRespondingAgents += $agent
                } else {
                    $notInstalledCount++
                }
            }
        }

        $nonRespondingCount = $nonRespondingAgents.Count

        if ($totalAgents -eq 0) {
            $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-warning'></span> No agents found!</span></td>"
        } elseif (($nonRespondingCount -eq 0) -and ($notInstalledCount -eq 0)) {
            $htmlContent += "<td class='ok'>All agents are responding</td>"
        } else {
            # Create separate clickable buttons for each issue type
            $cellContent = "<b>Information</b><br>"
            
            if ($nonRespondingCount -gt 0) {
                # Prepare non-responding agents data
                $nonRespondingDetails = @()
                foreach ($agent in $nonRespondingAgents) {
                    $nonRespondingDetails += "❌ Not Responding: $($agent.DnsHostName) (IP: $($agent.IPAddress))"
                }
                
                $safeForestName1 = $forest.ForestDnsName -replace "'", "&apos;"
                $safeNonRespondingDetails = ($nonRespondingDetails -join ", ") -replace "'", "&apos;"
                $onClickFunction1 = "showGroupDetails('$safeForestName1 - Agents Not Responding', '$safeNonRespondingDetails')"
                
                $cellContent += "<span style='cursor: pointer; color: #dc3545; text-decoration: underline; font-weight: 600; display: inline-block; margin: 2px 0;' onclick=`"$onClickFunction1`" title='Click to view non-responding agents'> $nonRespondingCount Agent(s) not responding</span>"
            }
            
            if ($notInstalledCount -gt 0) {
                # Add line break if both issues exist
                if ($nonRespondingCount -gt 0) {
                    $cellContent += "<br>"
                }
                
                # Prepare not installed agents data
                $notInstalledAgents = $agents | Where-Object { -not $_.Installed }
                $notInstalledDetails = @()
                foreach ($agent in $notInstalledAgents) {
                    $notInstalledDetails += "Not Installed: $($agent.DnsHostName) (IP: $($agent.IPAddress))"
                }
                
                $safeForestName2 = $forest.ForestDnsName -replace "'", "&apos;"
                $safeNotInstalledDetails = ($notInstalledDetails -join ", ") -replace "'", "&apos;"
                $onClickFunction2 = "showGroupDetails('$safeForestName2 - Agents Not Installed', '$safeNotInstalledDetails')"
                
                $cellContent += "<span style='cursor: pointer; color: #ffc107; text-decoration: underline; font-weight: 600; display: inline-block; margin: 2px 0;' onclick=`"$onClickFunction2`" title='Click to view agents not installed'> $notInstalledCount DC(s) without agent installed</span>"
            }
            
            $htmlContent += "<td class='warning'>$cellContent</td>"
        }

    } else {
        $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-warning'></span>Forest not running</span></td>"
    }
}
$htmlContent += "</tr>"
# --- END CHECK 2: Agent Responding Status ---
# --- START CHECK 3: ADFR Scheduled Export Setting ---
$htmlContent += "<tr><td><b>Export Setting Enabled</b></td>"
foreach ($forest in $forests) {
    if ($forest.IsRunning -eq $true) {
        $configPath = "C:\ProgramData\Semperis\$($forest.ForestDnsName).$($forest.ForestID)\General\GeneralConfiguration.xml"

        if (Test-Path $configPath) {
            try {
                [xml]$config = Get-Content $configPath

                # detect version (adjust property name if needed)
                $forestVersion = $semperisVersion

                if ($forestVersion -like "3.8.*" -or
                    $forestVersion -like "4.0.*" -or
                    $forestVersion -like "4.1.*" -or
                    $forestVersion -like "4.2.*" -or
                    $forestVersion -like "5.0.*") {

                    # old versions use IsRunScheduledSettingsExport
                    $isExportEnabled = $config.GeneralConfiguration.IsRunScheduledSettingsExport
                }
                else {
                    # 5.1+ versions use IsExportSettingsEnabled
                    $isExportEnabled = $config.GeneralConfiguration.IsExportSettingsEnabled
                }

                if ($isExportEnabled -eq "true") {
                    $htmlContent += "<td class='ok'><span class='custom-check'></span>Enabled</td>"
                }
                elseif ($isExportEnabled -eq $null) {
                    $htmlContent += "<td class='ko'><span class='custom-fail'></span> Unknown version $forestVersion</td>"
                }
                else {
                    $htmlContent += "<td class='ko'><span class='custom-fail'></span> Enable Export setting ASAP</td>"
                }
            }
            catch {
                $htmlContent += "<td class='ko'><span class='custom-fail'></span> Error reading config</td>"
            }
        }
        else {
            $htmlContent += "<td class='ko'><span class='custom-fail'></span> Config file not found</td>"
        }
    }
    else {
        $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-warning'></span>Forest not running</span></td>"
    }
}
$htmlContent += "</tr>"
# --- END CHECK 3: ADFR Scheduled Export Setting --
# --- STARt CHECK 4: SMTP Verification ---
$htmlContent += "<tr><td><b>SMTP Verification</b></td>"
foreach ($forest in $forests) {
    $null = Select-ADFRForest $forest.ForestDnsName

    if ($forest.IsRunning -eq $true) {
        $settings = Get-ADFRSetting
        if ($settings.smtp.Verified -eq $true) {
            $htmlContent += "<td class='ok'><span class='custom-check'></span>Configured & Verified</td>"
        } else {
            $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-warning'></span>Not Configured and verified</span></td>"
        }
    } else {
        $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-warning'></span>Forest not running</span></td>"
    }
}
$htmlContent += "</tr>"
# --- END CHECK 4: SMTP Verification ---

# --- START CHECK 5: Last Valid Backup vs. Most Recent Backup ---
$htmlContent += "<tr><td><b>Last Valid Backup</b></td>"
foreach ($forest in $forests) {
    $null = Select-ADFRForest $forest.ForestDnsName

    if ($forest.IsRunning -eq $true) {
        $backupJobs = Get-ADFRBackupJob | Where-Object { $_.EndDateTime -ne $null } | Sort-Object EndDateTime -Descending

                $mostRecentBackup = $backupJobs | Select-Object -First 1
                $lastValidBackup = $backupJobs | Where-Object { $_.ValidationStatus -eq "Valid" } | Select-Object -First 1

                if ($mostRecentBackup -and $mostRecentBackup.ValidationStatus -eq "Valid") {
                    $htmlContent += "<td class='ok'><span class='custom-check'></span>Most Recent = Last Valid</td>"
                } elseif ($mostRecentBackup -and $lastValidBackup) {
                    $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-warning'></span>  Most Recent <span class='custom-fail'></span> Last Valid Backup! Most recent: $($mostRecentBackup.EndDateTime), Last valid: $($lastValidBackup.EndDateTime)</span></td>"
                } else {
                    $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-fail'></span>No valid backups found</span></td>"
                }
            } else {
                $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-warning'></span>Forest not running</span></td>"
            }
        }
        # --- END CHECK 5: Last Valid Backup vs. Most Recent Backup ---
# --- END CHECK 5: Last Valid Backup vs. Most Recent Backup ---

# --- START  CHECK 6: Multi-Forest Distribution Point Status ---
$htmlContent += "<tr><td><b>MFDP Status</b></td>"
foreach ($forest in $forests) {
    $null = Select-ADFRForest $forest.ForestDnsName

    # Retrieve forest information specific to the current forest
    $forestInfo = Get-ADFRForest | Where-Object { $_.ForestDnsName -eq $forest.ForestDnsName }

    if ($forestInfo) {
        if ($forestInfo.MultiForestDistributionPointMode -eq "Disabled") {
            $htmlContent += "<td class='warning'>MFDP not configured</td>"
        } elseif ($forestInfo.MultiForestDistributionPointMode -eq "Enabled") {
            $htmlContent += "<td class='ok'><span class='custom-check'></span>MFDP Enabled</td>"
        } else {
            $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-warning'></span>Unknown MFDP status</span></td>"
        }
    } else {
        $htmlContent += "<td class='warning'>NO MFDP on this ADFR</td>"
    }
}
$htmlContent += "</tr>"
# --- END CHECK 6: Multi-Forest Distribution Point Status ---

# --- START CHECK 7: ADFR Backup Rules Without Encryption ---
$htmlContent += "<tr><td><b>ADFR Backup Rule (No Encryption)</b></td>"
foreach ($forest in $forests) {
    $null = Select-ADFRForest $forest.ForestDnsName

    # Retrieve backup rules where Encrypt = 0 (assumed to be "DontEncrypt")
    $unencryptedRules = Get-ADFRBackupRule | Where-Object { $_.Encrypt -eq 2 }

    if ($unencryptedRules) {
        # Extract rule names
        $ruleNames = ($unencryptedRules | ForEach-Object { $_.Name }) -join ", "
        $htmlContent += "<td class='warning'><span class='custom-warning'></span> Backup rules with NO encryption: $ruleNames</td>"
    } else {
        $htmlContent += "<td class='ok'><span class='custom-check'></span>All backup rules are encrypted</td>"
    }
}
$htmlContent += "</tr>"
# --- END CHECK 7: ADFR Backup Rules Without Encryption ---

# --- START CHECK 8: ADFR CHECK PROTOCOL HTTP vs TCP ---
$adfrProtocols = @{}
# Registry base path
$baseRegPath = "HKLM:\SOFTWARE\Semperis\MultiForest"
$forestKeys = Get-ChildItem -Path $baseRegPath

foreach ($forestKey in $forestKeys) {
    $forestName = (Get-ItemProperty -Path "$baseRegPath\$($forestKey.PSChildName)" -Name "ForestDnsName" -ErrorAction SilentlyContinue).ForestDnsName
    if (-not $forestName) { continue }

    $adfrServerRegPath = "$baseRegPath\$($forestKey.PSChildName)\Semperis\ADFR\Server"
    $msToDc = (Get-ItemProperty -Path $adfrServerRegPath -Name "PrimaryDcBackupTransport" -ErrorAction SilentlyContinue).PrimaryDcBackupTransport
    $dpToDc = (Get-ItemProperty -Path $adfrServerRegPath -Name "PrimaryDpBackupTransport" -ErrorAction SilentlyContinue).PrimaryDpBackupTransport

    # Force fallback to "N/A" if null or empty
    if ([string]::IsNullOrWhiteSpace($msToDc)) { $msToDc = "N/A" }
    if ([string]::IsNullOrWhiteSpace($dpToDc)) { $dpToDc = "N/A" }

    $adfrProtocols[$forestName] = @{
        DC = $msToDc
        DP = $dpToDc
    }
}
# Add DC Protocol row
$htmlContent += "<tr><td><b>DC Protocol</b></td>"
foreach ($forest in $forests) {
    $proto = $adfrProtocols[$forest.ForestDnsName]
    if ($proto.DC -eq "TCP") {
        $htmlContent += "<td class='ok'>$($proto.DC)</td>"
    } elseif ($proto.DC -eq "HTTP") {
        $htmlContent += "<td class='warning'>$($proto.DC)</td>"
    } else {
        $htmlContent += "<td>$($proto.DC)</td>"
    }
}
$htmlContent += "</tr>"

# Add DP Protocol row
$htmlContent += "<tr><td><b>DP Protocol</b></td>"
foreach ($forest in $forests) {
    $proto = $adfrProtocols[$forest.ForestDnsName]
    if ($proto.DP -eq "TCP") {
        $htmlContent += "<td class='ok'>$($proto.DP)</td>"
    } elseif ($proto.DP -eq "HTTP") {
        $htmlContent += "<td class='warning'>$($proto.DP)</td>"
    } else {
        $htmlContent += "<td>$($proto.DP)</td>"
    }
}
$htmlContent += "</tr>"
# --- END CHECK 8: ADFR CHECK PROTOCOL HTTP vs TCP ---
$htmlContent += "</table>"
########## END of the Check Table 

# Add Expand All / Collapse All buttons with CSS icons
$htmlContent += @"
<style>
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
</style>
<div style="text-align: right; margin: 10px 0;">
    <button id="expandAll" style="background: linear-gradient(135deg, #17212d 0%, #2c3e50 100%); color: white; border: none; padding: 6px 15px; margin: 0 5px; border-radius: 5px; cursor: pointer; font-size: 14px; transition: all 0.3s ease;" onmouseover="this.style.backgroundColor='#2c3e50';" onmouseout="this.style.backgroundColor='#17212d';">
        <span class="expand-icon"></span>Expand All
    </button>
    <button id="collapseAll" style="background: linear-gradient(135deg, #17212d 0%, #2c3e50 100%); color: white; border: none; padding: 6px 15px; margin: 0 5px; border-radius: 5px; cursor: pointer; font-size: 14px; transition: all 0.3s ease;" onmouseover="this.style.backgroundColor='#2c3e50';" onmouseout="this.style.backgroundColor='#17212d';">
        <span class="collapse-icon"></span>Collapse All
    </button>
</div>
"@

#----- START SECTION ADFR Management Server 

$htmlContent += "<button class='collapsible'>🧩 ADFR Management Server </button><div class='content'>"
# Start table
$htmlContent += "<table>
<tr>
    <th>ADFR Hostname</th>
    <th>ADFR IP</th>
    <th>SQL Version</th>
    <th>SQL (SMPRS) Startup Mode</th>
    <th>Net TCP Binding</th>
    <th>Remote Registry</th>
    <th>Semperis Web Mmgt Certificate</th>
</tr>"
#### Semperis Web Certificate
$desiredFriendlyName = "Semperis Web Management Certificate"

$certs = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {
    $_.FriendlyName -eq $desiredFriendlyName
}

if ($certs.Count -eq 1) {
    $certStatus = "<td class='ok'><span class='custom-check'></span> 1 Certificate Found (Expires: $($certs[0].NotAfter.ToString('yyyy-MM-dd')))</td>"
} elseif ($certs.Count -gt 1) {
    $certStatus = "<td class='warning'><span class='custom-warning'></span> $($certs.Count) Certificates Found</td>"
} else {
    $certStatus = "<td class='ko'><span class='custom-fail'></span> Not Found</td>"
}
# Hostname and IP
$fqdn = [System.Net.Dns]::GetHostByName(($env:COMPUTERNAME)).HostName
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.InterfaceAlias -notlike 'Loopback*' } | Select-Object -First 1).IPAddress


# SQL Version (simplified: 2019 / 2022)
try {
    # Try multiple connection methods for SQL version check
    $sqlConnectionMethods = @(
        "localhost\SMPRS",
        "localhost,1433", 
        ".\SMPRS",
        "(local)\SMPRS"
    )
    
    $sqlVerFull = $null
    $sqlConnectionSuccess = $false
    
    foreach ($serverInstance in $sqlConnectionMethods) {
        try {
            $sqlVerFull = Invoke-Sqlcmd -Query "SELECT SERVERPROPERTY('ProductVersion') AS Version" -ServerInstance $serverInstance -ErrorAction Stop | Select-Object -ExpandProperty Version
            $sqlConnectionSuccess = $true
            break
        } catch {
            continue
        }
    }
    
    if ($sqlConnectionSuccess -and $sqlVerFull) {
        if ($sqlVerFull.StartsWith("15.")) {
            $sqlVersion = "SQL Server 2019"
        } elseif ($sqlVerFull.StartsWith("16.")) {
            $sqlVersion = "SQL Server 2022"
        } else {
            $sqlVersion = "Other ($sqlVerFull)"
        }
    } else {
        $sqlVersion = "<span class='custom-fail'></span> SQL Not Found"
    }
} catch {
    $sqlVersion = "<span class='custom-fail'></span> SQL Not Found"
}
# SMPRS SQL Service Detection (Flexible)
$smprsService = Get-Service | Where-Object { $_.Name -like "MSSQL$*" }
$sqlServiceStatus = if ($smprsService) { $smprsService.StartType } else { "<span class='custom-fail'></span> Not Found" }

# Binding Info
$siteName = "SemperisSite"
$expectedBindingInfo = "8791:*"
$tcpStatus = "<span class='custom-fail'></span> Not Configured"

if (Get-Module -ListAvailable WebAdministration) {
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    if (Test-Path "IIS:\Sites\$siteName") {
        $site = Get-Item "IIS:\Sites\$siteName"
        $netTcpBinding = $site.Bindings.Collection | Where-Object {
            $_.protocol -eq "net.tcp" -and $_.bindingInformation -eq $expectedBindingInfo
        }
        if ($netTcpBinding) {
            $tcpStatus = "<span class='custom-check'></span>Binding present ($expectedBindingInfo)"
        } else {
            $tcpStatus = "<span class='custom-fail'></span>Binding not present ($expectedBindingInfo)"
        }
    }
}

# Remote Registry
try {
    $remoteRegService = (Get-Service -Name RemoteRegistry).StartType
} catch {
    $remoteRegService = "<span class='custom-fail'></span> Not Found"
}

# Output the row
$htmlContent += "<tr>
<td>$fqdn</td>
<td>$ip</td>
<td>$sqlVersion</td>
<td>$sqlServiceStatus</td>
<td>$tcpStatus</td>
<td>$remoteRegService</td>
$certStatus
</tr>"

$htmlContent += "</table><br>"
# Add Excluded Partitions table for each forest
$htmlContent += "<h3 class='forest-badge'>Excluded Partitions by Forest</h3>"
$htmlContent += "<table><tr>
    <th>Forest Name</th>
    <th>Partition Name</th>
    <th>Excluded Partition</th>
</tr>"
# Check registry for each forest
foreach ($forest in $forests) {
    $forestRegistryKey = "$($forest.ForestID).$($forest.ForestDnsName)"
    $excludedPartitionsPath = "HKLM:\SOFTWARE\Semperis\MultiForest\$forestRegistryKey\Semperis\ADFR\Server\ExcludedPartitions"
    if (Test-Path $excludedPartitionsPath) {
        try {
            $excludedPartitions = Get-ItemProperty -Path $excludedPartitionsPath -ErrorAction SilentlyContinue
            $hasPartitions = $false
            # Loop through all properties except PS* properties
            foreach ($property in $excludedPartitions.PSObject.Properties) {
                if ($property.Name -notlike "PS*") {
                    $hasPartitions = $true
                    $partitionName = $property.Name
                    $excludedValue = $property.Value
                    
                    $htmlContent += "<tr>
                        <td>$($forest.ForestDnsName)</td>
                        <td>$partitionName</td>
                        <td>$excludedValue</td>
                    </tr>"
                }
            }
            # If no partitions found in this forest
            if (-not $hasPartitions) {
                $htmlContent += "<tr>
                    <td>$($forest.ForestDnsName)</td>
                    <td colspan='2' class='ok'>No excluded partitions configured</td>
                </tr>"
            }
        } catch {
            $htmlContent += "<tr>
                <td>$($forest.ForestDnsName)</td>
                <td colspan='2' class='ko'>Error reading registry</td>
            </tr>"
        }
    } else {
        $htmlContent += "<tr>
            <td>$($forest.ForestDnsName)</td>
            <td colspan='2' class='warning'>ExcludedPartitions registry key not found</td>
        </tr>"
    }
}
$htmlContent += "</table><br>"

$htmlContent += "</div>"  # Close collapsible content

# ---- END SECTION ADFR Management Server

# --- START SECTION Semperis Certificates ---
$htmlContent += "<button class='collapsible'>📜 Semperis Certificates Inventory</button><div class='content'>"
$htmlContent += "<table><tr>
    <th>Certificate Store</th>
    <th>Certificate Name (Subject)</th>
    <th>Thumbprint</th>
    <th>Expiration Date</th>
    <th>Friendly Name</th>
</tr>"

# Get certificates from Personal store
$personalCerts = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {
    $_.Subject -like "*Semperis*" -or $_.FriendlyName -like "*Semperis*" 
}

# Get certificates from Trusted Root store
$trustedRootCerts = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {
    $_.Subject -like "*Semperis*" -or $_.FriendlyName -like "*Semperis*" 
}

# Add Personal certificates to table
foreach ($cert in $personalCerts) {
    $subjectcert = if ($cert.Subject) { $cert.Subject } else { "N/A" }
    $thumbprint = if ($cert.Thumbprint) { $cert.Thumbprint } else { "N/A" }
    $expiry = if ($cert.NotAfter) { $cert.NotAfter.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
    $friendlyName = if ($cert.FriendlyName) { $cert.FriendlyName } else { "N/A" }
    
    $htmlContent += "<tr>
        <td>Personal</td>
        <td>$subjectcert</td>
        <td>$thumbprint</td>
        <td>$expiry</td>
        <td>$friendlyName</td>
    </tr>"
}

# Add Trusted Root certificates to table
foreach ($cert in $trustedRootCerts) {
    $subjectcert = if ($cert.Subject) { $cert.Subject } else { "N/A" }
    $thumbprint = if ($cert.Thumbprint) { $cert.Thumbprint } else { "N/A" }
    $expiry = if ($cert.NotAfter) { $cert.NotAfter.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
    $friendlyName = if ($cert.FriendlyName) { $cert.FriendlyName } else { "N/A" }
    
    $htmlContent += "<tr>
        <td>Trusted Root</td>
        <td>$subjectcert</td>
        <td>$thumbprint</td>
        <td>$expiry</td>
        <td>$friendlyName</td>
    </tr>"
}

# If no certificates found, add a message
if ($personalCerts.Count -eq 0 -and $trustedRootCerts.Count -eq 0) {
    $htmlContent += "<tr><td colspan='5' class='warning'><span class='custom-warning'></span> No Semperis certificates found in Personal or Trusted Root stores</td></tr>"
}

$htmlContent += "</table></div>"
# --- END SECTION Semperis Certificates ---

# --- START SECTION Backup Job Summary ---
$htmlContent += "<button class='collapsible'>📦 Backup Job Summary</button><div class='content'>"
foreach ($forest in $forests) {
    $null = Select-ADFRForest $forest.ForestDnsName
    $htmlContent += "<div class='forest-badge'>Forest: $($forest.ForestDnsName)</div>"

    # Get backup rule IDs and names
    $rules = Get-ADFRBackupRule | ForEach-Object {
        [PSCustomObject]@{
            ID   = $_.ID
            Name = $_.Name
        }
    }

    # Get latest jobs
    $latestBackupJobs = Get-ADFRBackupJob |
        Where-Object { $_.EndDateTime -ne $null } |
        Sort-Object EndDateTime -Descending |
        Select-Object -First 7

    if ($latestBackupJobs.Count -eq 0) {
        $htmlContent += "<p>No backup jobs found.</p>"
        continue
    }

    # Start table
    $htmlContent += "<table><tr><th>Property</th>"

    foreach ($job in $latestBackupJobs) {
        $htmlContent += "<th>$($job.ID.Guid)</th>"
    }
    $htmlContent += "</tr>"

    # Define row values per property
    $properties = @(
        @{ Name = "Backup Rule Name"; Values = { param($job) ($rules | Where-Object { $_.ID -eq $job.BackupRuleID }).Name } },

        @{ Name = "Status"; Values = { param($job)
                switch ($job.Status) {
                    "Success"         { @{ Class = "ok"; Value = "<span class='custom-check'></span> Success" } }
                    "PartialSuccess"  { @{ Class = "warning"; Value = "<span class='custom-warning'></span> Partial" } }
                    default           { @{ Class = "ko"; Value = "<span class='custom-fail'></span> $($job.Status)" } }
                }
            }; StyleCell = $true },

        @{ Name = "Valid"; Values = { param($job)
                if ($job.ValidationStatus -eq 'Valid') {
                    "<span class='custom-check'></span> <span style='color:green'>True</span>"
                } else {
                    "<span class='custom-fail'></span> <span style='color:red'>False</span>"
                }
            }},

        @{ Name = "Start Time"; Values = { param($job)
                if ($job.StartDateTime) { $job.StartDateTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "—" }
            }},

        @{ Name = "End Time"; Values = { param($job)
                if ($job.EndDateTime) { $job.EndDateTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "—" }
            }},

        @{ Name = "Error Message"; Values = { param($job)
                if ([string]::IsNullOrWhiteSpace($job.ErrorMessage)) { "—" } else { $job.ErrorMessage }
            }},

        @{ Name = "Cloud Forest AD Validation Status"; Values = { param($job)
                if ([string]::IsNullOrWhiteSpace($job.CloudForestADValidationStatus)) {
                    "—"
                } else {
                    $job.CloudForestADValidationStatus -replace "NotValid", "Not Valid"
                }
            }},

        @{ Name = "Duration (HH:MM:SS)"; Values = { param($job)
                if ($job.StartDateTime -and $job.EndDateTime) {
                    $ts = New-TimeSpan $job.StartDateTime $job.EndDateTime
                    "{0:00}:{1:00}:{2:00}" -f $ts.Hours, $ts.Minutes, $ts.Seconds
                } else { "—" }
            }}
    )

    # Build rows
    foreach ($prop in $properties) {
        $htmlContent += "<tr><td><b>$($prop.Name)</b></td>"
        foreach ($job in $latestBackupJobs) {
            $value = & $prop.Values $job

            if ($prop.StyleCell -eq $true -and $value -is [hashtable]) {
                $htmlContent += "<td class='$($value.Class)'>$($value.Value)</td>"
            } else {
                $htmlContent += "<td>$value</td>"
            }
        }
        $htmlContent += "</tr>"
    }

    $htmlContent += "</table>"
} 
$htmlContent += "</div>"
# --- END SECTION Backup Job Summary ---

# --- START SECTION Backup Rule Setting ---
$htmlContent += "<button class='collapsible'>🛡️ Backup Rules Configuration</button><div class='content'>"
foreach ($forest in $forests) {
    $null = Select-ADFRForest $forest.ForestDnsName
    $groups = Get-ADFRBackupGroup
    $groupsmember = $groups | Select-Object -ExpandProperty DomainControllerBackupGroupList
    $htmlContent += "<div class='forest-badge'>Forest: $($forest.ForestDnsName)</div>"
    $htmlContent += "<table>
        <tr>
            <th>Rule Name</th>
            <th>Enable</th>
            <th>Backup Retention</th>
            <th>Repeat (Days)</th>
            <th>Backup Start Time</th>
            <th>Backup Group Name</th>
            <th>Valid for Recovery</th>
        </tr>"

    # Get all Backup Rules
    $backupRules = Get-ADFRBackupRule

    foreach ($rule in $backupRules) {
        $rulename = $rule.Name
        $ruleRetention = $rule.Retention
        $ruleDays = $rule.Days
        $RuleEnable = $rule.Enabled
        $ruleBackupTime = $rule.StartTime
        $ruleValidation = $rule.Validated
        $ruleBackupGroup = $rule.BackupRuleEntries.BackupGroupName

        # Format status with appropriate color/icon
        if ($ruleValidation -eq "Validated") {
            $statusHtml = "<td class='ok'><span class='custom-check'></span> Valid for Recovery</td>"
        } else {
            $statusHtml = "<td class='ko'><span class='blinking-icon'> <span class='custom-fail'></span> Not Valid </span></td>"
        }

        # Create clickable backup group cell with DC information
        $backupGroupCell = ""
        if ($ruleBackupGroup) {
            # Handle multiple backup groups (comma-separated)
            $groupNames = $ruleBackupGroup -split ',' | ForEach-Object { $_.Trim() }
            $clickableGroups = @()
            
            foreach ($groupName in $groupNames) {
                # Find the corresponding group in $groups to get DC list
                $matchingGroup = $groups | Where-Object { $_.DisplayName -eq $groupName }
                if ($matchingGroup) {
                    # Get Domain Controllers from the group
                    $dcList = ""
                    if ($matchingGroup.DomainControllerBackupGroupList) {
                        $dcList = ($matchingGroup.DomainControllerBackupGroupList.DomainControllerFQDN) -join ", "
                    } elseif ($matchingGroup.DomainControllers) {
                        # Fallback to DomainControllers property if available
                        $dcList = $matchingGroup.DomainControllers -join ", "
                    }
                    
                    # Create clickable span for this group - escape quotes for JavaScript
                    $safeGroupName = $groupName -replace "'", "&apos;"
                    $safeDcList = $dcList -replace "'", "&apos;"
                    $onClickFunction = "showGroupDetails('$safeGroupName', '$safeDcList')"
                    $clickableGroups += "<span style='cursor: pointer; color: #17a2b8; text-decoration: underline; font-weight: 600;' onclick=`"$onClickFunction`" title='Click to view Domain Controllers in this group'>📋 $groupName</span>"
                } else {
                    # Group not found, show as non-clickable
                    $clickableGroups += "<span style='color: #856404;'><span class='custom-warning'> $groupName (Not Found)</span></span>"
                }
            }
            
            $backupGroupCell = "<td>" + ($clickableGroups -join "<br>") + "</td>"
        } else {
            $backupGroupCell = "<td style='color: #721c24;'><span class='custom-fail'>No Groups Assigned</span></td>"
        }

        $htmlContent += "<tr>
            <td>$rulename</td>
            <td>$RuleEnable</td>
            <td>$ruleRetention</td>
            <td>$ruleDays</td>
            <td>$ruleBackupTime</td>
            $backupGroupCell
            $statusHtml
        </tr>"
    }

    $htmlContent += "</table>"
}
$htmlContent += "</div>"  # Close collapsible content
# --- END SECTION Backup Rule Setting ---


###############################
# --- START SECTION: ADFR Recovery Administrator ---
$htmlContent += "<button class='collapsible'>🔐 RBAC Recovery Administrator</button><div id='rbacCheck' class='content'><table border='1'>
<tr>
    <th>Forest Name</th>
    <th>Recovery Administrator</th>
</tr>"
# Define SQL Server and Query
$SQLServer = "localhost\SMPRS"
$Database = "master"
# SQL Query with fixed forest name parsing logic
$SQLQuery = @'
DECLARE @ForestName NVARCHAR(255), @DBName NVARCHAR(255), @SQL NVARCHAR(MAX);

-- Cursor to loop through each forest database
DECLARE ForestCursor CURSOR FOR
SELECT name 
FROM sys.databases
WHERE name LIKE 'Smprs_CM_%'
AND name LIKE '%.%.%.%'; -- Ensure it's a forest-like DB

-- Open Cursor
OPEN ForestCursor;
FETCH NEXT FROM ForestCursor INTO @DBName;

-- Temp table to store results
IF OBJECT_ID('tempdb..#FilteredUsers') IS NOT NULL DROP TABLE #FilteredUsers;
CREATE TABLE #FilteredUsers (
    ForestName NVARCHAR(255),
    DisplayName NVARCHAR(255)
);

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Step 1: Clean suffix
    DECLARE @Suffix NVARCHAR(255) = REPLACE(@DBName, 'Smprs_CM_', '');
    IF LEFT(@Suffix, 5) = 'Data.' SET @Suffix = STUFF(@Suffix, 1, 5, '');

    -- Step 2: If ends with .GUID → remove it
    IF LEN(@Suffix) > 37 AND RIGHT(@Suffix, 37) LIKE '.________-____-____-____-____________'
    BEGIN
        SET @ForestName = LEFT(@Suffix, LEN(@Suffix) - 37);
    END
    ELSE
    BEGIN
        SET @ForestName = @Suffix;
    END

    -- Step 3: Build dynamic SQL per DB
    SET @SQL = '
    INSERT INTO #FilteredUsers (ForestName, DisplayName)
    SELECT DISTINCT ''' + @ForestName + ''', ri.DisplayName
    FROM ' + QUOTENAME(@DBName) + '.dbo.tblRbacIdentities ri
    JOIN ' + QUOTENAME(@DBName) + '.dbo.tblRbacIdentitiesToPersonas rp
        ON ri.RbacIdentityID = rp.RbacIdentityID
    WHERE rp.RbacPersonaID = ''42E26D4A-977A-11E7-ABC4-CEC278B6B50A''
    AND ri.RbacIdentityID IS NOT NULL;';

    EXEC sp_executesql @SQL;

    FETCH NEXT FROM ForestCursor INTO @DBName;
END

CLOSE ForestCursor;
DEALLOCATE ForestCursor;

-- Return results
SELECT ForestName, DisplayName
FROM #FilteredUsers
ORDER BY ForestName, DisplayName;

DROP TABLE #FilteredUsers;
'@

try {
    # Define SQL Server connection methods
    $connectionMethods = @(
        "Server=localhost\SMPRS;Database=$Database;Integrated Security=True;TrustServerCertificate=True;",
        "Server=localhost,1433;Database=$Database;Integrated Security=True;TrustServerCertificate=True;",
        "Server=.\SMPRS;Database=$Database;Integrated Security=True;TrustServerCertificate=True;",
        "Server=(local)\SMPRS;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"
    )
    
    $sqlResults = $null
    $connectionSuccess = $false
    $useDirectMethod = $false
    
    foreach ($connectionString in $connectionMethods) {
        try {
            # First try the original complex SQL cursor method
            $sqlResults = Invoke-Sqlcmd -ConnectionString $connectionString -Query $SQLQuery -ErrorAction Stop
            $connectionSuccess = $true
            break
        } catch {
            # If we get op_Division or similar parsing errors, try direct method
            if ($_.Exception.Message -like "*op_Division*" -or $_.Exception.Message -like "*Method invocation failed*") {
                $useDirectMethod = $true
                break
            }
            continue
        }
    }
    
    # If original method failed with parsing errors, use direct database naming
    if ($useDirectMethod) {
        $allResults = @()
        foreach ($connectionString in $connectionMethods) {
            try {
                foreach ($forest in $forests) {
                    $databaseName = "Smprs_Cm_Data.$($forest.ForestDnsName).$($forest.ForestID)"
                    
                    $directQuery = @"
SELECT DISTINCT '$($forest.ForestDnsName)' as ForestName, ri.DisplayName
FROM [$databaseName].dbo.tblRbacIdentities ri
INNER JOIN [$databaseName].dbo.tblRbacPersonaIdentities rpi ON ri.RbacIdentityID = rpi.RbacIdentityID
INNER JOIN [$databaseName].dbo.tblRbacPersonas rp ON rpi.RbacPersonaID = rp.RbacPersonaID
WHERE rp.RbacPersonaID = '42E26D4A-977A-11E7-ABC4-CEC278B6B50A'
AND ri.RbacIdentityID IS NOT NULL;
"@
                    
                    try {
                        $forestResults = Invoke-Sqlcmd -ConnectionString $connectionString -Query $directQuery -ErrorAction Stop
                        if ($forestResults) {
                            $allResults += $forestResults
                        }
                    } catch {
                        # Database might not exist for this forest, continue
                        continue
                    }
                }
                $sqlResults = $allResults
                $connectionSuccess = $true
                break
            } catch {
                continue
            }
        }
    }
    
    if (-not $connectionSuccess) {
        $htmlContent += "<tr><td colspan='2' class='ko'><p class='blinking-icon'><span class='custom-warning'></span></p>Error - All SQL connection methods failed</td></tr>"
        return
    }
    
    if ($sqlResults) {
        if ($useDirectMethod) {
            # Direct method - results are already grouped by forest
            foreach ($row in $sqlResults) {
                $htmlContent += "<tr><td>$($row.ForestName)</td><td class='ok'>$($row.DisplayName)</td></tr>"
            }
        } else {
            # Original method - use existing forest matching logic
            $forestGroups = $sqlResults | Group-Object -Property ForestName

            foreach ($forest in $forests) {            
                $null = Select-ADFRForest $forest.ForestDnsName
                
                # More flexible forest name matching
                $forestData = $forestGroups | Where-Object {
                    $sqlForestName = ($_.Name -replace '\.$', '').ToLower().Trim()
                    $psForestName = ($forest.ForestDnsName -replace '\.$', '').ToLower().Trim()
                    
                    # Try exact match first, then partial matches
                    $sqlForestName -eq $psForestName -or 
                    $sqlForestName.Contains($psForestName) -or 
                    $psForestName.Contains($sqlForestName)
                }

                if ($forestData) {
                    foreach ($row in $forestData.Group) {
                        $htmlContent += "<tr><td>$($row.ForestName)</td><td class='ok'>$($row.DisplayName)</td></tr>"
                    }
                } else {
                    $htmlContent += "<tr><td>$($forest.ForestDnsName)</td><td class='ko'><span class='blinking-icon'><span class='custom-fail'></span>No Recovery Administrator Found</span></td></tr>"
                }
            }
        }
    } else {
        foreach ($forest in $forests) {
            $htmlContent += "<tr><td>$($forest.ForestDnsName)</td><td class='ko'><span class='blinking-icon'><span class='custom-fail'></span> No Records Found</span></td></tr>"
        }
    }
} catch {
    $htmlContent += "<tr><td colspan='2' class='ko'><p class='blinking-icon'><span class='custom-warning'></span></p>Error - Unexpected issue when querying SQL Server</td></tr>"
}
$htmlContent += "</table></div>"
# --- END SECTION ADFR Recovery Administrator ---

# --- START SECTION: ADFR MS & DP Specs ---
##################################
$htmlContent += "<button class='collapsible'>🖥️ Free Space : ADFR and DPs</button><div class='content'>"

foreach ($forest in $forests) {
    # Switch forest context
    $null = Select-ADFRForest $forest.ForestDnsName

    # Header per forest
    $htmlContent += "<div class='forest-badge'>Forest: $($forest.ForestDnsName)</div>"
    $htmlContent += "<table><tr>
        <th>Distribution Point</th>
        <th>IP Address</th>
        <th>Backup Path</th>
        <th>Drive Letter</th>
        <th>Free Space (GB)</th>
        <th>Total Size (GB)</th>
        <th>Total Backup Size (GB)</th>
    </tr>"

    # Get all Distribution Points except "Local DC Backup"
    $distributionPoints = Get-ADFRDistributionPoint | Where-Object { $_.FriendlyName -ne "Local DC Backup" }

    foreach ($dp in $distributionPoints) {

        $totalBackupSizeGB = "N/A"
        # Extract Drive Letter from BackupPath
        if ($dp.BackupPath) {
            $driveLetter = ($dp.BackupPath -split ':')[0] + ':'

            # Get WMI Disk Information
            try {
                $disk = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $dp.IPAddress -Filter "DeviceID = '$driveLetter'" -ErrorAction Stop
                $freeSpaceGB = "{0:N2}" -f ($disk.FreeSpace / 1GB)
                $totalSizeGB = "{0:N2}" -f ($disk.Size / 1GB)
            } catch {
                $freeSpaceGB = "N/A"
                $totalSizeGB = "N/A"
            }

            # If Disk is found, calculate Free Space and Total Size in GB
            if ($disk) {
                $freeSpaceGB = "{0:N2}" -f ($disk.FreeSpace / 1GB)
                $totalSizeGB = "{0:N2}" -f ($disk.Size / 1GB)
            } else {
                $freeSpaceGB = "N/A"
                $totalSizeGB = "N/A"
            }
            # Calculate Total Folder Size
            if (Test-Path $dp.BackupPath) {
                $folderSizeBytes = (Get-ChildItem -Path $dp.BackupPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                if ($folderSizeBytes) {
                    $totalBackupSizeGB = "{0:N2}" -f ($folderSizeBytes / 1GB)
                }
            } else {
                $driveLetter = "N/A"
                $freeSpaceGB = "N/A"
                $totalSizeGB = "N/A"
            }

        # Add DP Info to Table
        $htmlContent += "<tr>
            <td>$($dp.FriendlyName)</td>
            <td>$($dp.IPAddress)</td>
            <td>$($dp.BackupPath)</td>
            <td>$driveLetter</td>
            <td>$freeSpaceGB GB</td>
            <td>$totalSizeGB GB</td>
            <td>$totalBackupSizeGB GB</td>
        </tr>"
        }   
    }
    $htmlContent += "</table>"

}
$htmlContent += "</div>"

##################################
##################################
# --- START SECTION: MFDP & Cloud Distribution Point ---
$htmlContent += "<button class='collapsible'>☁️ MFDP & Cloud Distribution Point</button><div id='mfdpCheck' class='content'><table border='1'>
<tr>
     <th>MFDP Type</th>
     <th>MFDP Name</th>
</tr>"
# Define SQL Server and Database
$SQLServer = "localhost\SMPRS"
$Database = "Smprs_Cm_Data"
# Define the SQL Query to include both Configuration 0 and 4
$SQLQuery = @"
SELECT Configuration, Name
FROM dbo.tblAdfrDistributionPoints
WHERE Configuration IN (0, 4)
"@

try {
    # Try multiple connection methods in order of preference
    $connectionMethods = @(
        "Server=localhost\SMPRS;Database=$Database;Integrated Security=True;TrustServerCertificate=True;",
        "Server=localhost,1433;Database=$Database;Integrated Security=True;TrustServerCertificate=True;",
        "Server=.\SMPRS;Database=$Database;Integrated Security=True;TrustServerCertificate=True;",
        "Server=(local)\SMPRS;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"
    )
    
    $sqlResults = $null
    $connectionSuccess = $false
    
    foreach ($connectionString in $connectionMethods) {
        try {
            $sqlResults = Invoke-Sqlcmd -ConnectionString $connectionString -Query $SQLQuery -ErrorAction Stop
            $connectionSuccess = $true
            break
        } catch {
            continue
        }
    }
    
    if (-not $connectionSuccess) {
        $htmlContent += "<tr><td colspan='2' class='ko'><p class='blinking-icon'><span class='custom-warning'></span></p>Error - All SQL connection methods failed</td></tr>"
        return
    }
    
    if ($sqlResults) {
        foreach ($row in $sqlResults) {
            $type = switch ($row.Configuration) {
                4 { "Cloud Storage Azure" }
                0 { "MFDP" }
                default { "Unknown Type" }
            }

            $htmlContent += "<tr><td>$type</td><td>$($row.Name)</td></tr>"
        }
    } else {
        $htmlContent += "<tr><td colspan='2' class='warning'><span class='custom-warning'></span> No Distribution Points Found</span></td></tr>"
    }
} catch {
    $htmlContent += "<tr><td colspan='2' class='ko'><p class='blinking-icon'><span class='custom-warning'></span></p>Error - Unexpected issue when querying SQL Server</td></tr>"
}
$htmlContent += "</table></div>"
# --- END SECTION: MFDP & Cloud Distribution Point ---


##################################
# --- START SECTION: ADFR MS & DP Specs ---
##################################
# --- START SECTION - Domain Controllers Free Space ---
$htmlContent += "<button class='collapsible'>🆓 Domain Controller Information</button><div class='content'>"

foreach ($forest in $forests) {
    # Switch forest context
    $null = Select-ADFRForest $forest.ForestDnsName

    # Header per forest
    $htmlContent += "<div class='forest-badge'>Forest: $($forest.ForestDnsName)</div>"
    $htmlContent += "<table><tr>
        <th>Domain Controller</th>
        <th>IP Address</th>
        <th>OS Version</th>
        <th>AD Site</th>
        <th>Free Space (GB)</th>
        <th>DC Backup Path</th>
        <th>Agent Version</th>
    </tr>"

    # Get installed agents and sort alphabetically by DNS name
    $agents = Get-ADFRAgent | Where-Object { $_.Installed } | Sort-Object DnsHostName

    foreach ($agent in $agents) {
        # Convert MB to GB
        $freeSpaceGB = [math]::Round($agent.FreeSpaceOnBackupDriveMB / 1024, 2)
        $freeSpaceFormatted = "{0:N2}" -f $freeSpaceGB

        # Check version
        if ($agent.Version -eq $semperisVersion) {
            $versionStatus = $agent.Version
        } else {
            $versionStatus = "$($agent.Version) :  <span class='custom-warning'></span> Please upgrade"
        }

        # Build row
        $htmlContent += "<tr>
            <td>$($agent.DnsHostName)</td>
            <td>$($agent.IPAddress)</td>
            <td>$($agent.OsProductName)</td>
            <td>$($agent.ADsite)</td>
            <td>$freeSpaceFormatted GB</td>
            <td>$($agent.BackupLocation)</td>
            <td>$versionStatus</td>
        </tr>"
    }

    $htmlContent += "</table>"
}
$htmlContent += "</div>"
# --- END SECTION - Domain Controllers Free Space ---

##################################
# --- START SECTION - Export Settings for the Last 7 Days ---
$htmlContent += "<button class='collapsible'> ⚙️ Export Settings - Last 7 Days</button><div class='content'>"
$htmlContent += "<table><tr><th>Forest Name</th>"

# Generate the last 7 days' headers
$days = @()
for ($i = 0; $i -lt 7; $i++) {
    $dayLabel = (Get-Date).AddDays(-$i).ToString("MMM dd")
    $htmlContent += "<th>$dayLabel</th>"
    $days += (Get-Date).AddDays(-$i).Date  # Store dates to compare later
}
$htmlContent += "</tr>"

# Iterate through each forest to get the proper configuration path
foreach ($forest in $forests) {
    if ($forest.IsRunning -eq $true) {
        $portationpath = "C:\ProgramData\Semperis\$($forest.ForestDnsName).$($forest.ForestID)\General\GeneralConfiguration.xml"
        
        if (Test-Path $portationpath) {
            try {
                [xml]$config = Get-Content $portationpath
                $exportSettingPath = $config.GeneralConfiguration.PortationFolder
                
                # Get the forest name for display
                $forestName = $forest.ForestDnsName
                
                # Check if Exports folder exists using the configuration path
                $exportsPath = Join-Path -Path $exportSettingPath -ChildPath "Exports"
                $htmlContent += "<tr><td>$forestName</td>"

                if (Test-Path $exportsPath) {
                    # Get all .zip files in the folder
                    $exports = Get-ChildItem -Path $exportsPath -Filter "*.zip" | Select-Object Name, CreationTime

                    # Loop through the last 7 days
                    foreach ($day in $days) {
                        $foundExport = $exports | Where-Object { $_.CreationTime.Date -eq $day }
                        if ($foundExport) {
                            $htmlContent += "<td class='ok'><span class='custom-check'></span>Ok</td>"
                        } else {
                            $htmlContent += "<td class='ko'><span class='custom-fail'></span> No Export</td>"
                        }
                    }
                } else {
                    # If Exports folder doesn't exist, mark all 7 days as failed
                    for ($i = 0; $i -lt 7; $i++) {
                        $htmlContent += "<td class='ko'><span class='custom-fail'></span> No Export</td>"
                    }
                }
            } catch {
                # If error reading config, mark all 7 days as error
                for ($i = 0; $i -lt 7; $i++) {
                    $htmlContent += "<td class='ko'><span class='custom-fail'></span> Config Error</td>"
                }
            }
        } else {
            # If config file not found, mark all 7 days as error
            for ($i = 0; $i -lt 7; $i++) {
                $htmlContent += "<td class='ko'><span class='custom-fail'></span> Config Not Found</td>"
            }
        }
    } else {
        # If forest not running, mark all 7 days as warning
        for ($i = 0; $i -lt 7; $i++) {
            $htmlContent += "<td class='ko'><span class='blinking-icon'><span class='custom-warning'></span>Forest Not Running</span></td>"
        }
    }

    $htmlContent += "</tr>"
}
$htmlContent += "</table></div>"

# --- END SECTION - Export Settings for the Last 7 Days ---


##################################
# --- START SECTION : ADFR Services Status Check ---
$htmlContent += "<button class='collapsible'>📋 ADFR Registry Checks</button><div class='content'>"
# Get all forest registry keys, excluding "Upgrade"
$multiForestPath = "HKLM:\SOFTWARE\Semperis\MultiForest"
$forestRegistryKeys = Get-ChildItem -Path $multiForestPath | Where-Object { $_.PSChildName -ne "Upgrade" }

# Get global LogLevel (should be same for all forests)
$logLevelKey = "HKLM:\SOFTWARE\Semperis"
$logLevel = (Get-ItemProperty -Path $logLevelKey -Name LogLevel -ErrorAction SilentlyContinue).LogLevel
if (-not $logLevel) { $logLevel = "N/A" }

foreach ($key in $forestRegistryKeys) {
    $forestFullName = $key.PSChildName
    $forestName = $forestFullName -replace '^.+?\.', ''
    $serverPath = "HKLM:\SOFTWARE\Semperis\MultiForest\$forestFullName\Semperis\ADFR\Server"
    $OLRSettings = "$serverPath\BackupIndexing"
    $excludedPartitionsPath = "$serverPath\ExcludedPartitions"

    # Check if OLR module is enabled for this forest (Module ID 1458)
    # Registry format: {GUID}.{ForestDnsName} -> Folder format: {ForestDnsName}.{GUID}
    $hasOLR = $false
    if ($forestFullName -match '^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\.(.+)$') {
        $guid = $matches[1]
        $dnsName = $matches[2]
        $folderName = "$dnsName.$guid"
        $licensePath = "C:\ProgramData\Semperis\$folderName\General\License.lic"
        if (Test-Path $licensePath) {
            try {
                [xml]$licenseXml = Get-Content $licensePath -ErrorAction Stop
                $modules = $licenseXml.License.Modules.Module | ForEach-Object { $_.Id }
                if ($modules -contains "1458") {
                    $hasOLR = $true
                }
            } catch {
                $hasOLR = $false
            }
        }
    }

    # Read values
    $gcLevel = (Get-ItemProperty -Path $serverPath -Name GcPartitionOccupancyLevel -ErrorAction SilentlyContinue).GcPartitionOccupancyLevel
    if (-not $gcLevel) { $gcLevel = "NA" }

    $skipGC = (Get-ItemProperty -Path $serverPath -Name SkipGCRebuild -ErrorAction SilentlyContinue).SkipGCRebuild
    if ($null -eq $skipGC) { $skipGC = "NA" }

    $timeout = (Get-ItemProperty -Path $serverPath -Name OperationTimeoutSeconds -ErrorAction SilentlyContinue).OperationTimeoutSeconds
    if (-not $timeout) { $timeout = "NA" }

    $waitMins = (Get-ItemProperty -Path $serverPath -Name MaxWaitForGcRebuildMins -ErrorAction SilentlyContinue).MaxWaitForGcRebuildMins
    if (-not $waitMins) { $waitMins = "NA" }

    $excludeRodc = (Get-ItemProperty -Path $serverPath -Name ExcludeRodc -ErrorAction SilentlyContinue).ExcludeRodc
    if (-not $excludeRodc) { $excludeRodc = "NA" }
    
    # OLR Checks (only if OLR is licensed)
    if ($hasOLR) {
        $saveBatchSize = (Get-ItemProperty -Path $OLRSettings -Name "SaveBatchSize" -ErrorAction SilentlyContinue).SaveBatchSize
        if (-not $saveBatchSize) { $saveBatchSize = "NA" }

        $ProcessBatchSize = (Get-ItemProperty -Path $OLRSettings -Name "ProcessBatchSize" -ErrorAction SilentlyContinue).ProcessBatchSize
        if (-not $ProcessBatchSize) { $ProcessBatchSize = "NA" }

        $LdapPageSize = (Get-ItemProperty -Path $OLRSettings -Name "LdapPageSize" -ErrorAction SilentlyContinue).LdapPageSize
        if (-not $LdapPageSize) { $LdapPageSize = "NA" }
    }

    # ExcludedPartitions check
    $excludedPartitions = @("Not Configured")
    if (Test-Path $excludedPartitionsPath) {
        $excludedProps = Get-ItemProperty -Path $excludedPartitionsPath
        $partitionKeys = @()
        foreach ($name in $excludedProps.PSObject.Properties.Name) {
            if ($excludedProps.$name -eq 1) {
                $partitionKeys += $name
            }
        }
        if ($partitionKeys.Count -gt 0) {
            $excludedPartitions = $partitionKeys -join "<br>"
        } else {
            $excludedPartitions = "None"
        }
    }

    # Start table for this forest
    $htmlContent += "<h3 class='forest-badge'>Forest: $forestName</h3>"
    $htmlContent += "<table><tr>
    <th>GC Occupancy</th>
    <th>Skip GC Rebuild</th>
    <th>LogLevel</th>
    <th>OperationTimeoutSeconds</th>
    <th>MaxWaitForGcRebuildMins</th>
    <th>ExcludeRodc</th>
    <th>Excluded Partitions</th>"
    if ($hasOLR) {
        $htmlContent += "
    <th>OLR SaveBatchSize</th>
    <th>OLR ProcessBatchSize</th>
    <th>OLR LdapPageSize</th>"
    }
    $htmlContent += "
    </tr>"
    $htmlContent += "<tr>
    <td>$gcLevel</td>
    <td>$skipGC</td>
    <td>$logLevel</td>
    <td>$timeout</td>
    <td>$waitMins</td>
    <td>$excludeRodc</td>
    <td>$excludedPartitions</td>"
    if ($hasOLR) {
        $htmlContent += "
    <td>$saveBatchSize</td>
    <td>$ProcessBatchSize</td>
    <td>$LdapPageSize</td>"
    }
    $htmlContent += "
    </tr>"
    $htmlContent += "</table>"
}
$htmlContent += "</div>"
# --- END START SECTION : ADFR Services Status Check ---
# --- START SECTION : OLR Indexing table ---
# Collect forests with OLR enabled
$forestsWithOLR = @()
foreach ($forest in $forests) {
    $licensePath = "C:\ProgramData\Semperis\$($forest.ForestDnsName).$($forest.ForestID)\General\License.lic"
    if (Test-Path $licensePath) {
        try {
            [xml]$licenseXml = Get-Content $licensePath -ErrorAction Stop
            $modules = $licenseXml.License.Modules.Module | ForEach-Object { $_.Id }
            if ($modules -contains "1458") {
                $forestsWithOLR += @{
                    ForestName = $forest.ForestDnsName
                    ForestID = $forest.ForestID
                }
            }
        } catch {
            # Skip if license cannot be read
        }
    }
}

# Only show section if at least one forest has OLR
if ($forestsWithOLR.Count -gt 0) {
    $htmlContent += "<button class='collapsible'>🔍 OLR Indexing Status</button><div class='content'>"
    
    foreach ($olrForest in $forestsWithOLR) {
        # Get database size for this forest
        $olrDatabase = "Smprs_Cm_Data.$($olrForest.ForestName).$($olrForest.ForestID)"
        $dbSizeQuery = "SELECT SUM(size) * 8 / 1024 AS TotalSizeMB FROM sys.database_files;"
        $dbSizeText = "N/A"
        try {
            $dbSizeConnectionString = "Server=localhost\SMPRS;Database=$olrDatabase;Integrated Security=True;TrustServerCertificate=True;"
            $dbSizeResult = Invoke-Sqlcmd -ConnectionString $dbSizeConnectionString -Query $dbSizeQuery -ErrorAction Stop
            if ($dbSizeResult -and $dbSizeResult.TotalSizeMB) {
                $sizeMB = $dbSizeResult.TotalSizeMB
                if ($sizeMB -ge 1024) {
                    $sizeGB = [math]::Round($sizeMB / 1024, 2)
                    $dbSizeText = "$sizeGB GB"
                } else {
                    $dbSizeText = "$sizeMB MB"
                }
            }
        } catch {
            $dbSizeText = "N/A"
        }
        
        $htmlContent += "<div class='forest-badge'>Forest: $($olrForest.ForestName) <span style='margin-left: 15px; color: #20c997;'>| 💾 DB Size: $dbSizeText</span></div>"
        $htmlContent += "<table><tr>
            <th>Domain FQDN</th>
            <th>Domain Controller FQDN</th>
            <th>Dc Session Tag</th>
            <th>Start Date</th>
            <th>End Date</th>
            <th>Object Count</th>
            <th>Elapsed (min)</th>
            <th>Status</th>
        </tr>"
        
        # OLR Indexing SQL Query
        $olrDatabase = "Smprs_Cm_Data.$($olrForest.ForestName).$($olrForest.ForestID)"
        $olrQuery = @"
Declare @formatNumber char(12) = '###,###,##0' ;
Declare @formatDate char(24) = 'yyyy-MM-dd HH:mm:ss' ;

Select dc.DomainFQDN
  ,dc.DomainControllerFQDN
  ,si.DcSessionTag
  ,Case when (si.StartDateTime is not null) then Format(si.StartDateTime, @formatDate) End as StartDate
  ,Case when (si.EndDateTime is not null) then Format(si.EndDateTime, @formatDate) End as EndDate
  ,Format(Count(bs.DcSessionTag), @formatNumber) as ObjectCount
  ,(
   case when si.Status in (2,4) 
   then (DateDiff(minute, si.StartDateTime, si.EndDateTime) ) 
   else (DateDiff(minute, si.StartDateTime, GetUtcDate())) End
  ) as 'Elapsed (min)'
  ,(
   case 
    when si.Status = 0 then 'Indexing not required' 
    when si.Status = 1 then 'Ready for Indexing' 
    when si.Status = 2 then 'Indexed' 
    when si.Status = 3 then 'Indexing in progress' 
    when si.Status = 4 then 'Error' 
   end
  ) as Status
From [tblAdfrBackupDcSessionIndexingInfo] as si
Inner Join tblAdfrBackupDCSessions as dc on dc.DCSessionTag = si.DcSessionTag
Inner Join tblAdfrBackupDcSessionToAdObjectState as bs on bs.DcSessionTag = si.DcSessionTag
Group By si.status, si.StartDateTime, si.EndDateTime, si.DcSessionTag ,dc.DomainFQDN, dc.DomainControllerFQDN
"@
        
        try {
            $olrConnectionString = "Server=localhost\SMPRS;Database=$olrDatabase;Integrated Security=True;TrustServerCertificate=True;"
            $olrResults = Invoke-Sqlcmd -ConnectionString $olrConnectionString -Query $olrQuery -ErrorAction Stop
            
            if ($olrResults) {
                foreach ($row in $olrResults) {
                    # Determine status class
                    $statusClass = switch ($row.Status) {
                        'Indexed' { 'ok' }
                        'Error' { 'ko' }
                        'Indexing in progress' { 'warning' }
                        default { '' }
                    }
                    
                    $htmlContent += "<tr>
                        <td>$($row.DomainFQDN)</td>
                        <td>$($row.DomainControllerFQDN)</td>
                        <td>$($row.DcSessionTag)</td>
                        <td>$($row.StartDate)</td>
                        <td>$($row.EndDate)</td>
                        <td>$($row.ObjectCount)</td>
                        <td>$($row.'Elapsed (min)')</td>
                        <td class='$statusClass'>$($row.Status)</td>
                    </tr>"
                }
            } else {
                $htmlContent += "<tr><td colspan='8' class='warning'><span class='custom-warning'></span> No OLR indexing data found</td></tr>"
            }
        } catch {
            $htmlContent += "<tr><td colspan='8' class='ko'><span class='custom-fail'></span> Error querying OLR database: $($_.Exception.Message)</td></tr>"
        }
        
        $htmlContent += "</table>"
    }
    
    $htmlContent += "</div>"
}
# --- END SECTION : OLR Indexing table ---
######################
# --- START SECTION : Semperis Services Status Check ---
$htmlContent += "<button class='collapsible'>🛠️ Semperis Services Status</button><div class='content'>"
$htmlContent += "<table><tr><th>Service Category</th><th>Status</th></tr>"

# Get all Semperis services
$allServices = Get-Service | Where-Object { $_.DisplayName -match "Semperis" }

# Separate services into global ADFR and per-forest
$globalADFRServices = $allServices | Where-Object { $_.DisplayName -notmatch "\(.*\)" }
$forestADFRServices = $allServices | Where-Object { $_.DisplayName -match "\(.*\)" }

# --- Check Global ADFR Services ---
$stoppedGlobal = $globalADFRServices | Where-Object { $_.Status -ne "Running" }
if ($stoppedGlobal) {
    $stoppedList = ($stoppedGlobal | ForEach-Object { $_.DisplayName }) -join ", "
    $htmlContent += "<tr><td>ADFR Services</td><td class='ko'><span class='custom-fail'></span> KO - Not Running: $stoppedList</td></tr>"
} else {
    $htmlContent += "<tr><td>ADFR Services</td><td class='ok'><span class='custom-check'></span>Ok</td></tr>"
}

# --- Extract Unique Forest Names ---
$forestNames = $forestADFRServices | ForEach-Object {
    if ($_.DisplayName -match "\(.*\)") { $matches[0] }
} | Select-Object -Unique

# --- Check Per-Forest ADFR Services ---
foreach ($forest in $forestNames) {
    # Get services for this specific forest
    $forestServices = $forestADFRServices | Where-Object { $_.DisplayName -match [regex]::Escape($forest) }
    $stoppedForestServices = $forestServices | Where-Object { $_.Status -ne "Running" }

    if ($stoppedForestServices) {
        $stoppedList = ($stoppedForestServices | ForEach-Object { $_.DisplayName }) -join ", "
        $htmlContent += "<tr><td>ADFR Services - $forest</td><td class='ko'><span class='custom-fail'></span> KO - Not Running: $stoppedList</td></tr>"
    } else {
        $htmlContent += "<tr><td>ADFR Services - $forest</td><td class='ok'><span class='custom-check'></span>Ok</td></tr>"
    }
}

$htmlContent += "</table></div>"
# --- END SECTION : ADFR Services Status Check ---

# --- START SECTION : Forest Recovery Requirements Check ---
$htmlContent += "<button class='collapsible'> 🌲 Forest Recovery DC Requirements</button><div class='content'>"

foreach ($forest in $forests) {
    try {
        Write-Host "Analyzing forest: $($forest.ForestDnsName)" -ForegroundColor Cyan
        
        # Select the forest context
        $null = Select-ADFRForest $forest.ForestDnsName
        
        # Get the latest valid successful backup
        $lastBackup = Get-ADFRBackupJob |
            Where-Object {
                $_.Status -eq 'Success' -and
                $_.ValidationStatus -eq 'Valid'
            } |
            Sort-Object EndDateTime |
            Select-Object -Last 1
        
        if (-not $lastBackup) {
            $htmlContent += "<div class='forest-badge'>Forest: $($forest.ForestDnsName) - No Valid Backup</div>"
            $htmlContent += "<p class='warning'><span class='custom-warning'></span> No valid successful backup found for $($forest.ForestDnsName)</p>"
            continue
        }
        
        # Store the RuleSessionTag (GUID)
        $backupGuid = $lastBackup.RuleSessionTag

        
        # Create temporary directory for XML output in the same location as the report
        $reportDirectory = Split-Path $outputFile -Parent
        $tempPath = Join-Path $reportDirectory "ADFR_Recovery_Temp_$backupGuid"
        if (-not (Test-Path $tempPath)) {
            New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
        }
        
        # Generate JSON file using Get-ADFRBackupSettings
        try {
            Get-ADFRBackupJob -BackupTag $backupGuid | Get-ADFRBackupSettings -MSOutputFilePath $tempPath
            
            # Find the generated JSON file
            $jsonFile = Get-ChildItem -Path $tempPath -Filter "Config_*.json" -File | Select-Object -First 1
            
            if (-not $jsonFile) {
                throw "No Config JSON file found in $tempPath"
            }
            
       
            $jsonContent = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            
            # Extract DC list
            $dcList = $jsonContent.forestData.dcList
            
            if ($dcList.Count -eq 0) {
                $htmlContent += "<div class='forest-badge'>Forest: $($forest.ForestDnsName)</div>"
                $htmlContent += "<p class='warning'><span class='custom-warning'></span> No DCs found in backup</p>"
            } else {
                # Calculate maximum number of disks across all DCs
                $maxDisks = ($dcList | ForEach-Object { $_.provisioningData.diskLayouts.Count } | Measure-Object -Maximum).Maximum
                
                # Build CSV data for download
                $csvHeaders = @("DC Name", "Domain", "Site", "OS", "Core/GUI", "IP Address")
                for ($i = 1; $i -le $maxDisks; $i++) {
                    $csvHeaders += "Disk $i"
                    $csvHeaders += "Size (GB)"
                }
                $csvRows = @()
                $csvRows += $csvHeaders -join ","
                
                foreach ($dc in $dcList) {
                    $provData = $dc.provisioningData
                    $osType = if ($provData.osInfo.installationType -eq "Server Core") { "Core" } else { "GUI" }
                    $diskLayouts = $provData.diskLayouts
                    
                    $rowData = @(
                        "`"$($provData.hostname)`"",
                        "`"$($provData.domain)`"",
                        "`"$($provData.site)`"",
                        "`"$($provData.osInfo.productName)`"",
                        "`"$osType`"",
                        "`"$($provData.originalIPSettings.ipAddress)`""
                    )
                    
                    for ($i = 0; $i -lt $maxDisks; $i++) {
                        if ($i -lt $diskLayouts.Count) {
                            $disk = $diskLayouts[$i]
                            $driveLetter = $disk.driveName -replace '\\', ''
                            $sizeGB = [math]::Round($disk.totalSizeMB / 1024, 2)
                            $rowData += "`"$driveLetter`""
                            $rowData += "`"$sizeGB`""
                        } else {
                            $rowData += "`"-`""
                            $rowData += "`"-`""
                        }
                    }
                    $csvRows += $rowData -join ","
                }
                
                # Encode CSV data as base64 to avoid quote issues
                $csvDataRaw = $csvRows -join "`r`n"
                $csvBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($csvDataRaw))
                $safeForestName = $forest.ForestDnsName -replace "[^a-zA-Z0-9]", "_"
                
                # Build HTML table with download button
                $htmlContent += "<div class='forest-badge'>Forest: $($forest.ForestDnsName) - Recovery Requirements ($($dcList.Count) DCs) <span style='margin-left: 15px;'><a href='#' onclick=`"downloadRecoveryCSV('$safeForestName', '$csvBase64'); return false;`" style='color: #20c997; text-decoration: none; font-size: 13px;'>📥 Download CSV</a></span></div>"
                $htmlContent += "<table><tr>"
                $htmlContent += "<th>DC Name</th><th>Domain</th><th>Site</th><th>OS</th><th>Core/GUI</th><th>IP Address</th>"
                
                # Add disk columns dynamically
                for ($i = 1; $i -le $maxDisks; $i++) {
                    $htmlContent += "<th>Disk $i</th><th>Size (GB)</th>"
                }
                $htmlContent += "</tr>"
                
                # Build rows for each DC
                foreach ($dc in $dcList) {
                    $provData = $dc.provisioningData
                    $osType = if ($provData.osInfo.installationType -eq "Server Core") { "Core" } else { "GUI" }
                    $diskLayouts = $provData.diskLayouts
                    
                    $htmlContent += "<tr>"
                    $htmlContent += "<td>$($provData.hostname)</td>"
                    $htmlContent += "<td>$($provData.domain)</td>"
                    $htmlContent += "<td>$($provData.site)</td>"
                    $htmlContent += "<td>$($provData.osInfo.productName)</td>"
                    $htmlContent += "<td>$osType</td>"
                    $htmlContent += "<td>$($provData.originalIPSettings.ipAddress)</td>"
                    
                    # Add disk information
                    for ($i = 0; $i -lt $maxDisks; $i++) {
                        if ($i -lt $diskLayouts.Count) {
                            $disk = $diskLayouts[$i]
                            $driveLetter = $disk.driveName -replace '\\', ''
                            $sizeGB = [math]::Round($disk.totalSizeMB / 1024, 2)
                            $htmlContent += "<td>$driveLetter</td><td>$sizeGB</td>"
                        } else {
                            $htmlContent += "<td>-</td><td>-</td>"
                        }
                    }
                    $htmlContent += "</tr>"
                }
                
                $htmlContent += "</table>"
            }
            
            # Clean up temporary files
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            
        } catch {
            Write-Warning "  Failed to generate backup settings: $($_.Exception.Message)"
            $htmlContent += "<div class='forest-badge'>Forest: $($forest.ForestDnsName) - Export Failed</div>"
            $htmlContent += "<p class='ko'><span class='custom-fail'></span> Failed to export backup settings: $($_.Exception.Message)</p>"
            
            # Clean up on error too
            if (Test-Path $tempPath) {
                Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            continue
        }
        
    } catch {
        Write-Error "Error processing forest $($forest.ForestDnsName): $($_.Exception.Message)"
        $htmlContent += "<div class='forest-badge'>Forest: $($forest.ForestDnsName) - Processing Error</div>"
        $htmlContent += "<p class='ko'><span class='custom-fail'></span> Error: $($_.Exception.Message)</p>"
    }
}

$htmlContent += "</div>"
# --- END SECTION : Forest Recovery Requirements Check ---
# Close the main container div
$htmlContent += "</div>"

# Add Floating Issues Bubble HTML
$htmlContent += @"
<div id="issuesBubble" class="issues-bubble">
    <button class="bubble-btn">⚠<span id="bubbleCount" class="bubble-count">0</span></button>
    <div id="issuesPanel" class="issues-panel">
        <div class="panel-header"><h4>Issues Summary</h4><button id="panelClose" class="panel-close">&times;</button></div>
        <div class="panel-stats">
            <div class="stat-item warnings"><div class="stat-icon warning-icon">⚠</div><span id="warningCount">0</span> Warnings</div>
            <div class="stat-item errors"><div class="stat-icon error-icon">✗</div><span id="errorCount">0</span> Errors</div>
        </div>
        <div id="panelBody" class="panel-body"></div>
    </div>
</div>
"@

#--- End of BODY Script
$htmlContent += "</body></html>"
$htmlContent | Out-File -FilePath $outputFile -Encoding UTF8

# --- PDF GENERATION LOGIC --

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
        foreach ($forest in $forests) {
            $forestList += "- $($forest.ForestDnsName)`n"
        }
        
        # Create plain text email body (customize this message as needed)
        $emailBody = @"
Hello,

Please find attached the ADFR Health-Check Report generated on $(Get-Date -Format 'yyyy-MM-dd') at $(Get-Date -Format 'HH:mm').

Protected Forests:
$forestList
This automated report provides a comprehensive overview of your Active Directory Forest Recovery environment, including:
- Management Server status and configuration
- Forest and domain health checks
- Backup job status and validation
- Service status monitoring
- Forest recovery requirements

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

Write-Host "Thank you for using the ADFR Health-Check Report on your ADFR MS !"  -ForegroundColor Green
Write-Host "For any support Assistance contact, bryano@semperis.com"  -ForegroundColor Green