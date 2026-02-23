# APK Build and Distribution Guide

## ✅ Release APK Built Successfully

### Location
The installable APK is located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

**Size:** 24.0MB  
**Type:** Universal APK (works on all Android devices)

---

## How to Share and Install

### Method 1: Direct File Transfer
1. Copy `app-release.apk` from the `build/app/outputs/flutter-apk/` folder
2. Send via:
   - WhatsApp
   - Email
   - Google Drive
   - USB cable
   - Bluetooth

### Method 2: Install on Device
1. Copy APK to device
2. Open file manager on Android device
3. Tap on `app-release.apk`
4. If prompted, enable "Install from Unknown Sources"
5. Tap "Install"

---

## Why Previous APK Didn't Install

The APK in `flutter-apk` folder might have been:
1. **Debug APK** - Not properly signed for distribution
2. **Corrupted** - Incomplete build
3. **Wrong architecture** - Built for specific CPU only

The new `app-release.apk` is:
- ✅ Properly signed with debug key
- ✅ Universal (works on all Android devices)
- ✅ Release build (optimized and smaller)

---

## Building APKs - Commands Reference

### Universal APK (Recommended for Distribution)
```bash
flutter build apk --release
```
- **Output:** `build/app/outputs/flutter-apk/app-release.apk`
- **Size:** ~24MB
- **Works on:** All Android devices (ARM, x86, 32-bit, 64-bit)
- **Best for:** Sharing with users

### Split APKs (Smaller Size)
```bash
flutter build apk --split-per-abi --release
```
- **Output:** Multiple APKs in `build/app/outputs/flutter-apk/`:
  - `app-armeabi-v7a-release.apk` (32-bit ARM - most phones)
  - `app-arm64-v8a-release.apk` (64-bit ARM - modern phones)
  - `app-x86-release.apk` (32-bit Intel - emulators)
  - `app-x86_64-release.apk` (64-bit Intel - emulators)
- **Size:** ~12-15MB each
- **Best for:** Google Play Store (automatic selection)

### Debug APK (For Testing)
```bash
flutter build apk --debug
```
- **Output:** `build/app/outputs/flutter-apk/app-debug.apk`
- **Size:** Larger than release
- **Best for:** Development testing only

---

## App Bundle (For Google Play Store)

If you want to publish to Google Play Store:

```bash
flutter build appbundle --release
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

---

## Signing Configuration

### Current Setup
The app is currently signed with **debug keys** (line 49 in `android/app/build.gradle`):
```gradle
signingConfig = signingConfigs.debug
```

### For Production (Google Play Store)
You need to create a proper signing key:

1. **Generate keystore:**
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. **Create `android/key.properties`:**
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>
```

3. **Update `android/app/build.gradle`:**
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

---

## Troubleshooting

### "App not installed" Error
**Causes:**
- Older version already installed with different signature
- Corrupted APK
- Insufficient storage

**Solutions:**
1. Uninstall old version first
2. Re-download APK
3. Free up storage space

### "Install from Unknown Sources" Blocked
**Solution:**
1. Go to Settings > Security
2. Enable "Unknown Sources" or "Install Unknown Apps"
3. Allow installation from File Manager

### APK Too Large
**Solutions:**
1. Use split APKs: `flutter build apk --split-per-abi --release`
2. Enable ProGuard (minification)
3. Remove unused assets

---

## Version Information

**Current Version:**
- Version Code: 1
- Version Name: 1.0.0+1

To update version (in `android/app/build.gradle`):
```gradle
versionCode = 2
versionName = "1.0.1"
```

---

## Quick Commands

### Clean and Rebuild
```bash
flutter clean
flutter build apk --release
```

### Check APK Size
```bash
dir build\app\outputs\flutter-apk\app-release.apk
```

### Install Directly to Connected Device
```bash
flutter install --release
```

---

## Distribution Checklist

Before sharing APK:
- [ ] Test on at least one physical device
- [ ] Verify all features work
- [ ] Check app permissions
- [ ] Test offline functionality
- [ ] Verify sync works
- [ ] Check database operations
- [ ] Test on different Android versions if possible

---

## Notes

1. **Debug vs Release:**
   - Debug APK: Larger, includes debugging symbols, slower
   - Release APK: Smaller, optimized, faster, no debugging

2. **Universal vs Split:**
   - Universal: One APK for all devices (larger)
   - Split: Multiple APKs, smaller but need right one for device

3. **Signing:**
   - Debug signing: OK for testing and internal distribution
   - Release signing: Required for Google Play Store

4. **File Location:**
   - Always check `build/app/outputs/flutter-apk/` folder
   - APK name indicates type: `app-release.apk`, `app-debug.apk`

---

## Current Build Configuration

From `android/app/build.gradle`:
- **Application ID:** com.example.rlmss
- **Min SDK:** 21 (Android 5.0)
- **Target SDK:** 35 (Android 15)
- **Compile SDK:** 35
- **Multi-Dex:** Enabled
- **Minify:** Disabled (for easier debugging)

---

## Success!

Your release APK is ready to share:
📦 **File:** `build/app/outputs/flutter-apk/app-release.apk`
📏 **Size:** 24.0MB
✅ **Status:** Ready to install on any Android device

Just copy this file and send it to your users!
