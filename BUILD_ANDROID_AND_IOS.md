# Build for Android & iOS - Upload Fix

**Date**: August 28, 2026  
**Fix**: Signature/Image upload connectivity check added  
**Platforms**: Android (APK) + iOS (IPA)

---

## 🤖 Android Build (APK)

### Step 1: Clean Previous Build
```powershell
cd c:\projects\rlmss
flutter clean
```

### Step 2: Get Dependencies
```powershell
flutter pub get
```

### Step 3: Build Release APK
```powershell
flutter build apk --release
```

**Build time**: ~5-10 minutes  
**Expected output**:
```
✓ Built build\app\outputs\flutter-apk\app-release.apk (XX.XMB)
```

### Step 4: Locate APK
```
c:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk
```

### Step 5: Install on Android Device
```powershell
# Via USB
adb devices
adb install -r build\app\outputs\flutter-apk\app-release.apk

# Or copy to device and install manually
```

---

## 🍎 iOS Build (IPA)

### Prerequisites
⚠️ **iOS builds require macOS with Xcode**  
You cannot build iOS apps on Windows. You need:
- macOS computer (or Mac in cloud/VM)
- Xcode 14.0 or later
- Apple Developer account (for distribution)
- CocoaPods installed

### Option A: Build on Mac

#### Step 1: Transfer Project to Mac
```bash
# On Mac, clone or copy the project
cd ~/projects
# Copy project files from Windows machine
```

#### Step 2: Clean & Install Dependencies
```bash
cd ~/projects/rlmss
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

#### Step 3: Build iOS Release
```bash
# For testing on device (no App Store)
flutter build ios --release

# For App Store distribution
flutter build ipa --release
```

**Build time**: ~10-20 minutes  
**Output location**:
```
build/ios/iphoneos/Runner.app  # Device build
build/ios/ipa/rlmss.ipa        # App Store build
```

#### Step 4: Install on iPhone
```bash
# Using Xcode
open ios/Runner.xcworkspace
# Then: Product > Run (Cmd+R)

# Using command line (requires device connected)
flutter install --release
```

### Option B: Use Cloud Mac (Codemagic, CircleCI)

If you don't have a Mac, use a cloud service:

1. **Codemagic** (easiest): https://codemagic.io
   - Connect GitHub repo
   - Configure iOS build workflow
   - Download IPA when ready

2. **CircleCI**: https://circleci.com
   - Use macOS executor
   - Configure flutter build

3. **GitHub Actions** (if using GitHub)
   - Use `macos-latest` runner
   - Add workflow for iOS build

### Option C: Remote Mac Access

1. **MacStadium**: Rent Mac in cloud
2. **AWS EC2 Mac**: Amazon Mac instances
3. **MacinCloud**: Hourly Mac rental

---

## 📱 Platform-Specific Notes

### Android
- ✅ Can build on Windows, Mac, or Linux
- ✅ No Apple account needed
- ✅ Easy side-loading for testing
- ✅ APK can be distributed via file sharing

### iOS
- ❌ Requires macOS to build
- ❌ Requires Apple Developer account ($99/year for distribution)
- ⚠️ TestFlight needed for easy distribution
- ⚠️ Cannot side-load easily (needs Xcode or TestFlight)

---

## 🔧 iOS-Specific Configuration Check

Before building iOS, verify these files:

### 1. Check `ios/Podfile`
Should have platform version >= 12.0:
```ruby
platform :ios, '12.0'
```

### 2. Check `ios/Runner/Info.plist`
Should have required permissions:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera is required for capturing learner photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access for signature images</string>
```

### 3. Check Bundle Identifier
File: `ios/Runner.xcodeproj/project.pbxproj`
Should have unique bundle ID like:
```
PRODUCT_BUNDLE_IDENTIFIER = za.co.rlms.rlmss;
```

---

## 📦 Distribution Options

### Android Distribution
1. **Direct APK**: Share file via USB, email, cloud storage
2. **Google Play Store**: Upload to Play Console
3. **Internal Testing**: Firebase App Distribution, TestFlight equivalent

### iOS Distribution
1. **TestFlight**: Beta testing (requires App Store Connect)
2. **App Store**: Full public release
3. **Enterprise**: In-house distribution (requires Enterprise account $299/year)
4. **Ad Hoc**: Limited to 100 devices (requires developer account)

---

## 🧪 Testing the Fix

### Both Platforms
1. Login as SDP user
2. Go to Learner Details
3. Capture signature
4. **Expect**: "Signature uploaded successfully"
5. Verify file on server: `https://rlms.rlms.co.za/mobile/signatures/`

### Android Logs
```powershell
adb logcat | Select-String "SIG_UPLOAD|IMG_UPLOAD|CONNECTIVITY"
```

### iOS Logs
```bash
# On Mac, with device connected
flutter logs | grep "SIG_UPLOAD\|IMG_UPLOAD\|CONNECTIVITY"

# Or in Xcode: Window > Devices and Simulators > View Device Logs
```

---

## ⚡ Quick Commands Reference

### Android (Windows)
```powershell
flutter clean ; flutter pub get ; flutter build apk --release
```

### iOS (Mac)
```bash
flutter clean && flutter pub get && cd ios && pod install && cd .. && flutter build ipa --release
```

---

## 🚨 Common iOS Build Issues

### Issue: "No valid code signing identity"
**Solution**: Open Xcode, sign in with Apple ID, let Xcode manage signing

### Issue: "Pod install fails"
**Solution**:
```bash
cd ios
pod repo update
pod install
cd ..
```

### Issue: "Flutter not found"
**Solution**: 
```bash
export PATH="$PATH:$HOME/flutter/bin"
flutter doctor
```

### Issue: "Architecture arm64 not found"
**Solution**: Update Podfile:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end
```

---

## 📋 Build Checklist

### Android ✅
- [ ] Run `flutter clean`
- [ ] Run `flutter pub get`
- [ ] Build with `flutter build apk --release`
- [ ] Locate APK in `build\app\outputs\flutter-apk\`
- [ ] Test on Android device
- [ ] Verify uploads work

### iOS ⚠️ (Requires Mac)
- [ ] Transfer project to Mac
- [ ] Run `flutter clean`
- [ ] Run `flutter pub get`
- [ ] Run `cd ios && pod install && cd ..`
- [ ] Build with `flutter build ipa --release`
- [ ] Locate IPA in `build/ios/ipa/`
- [ ] Install via Xcode or TestFlight
- [ ] Test on iPhone
- [ ] Verify uploads work

---

## 🆘 Need Help?

### Don't Have a Mac?
**Options**:
1. Use cloud Mac service (Codemagic recommended)
2. Borrow a Mac temporarily
3. Focus on Android only for now
4. Hire iOS build service (Fiverr, Upwork)

### Build Errors?
Check:
```bash
flutter doctor -v
flutter --version
```

All platforms should show:
```
Flutter 3.x.x
Dart 3.x.x
```

---

**Next**: After building, see `UPLOAD_FIX_QUICK_REFERENCE.md` for testing
