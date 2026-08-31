# Build Summary - Android & iOS

**Date**: August 28, 2026  
**Fix**: Signature/Image Upload - Missing Connectivity Check  
**Impact**: CRITICAL - Uploads don't work until rebuilt  

---

## 🎯 What You Need to Do

### ✅ Android (You Can Do Now - Windows)
```powershell
cd c:\projects\rlmss
flutter clean
flutter pub get
flutter build apk --release
```
**Output**: `build\app\outputs\flutter-apk\app-release.apk`  
**Time**: 5-10 minutes  
**Install**: `adb install -r build\app\outputs\flutter-apk\app-release.apk`

### ⚠️ iOS (Requires Mac)
**Option 1**: If you have a Mac
```bash
flutter clean && flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release
```
**Output**: `build/ios/ipa/rlmss.ipa`  
**Time**: 10-20 minutes

**Option 2**: If you DON'T have a Mac  
→ Use **Codemagic.io** (free cloud Mac builds)  
→ Or rent Mac: MacStadium, MacinCloud, AWS EC2 Mac  
→ Or skip iOS for now, focus on Android

---

## 📱 Platform Quick Facts

| | Android | iOS |
|---|---------|-----|
| **Build on Windows?** | ✅ Yes | ❌ No (needs Mac) |
| **Developer Account?** | Not needed | $99/year for App Store |
| **Easy Distribution?** | ✅ APK file sharing | ⚠️ TestFlight or App Store |
| **Build Time** | 5-10 min | 10-20 min |
| **Testing** | Side-load APK | Xcode or TestFlight |

---

## 🔗 Documentation Files

### Build Guides
- `REBUILD_FOR_UPLOAD_FIX.md` - Android step-by-step
- `BUILD_ANDROID_AND_IOS.md` - Complete dual-platform guide
- `IOS_BUILD_QUICK_GUIDE.md` - iOS-specific reference

### Testing
- `UPLOAD_FIX_QUICK_REFERENCE.md` - Quick test checklist
- `SIGNATURE_IMAGE_UPLOAD_FIX_COMPLETE.md` - Technical details

---

## 🧪 How to Test After Building

### Both Platforms
1. Install new build
2. Login as SDP user
3. Go to any Learner Details page
4. Capture signature or profile image
5. **Expect**: "Signature uploaded successfully" or "Image uploaded successfully"
6. **Verify**: File exists on server at `/mobile/signatures/` or `/mobile/learnerImages/`

### Android Logs
```powershell
adb logcat | Select-String "SIG_UPLOAD|IMG_UPLOAD|CONNECTIVITY"
```

### iOS Logs (Mac)
```bash
flutter logs | grep "SIG_UPLOAD\|IMG_UPLOAD\|CONNECTIVITY"
```

**Success indicators**:
```
[CONNECTIVITY] ✅ ONLINE (Status: 200)
[SIG_UPLOAD] ✅ File loaded: 15234 bytes
[SIG_UPLOAD] Response status: 200
[SIG_UPLOAD] ✅ signature uploaded successfully
```

---

## ⚡ Quick Commands

### Android (One-liner)
```powershell
cd c:\projects\rlmss ; flutter clean ; flutter pub get ; flutter build apk --release
```

### iOS (One-liner, Mac only)
```bash
cd ~/projects/rlmss && flutter clean && flutter pub get && cd ios && pod install && cd .. && flutter build ipa --release
```

---

## 🚨 What Happens If You Don't Rebuild?

❌ **Current APK/IPA will continue to fail**:
- Uploads throw `NoSuchMethodError: _checkConnectivity`
- Files save locally only (not to server)
- Database has filenames but server has no actual files
- PDFs show broken image links
- Users see no error (fails silently)

✅ **After rebuild**:
- Connectivity check works
- Files upload to server immediately when online
- Database and filesystem in sync
- PDFs display signatures/images correctly
- Success messages shown to user

---

## 💡 Recommendations

### If You Have Both Android & iOS Users
1. **Build Android first** (you can do now on Windows)
2. **Deploy to Android devices** for immediate testing
3. **Arrange iOS build** via Mac/cloud service
4. **Deploy to iPhones** when ready

### If You're Android-Only
- Build APK now
- Test thoroughly
- Deploy to all Android devices
- Skip iOS sections

### If You're iOS-Only
- Use Codemagic.io (easiest for first-time iOS build)
- Or find someone with a Mac
- Or rent cloud Mac temporarily

---

## 📞 Need Help?

### Build Won't Complete?
```powershell
# Check Flutter installation
flutter doctor -v

# Should show:
# [✓] Flutter
# [✓] Android toolchain
# [✓] Xcode (on Mac)
```

### Upload Still Failing After Rebuild?
1. Check logs for `[CONNECTIVITY]` messages
2. Verify `AppConfig.saveSignatureUrl` is correct
3. Check server permissions on `/mobile/signatures/` folder
4. Test server endpoint directly: `curl https://rlms.rlms.co.za/mobile/save_signature.php`

### Can't Install on Device?
**Android**: Enable "Install from Unknown Sources"  
**iOS**: Trust developer certificate in Settings → General → Device Management

---

## ✅ Success Checklist

### Android
- [ ] APK built successfully
- [ ] APK installed on test device
- [ ] Login works
- [ ] Signature capture works
- [ ] Success message appears
- [ ] File visible on server
- [ ] Logs show `[CONNECTIVITY] ✅ ONLINE`

### iOS
- [ ] IPA built successfully (or via cloud)
- [ ] IPA installed on test iPhone
- [ ] Login works
- [ ] Signature capture works
- [ ] Success message appears
- [ ] File visible on server
- [ ] Logs show `[CONNECTIVITY] ✅ ONLINE`

---

**START HERE**: Run Android build commands at top of this file  
**THEN**: Follow testing guide in `UPLOAD_FIX_QUICK_REFERENCE.md`
