# ARPL ASSESSOR MENU FIX - COMPLETE ✅

**Date:** July 14, 2026  
**Status:** FIXED - APK REBUILT AND READY FOR INSTALLATION

---

## PROBLEM SUMMARY

Facilitator 6 with `arpl_Assessor` role was seeing the **regular assessor menu** instead of the **ARPL menu** on the ONLINE production server, even though:
- The ONLINE database has correct ARPL data
- The facilitator has the correct role
- The app worked correctly on LOCAL development server

---

## ROOT CAUSE IDENTIFIED

The issue was **NOT** a database problem or logic error. The real problem was:

### 1. **Old APK with Wrong Server Configuration**
- The installed APK was built BEFORE `lib/config.dart` was updated
- Old APK pointed to: `http://192.168.0.57:8080/assessorReport2/mobile` (LOCAL)
- New config points to: `https://rlms.rlms.co.za/mobile` (ONLINE)
- Since the server URL is compiled into the APK, the old APK continued fetching from LOCAL server

### 2. **Different Data on LOCAL vs ONLINE**
- **LOCAL database:** `Project_pathway = "Short Skills Programme"` (NOT ARPL)
- **ONLINE database:** `Project_pathway = "[{\"type\":\"ARPL\",\"name\":\"Bricklayer\"}]"` (ARPL)
- The app fetching from LOCAL would never see ARPL data

---

## FIXES APPLIED

### 1. Server Configuration ✅
**File:** `lib/config.dart`

Updated to point to ONLINE production server:
```dart
static const String serverHost = 'rlms.rlms.co.za';
static const int serverPort = 443;
static const String serverProtocol = 'https';
static const String basePath = '/mobile';
```

### 2. Pathway Detection Logic ✅
**File:** `lib/ArplAssessorPage.dart` (lines 62-95)

Enhanced to detect ARPL from multiple formats:
```dart
bool isARPL = pathway.contains('ARPL') ||
    pathway.contains('ELECTRICIAN') ||
    pathway.contains('BRICKLAYING') ||
    pathway.contains('BRICKLAYER') ||
    pathway.contains('PLUMBING') ||
    pathway.contains('PLUMBER') ||
    pathway.contains('ELECTRICITY');
```

This correctly handles:
- ✅ JSON format: `[{"type":"ARPL","name":"Bricklayer"}]`
- ✅ Trade names: ELECTRICIAN, BRICKLAYER, PLUMBER
- ✅ Direct text: "ARPL"

### 3. Database Query ✅
**File:** `mobile/get_classes.php`

Already returns correct `Project_pathway` field with comprehensive logging:
```php
SELECT c.classID, c.className, s.Project_pathway
FROM class c
JOIN sites s ON s.siteID = c.siteID
WHERE f.facilitator_id = ?
```

### 4. Debug Logging Added ✅

Added comprehensive logging to trace the issue:
- **`lib/ArplAssessorPage.dart`:** Pathway detection logging
- **`mobile/get_classes.php`:** Server response logging
- **`mobile/login.php`:** Role detection logging
- **`lib/main.dart`:** Navigation logging

---

## APK BUILD COMPLETED

### Build Information:
- **Build Date:** July 14, 2026
- **Build Type:** Release (optimized, production-ready)
- **APK Size:** 45.9 MB
- **APK Location:** `C:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk`

### Build Process:
```cmd
✅ flutter clean
✅ flutter pub get
✅ flutter build apk --release
```

---

## INSTALLATION INSTRUCTIONS

### Step 1: Uninstall Old APK (CRITICAL)
On the Android device:
1. Go to **Settings** → **Apps**
2. Find **RLMSS** app
3. Tap **Uninstall**
4. Confirm uninstall

**⚠️ IMPORTANT:** You MUST uninstall the old app completely. Installing over it will NOT update the server configuration!

### Step 2: Install New APK
1. Transfer the APK to the device:
   ```
   build\app\outputs\flutter-apk\app-release.apk
   ```
2. On the device, open the APK file
3. Allow installation from unknown sources if prompted
4. Tap **Install**
5. Tap **Open** after installation

### Step 3: Test the Fix
1. Open the app
2. Log in with **Facilitator ID: 6**
3. You should see the **ARPL Assessor Menu** with:
   - ✅ ARPL Toolkit
   - ✅ ARPL Competency Scale
   - ✅ ARPL Marking
   - ✅ ARPL Hierarchical Navigator

---

## VERIFICATION CHECKLIST

After installing the new APK, verify these items:

### ✅ Server Configuration
Check Android logcat for:
```
[CONFIG] Base URL: https://rlms.rlms.co.za/mobile
```

**If you see `http://192.168.0.57:8080`, the old APK is still installed!**

