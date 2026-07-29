#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Compares ARPL assessor configuration between LOCAL and ONLINE servers
    
.DESCRIPTION
    Fetches diagnostic data from both servers and shows what's different
    
.EXAMPLE
    .\compare_servers.ps1
#>

# Configuration
$localUrl = "http://192.168.0.57:8080/assessorReport2/mobile/compare_local_vs_online.php"
$onlineUrl = "https://rlms.rlmss.co.za/mobile/compare_local_vs_online.php"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "ARPL ASSESSOR - LOCAL vs ONLINE SERVER COMPARISON" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Helper function to format JSON nicely
function Format-Comparison {
    param(
        [object]$localData,
        [object]$onlineData,
        [string]$section
    )
    
    Write-Host "[$section]" -ForegroundColor Yellow
    Write-Host ""
    
    # Get the local value
    $localValue = $localData.$section
    $onlineValue = $onlineData.$section
    
    if ($null -eq $localValue) {
        Write-Host "LOCAL:  (not found)" -ForegroundColor Red
    } else {
        Write-Host "LOCAL:  $(ConvertTo-Json $localValue -Depth 3)" -ForegroundColor Green
    }
    
    Write-Host ""
    
    if ($null -eq $onlineValue) {
        Write-Host "ONLINE: (not found)" -ForegroundColor Red
    } else {
        Write-Host "ONLINE: $(ConvertTo-Json $onlineValue -Depth 3)" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # Check if they match
    if ($(ConvertTo-Json $localValue) -eq $(ConvertTo-Json $onlineValue)) {
        Write-Host "[MATCH]" -ForegroundColor Green
    } else {
        Write-Host "[DIFFERENT]" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "---" -ForegroundColor Gray
    Write-Host ""
}

# Fetch data from LOCAL server
Write-Host "Fetching data from LOCAL server: $localUrl" -ForegroundColor Cyan
try {
    $localResponse = Invoke-WebRequest -Uri $localUrl -ErrorAction Stop
    $localData = $localResponse.Content | ConvertFrom-Json
    Write-Host "[OK] LOCAL server response received" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] fetching LOCAL server: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host ""

# Fetch data from ONLINE server
Write-Host "Fetching data from ONLINE server: $onlineUrl" -ForegroundColor Cyan
try {
    $onlineResponse = Invoke-WebRequest -Uri $onlineUrl -ErrorAction Stop
    $onlineData = $onlineResponse.Content | ConvertFrom-Json
    Write-Host "[OK] ONLINE server response received" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] fetching ONLINE server: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "DETAILED COMPARISON" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Connection Info
Format-Comparison $localData $onlineData "connection_info"

# 2. Facilitator Check
Format-Comparison $localData $onlineData "facilitator_check"

# 3. Role Detection
Format-Comparison $localData $onlineData "role_detection"

# 4. Get Classes Check
Format-Comparison $localData $onlineData "get_classes_check"

# 5. Pathway Detection
Format-Comparison $localData $onlineData "pathway_detection"

# 6. Critical Issues
Write-Host "[CRITICAL ISSUES]" -ForegroundColor Yellow
Write-Host ""

$localIssues = $localData.critical_issues
$onlineIssues = $onlineData.critical_issues

if ($localIssues.Count -eq 0) {
    Write-Host "LOCAL:  [OK] No issues found" -ForegroundColor Green
} else {
    Write-Host "LOCAL:  [ERROR] Issues found:" -ForegroundColor Red
    foreach ($issue in $localIssues) {
        Write-Host "  - $($issue.issue): $($issue.solution)" -ForegroundColor Red
    }
}

Write-Host ""

if ($onlineIssues.Count -eq 0) {
    Write-Host "ONLINE: [OK] No issues found" -ForegroundColor Green
} else {
    Write-Host "ONLINE: [ERROR] Issues found:" -ForegroundColor Red
    foreach ($issue in $onlineIssues) {
        Write-Host "  - $($issue.issue): $($issue.solution)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Summary table
$summaryTable = @(
    @{
        Check = "Facilitator Found"
        Local = $localData.facilitator_check.found
        Online = $onlineData.facilitator_check.found
    },
    @{
        Check = "Role Detected as ARPL"
        Local = $($localData.role_detection.detected_role -eq 'arpl_assessor')
        Online = $($onlineData.role_detection.detected_role -eq 'arpl_assessor')
    },
    @{
        Check = "Project_pathway Column"
        Local = $localData.get_classes_check.all_columns_present.Project_pathway
        Online = $onlineData.get_classes_check.all_columns_present.Project_pathway
    },
    @{
        Check = "Pathway Detects as ARPL"
        Local = $localData.pathway_detection.will_detect_as_arpl
        Online = $onlineData.pathway_detection.will_detect_as_arpl
    },
    @{
        Check = "No Critical Issues"
        Local = ($localData.critical_issues.Count -eq 0)
        Online = ($onlineData.critical_issues.Count -eq 0)
    }
)

$summaryTable | Format-Table -AutoSize @{
    Label = "Check"
    Expression = {$_.Check}
    Width = 30
}, @{
    Label = "Local"
    Expression = {if ($_.Local) { "YES" } else { "NO" }}
    Width = 8
    Alignment = "Center"
}, @{
    Label = "Online"
    Expression = {if ($_.Online) { "YES" } else { "NO" }}
    Width = 8
    Alignment = "Center"
} | Out-Host

Write-Host ""

# Specific differences
Write-Host "DIFFERENCES FOUND:" -ForegroundColor Yellow
Write-Host ""

$differences = @()

# Compare facilitator
if ($localData.facilitator_check.role_lowercase -ne $onlineData.facilitator_check.role_lowercase) {
    $differences += @{
        Item = "Facilitator Role"
        Local = $localData.facilitator_check.role_lowercase
        Online = $onlineData.facilitator_check.role_lowercase
    }
}

# Compare role detection
if ($localData.role_detection.detected_role -ne $onlineData.role_detection.detected_role) {
    $differences += @{
        Item = "Detected Role"
        Local = $localData.role_detection.detected_role
        Online = $onlineData.role_detection.detected_role
    }
}

# Compare pathway detection
if ($localData.pathway_detection.will_detect_as_arpl -ne $onlineData.pathway_detection.will_detect_as_arpl) {
    $differences += @{
        Item = "Pathway Detected as ARPL"
        Local = $localData.pathway_detection.will_detect_as_arpl
        Online = $onlineData.pathway_detection.will_detect_as_arpl
    }
}

if ($differences.Count -eq 0) {
    Write-Host "[OK] All checks match between LOCAL and ONLINE servers!" -ForegroundColor Green
    Write-Host ""
    Write-Host "If ARPL menu still doesn't appear online, the issue might be:" -ForegroundColor Yellow
    Write-Host "  1. Old APK version on device (rebuild and reinstall)" -ForegroundColor Yellow
    Write-Host "  2. App cache (clear with: adb shell pm clear com.example.rlmss)" -ForegroundColor Yellow
    Write-Host "  3. Different online server configuration not captured here" -ForegroundColor Yellow
} else {
    Write-Host "[ERROR] Differences found:" -ForegroundColor Red
    $differences | Format-Table -AutoSize @{
        Label = "Item"
        Expression = {$_.Item}
    }, @{
        Label = "Local"
        Expression = {$_.Local}
    }, @{
        Label = "Online"
        Expression = {$_.Online}
    } | Out-Host
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "END OF COMPARISON" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
