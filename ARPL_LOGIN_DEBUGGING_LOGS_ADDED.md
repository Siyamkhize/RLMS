# ARPL ASSESSOR LOGIN - COMPREHENSIVE DEBUGGING LOGS ADDED

**Date:** Current Session
**Purpose:** Add detailed logging to diagnose ARPL assessor menu issue
**Status:** ✅ COMPLETE - Logs added to backend and frontend

---

## LOGS ADDED - OVERVIEW

I've added comprehensive logging at every step of the login and navigation flow:

1. **Backend PHP (login.php)** - Role detection and response
2. **Backend PHP (get_classes.php)** - Pathway data retrieval
3. **Flutter (main.dart)** - Login response parsing and navigation
4. **Flutter (ArplAssessorPage.dart)** - Pathway detection and UI rendering

---

## 1. BACKEND: mobile/login.php

### Added Logs:

**Role Detection (Lines 215-235):**
```php
error_log("[LOGIN] Facilitator {$row['facilitator_id']}: DB role = '{$row['role']}', normalized = '$dbRole'");

// When ARPL detected:
error_log("[LOGIN] Detected ARPL Assessor role");

// When other roles detected:
error_log("[LOGIN] Detected Assessor role");
error_log("[LOGIN] Detected Moderator role");
error_log("[LOGIN] Defaulting to Facilitator role");
```

**Final Response (Lines 245-255):**
```php
error_log("[LOGIN] Final response role for facilitator {$row['facilitator_id']}: '$role'");
error_log("[LOGIN] Sending response - Role: '$role', Facilitator: $facilitator_id, Classes count: " . count($classes));

// If classes found:
error_log("[LOGIN] First class data: " . json_encode($classes[0]));

// If query fails:
error_log("[LOGIN ERROR] Failed to prepare class information query");
```

### What To Look For:

**Example Success Log:**
```
[LOGIN] Facilitator 6: DB role = 'arpl_Assessor', normalized = 'arpl_assessor'
[LOGIN] Detected ARPL Assessor role
[LOGIN] Final response role for facilitator 6: 'arpl_assessor'
[LOGIN] Sending response - Role: 'arpl_assessor', Facilitator: 6, Classes count: 1
[LOGIN] First class data: {"classID":"797","className":"Class A",...}
```

**Example Problem Log:**
```
[LOGIN] Facilitator 6: DB role = 'Assessor', normalized = 'assessor'
[LOGIN] Detected Assessor role  // ❌ Wrong! Should be ARPL Assessor
```

---

## 2. BACKEND: mobile/get_classes.php

### Added Logs:

**Request Received:**
```php
error_log("[GET_CLASSES] Request for facilitator_id: $facilitator_id");
```

**Pathway Data Per Class:**
```php
// If Project_pathway is empty:
error_log("[GET_CLASSES] WARNING: Empty Project_pathway for classID {$row['classID']}");

// If Project_pathway has data:
error_log("[GET_CLASSES] ClassID {$row['classID']}: Project_pathway = '{$row['Project_pathway']}'");
```

**Response Summary:**
```php
error_log("[GET_CLASSES] Returning " . count($classes) . " classes for facilitator $facilitator_id");
error_log("[GET_CLASSES] First class: " . json_encode($classes[0]));
```

### What To Look For:

**Example Success Log:**
```
[GET_CLASSES] Request for facilitator_id: 6
[GET_CLASSES] ClassID 797: Project_pathway = 'Electrician'
[GET_CLASSES] Returning 1 classes for facilitator 6
[GET_CLASSES] First class: {"classID":"797","Project_pathway":"Electrician",...}
```

**Example Problem Log:**
```
[GET_CLASSES] ClassID 797: Project_pathway = ''  // ❌ Empty!
[GET_CLASSES] WARNING: Empty Project_pathway for classID 797
```

---

## 3. FRONTEND: lib/main.dart

### Added Logs:

**Login Response Parsing (Lines 463-485):**
```dart
debugPrint('[LOGIN] Raw role from server: "$role"');
debugPrint('[LOGIN] Extracted values:');
debugPrint('[LOGIN]   - role: "$role"');
debugPrint('[LOGIN]   - facilitator_id: "$facilitatorId"');
debugPrint('[LOGIN]   - classID: "$classID"');
debugPrint('[LOGIN]   - role.toLowerCase(): "${role.toLowerCase()}"');
```

**Navigation Decision (Lines 688-700):**
```dart
debugPrint('[NAVIGATION] ===== NAVIGATION DEBUG =====');
debugPrint('[NAVIGATION] Role: "$role"');
debugPrint('[NAVIGATION] Normalized role: "$normalizedRole"');
debugPrint('[NAVIGATION] classID: "$classID"');
debugPrint('[NAVIGATION] sdp: "$sdp"');
debugPrint('[NAVIGATION] facilitator_id: "$facilitatorId"');
debugPrint('[NAVIGATION] data keys: ${data.keys.toList()}');
debugPrint('[NAVIGATION] =============================');
```

