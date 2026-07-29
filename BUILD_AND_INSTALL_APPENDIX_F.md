# 📱 BUILD & INSTALL APK - APPENDIX F INTEGRATION

**Date:** July 15, 2026  
**Build:** Appendix F Redesign Complete  
**Status:** Ready to Build

---

## 🚀 QUICK BUILD & INSTALL

### Option 1: Build Release APK (Recommended)

```cmd
cd c:\projects\rlmss
flutter clean
flutter pub get
flutter build apk --release
```

**APK Location:** `build\app\outputs\flutter-apk\app-release.apk`

### Option 2: Build for Connected Device (Fastest)

```cmd
cd c:\projects\rlmss
flutter clean
flutter pub get
flutter install
```

---

## 📋 STEP-BY-STEP INSTRUCTIONS

### Step 1: Clean Build Environment

```cmd
cd c:\projects\rlmss
flutter clean
```

**Expected Output:**
```
Deleting build...
Deleting .dart_tool...
Deleting .flutter-plugins
Deleting .flutter-plugins-dependencies
```

### Step 2: Get Dependencies

```cmd
flutter pub get
```

**Expected Output:**
```
Running "flutter pub get" in rlmss...
Resolving dependencies...
Got dependencies!
```

### Step 3: Build Release APK

```cmd
flutter build apk --release
```

**Expected Output:**
```
Building with sound null safety
Running Gradle task 'assembleRelease'...
✓ Built build\app\outputs\flutter-apk\app-release.apk (XX.XMB)
```

**This will take 5-10 minutes.**

---

## 📲 INSTALLATION OPTIONS

### Option A: USB Installation (Recommended)

1. **Connect Device via USB**
2. **Enable USB Debugging** on device:
   - Settings → About Phone → Tap "Build Number" 7 times
   - Settings → Developer Options → Enable "USB Debugging"
3. **Install:**

```cmd
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

**If adb not found:**
```cmd
flutter install
```

### Option B: File Transfer Installation

1. **Copy APK to device:**
   - Connect device via USB
   - Open File Explorer
   - Navigate to: `c:\projects\rlmss\build\app\outputs\flutter-apk\`
   - Copy `app-release.apk` to device Downloads folder

2. **Install on device:**
   - Open Files app on device
   - Navigate to Downloads
   - Tap `app-release.apk`
   - Tap "Install"
   - If prompted, allow "Install from unknown sources"

### Option C: Direct Install (If Device Connected)

```cmd
flutter install
```

---

## ✅ VERIFY INSTALLATION

After installing, test the new Appendix F:

### Test 1: Launch App
- [ ] Open RLMS app on device
- [ ] Login as Facilitator ID: 6
- [ ] Password: (your password)
- [ ] Verify successful login

### Test 2: Navigate to Appendix F
- [ ] Tap hamburger menu
- [ ] Tap "View Complete Toolkit"
- [ ] Select learner: Anele Cele (ID 11701)
- [ ] Class: 797
- [ ] Tap "Appx F" tab

### Test 3: Verify New Design
- [ ] Should see 3 sections:
  - ✅ 1. KNOWLEDGE ASSESSMENT
  - ✅ 2. PRACTICAL TASKS
  - ✅ 3. WORKPLACE OBSERVATION

### Test 4: Edit Mode
- [ ] Tap Edit icon (✏️ pencil)
- [ ] Verify "Add Question" button appears in Knowledge section
- [ ] Verify "Add Task" button appears in Practical section
- [ ] Verify dropdowns appear in Workplace Observation

---

## ⚠️ IMPORTANT NOTES

### Before Building:
1. ✅ Flutter code is already integrated
2. ⚠️ Backend files need to be uploaded (see below)
3. ✅ App will compile and run
4. ⚠️ Appendix F won't load data until backend is set up

### Backend Setup Required:
**The app will work, but Appendix F will be empty until you:**
1. Upload `create_appendix_f_redesign_tables.sql` and run it
2. Upload `mobile/get_appendix_f_data.php`
3. Upload `mobile/save_appendix_f_data.php`

**Until backend is set up:**
- ✅ App will launch normally
- ✅ B, D, E continue to work
- ⚠️ Appendix F will show empty sections
- ⚠️ Workplace Observation won't load activities

---

## 🔧 TROUBLESHOOTING

### Issue: "Flutter not found"
**Solution:**
```cmd
where flutter
```
If not found, add Flutter to PATH or use full path:
```cmd
C:\path\to\flutter\bin\flutter.bat build apk --release
```

### Issue: "Gradle build failed"
**Solution:**
```cmd
cd android
gradlew clean
cd ..
flutter clean
flutter build apk --release
```

### Issue: "No connected devices"
**Check:**
```cmd
flutter devices
```

If no devices, ensure:
- USB debugging enabled
- USB cable connected
- Device authorized (check device screen)

### Issue: "Installation failed"
**Solution:**
```cmd
# Uninstall old version first
adb uninstall com.rlms.rlms