### ✅ Pathway Detection
Check logs for:
```
[ArplAssessorPage] DEBUG: Raw pathway from data: "[{\"type\":\"ARPL\",\"name\":\"Bricklayer\"}]"
[ArplAssessorPage] DEBUG: Contains ARPL? true
[ArplAssessorPage] DEBUG: Contains BRICKLAYER? true
[ArplAssessorPage] Detected Pathway: ARPL
[ArplAssessorPage] Will show ARPL dashboard
```

### ✅ Menu Appearance
Log in as facilitator 6 and verify:
- [ ] ARPL Toolkit menu item appears
- [ ] ARPL Competency Scale menu item appears
- [ ] ARPL menu items are functional
- [ ] No regular assessor menu items (only ARPL items)

---

## TEST CREDENTIALS

**For Testing on ONLINE Server:**
- **Facilitator ID:** 6
- **Role:** `arpl_Assessor`
- **ClassID:** 797
- **Pathway:** ARPL - Bricklayer

**Expected Database Data (on ONLINE):**
```json
{
  "classID": 797,
  "className": "class A",
  "Project_pathway": "[{\"type\":\"ARPL\",\"trade_id\":\"2\",\"name\":\"Bricklayer\",\"ofo_code\":\"641201\",\"qualificationID\":\"QF002\",\"pathway_level\":\"NQF 4\"}]",
  "project_id": 100
}
```

---

## TROUBLESHOOTING

### Problem: Still shows LOCAL server in logs
**Symptoms:** Logs show `http://192.168.0.57:8080`

**Solution:**
1. Verify you uninstalled the old app completely
2. Check `lib/config.dart` has `serverHost = 'rlms.rlms.co.za'`
3. Rebuild APK: `flutter clean && flutter pub get && flutter build apk --release`
4. Reinstall

### Problem: Still shows "Short Skills Programme"
**Symptoms:** Logs show `Detected Pathway: SHORT SKILLS PROGRAMME`

**Solution:** This means the app is still fetching from LOCAL database. Follow the solution above.

### Problem: Shows ARPL but menu items don't work
**Symptoms:** Menu appears but items are non-functional

**Solution:** 
1. Check internet connectivity
2. Verify ONLINE server is accessible from the device
3. Check server logs for errors

### Problem: DNS lookup failed
**Symptoms:** Error: `Failed host lookup: 'rlms.rlmsco.com'`

**Solution:** Ensure config uses `rlms.rlms.co.za` (with second dot), NOT `rlms.rlmsco.com`

---

## TECHNICAL DETAILS

### Why APK Rebuild Was Required

Flutter apps are compiled into native code. The server configuration in `lib/config.dart` is:
1. Read at compile time
2. Compiled into the app binary
3. Cannot be changed without rebuilding

This is why changing `config.dart` required a complete rebuild and reinstall.

### Pathway Detection Flow

1. **App starts** → Fetches classes from `mobile/get_classes.php`
2. **Server returns** → `Project_pathway` field with JSON data
3. **App parses** → Extracts pathway string and converts to uppercase
4. **App checks** → Contains "ARPL" or trade names?
5. **If YES** → Shows ARPL menu
6. **If NO** → Shows default assessor menu

### Database Schema

The ONLINE database correctly stores pathway data as JSON:
```sql
sites.Project_pathway = '[{"type":"ARPL","name":"Bricklayer","ofo_code":"641201"}]'
```

The app correctly parses this JSON string and detects "ARPL" within it.

---

## FILES MODIFIED

All changes are complete and included in the new APK:

1. ✅ `lib/config.dart` - Server configuration
2. ✅ `lib/ArplAssessorPage.dart` - Pathway detection logic
3. ✅ `mobile/get_classes.php` - Server endpoint with logging
4. ✅ `mobile/login.php` - Login with role logging
5. ✅ `lib/main.dart` - Navigation logging

---

## NEXT STEPS

1. **Uninstall** old APK from device
2. **Install** new APK: `build\app\outputs\flutter-apk\app-release.apk`
3. **Test** with facilitator 6
4. **Verify** ARPL menu appears
5. **Confirm** menu items are functional

---

## SUMMARY

✅ **Root cause identified:** Old APK with wrong server config  
✅ **Code fixes applied:** Pathway detection + server config  
✅ **APK rebuilt:** Fresh release APK ready  
✅ **Testing guide:** Complete verification checklist provided  

**Action Required:** Uninstall old app, install new APK, and test.

---

## SUPPORT

If issues persist after following these steps:
1. Share Android logcat logs showing:
   - `[CONFIG] Base URL: ...`
   - `[ArplAssessorPage] Detected Pathway: ...`
2. Confirm complete uninstall of old app
3. Verify device can access `https://rlms.rlms.co.za`
