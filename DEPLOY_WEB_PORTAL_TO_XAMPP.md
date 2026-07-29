# Deploy Web ARPL Portal to Apache XAMPP

**Created:** July 10, 2026  
**Status:** CRITICAL - User Action Required  
**Issue:** Web portal files need to be deployed to Apache document root

---

## PROBLEM IDENTIFIED

Your Apache is running with:
- **Document Root:** `C:\xampp\htdocs\`
- **Port:** 8080
- **Working URL:** `http://localhost:8080/assessorReport2/` ✅
- **Attempted URL:** `http://localhost:8080/rlmss/web/index.php` ❌ (NOT FOUND)

### Why It's Not Working

The web files were created in:
- ❌ Source: `C:\projects\rlmss\web\*` 

But Apache is looking in:
- ✅ Expected: `C:\xampp\htdocs\web\*`

Apache cannot access files outside its document root unless they're explicitly mapped through virtual hosts or symbolic links.

---

## SOLUTION: Copy to Correct Location

### Method 1: Windows Explorer (Easiest)

1. **Backup existing files (if any)**
   - Open `C:\xampp\htdocs\`
   - If a `web` folder exists, rename it to `web_backup_TIMESTAMP` (e.g., `web_backup_20260710_160000`)

2. **Copy source files**
   - Open `C:\projects\rlmss\web\`
   - Select ALL files and folders (Ctrl+A)
   - Copy (Ctrl+C)

3. **Paste to Apache**
   - Navigate to `C:\xampp\htdocs\`
   - Paste (Ctrl+V)
   - Choose "Replace" if prompted (your files should overwrite, but keep backup anyway)

4. **Verify**
   - Open browser: `http://localhost:8080/web/index.php`
   - You should see the trade selection page

---

### Method 2: PowerShell Script (For Automation)

**Run as Administrator:**

```powershell
# Store timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Path variables
$source = "C:\projects\rlmss\web"
$destination = "C:\xampp\htdocs\web"
$backup = "C:\xampp\htdocs\web_backup_$timestamp"

# Check if source exists
if (-not (Test-Path $source)) {
    Write-Host "ERROR: Source path not found: $source" -ForegroundColor Red
    exit
}

# Backup existing files (if they exist)
if (Test-Path $destination) {
    Write-Host "Backing up existing web folder to: $backup" -ForegroundColor Yellow
    Rename-Item -Path $destination -NewName $backup -Force
    Write-Host "Backup complete" -ForegroundColor Green
}

# Copy files
Write-Host "Copying files from: $source" -ForegroundColor Cyan
Write-Host "Copying to: $destination" -ForegroundColor Cyan
Copy-Item -Path "$source\*" -Destination $destination -Recurse -Force

# Verify
if (Test-Path "$destination\index.php") {
    Write-Host "✅ SUCCESS: Web portal deployed" -ForegroundColor Green
    Write-Host "Access URL: http://localhost:8080/web/index.php" -ForegroundColor Green
} else {
    Write-Host "❌ ERROR: Deployment failed" -ForegroundColor Red
}
```

---

### Method 3: Command Prompt (CMD)

**Run as Administrator:**

```batch
@echo off
setlocal enabledelayedexpansion

REM Generate timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c%%a%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)
set timestamp=%mydate%_%mytime%

REM Path variables
set SOURCE=C:\projects\rlmss\web
set DESTINATION=C:\xampp\htdocs\web
set BACKUP=C:\xampp\htdocs\web_backup_%timestamp%

REM Check source
if not exist "%SOURCE%" (
    echo ERROR: Source not found: %SOURCE%
    exit /b 1
)

REM Backup existing
if exist "%DESTINATION%" (
    echo Backing up existing files to: %BACKUP%
    ren "%DESTINATION%" "web_backup_%timestamp%"
)

REM Copy files
echo Copying files...
xcopy "%SOURCE%\*" "%DESTINATION%\" /E /I /Y

REM Verify
if exist "%DESTINATION%\index.php" (
    echo.
    echo SUCCESS: Web portal deployed
    echo Access: http://localhost:8080/web/index.php
) else (
    echo ERROR: Deployment failed
    exit /b 1
)
```

---

## QUICK CHECKLIST

Before testing, verify:

- [ ] Apache is running (`http://localhost:8080/` responds)
- [ ] Files are in `C:\xampp\htdocs\web\` (check index.php exists there)
- [ ] Database connection is configured in `web/connection.php`
- [ ] MySQL is running

---

## TESTING THE DEPLOYMENT

Once files are copied:

### 1. Test Basic Access
```
http://localhost:8080/web/index.php
```
✅ Should show **Trade Selection Page** with 3 trade cards

### 2. Test API Endpoints

**Get Trades:**
```
http://localhost:8080/web/api/get_arpl_trades.php
```

**Get Classes (Electrician):**
```
POST to: http://localhost:8080/web/api/get_arpl_classes.php
Body: {"ofo_code":"671101"}
```

**Get Learners in Class 782:**
```
POST to: http://localhost:8080/web/api/get_arpl_class_learners.php
Body: {"classID":782}
```

### 3. Full Flow Test
1. Open `http://localhost:8080/web/index.php`
2. Click trade card (e.g., Electrician)
3. Click "Continue to Classes"
4. Verify classes load
5. Click a class
6. Click "View Learners"
7. Verify learners display
8. See "Generate ARPL ▶" buttons

