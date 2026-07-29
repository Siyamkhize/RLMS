# INSTALL NEW APK - QUICK GUIDE

**APK Status:** ✅ READY  
**Build:** SUCCESS (26.0 seconds, 0 errors)  
**Size:** 140 MB  
**Location:** `c:\projects\rlmss\build\app\outputs\flutter-apk\app-debug.apk`

---

## WHAT'S NEW IN THIS BUILD

✅ Trade names are now dynamic (no more hardcoded "Plumber")  
✅ Appendix A, C, I, J all show correct trade title  
✅ Electrician displays for OFO 671101  
✅ Appendix F practical section: 13 empty rows (FIXED)  
✅ Professional UI with proper styling  

---

## INSTALLATION METHOD 1: Using Flutter (Recommended)

```bash
cd c:\projects\rlmss
flutter install
```

---

## INSTALLATION METHOD 2: Using ADB Direct

### Step 1: Connect Device
Ensure your device is connected via USB or TCP connection:
```bash
adb devices
```

Should show your device in the list.

### Step 2: Install APK
```bash
adb install -r "c:\projects\rlmss\build\app\outputs\flutter-apk\app-debug.apk"
```

The `-r` flag means "reinstall" (replace existing app).

---

## INSTALLATION METHOD 3: Manual File Transfer

If ADB is not working:

1. Connect device via USB (file transfer mode)
2. Copy APK file to device: `c:\projects\rlmss\build\app\outputs\flutter-apk\app-debug.apk`
3. On device, open file manager
4. Navigate to Downloads folder
5. Tap APK file to install
6. Follow on-device prompts

---

## VERIFY INSTALLATION

After installation:

1. Open app
2. Login as Facilitator
3. Go to ARPL Toolkit
4. Search for Learner ID: 20286 (Nkosivile Sophangisa)
5. Open Appendix A → Should show "Trade Title: Electrician" ✓
6. Open Appendix F → Should show 13 empty rows ✓

---

## TROUBLESHOOTING

### APK Installation Fails
- Device may need to allow installation from unknown sources
  - Settings → Apps → Allow installation from unknown sources
  
### Device Not Found
- Restart ADB: `adb kill-server` then `adb start-server`
- Check USB cable connection
- Accept permission prompts on device

### App Won't Open
- Uninstall previous version first: `adb uninstall com.example.rlmss`
- Then install new APK

---

## APK DETAILS

| Item | Value |
|---|---|
| Build Date | July 9, 2026 |
| Build Time | 26.0 seconds |
| APK Size | 140 MB |
| Min SDK | Android 5.0+ |
| Status | DEBUG (not production) |
| File | app-debug.apk |

---

## QUICK COMMANDS

```bash
# View device list
adb devices

# Install APK
adb install -r "c:\projects\rlmss\build\app\outputs\flutter-apk\app-debug.apk"

# Uninstall app
adb uninstall com.example.rlmss

# View logs (if app crashes)
adb logcat

# Clear app data
adb shell pm clear com.example.rlmss
```

---

## SUPPORT

If installation fails:
1. Check device connection: `adb devices`
2. Try restarting ADB: `adb kill-server` & `adb start-server`
3. Uninstall previous version and retry
4. Check Android Studio logs for detailed errors

---

**Status:** ✅ READY TO INSTALL
