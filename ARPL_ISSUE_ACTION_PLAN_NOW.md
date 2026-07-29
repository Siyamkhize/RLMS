# ARPL ASSESSOR MENU - IMMEDIATE ACTION PLAN

## STATUS: Multiple Issues Identified

### Issue 1: ✅ FIXED - APK Points to Wrong Server
**Status:** FIXED - New APK built  
**Evidence:** Logs show ONLINE server being accessed  
**Action:** ✅ New APK installed successfully

### Issue 2: ✅ FIXED - `mobile/login.php` Missing `Project_pathway`
**Status:** FIXED in code  
**Evidence:** Login response doesn't include `Project_pathway` field  
**Action:** ⚠️ **MUST UPLOAD** fixed `mobile/login.php` to ONLINE server  

### Issue 3: ⚠️ CRITICAL - ArplAssessorPage Not Loading
**Status:** INVESTIGATING  
**Evidence:** No logs from `[ArplAssessorPage]` after navigation  
**Possible Causes:**
- Page is crashing during initialization
- Import error
- Navigation not completing
- Logs being suppressed

---

## IMMEDIATE ACTIONS REQUIRED

### Action 1: Upload Fixed login.php ⚠️ CRITICAL

**File to Upload:**
```
c:\projects\rlmss\mobile\login.php
```

**Upload to:**
```
https://rlms.rlms.co.za/mobile/login.php
```

**What was fixed:**
Line 220 changed from:
```php
SELECT s.project_id, c.* 
```

To:
```php
SELECT s.project_id, s.Project_pathway, c.* 
```

**Verify Upload:**
After uploading, log in and check response includes:
```json
"Project_pathway": "[{\"type\":\"ARPL\",\"name\":\"Bricklayer\"}]"
```

---

### Action 2: Check for ArplAssessorPage Loading Issue

**Current Evidence:**
```
[NAVIGATION] About to navigate to ArplAssessorPage
[NAVIGATION] ======================================
```

**Missing (should appear next):**
```
[ArplAssessorPage] ===== INITIALIZATION =====
[ArplAssessorPage] Facilitator ID: 6
[ArplAssessorPage] Starting fetchClasses...
```

**Possible Reasons:**
1. **Import Error** - Check if ArplAssessorPage.dart has syntax errors
2. **Crash During Init** - Check for null reference errors
3. **Navigation Blocked** - Check for navigation guards
4. **Build Issue** - Page not included in APK

**Next Steps:**
1. Check device logs for crash reports
2. Look for any Flutter error messages after navigation
3. Verify ArplAssessorPage.dart has no syntax errors
4. Try adding try-catch in initState

---

### Action 3: Verify New APK is Actually Installed

**Check these logs:**
```
[CONFIG] Base URL: https://rlms.rlms.co.za/mobile  ← Should be ONLINE
```

**If you see:**
```
[CONFIG] Base URL: http://192.168.0.57:8080  ← OLD APK still installed!
```

Then:
1. Uninstall app completely
2. Clear app data
3. Reinstall from `build\app\outputs\flutter-apk\app-release.apk`

---

## DIAGNOSTIC CHECKLIST

### ✅ Confirmed Working:
- [x] New APK built successfully
- [x] APK points to ONLINE server (`rlms.rlms.co.za`)
- [x] Facilitator 6 has `arpl_assessor` role
- [x] ONLINE database has correct ARPL data
- [x] Pathway detection logic is correct
- [x] Navigation detects ARPL assessor role

### ⚠️ Not Yet Verified:
- [ ] `mobile/login.php` uploaded to ONLINE server
- [ ] Login response includes `Project_pathway`
- [ ] ArplAssessorPage loads without crashing
- [ ] ArplAssessorPage fetchClasses() executes
- [ ] Pathway detection runs successfully
- [ ] ARPL menu appears

---

## EXPECTED LOG SEQUENCE (COMPLETE FLOW)

### 1. Login Phase:
```
[LOGIN] Raw parsed data: {success: true, role: arpl_assessor, ...}
[LOGIN] Login success: true
[LOGIN] Raw role from server: "arpl_assessor"
```