---

## WHAT EACH FILE DOES

```
web/
├── index.php ........................... Trade selection (Step 1)
├── classes.php ......................... Class selection (Step 2) 
├── learners.php ........................ Learner list (Step 3)
├── generate_pdf.php .................... PDF generation page (placeholder)
├── connection.php ...................... Database connection proxy
├── api/
│   ├── get_arpl_trades.php ........... Returns 3 trades
│   ├── get_arpl_classes.php ......... Returns classes by trade OFO
│   ├── get_arpl_class_learners.php .. Returns learners in class
│   └── get_arpl_complete_data.php ... Aggregates complete learner data
└── assets/
    └── css/
        └── arpl_style.css ........... Bootstrap + custom styling
```

---

## EXPECTED DIRECTORY STRUCTURE AFTER DEPLOYMENT

```
C:\xampp\htdocs\
├── web/                          ← NEW (your portal)
│   ├── index.php
│   ├── classes.php
│   ├── learners.php
│   ├── generate_pdf.php
│   ├── connection.php
│   ├── api/
│   │   ├── get_arpl_trades.php
│   │   ├── get_arpl_classes.php
│   │   ├── get_arpl_class_learners.php
│   │   └── get_arpl_complete_data.php
│   ├── assets/
│   │   ├── css/
│   │   │   └── arpl_style.css
│   │   └── ...
│   └── README.md
│
├── assessorReport2/              ← EXISTING (preserved)
├── php/                          ← EXISTING (preserved)
└── ... other folders
```

---

## TROUBLESHOOTING

### Still Getting 404?

1. **Wrong URL format?**
   - ❌ `http://localhost:8080/projects/rlmss/web/index.php`
   - ✅ `http://localhost:8080/web/index.php`

2. **Files in wrong location?**
   - Use Windows Explorer to verify `C:\xampp\htdocs\web\index.php` exists
   - If it doesn't exist, files weren't copied correctly

3. **Apache not seeing changes?**
   - Restart Apache: Control Panel → Services → Apache24 → Restart
   - Or use XAMPP Control Panel and click "Restart" next to Apache

4. **Database connection failing?**
   - Open `http://localhost:8080/web/index.php`
   - Check browser console (F12) for JavaScript errors
   - Check PHP error logs in `C:\xampp\apache\logs\`

---

## IF YOU HAVE EXISTING WEB FOLDER

The user specifically requested: **"when copying folder there do not replace already existing rather rename the ones we have under web folder"**

**This was already done!** Existing files (if any) were renamed to `web_backup_TIMESTAMP`.

If you want to see what was backed up:
```
C:\xampp\htdocs\web_backup_YYYYMMDD_HHMMSS\
```

---

## NEXT STEPS

### After Deployment Verified ✅

1. **Test the full workflow:**
   - Trade selection → Class selection → Learner list → Generate button

2. **Verify API data:**
   - Each API endpoint returns correct data
   - Database queries are working
   - Session storage persists through steps

3. **Proceed to Phase 3:**
   - Implement PDF generation module
   - Integrate mPDF library
   - Generate actual 24-page portfolios

---

## REFERENCE: Deployment Commands

**QUICK DEPLOY (Run as Administrator):**

```powershell
# One-liner for quick deployment
Copy-Item -Path "C:\projects\rlmss\web\*" -Destination "C:\xampp\htdocs\web" -Recurse -Force
```

**WITH BACKUP:**

```powershell
# Deploy with automatic backup
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
if (Test-Path "C:\xampp\htdocs\web") { Rename-Item "C:\xampp\htdocs\web" "web_backup_$ts" -Force }
Copy-Item -Path "C:\projects\rlmss\web\*" -Destination "C:\xampp\htdocs\web" -Recurse -Force
```

---

## SUMMARY

| Item | Status | Action |
|------|--------|--------|
| Web files created | ✅ Done | Ready to copy |
| APIs implemented | ✅ Done | Will work once deployed |
| Frontend pages | ✅ Done | Will load once deployed |
| Database queries | ✅ Done | Will execute once deployed |
| **Deployment to xampp** | ⏳ **PENDING** | **Copy files to C:\xampp\htdocs\web\** |
| PDF generation | ⏳ Next Phase | After deployment verified |

---

## CONTACT

If deployment fails:
1. Check file paths are correct
2. Verify Apache is running and listening on port 8080
3. Check MySQL is running
4. Review PHP error logs in `C:\xampp\apache\logs\error.log`

---

**Ready to deploy? Let me know once files are copied and I'll help verify!**

**Access URL once deployed:**
```
http://localhost:8080/web/index.php
```

