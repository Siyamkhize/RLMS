# ⚡ START BUILD NOW

**Copy and paste these commands** into PowerShell to build for Android:

---

## 🤖 Android Build (Do This Now)

```powershell
cd c:\projects\rlmss
flutter clean
flutter pub get
flutter build apk --release
```

**Wait for**: `✓ Built build\app\outputs\flutter-apk\app-release.apk`

---

## 📦 Find Your APK

```powershell
explorer build\app\outputs\flutter-apk\
```

**File**: `app-release.apk`

---

## 📲 Install on Android Device

### Option 1: USB Cable
```powershell
adb devices
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

### Option 2: Copy to Device
1. Copy `app-release.apk` to your phone
2. Open file on phone
3. Click "Install"
4. If blocked, enable "Install from Unknown Sources"

---

## 🧪 Test Immediately

1. Open app
2. Login as **SDP user**
3. Go to **Learner Details**
4. Capture a **signature**
5. **Look for**: "Signature uploaded successfully" ✅

---

## 🍎 iOS Build (Optional - Needs Mac)

**Don't have a Mac?** → Use Codemagic.io (free)

**Have a Mac?** Run this:
```bash
cd ~/projects/rlmss
flutter clean && flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release
```

---

## 🚨 Build Failed?

Run diagnostics:
```powershell
flutter doctor -v
```

Should show:
```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain
```

If not, install missing components.

---

## ✅ After Build

**Test**: See `UPLOAD_FIX_QUICK_REFERENCE.md`  
**Details**: See `BUILD_SUMMARY_ANDROID_IOS.md`  
**iOS Guide**: See `IOS_BUILD_QUICK_GUIDE.md`

---

**NEXT**: Copy the Android build commands above and run them now! ⬆️
