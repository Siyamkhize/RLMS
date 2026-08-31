# iOS Build Quick Guide

**⚠️ IMPORTANT**: iOS builds require macOS - you cannot build on Windows

---

## Prerequisites Checklist

- [ ] macOS computer (10.15 Catalina or later)
- [ ] Xcode 14.0+ installed (from App Store)
- [ ] Flutter SDK installed
- [ ] CocoaPods installed (`sudo gem install cocoapods`)
- [ ] Apple Developer account (for App Store, $99/year)

---

## Build Commands (Mac Only)

```bash
# Navigate to project
cd ~/projects/rlmss

# Clean previous build
flutter clean

# Get dependencies
flutter pub get

# Install iOS dependencies
cd ios
pod install
cd ..

# Build for testing on device
flutter build ios --release

# OR build for App Store distribution
flutter build ipa --release
```

---

## Output Locations

**Device build**: `build/ios/iphoneos/Runner.app`  
**App Store build**: `build/ios/ipa/rlmss.ipa`

---

## Install on iPhone

### Method 1: Xcode (Easiest)
```bash
open ios/Runner.xcworkspace
```
Then: Product → Run (⌘+R)

### Method 2: Command Line
```bash
flutter install --release
```
(Device must be connected via USB)

### Method 3: TestFlight (For Distribution)
1. Upload IPA to App Store Connect
2. Create TestFlight beta
3. Invite testers via email
4. They install from TestFlight app

---

## Don't Have a Mac?

### Option 1: Cloud Mac (Recommended)
**Codemagic** - https://codemagic.io
- Free for open source
- Connect GitHub repo
- Auto-build on push
- Download IPA when ready

### Option 2: Rent Mac by the Hour
- **MacStadium**: https://macstadium.com
- **MacinCloud**: https://macincloud.com  
- **AWS EC2 Mac**: https://aws.amazon.com/ec2/instance-types/mac/

### Option 3: Use GitHub Actions
```yaml
# .github/workflows/ios.yml
name: iOS Build
on: [push]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: cd ios && pod install && cd ..
      - run: flutter build ipa --release
      - uses: actions/upload-artifact@v2
        with:
          name: ipa
          path: build/ios/ipa/*.ipa
```

---

## Common Issues

### "No code signing identity"
**Fix**: Open Xcode → Preferences → Accounts → Sign in with Apple ID

### "pod install fails"
**Fix**:
```bash
cd ios
pod repo update
pod install --repo-update
cd ..
```

### "Architecture not found"
**Fix**: Update `ios/Podfile`:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
```

---

## Testing iOS Build

After installation:
1. Open app on iPhone
2. Login as SDP user
3. Go to Learner Details
4. Capture signature
5. **Expect**: "Signature uploaded successfully"

View logs:
```bash
flutter logs | grep "SIG_UPLOAD\|CONNECTIVITY"
```

---

## Distribution Options

### 1. TestFlight (Beta Testing)
- Free with Apple Developer account
- Up to 10,000 testers
- Builds expire after 90 days

### 2. App Store (Public Release)
- Requires App Store review
- Takes 1-3 days for approval
- Available to all iOS users

### 3. Ad Hoc (Internal Testing)
- Limited to 100 devices per year
- Requires device UDIDs
- No review needed

### 4. Enterprise (Company Only)
- Requires Enterprise account ($299/year)
- Unlimited internal distribution
- Cannot distribute publicly

---

## Quick Comparison

| Method | Cost | Build Location | Difficulty |
|--------|------|----------------|------------|
| **Own Mac** | Mac cost | Local | Easy |
| **Codemagic** | Free tier | Cloud | Easiest |
| **GitHub Actions** | Free | Cloud | Medium |
| **Rent Mac** | $20-50/month | Cloud | Easy |

---

## Need Help?

Check Flutter doctor:
```bash
flutter doctor -v
```

Should show:
```
[✓] Xcode - develop for iOS
[✓] CocoaPods version X.X.X
```

---

**Full details**: See `BUILD_ANDROID_AND_IOS.md`  
**Testing guide**: See `UPLOAD_FIX_QUICK_REFERENCE.md`