### 2. Navigation Phase:
```
[NAVIGATION] Detected ARPL Assessor role
[NAVIGATION] About to navigate to ArplAssessorPage
```

### 3. ArplAssessorPage Init Phase (MISSING!):
```
[ArplAssessorPage] ===== INITIALIZATION =====
[ArplAssessorPage] Facilitator ID: 6
[ArplAssessorPage] Starting fetchClasses...
[CONFIG] Base URL: https://rlms.rlms.co.za/mobile
[ArplAssessorPage] Fetching classes from: https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=6
```

### 4. Pathway Detection Phase (MISSING!):
```
[ArplAssessorPage] DEBUG: Raw pathway from data: "[{\"type\":\"ARPL\",\"name\":\"Bricklayer\"}]"
[ArplAssessorPage] DEBUG: Contains ARPL? true
[ArplAssessorPage] Detected Pathway: ARPL
```

### 5. Build Phase (MISSING!):
```
[ArplAssessorPage] ===== BUILD METHOD =====
[ArplAssessorPage] _pathwayType: "ARPL"
[ArplAssessorPage] Will show ARPL dashboard
```

**We're stuck after step 2!**

---

## HYPOTHESIS: Why ArplAssessorPage Isn't Loading

### Theory 1: Page Constructor Crash
The `ArplAssessorPage` constructor might be throwing an error if it's expecting data that's not being passed.

**Check:**
```dart
const ArplAssessorPage({super.key, required this.facilitator_id});
```

Is `facilitator_id` being passed as String? Check the navigation code.

### Theory 2: initState Crash
The `initState()` calls `fetchClasses()` immediately, which might be crashing if:
- No network connectivity
- Server timeout
- Malformed URL
- Missing AppConfig.buildUrl method

### Theory 3: Import Error
The main.dart imports `ArplAssessorPage.dart` but if the file wasn't included in the APK build, it would fail silently.

**Verify:**
```dart
import 'ArplAssessorPage.dart';  // Check this import in main.dart
```

---

## IMMEDIATE TESTING STEPS

### Step 1: Upload Fixed login.php
```
Upload: c:\projects\rlmss\mobile\login.php
To: https://rlms.rlms.co.za/mobile/login.php
```

### Step 2: Test Login Again
Log in as Facilitator 6 and capture COMPLETE logs including:
- Login response (should now include `Project_pathway`)
- Navigation logs
- **Any error/crash logs after navigation**
- ArplAssessorPage logs (if they appear)

### Step 3: Check for Crash Reports
Look for Flutter error messages like:
```
Exception: ...
Stack trace: ...
```

### Step 4: If Still No Logs
Try adding error handling in main.dart navigation:
```dart
try {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ArplAssessorPage(
        facilitator_id: facilitatorId,
      ),
    ),
  );
} catch (e) {
  debugPrint('[NAVIGATION ERROR] Failed to navigate: $e');
}
```

---

## FILES STATUS

### ✅ Already Fixed:
- `lib/config.dart` - Points to ONLINE server
- `lib/ArplAssessorPage.dart` - Pathway detection logic
- `mobile/get_classes.php` - Returns Project_pathway
- `mobile/login.php` - **FIXED but not uploaded yet!**

### ⚠️ Need to Upload:
- `mobile/login.php` → ONLINE server

### 📦 Already Built:
- `build/app/outputs/flutter-apk/app-release.apk` - New APK with fixes

---

## NEXT MESSAGE SHOULD INCLUDE:

1. **Confirmation** that `mobile/login.php` was uploaded to ONLINE
2. **New login logs** showing `Project_pathway` in response
3. **Complete logs** after navigation attempt
4. **Any error messages** or crash reports
5. **Whether ArplAssessorPage logs appear**

---

## IF ArplAssessorPage STILL DOESN'T LOAD:

We'll need to:
1. Add try-catch error handling
2. Add more detailed navigation logs
3. Check for import errors in main.dart
4. Verify ArplAssessorPage.dart compiled into APK
5. Test with a simpler test page first

But first: **Upload mobile/login.php and test again!**