**ARPL Assessor Navigation (Lines 760-775):**
```dart
debugPrint('[NAVIGATION] ===== ARPL ASSESSOR NAVIGATION =====');
debugPrint('[NAVIGATION] Detected ARPL Assessor role');
debugPrint('[NAVIGATION] Facilitator ID: "$facilitatorId"');
debugPrint('[NAVIGATION] ClassID: "$classID"');
debugPrint('[NAVIGATION] About to navigate to ArplAssessorPage');
debugPrint('[NAVIGATION] ======================================');

// After successful auth:
debugPrint('[NAVIGATION] Successfully authenticated, pushing to ArplAssessorPage');
```

### What To Look For:

**Example Success Log:**
```
[LOGIN] Raw role from server: "arpl_assessor"
[LOGIN] Extracted values:
[LOGIN]   - role: "arpl_assessor"
[LOGIN]   - facilitator_id: "6"
[NAVIGATION] ===== NAVIGATION DEBUG =====
[NAVIGATION] Role: "arpl_assessor"
[NAVIGATION] Normalized role: "arpl_assessor"
[NAVIGATION] ===== ARPL ASSESSOR NAVIGATION =====
[NAVIGATION] Detected ARPL Assessor role
[NAVIGATION] About to navigate to ArplAssessorPage
[NAVIGATION] Successfully authenticated, pushing to ArplAssessorPage
```

**Example Problem Log:**
```
[LOGIN] Raw role from server: "assessor"  // ❌ Wrong! Should be arpl_assessor
[NAVIGATION] Role: "assessor"
[NAVIGATION] Normalized role: "assessor"
// Will navigate to AssessorPage, not ArplAssessorPage
```

---

## 4. FRONTEND: lib/ArplAssessorPage.dart

### Added Logs:

**Initialization (Lines 40-45):**
```dart
print('[ArplAssessorPage] ===== INITIALIZATION =====');
print('[ArplAssessorPage] Facilitator ID: ${widget.facilitator_id}');
print('[ArplAssessorPage] Starting fetchClasses...');
```

**Fetch Classes:**
```dart
print('[ArplAssessorPage] Fetching classes from: $url');
```

**Pathway Detection (Lines 75-90) - ENHANCED:**
```dart
print('[ArplAssessorPage] Detected Pathway: $_pathwayType (from data: $pathway, isARPL: $isARPL)');
```

**UI Rendering (Lines 348-360):**
```dart
print('[ArplAssessorPage] ===== BUILD METHOD =====');
print('[ArplAssessorPage] _pathwayType: "$_pathwayType"');
print('[ArplAssessorPage] Will show ${_pathwayType == 'ARPL' ? 'ARPL' : 'DEFAULT'} dashboard');
print('[ArplAssessorPage] Will use ${_pathwayType == 'ARPL' ? '_buildARPLDrawerItems' : '_buildDefaultDrawerItems'}');
print('[ArplAssessorPage] ===========================');
```

### What To Look For:

**Example Success Log:**
```
[ArplAssessorPage] ===== INITIALIZATION =====
[ArplAssessorPage] Facilitator ID: 6
[ArplAssessorPage] Starting fetchClasses...
[ArplAssessorPage] Fetching classes from: https://rlms.rlmsco.com/mobile/get_classes.php?facilitator_id=6
[ArplAssessorPage] Detected Pathway: ARPL (from data: ELECTRICIAN, isARPL: true)
[ArplAssessorPage] ===== BUILD METHOD =====
[ArplAssessorPage] _pathwayType: "ARPL"
[ArplAssessorPage] Will show ARPL dashboard
[ArplAssessorPage] Will use _buildARPLDrawerItems
```

**Example Problem Log (Before Fix):**
```
[ArplAssessorPage] Detected Pathway: ELECTRICIAN (from data: ELECTRICIAN, isARPL: false)  // ❌ Bug!
[ArplAssessorPage] _pathwayType: "ELECTRICIAN"  // ❌ Should be "ARPL"
[ArplAssessorPage] Will show DEFAULT dashboard  // ❌ Wrong menu!
```

**Example Success Log (After Fix):**
```
[ArplAssessorPage] Detected Pathway: ARPL (from data: ELECTRICIAN, isARPL: true)  // ✅ Fixed!
[ArplAssessorPage] _pathwayType: "ARPL"  // ✅ Correct!
[ArplAssessorPage] Will show ARPL dashboard  // ✅ Correct menu!
```

---

## HOW TO VIEW LOGS

### **Backend PHP Logs:**

**Location:** Server error log (typically `/var/log/apache2/error.log` or configured path)

