# Rebuild APK - ARPL Trade Display Fix

## STATUS
All code fixes are complete. Ready to rebuild APK.

## Files Modified
- 7 Dart files (trade name mappings, OFO defaults removed)
- 5 PHP files (endpoint routing, OFO validation)

## Rebuild Commands

### Step 1: Clean Previous Build
```bash
cd c:\projects\rlmss
flutter clean
```

### Step 2: Get Dependencies
```bash
flutter pub get
```

### Step 3: Build Release APK
```bash
flutter build apk --release
```

Expected output:
```
Built build\app\outputs\flutter-apk\app-release.apk
```

## Installation

### Device Connected via USB
```bash
flutter install build\app\outputs\flutter-apk\app-release.apk
```

### Manual Installation
1. Connect Android device via USB
2. Enable Developer Mode & USB Debugging
3. Uninstall old app:
   ```bash
   adb uninstall com.rlmss.app
   ```
4. Install new APK:
   ```bash
   adb install build\app\outputs\flutter-apk\app-release.apk
   ```

## What to Test After Installation

### Quick Test (5 minutes)
1. Login as Bricklayer (classID 783)
2. Go to ARPL Portfolio → ARPL Assessor
3. Verify: See Bricklayer questions (NOT Electrician questions)
4. Verify: Trade shows "Bricklayer", OFO shows "641201"

### Full Test (15 minutes)
- Test both Bricklayer and Electrician logins
- Go through multiple appendices
- Verify offline functionality
- Sync data and verify persistence

## Troubleshooting Build Issues

### Build fails with dependency errors
```bash
flutter pub get --no-offline
flutter pub upgrade
flutter build apk --release
```

### Build succeeds but APK too large
This is normal. Check:
- Size should be 50-150 MB for release
- If >200 MB, check for duplicate assets

### APK installs but crashes on startup
- Clear app cache on device
- Uninstall and reinstall
- Check Flutter logs: `flutter logs`

## Build Time Estimates
- `flutter clean` → 30 seconds
- `flutter pub get` → 1-2 minutes (if dependencies cached)
- `flutter build apk --release` → 3-5 minutes

**Total: 5-10 minutes**

## After Successful Installation

1. Take APK file from: `build\app\outputs\flutter-apk\app-release.apk`
2. Back it up to a safe location
3. Share with QA/testing team
4. Document version number (check pubspec.yaml)

## Verification Commands

Check what was actually changed:
```bash
git diff lib/ | grep -i "671101\|671102\|671103\|642601\|641201"
```

Should show:
- Removed: `?? '671101'` patterns
- Removed: `'671102'` mappings
- Removed: `'671103'` mappings
- Added: `'642601'` for Plumber
- Added: `'641201'` for Bricklayer

---

**Ready to proceed with rebuild!**
