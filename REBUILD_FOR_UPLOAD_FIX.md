# ⚠️ REBUILD REQUIRED - Upload Fix

**Date**: August 28, 2026  
**Priority**: CRITICAL - App Cannot Upload Signatures/Images Until Rebuilt  
**Platforms**: Android + iOS

## What Was Fixed
The missing `_checkConnectivity()` method has been added to `LearnerDetailsPage.dart`. Without this method, every signature and image upload failed silently.

## Why Rebuild Is Required
This is a **Dart code change** that requires recompilation. The old APK/IPA will continue to fail uploads because it's still calling a non-existent method.

## Quick Links
- **Android Build**: See instructions below
- **iOS Build**: See `BUILD_ANDROID_AND_IOS.md` (requires macOS)
- **Testing Guide**: See `UPLOAD_FIX_QUICK_REFERENCE.md`

---

## Android Rebuild Instructions

### 1. Clean Previous Build
```powershell
cd c:\projects\rlmss
flutter clean
```

### 2. Get Dependencies
```powershell
flutter pub get
```

### 3. Build Release APK
```powershell
flutter build apk --release
```

**Expected output**:
```
✓ Built build\app\outputs\flutter-apk\app-release.apk (XX.XMB)
```

### 4. Locate APK
The new APK will be at:
```
c:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk
```

### 5. Install on Test Device
```powershell
# Via USB
adb install -r build\app\outputs\flutter-apk\app-release.apk

# Or copy to device and install manually
```

## Testing the Fix

### Quick Test (SDP Role, Online)
1. Login as SDP user
2. Go to any learner's details page
3. Capture a signature
4. **Watch for** success message: "Signature uploaded successfully"
5. Check server:
   ```
   https://rlms.rlms.co.za/mobile/signatures/
   ```
   Should now contain the signature file

### Detailed Log Verification
Connect device via USB and run:
```powershell
adb logcat | Select-String "SIG_UPLOAD|IMG_UPLOAD|CONNECTIVITY"
```

**Expected logs**:
```
[CONNECTIVITY] Checking network connectivity...
[CONNECTIVITY] ✅ ONLINE (Status: 200)
[SIG_UPLOAD] ========================================
[SIG_UPLOAD] STARTING UPLOAD PROCESS
[SIG_UPLOAD] Field: signature
[SIG_UPLOAD] ✅ File loaded: 15234 bytes
[SIG_UPLOAD] URL: https://rlms.rlms.co.za/mobile/save_signature.php
[SIG_UPLOAD] Sending request...
[SIG_UPLOAD] Response status: 200
[SIG_UPLOAD] ✅ signature uploaded successfully
```

## What Happens If You Don't Rebuild

❌ **Uploads will continue to fail**
- Every upload attempt will throw `NoSuchMethodError: _checkConnectivity`
- Files will save locally only
- Database gets filename, but server never receives file
- PDFs show broken images
- No error visible to user (fails silently)

## Files Changed
- `lib/LearnerDetailsPage.dart` (added `_checkConnectivity()` method + enhanced logging)

## Additional Changes in This Build
✅ Enhanced signature upload logging  
✅ Enhanced image upload logging  
✅ Added file existence checks before upload  
✅ Added timeout handling (30 seconds)  
✅ Added stack trace logging for debugging  

---

**NEXT ACTION**: Run the rebuild commands above

## iOS Build

⚠️ **iOS builds cannot be done on Windows** - requires macOS with Xcode.

**See full iOS instructions**: `BUILD_ANDROID_AND_IOS.md`

**Quick iOS build** (on Mac only):
```bash
cd ~/projects/rlmss
flutter clean && flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release
```

**Don't have a Mac?**  
- Use **Codemagic.io** (free cloud Mac builds)
- Or rent Mac: MacStadium, AWS EC2 Mac, MacinCloud
- Or focus on Android only for now
