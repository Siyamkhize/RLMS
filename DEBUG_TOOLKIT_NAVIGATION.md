# Debug Guide - Toolkit Navigation Issue

**Date:** July 8, 2026  
**Issue:** Dialog shows but button doesn't navigate to toolkit  
**Status:** Debug logging added

---

## 🐛 Problem Report

**User feedback:** "Dialog appears but it's not showing what is required for it to show"

This means:
- ✅ Dialog IS appearing (good!)
- ❌ Button doesn't navigate OR shows error message
- ❓ Missing required data (`_selectedLearnerId` or `_classId`)

---

## 🔍 Debug Logging Added

### What Was Added:

Added comprehensive logging to the "View Complete Toolkit" button:

```dart
print('[APPX H] View Toolkit button tapped');
print('[APPX H] _selectedLearnerId: $_selectedLearnerId');
print('[APPX H] _classId: $_classId');
```

### How to View Logs:

**Option 1: Via ADB (Recommended)**
```bash
adb -s adb-RZ8X306F7TZ-mKvVzH._adb-tls-connect._tcp logcat | findstr "APPX H"
```

**Option 2: Via Flutter**
```bash
flutter logs
```

**Option 3: Via Android Studio**
- Open Android Studio
- Go to Logcat tab
- Filter by "APPX H"

---

## 🧪 Test Steps to Capture Debug Info

### 1. Connect to Device Logs

Open a **NEW** terminal and run:
```bash
cd C:\projects\rlmss
adb -s adb-RZ8X306F7TZ-mKvVzH._adb-tls-connect._tcp logcat -s flutter
```

Keep this terminal open to see real-time logs.

### 2. Perform Test in App

1. Open the app on device
2. Login as facilitator
3. Navigate: **ARPL Assessor → Appendix H**
4. **Select a learner** from the dropdown
5. Fill in recommendation
6. Tap **"Save Recommendation"**
7. ✅ Dialog should appear
8. Tap **"View Complete Toolkit"** button
9. **Watch the logs** in your terminal

### 3. Expected Log Output

**If Everything Works:**
```
[APPX H] View Toolkit button tapped
[APPX H] _selectedLearnerId: 20286
[APPX H] _classId: 1
[APPX H] Navigating with learnerID: 20286, classID: 1
```
→ Toolkit viewer should open

**If Missing Data:**
```
[APPX H] View Toolkit button tapped
[APPX H] _selectedLearnerId: null
[APPX H] _classId: null
[APPX H] ERROR: Missing data
```
→ Red error message should show

**If Parse Error:**
```
[APPX H] View Toolkit button tapped
[APPX H] _selectedLearnerId: 20286
[APPX H] _classId: abc
[APPX H] ERROR: FormatException: Invalid radix-10 number
```
→ Red error message should show

---

## 📋 What to Check

### Scenario 1: No Logs Appear

**Meaning:** Button tap not registering

**Possible Causes:**
- Old APK still installed
- Build didn't include new code

**Solution:**
```bash
# Uninstall completely
adb -s adb-RZ8X306F7TZ-mKvVzH._adb-tls-connect._tcp uninstall com.example.rlmss

# Reinstall
adb -s adb-RZ8X306F7TZ-mKvVzH._adb-tls-connect._tcp install build\app\outputs\flutter-apk\app-debug.apk
```

### Scenario 2: Shows "Missing data" Error

**Meaning:** `_selectedLearnerId` or `_classId` is null

**Possible Causes:**
- Learner not selected from dropdown
- State lost after save
- Wrong page class (using wrong state)

**Solution:**
- Verify learner is selected before saving
- Check if `_fetchTraceabilityData()` is called before save
- Verify `_classId` is populated

### Scenario 3: Shows Parse Error

**Meaning:** `_selectedLearnerId` or `_classId` contains invalid data

**Possible Causes:**
- ClassID stored as text instead of number
- LearnerID has non-numeric characters

**Solution:**
- Check database values for learner 20286
- Verify classID format

### Scenario 4: Navigation Happens But Page Crashes

**Meaning:** ArplToolkitViewerPage has an error

**Possible Causes:**
- API endpoint not reachable
- Missing import
- Data model issue

**Solution:**
- Check ArplToolkitViewerPage logs
- Verify API endpoint accessible
- Check network connectivity

---

## 🔧 Quick Diagnostic Commands

### Check Device Connection:
```bash
adb devices
```

### View Last 100 Flutter Logs:
```bash
adb -s adb-RZ8X306F7TZ-mKvVzH._adb-tls-connect._tcp logcat -s flutter -t 100
```

### Clear Logs (Fresh Start):
```bash
adb -s adb-RZ8X306F7TZ-mKvVzH._adb-tls-connect._tcp logcat -c
```

### Check Installed App Version:
```bash
adb -s adb-RZ8X306F7TZ-mKvVzH._adb-tls-connect._tcp shell dumpsys package com.example.rlmss | findstr versionName
```

---

## 📊 Expected Behavior vs Current

### ✅ Expected (Working):

1. User completes Appendix H
2. Taps "Save Recommendation"
3. Dialog appears with green checkmark
4. User taps "View Complete Toolkit"
5. **LOGS:** 
   ```
   [APPX H] View Toolkit button tapped
   [APPX H] _selectedLearnerId: 20286
   [APPX H] _classId: 1
   [APPX H] Navigating with learnerID: 20286, classID: 1
   ```
6. Navigation to ArplToolkitViewerPage
7. Toolkit loads with 5 tabs
8. Data displays correctly

### ❌ Current Issue (Not Working):

1-4: Same as above
5. User taps "View Complete Toolkit"
6. **LOGS:** Either:
   - No logs (button not working)
   - Shows null values (missing data)
   - Shows error message
7. Navigation doesn't happen OR page crashes

---

## 🎯 Action Items

### For Developer (Me):

1. **Wait for log output** from test
2. **Analyze the specific error** based on logs
3. **Fix the root cause**:
   - If missing data: Ensure state is preserved
   - If wrong format: Add proper parsing
   - If page crashes: Fix ArplToolkitViewerPage

### For Tester (You):

1. ✅ **Run the test** with logs connected
2. ✅ **Copy the EXACT log output** you see
3. ✅ **Share the logs** with me
4. ✅ **Describe what happens** on screen:
   - Does error message appear?
   - Does nothing happen?
   - Does app crash?
   - Does wrong page open?

---

## 📝 Information Needed

Please provide:

1. **Device logs** from terminal (copy/paste)
2. **Screen behavior**:
   - Error message shown? (take screenshot)
   - Nothing happens?
   - App crashes?
   - Wrong page opens?
3. **Learner ID used** for testing
4. **Which Appendix H page**:
   - From ARPL Assessor main page?
   - From another entry point?

---

## 🚀 Current Build Status

- ✅ **Build:** Successful (43.2 seconds)
- ✅ **Installation:** Successful on device
- ✅ **Debug logging:** Added to button
- ⏳ **Testing:** Awaiting log output

**APK Location:** `C:\projects\rlmss\build\app\outputs\flutter-apk\app-debug.apk`  
**Device:** adb-RZ8X306F7TZ-mKvVzH._adb-tls-connect._tcp

---

## 📞 Next Steps

**Step 1:** Run test with logs connected:
```bash
# Terminal 1: Watch logs
adb -s adb-RZ8X306F7TZ-mKvVzH._adb-tls-connect._tcp logcat -s flutter

# Device: Perform test steps
```

**Step 2:** Copy log output and share it

**Step 3:** I'll analyze and fix the specific issue

---

**Status:** ⏳ Waiting for test results and log output

---
