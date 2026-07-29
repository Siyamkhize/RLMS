# Install ARPL Fix APK - Quick Guide

**APK Location:** `c:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk`  
**Build Date:** July 14, 2026  
**Build Size:** 45.9 MB

---

## Installation Steps

### 1. Enable USB Debugging (if not already enabled)
On the Android device:
- Settings → Developer Options → USB Debugging → Enable
- (Developer Options: Settings → About → Tap Build Number 7 times)

### 2. Connect Device via USB

### 3. Uninstall Old APK
```bash
adb uninstall com.example.rlmss
```

### 4. Install New APK
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

Or drag & drop the APK file onto the device through file manager.

### 5. Launch App
- Tap RLMSS icon on home screen
- Or: `adb shell am start -n com.example.rlmss/.MainActivity`

---

## Quick Test

1. **Login as ARPL Assessor**
   - Use facilitator assigned to:
     - Class 782 (Electrician) OR
     - Class 783 (Bricklayer)

2. **Verify ARPL Menu Shows**
   Should see:
   - Toolkit
   - Appendices A-I

3. **Test with Online Server** (optional)
   - Edit `lib/config.dart`
   - Point to: `rlms.rlms.co.za`
   - Rebuild: `flutter build apk --release`
   - Re-install APK

---

## Troubleshooting

### "Cannot connect to device"
```bash
adb devices
```
- Tap "Allow USB Debugging" on device when prompted
- Reconnect USB cable

### "Device not found"
- Ensure USB Debugging is ON in Developer Options
- Reconnect USB cable
- Restart ADB: `adb kill-server && adb start-server`

### "App crashes on login"
- Clear app cache: `adb shell pm clear com.example.rlmss`
- Reinstall APK
- Check logs: `adb logcat | grep RLMSS`

### "Still seeing normal assessor UI"
- Verify facilitator is assigned to ARPL class (782 or 783)
- Check `get_classes.php` returns Project_pathway with trade name
- Clear app cache and restart

---

## Verify Installation

```bash
# Check if app is installed
adb shell pm list packages | grep rlmss

# Check app version
adb shell dumpsys package com.example.rlmss | grep versionName

# View real-time logs
adb logcat | grep AssessorPage
```

---

## What's New in This Build

✅ **ARPL UI Detection Enhanced**
- Now detects ARPL from trade names: ELECTRICIAN, BRICKLAYING, PLUMBER, ELECTRICITY, etc.
- No longer dependent on full JSON pathway format
- Works with both local dev and online server data

✅ **Bug Fix**
- ARPL assessors on online server now see correct UI
- Toolkit and all appendices now accessible

---

## FAQ

**Q: Do I need to update the database?**  
A: No! The app now works with existing data. Optional database sync available in `fix_sites_project_pathway.sql`

**Q: Does this work with offline mode?**  
A: Yes, pathway detection happens when fetching classes, whether online or offline.

**Q: Can I go back to old APK?**  
A: Yes, just reinstall the previous APK. Changes are only in the app code, not the device data.

**Q: Will this affect normal assessors?**  
A: No, only ARPL assessors see ARPL UI. Normal assessors see normal assessor menu.

**Q: How do I switch between local and online?**  
A: Edit `lib/config.dart`, change server settings, rebuild APK with `flutter build apk --release`

---

## Support

If issues occur:
1. Check the error logs: `adb logcat | grep RLMSS`
2. Verify server is running and accessible
3. Clear cache: `adb shell pm clear com.example.rlmss`
4. Reinstall APK
5. Check that facilitator is assigned to ARPL class (782 or 783)

---

**Installation Time:** ~2 minutes  
**Testing Time:** ~5 minutes  
**Rollback Time:** ~1 minute (reinstall old APK)

