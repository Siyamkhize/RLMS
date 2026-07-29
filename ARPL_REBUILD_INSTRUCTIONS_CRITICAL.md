# ARPL ASSESSOR MENU FIX - REBUILD REQUIRED

## CRITICAL ISSUE IDENTIFIED

The app is using an **OLD CACHED APK** that points to the LOCAL development server instead of the ONLINE production server.

### Evidence from Logs:
```
[CONFIG] Base URL: http://192.168.0.57:8080/assessorReport2/mobile
```

### Expected (from config.dart):
```
[CONFIG] Base URL: https://rlms.rlms.co.za/mobile
```

---

## ROOT CAUSE

The `lib/config.dart` has been correctly updated to point to the ONLINE server (`rlms.rlms.co.za`), but the installed APK was built BEFORE this change. The APK has hardcoded the old LOCAL server URL.

**Why this causes the wrong menu:**
- OLD APK → Fetches from LOCAL server (`192.168.0.57`) 
- LOCAL database has: `Project_pathway = "Short Skills Programme"` (NOT ARPL)
- App detects "Short Skills Programme" → Shows DEFAULT menu ❌

**What should happen with NEW APK:**
- NEW APK → Fetches from ONLINE server (`rlms.rlms.co.za`)
- ONLINE database has: `Project_pathway = "[{\"type\":\"ARPL\",\"name\":\"Bricklayer\"}]"`
- App detects "ARPL" in pathway → Shows ARPL menu ✅

---

## SOLUTION: REBUILD AND REINSTALL APK

### Step 1: Clean Previous Build
```cmd
flutter clean
```

### Step 2: Get Dependencies
```cmd
flutter pub get
```

### Step 3: Verify Config Points to ONLINE Server
The file `lib/config.dart` should have:
```dart
static const String serverHost = 'rlms.rlms.co.za';  // ✅ ONLINE
static const int serverPort = 443;
static const String serverProtocol = 'https';
static const String basePath = '/mobile';
```

**NOT:**
```dart
static const String serverHost = '192.168.0.57';  // ❌ LOCAL
```

### Step 4: Build Release APK
```cmd
flutter build apk --release
```

### Step 5: Locate the APK
The new APK will be at:
```
build\app\outputs\flutter-apk\app-release.apk
```

### Step 6: Uninstall Old APK from Device
On the Android device:
1. Go to **Settings** → **Apps**
2. Find **RLMSS** app
3. Tap **Uninstall**
4. Confirm uninstall

**IMPORTANT:** You MUST uninstall the old app completely. Just installing over it may not update the config.

### Step 7: Install New APK
Transfer `app-release.apk` to the device and install it.

---

## VERIFICATION AFTER INSTALL

### Test 1: Check Server URL in Logs
After logging in, check the Android logcat for:
```
[CONFIG] Base URL: https://rlms.rlms.co.za/mobile
```

**If you see `http://192.168.0.57:8080`, the old APK is still installed!**

### Test 2: Check Pathway Detection
Look for these logs:
```
[ArplAssessorPage] DEBUG: Raw pathway from data: "[{\"type\":\"ARPL\",\"trade_id\":\"2\",\"name\":\"Bricklayer\"}]"
[ArplAssessorPage] DEBUG: Contains ARPL? true
[ArplAssessorPage] DEBUG: Contains BRICKLAYER? true
[ArplAssessorPage] Detected Pathway: ARPL
[ArplAssessorPage] Will show ARPL dashboard
```

**NOT:**
```
[ArplAssessorPage] DEBUG: Raw pathway from data: "Short Skills Programme"
[ArplAssessorPage] Detected Pathway: SHORT SKILLS PROGRAMME
[ArplAssessorPage] Will show DEFAULT dashboard
```

### Test 3: Verify ARPL Menu Appears
Log in as facilitator 6 with `arpl_Assessor` role. The app should show:
- ARPL Toolkit
- ARPL Competency Scale
- ARPL Marking
- ARPL Hierarchical Navigator

---

## PATHWAY DETECTION LOGIC (Already Fixed)

The `ArplAssessorPage.dart` has been updated to detect ARPL from multiple formats:

```dart
bool isARPL = pathway.contains('ARPL') ||
    pathway.contains('ELECTRICIAN') ||
    pathway.contains('BRICKLAYING') ||
    pathway.contains('BRICKLAYER') ||
    pathway.contains('PLUMBING') ||
    pathway.contains('PLUMBER') ||
    pathway.contains('ELECTRICITY');
```

This will match:
- ✅ JSON format: `[{"type":"ARPL","name":"Bricklayer"}]`
- ✅ Trade names: `ELECTRICIAN`, `BRICKLAYER`, `PLUMBER`, etc.
- ✅ Direct ARPL text: `ARPL`

---

## TROUBLESHOOTING

### Problem: Still sees LOCAL server in logs after rebuild
**Solution:** 
1. Ensure you ran `flutter clean` before building
2. Verify `lib/config.dart` has correct server URL
3. Completely uninstall the old app (don't just install over it)
4. Rebuild and reinstall

### Problem: DNS lookup failed for rlms.rlmsco.com
**Solution:** The correct URL is `rlms.rlms.co.za` (with second dot), NOT `rlms.rlmsco.com`

### Problem: Still shows "Short Skills Programme"
**Solution:** This means the app is fetching from LOCAL database. Rebuild APK to point to ONLINE server.

---

## FILES MODIFIED (Already Done - No Further Changes Needed)

1. ✅ `lib/config.dart` - Points to ONLINE server `rlms.rlms.co.za`
2. ✅ `lib/ArplAssessorPage.dart` - Enhanced pathway detection logic
3. ✅ `mobile/get_classes.php` - Returns `Project_pathway` field with logging
4. ✅ `mobile/login.php` - Added role detection logging
5. ✅ `lib/main.dart` - Added navigation logging

**All code changes are complete. Only rebuild and reinstall is required.**

---

## SUMMARY

**What was wrong:** Old APK points to LOCAL server with non-ARPL data  
**What was fixed:** Config updated to ONLINE server + pathway detection logic enhanced  
**What you need to do:** Rebuild APK and install it  
**Expected result:** ARPL menu appears for facilitator 6  

---

## QUICK COMMAND SEQUENCE

```cmd
flutter clean
flutter pub get
flutter build apk --release
```

Then uninstall old app and install `build\app\outputs\flutter-apk\app-release.apk`