# Then reinstall
adb install build\app\outputs\flutter-apk\app-release.apk
```

### Issue: "App crashes on launch"
**Check:**
- Device has Android 5.0+ (API 21+)
- Sufficient storage space
- No conflicting apps

---

## 📊 BUILD INFORMATION

### What's Included in This Build:
- ✅ Appendix F complete redesign (3 sections)
- ✅ Dynamic Knowledge Assessment
- ✅ Dynamic Practical Tasks
- ✅ Workplace Observation with dropdowns
- ✅ Proper save/load logic
- ✅ B, D, E continue to work as before
- ✅ All previous fixes and features

### File Changes Made:
- `lib/ArplToolkitViewerPage.dart` - Completely updated
- Added 3 new data classes
- Added new load/save methods
- Replaced _buildAppendixF() method
- Updated initState() and dispose()

### Backend Files to Upload (Separately):
1. `create_appendix_f_redesign_tables.sql`
2. `mobile/get_appendix_f_data.php`
3. `mobile/save_appendix_f_data.php`
4. `mobile/test_appendix_f_setup.php` (optional)

---

## 📱 APK DETAILS

**Package Name:** com.rlms.rlms  
**Version:** (check android/app/build.gradle)  
**Min SDK:** 21 (Android 5.0)  
**Target SDK:** 33 (Android 13)  
**APK Size:** ~50-60 MB (estimated)

---

## 🎯 NEXT STEPS AFTER INSTALLATION

### 1. Test Without Backend (Will Show Empty)
- Install APK
- Login
- Navigate to Appendix F
- Verify UI appears (but no data)

### 2. Upload Backend Files
```bash
# Upload these files via FTP/cPanel:
create_appendix_f_redesign_tables.sql → Run in phpMyAdmin
mobile/get_appendix_f_data.php → Upload to mobile folder
mobile/save_appendix_f_data.php → Upload to mobile folder
```

### 3. Run SQL
```sql
-- In phpMyAdmin, run:
SOURCE create_appendix_f_redesign_tables.sql;

-- OR paste the SQL content and execute
```

### 4. Test Backend
Visit: https://rlms.rlms.co.za/mobile/test_appendix_f_setup.php

Expected:
```json
{
  "ready": true,
  "status": "ready"
}
```

### 5. Test Full Functionality
- Restart app
- Navigate to Appendix F
- Should now load workplace observations
- Add questions/tasks
- Save and verify data persists

---

## 🚨 CRITICAL REMINDERS

1. **App will install and run WITHOUT backend**
   - But Appendix F will be empty
   - B, D, E will continue to work

2. **Backend setup is required for full functionality**
   - Upload SQL and PHP files
   - Test with test_appendix_f_setup.php

3. **Test incrementally**
   - First: Install APK, verify it launches
   - Second: Upload backend files
   - Third: Test full Appendix F functionality

---

## 📞 SUPPORT

If issues occur:
1. Check Flutter console for errors
2. Check device logcat: `adb logcat`
3. Verify backend files uploaded
4. Run test_appendix_f_setup.php
5. Check browser console (F12) for API errors

---

**Ready to build? Run these commands:**

```cmd
cd c:\projects\rlmss
flutter clean && flutter pub get && flutter build apk --release
```

**APK will be at:** `build\app\outputs\flutter-apk\app-release.apk`

**Good luck! 🚀**
