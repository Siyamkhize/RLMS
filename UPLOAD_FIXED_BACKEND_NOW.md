# 🔧 UPLOAD FIXED BACKEND - CONNECTION PATH FIX

**Date:** July 23, 2026  
**Issue:** Blank screen caused by wrong connection.php path  
**Fix:** Changed `require_once __DIR__ . '/../connection.php'` to `require_once 'connection.php'`

---

## 🚨 CRITICAL FIX

### Problem Identified:
- Backend was looking for `connection.php` in **parent directory** (`/public_html/`)
- But `connection.php` exists in **mobile directory** (`/public_html/mobile/`)
- This caused PHP fatal error, which prevented JSON from being returned
- App received error HTML instead of JSON, causing blank screen

### Solution:
Changed include path to match working reference file `get_class_trade_info.php`:
```php
// OLD (WRONG):
require_once __DIR__ . '/../connection.php';

// NEW (CORRECT):
require_once 'connection.php';
```

---

## 📤 UPLOAD INSTRUCTIONS

### File to Upload:
**Local Path:** `c:\projects\rlmss\mobile\get_arpl_hierarchy.php`  
**Server Path:** `/public_html/mobile/get_arpl_hierarchy.php`

### Upload Steps:

1. **Via FileZilla/FTP:**
   - Connect to server: `rlms.rlms.co.za`
   - Navigate to `/public_html/mobile/`
   - Upload `get_arpl_hierarchy.php` (overwrite existing)

2. **Via cPanel File Manager:**
   - Login to cPanel
   - Open File Manager
   - Navigate to `public_html/mobile/`
   - Click "Upload" button
   - Select `mobile/get_arpl_hierarchy.php` from local machine
   - Confirm overwrite

3. **Via Terminal/SSH:**
   ```bash
   # From local project root
   scp mobile/get_arpl_hierarchy.php user@rlms.rlms.co.za:/home/rlmsrlmsco/public_html/mobile/
   ```

---

## ✅ VERIFICATION

### Test Endpoint:
```
https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701
```

### Expected Response:
```json
{
    "pathways": {
        "ARPL": {
            "qualifications": {
                "Bricklayer": {
                    "theory_papers": {...},
                    "practical_papers": {...}
                }
            }
        }
    },
    "_debug": [...]
}
```

### Should NOT See:
- HTML error messages
- PHP warnings about missing connection.php
- "Failed to open stream" errors
- HTTP 500 errors

---

## 🔄 NEXT STEPS AFTER UPLOAD

1. **Test API Endpoint:**
   - Open test URL in browser
   - Verify valid JSON response
   - Check that trade name is "Bricklayer"

2. **Rebuild Flutter App:**
   ```cmd
   flutter clean
   flutter build apk --release
   ```

3. **Install on Device:**
   ```cmd
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```

4. **Test on Device:**
   - Login as ARPL Assessor (User ID: 6)
   - Click "Bricklaying" class (ID: 797)
   - Should see "Select Pathway" screen
   - Should NOT see blank gray screen

---

## 📋 WHAT WAS CHANGED

### Before:
```php
// Include connection from parent directory (production server structure)
// connection.php is in /public_html/, this file is in /public_html/mobile/
require_once __DIR__ . '/../connection.php';
```

### After:
```php
// Include connection from same directory (mobile folder)
require_once 'connection.php';
```

### Why This Works:
- Matches the pattern used in working file `get_class_trade_info.php`
- Server structure has `connection.php` in `/public_html/mobile/`
- Same directory include is simpler and more reliable

---

## 🐛 TROUBLESHOOTING

### If API Still Returns Error:

1. **Check file permissions:**
   ```bash
   chmod 644 /home/rlmsrlmsco/public_html/mobile/get_arpl_hierarchy.php
   ```

2. **Check connection.php exists:**
   ```bash
   ls -la /home/rlmsrlmsco/public_html/mobile/connection.php
   ```

3. **Check PHP error log:**
   - In cPanel, check Error Log
   - Look for any fatal errors related to get_arpl_hierarchy.php

4. **Test with diagnostic:**
   - Upload `diagnose_arpl_500_error.php` to mobile folder
   - Run: `https://rlms.rlms.co.za/mobile/diagnose_arpl_500_error.php`

### If Blank Screen Persists After Upload:

1. **Clear browser cache** (if testing in browser)
2. **Verify app is using correct URL** (check `lib/config.dart`)
3. **Check device logs:**
   ```cmd
   adb logcat -c
   adb logcat | findstr "ARPL 🔍 📡 📦 ✅ ❌"
   ```
4. **Check for app cache** - uninstall and reinstall app completely

---

## 📝 SUMMARY

**Root Cause:** Backend PHP file couldn't find connection.php because it was looking in the wrong directory

**Fix Applied:** Changed include path from `__DIR__ . '/../connection.php'` to `'connection.php'`

**Expected Result:** API will return valid JSON, app will display hierarchy instead of blank screen

**Status:** ✅ Backend fixed locally, **READY FOR UPLOAD**

---

## ⚡ QUICK UPLOAD COMMAND

If you have SCP access:
```bash
cd c:\projects\rlmss
scp mobile/get_arpl_hierarchy.php user@rlms.rlms.co.za:/home/rlmsrlmsco/public_html/mobile/
```

Then test immediately:
```
https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701
```

**Upload this file now, then proceed with rebuild and testing!** 🚀
