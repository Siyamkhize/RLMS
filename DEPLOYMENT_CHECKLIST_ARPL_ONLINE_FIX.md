# ARPL Online Server Deployment Checklist

## Issue
When connecting to the ONLINE server, ARPL assessors see the normal assessor menu instead of the ARPL-specific menu.

**Root Cause:** Role detection in PHP login endpoint was failing due to case-sensitive string comparison.

---

## Files to Deploy to Online Server

### 1. PHP Login Endpoint
**File:** `mobile/login.php`  
**Location on server:** `/public_html/mobile/login.php`  
**What changed:** Lines 213-230 - Improved ARPL role detection logic

**Key Change:**
```php
// OLD (case-sensitive, fails on mixed case):
elseif (strpos($dbRole, 'arpl_assessor') !== false)

// NEW (flexible, works on any case variation):
if (strpos($dbRole, 'arpl') !== false && strpos($dbRole, 'assessor') !== false)
```

### 2. Root Get Classes Endpoint
**File:** `get_classes.php`  
**Location on server:** `/public_html/get_classes.php`  
**What changed:** Line 43 - Fixed missing SQL variable declaration

### 3. Mobile Get Classes Endpoint
**File:** `mobile/get_classes.php`  
**Location on server:** `/public_html/mobile/get_classes.php`  
**What changed:** Lines 12-30 - Explicit column selection to ensure Project_pathway is included

---

## APK Distribution

### New APK Ready
- **File:** `build/app/outputs/flutter-apk/app-release.apk`
- **Size:** 45.8 MB
- **Build Date:** July 14, 2026
- **Features:**
  - ✅ Fixed ARPL role detection from PHP
  - ✅ Enhanced debug logging
  - ✅ Optimized get_classes queries

### Installation on Devices
```bash
# Clear app cache
adb shell pm clear com.example.rlmss

# Uninstall old version
adb uninstall com.example.rlmss

# Install new version
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Testing Plan

### Step 1: Deploy PHP Files
1. Upload `mobile/login.php` to online server
2. Upload `get_classes.php` to online server
3. Upload `mobile/get_classes.php` to online server

### Step 2: Install New APK
1. Clear app cache and uninstall old APK
2. Install new APK on test device

### Step 3: Test ARPL Login
1. Open app
2. Configure to point to **ONLINE server**
3. Login with **facilitator ID: 6**
4. Expected result: ARPL Dashboard appears

### Step 4: Verify Menu Items
Drawer should contain:
- ✅ ARPL Dashboard
- ✅ Assigned Classes
- ✅ Candidate Preparation
- ✅ Evidence Collection
- ✅ Portfolio Review
- ✅ Assessor Review (D,E,F)
- ✅ Access Recommendation (H)
- ✅ Evidence Checklist
- ✅ Remedials
- ✅ View Complete Toolkit

### Step 5: Check Logs
```bash
adb logcat | grep "LOGIN.*Detected"
```

Expected output:
```
[LOGIN] Facilitator 6: DB role = 'arpl_Assessor', normalized = 'arpl_assessor'
[LOGIN] Detected ARPL Assessor role
```

---

## Configuration Notes

### App Config (No Changes Needed)
Current `lib/config.dart` settings:
- Local Dev: `192.168.0.57:8080`
- Online: `rlms.rlms.co.za` (when active)

### Database Verification
Facilitator 6 on ONLINE server:
- **Facilitator ID:** 6
- **Name:** Sithandazile Mbotho
- **Role:** `arpl_Assessor` (capital A - important!)
- **Class:** 797 ("class A")
- **Pathway:** ARPL - Bricklayer (NQF 4)

---

## Rollback Procedure

If issues occur after deployment:
1. **Revert PHP files:**
   - Restore previous versions of login.php and get_classes.php
   - No database changes, so no data recovery needed

2. **Reinstall Previous APK:**
   - Download and install the previous APK version
   - Full rollback - no data loss

3. **Contact Support:**
   - Provide device logs: `adb logcat | grep "LOGIN\|AssessorPage"`
   - Include facilitator ID and login error details

---

## Success Criteria

✅ ARPL assessor sees ARPL menu (not normal assessor menu)  
✅ Dashboard shows ARPL-specific options (Toolkit, Appendices)  
✅ Can access all ARPL workflow pages  
✅ Logs show "Detected ARPL Assessor role"  
✅ No errors when fetching classes or pathways  

---

## FAQ

**Q: Why does it work on local dev but not online?**  
A: The local dev database likely has roles stored in consistent format, while the online database has mixed case (`arpl_Assessor`). The new code handles both.

**Q: Will this affect regular assessors?**  
A: No. Only roles containing both 'arpl' AND 'assessor' are treated as ARPL Assessors.

**Q: Do I need to update the database?**  
A: No. The code fix is purely in the PHP login logic. No database changes required.

**Q: What about other ARPL trades (plumber, electrician)?**  
A: The fix applies to all ARPL trades. The role detection checks for 'arpl' + 'assessor' pattern.

**Q: Can I test before deploying?**  
A: Yes! The new APK can connect to local dev server (which works) or online server (which now will work after PHP fix).

---

## Timeline

- **PHP Deployment:** Immediate (no restart needed)
- **APK Distribution:** Same day (users install when ready)
- **Expected ARPL Menu Appearance:** After login with new APK + PHP deployed
- **Full Deployment:** 5-15 minutes per device

---

## Support

If the ARPL menu doesn't appear after deployment:

1. **Check logs first:**
   ```bash
   adb logcat -c
   adb logcat | grep -E "LOGIN|AssessorPage|Detected"
   ```

2. **Verify PHP is deployed:**
   - Access `/mobile/login.php` directly (test endpoint)
   - Check for error logs in PHP error_log

3. **Verify APK installed:**
   ```bash
   adb shell pm list packages | grep rlmss
   ```

4. **Try full reinstall:**
   ```bash
   adb shell pm clear com.example.rlmss
   adb uninstall com.example.rlmss
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

---

## Verification After Deployment

Create these verification scripts to run on online server:

### 1. Test Login Endpoint
```php
// Test: /mobile/test_login.php
$facilitator_id = 6;
$stmt = $conn->prepare("SELECT role FROM facilitator WHERE facilitator_id = ?");
$stmt->bind_param("i", $facilitator_id);
$stmt->execute();
$result = $stmt->get_result();
$row = $result->fetch_assoc();

$dbRole = strtolower(trim($row['role']));
echo json_encode([
    'facilitator_id' => $facilitator_id,
    'db_role' => $row['role'],
    'normalized' => $dbRole,
    'contains_arpl' => strpos($dbRole, 'arpl') !== false,
    'contains_assessor' => strpos($dbRole, 'assessor') !== false,
    'will_detect_as' => (strpos($dbRole, 'arpl') !== false && strpos($dbRole, 'assessor') !== false) ? 'arpl_assessor' : 'other'
]);
```

### 2. Test Get Classes Endpoint
```bash
curl "https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=6" | jq '.[0]'
```

Should include: `Project_pathway` field with ARPL JSON data

---

**Deployment Date:** July 14, 2026  
**Status:** Ready for Deployment  
**Risk Level:** Very Low  
**Estimated Time:** 10-15 minutes