**View in real-time:**
```bash
ssh user@rlms.rlmsco.com
tail -f /var/log/apache2/error.log | grep LOGIN
tail -f /var/log/apache2/error.log | grep GET_CLASSES
```

**Download log file:**
```bash
scp user@rlms.rlmsco.com:/var/log/apache2/error.log ./server_error.log
```

### **Flutter Logs:**

**Android Studio / VS Code:**
- Run app in debug mode
- View "Debug Console" or "Logcat"
- Filter by: `LOGIN`, `NAVIGATION`, `ArplAssessorPage`

**Command Line:**
```bash
# View all logs
flutter logs

# Filter for specific tags
flutter logs | grep -E "LOGIN|NAVIGATION|ArplAssessor"

# ADB logcat (Android)
adb logcat | grep -E "flutter.*LOGIN|flutter.*NAVIGATION|flutter.*ArplAssessor"
```

---

## DEBUGGING WORKFLOW

### Step 1: Test Login
1. Clear app data / reinstall APK
2. Open app and log in as facilitator 6
3. Watch logs in real-time

### Step 2: Check Backend Logs

**Look for:**
```
[LOGIN] Facilitator 6: DB role = '???', normalized = '???'
[LOGIN] Detected ??? role
[LOGIN] Final response role for facilitator 6: '???'
```

**Questions to answer:**
- What is the raw role from database?
- What is the normalized role?
- What role is sent in the response?

### Step 3: Check Frontend Login Logs

**Look for:**
```
[LOGIN] Raw role from server: "???"
[NAVIGATION] Normalized role: "???"
[NAVIGATION] Detected ??? role
```

**Questions to answer:**
- Did Flutter receive the correct role from backend?
- Which page is it navigating to?

### Step 4: Check ArplAssessorPage Logs

**Look for:**
```
[ArplAssessorPage] Detected Pathway: ??? (from data: ???, isARPL: ???)
[ArplAssessorPage] _pathwayType: "???"
[ArplAssessorPage] Will show ??? dashboard
```

**Questions to answer:**
- What pathway data was received?
- Was it detected as ARPL?
- Which dashboard is being shown?

---

## EXPECTED LOG FLOW (SUCCESS CASE)

### Complete successful login flow:

```
# Backend: login.php
[LOGIN] Facilitator 6: DB role = 'arpl_Assessor', normalized = 'arpl_assessor'
[LOGIN] Detected ARPL Assessor role
[LOGIN] Final response role for facilitator 6: 'arpl_assessor'
[LOGIN] Sending response - Role: 'arpl_assessor', Facilitator: 6, Classes count: 1

# Frontend: main.dart
[LOGIN] Raw role from server: "arpl_assessor"
[LOGIN]   - role: "arpl_assessor"
[LOGIN]   - facilitator_id: "6"
[NAVIGATION] Normalized role: "arpl_assessor"
[NAVIGATION] ===== ARPL ASSESSOR NAVIGATION =====
[NAVIGATION] About to navigate to ArplAssessorPage
[NAVIGATION] Successfully authenticated, pushing to ArplAssessorPage

# Frontend: ArplAssessorPage
[ArplAssessorPage] ===== INITIALIZATION =====
[ArplAssessorPage] Facilitator ID: 6
[ArplAssessorPage] Fetching classes from: .../get_classes.php?facilitator_id=6

# Backend: get_classes.php
[GET_CLASSES] Request for facilitator_id: 6
[GET_CLASSES] ClassID 797: Project_pathway = 'Electrician'
[GET_CLASSES] Returning 1 classes for facilitator 6

# Frontend: ArplAssessorPage (pathway detection)
[ArplAssessorPage] Detected Pathway: ARPL (from data: ELECTRICIAN, isARPL: true)
[ArplAssessorPage] ===== BUILD METHOD =====
[ArplAssessorPage] _pathwayType: "ARPL"
[ArplAssessorPage] Will show ARPL dashboard
```

---

## FILES MODIFIED

1. ✅ **mobile/login.php** - Added role detection and response logging
2. ✅ **mobile/get_classes.php** - Added pathway data logging
3. ✅ **lib/main.dart** - Added login parsing and navigation logging
4. ✅ **lib/ArplAssessorPage.dart** - Added pathway detection and UI rendering logging

---

## NEXT STEPS

1. **Deploy updated PHP files to server:**
   ```bash
   scp mobile/login.php user@rlms.rlmsco.com:/home/rlmsrlmsco/public_html/mobile/
   scp mobile/get_classes.php user@rlms.rlmsco.com:/home/rlmsrlmsco/public_html/mobile/
   ```

2. **Rebuild APK with new Flutter logs:**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

3. **Test and collect logs:**
   - Install fresh APK
   - Log in as facilitator 6
   - Collect both backend and frontend logs

4. **Share logs with me** so we can identify exactly where the issue is

---

**Status:** All logging complete - ready for testing and diagnosis
