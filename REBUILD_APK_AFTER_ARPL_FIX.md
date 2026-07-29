# 🔧 ACTION REQUIRED: Rebuild APK After ARPL Bug Fix

**Date:** July 12, 2026  
**Status:** Code fixes complete, APK rebuild required  
**Time Estimate:** 15-20 minutes

---

## 🚨 CRITICAL: YOU MUST REBUILD THE APK

The Flutter app is still using the OLD API code that defaults to Electrician questions.

**What was fixed:**
- ✅ PHP API OFO code mapping (641201 = Bricklayer)
- ✅ Removed hardcoded Electrician defaults
- ✅ Added error messages if trade can't be determined

**What still needs to happen:**
- ⏳ Rebuild APK with these server changes

---

## 🏗️ REBUILD STEPS

### Step 1: Navigate to Project
```bash
cd c:\projects\rlmss
```

### Step 2: Clean Build
```bash
flutter clean
```

### Step 3: Get Dependencies
```bash
flutter pub get
```

### Step 4: Build APK (Release)
```bash
flutter build apk --release
```

**Expected Output:**
```
✓ Built build/app/outputs/flutter-apk/app-release.apk (xx MB)
```

### Step 5: Locate APK
```
Build Location: c:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk
```

---

## ✅ VERIFICATION AFTER BUILD

### Check 1: APK File Size
- Expected: ~48-50 MB (similar to previous)
- If much larger: Something may be wrong

### Check 2: Install on Device
```bash
flutter install
```

Or manually via Android Device:
1. Connect device via USB
2. Copy APK to device
3. Tap to install
4. Grant permissions

### Check 3: Test Bricklayer Questions
1. Login as Bricklayer user (classID 783)
2. Go to ARPL
3. **Should show:** Bricklayer questions
4. **Should NOT show:** Electrician questions

### Check 4: Test Electrician Questions
1. Login as Electrician user (classID 782)
2. Go to ARPL
3. **Should show:** Electrician questions
4. **Should NOT show:** Bricklayer questions

---

## 📊 PROGRESS TRACKING

- [x] Identified root cause (wrong OFO codes)
- [x] Fixed PHP API code (4 files)
- [x] Removed hardcoded defaults
- [ ] **← YOU ARE HERE**
- [ ] Rebuild APK
- [ ] Install on test device
- [ ] Verify Bricklayer sees correct questions
- [ ] Verify Electrician sees correct questions
- [ ] Deploy to production

---

## 🆘 TROUBLESHOOTING

### Build Fails
```bash
# Try these in order:
flutter pub cache clean
flutter pub get
flutter clean
flutter build apk --release
```

### APK Too Large (>100 MB)
```bash
# This usually means build artifacts not cleaned
flutter clean
flutter build apk --release --shrink
```

### Installation Fails
```bash
# Uninstall old version first
adb uninstall com.example.rlmss  # (adjust package name as needed)
flutter install
```

### App Still Shows Electrician Questions After Update
1. **Clear app cache:**
   - Settings → Apps → RLMSS → Storage → Clear Cache
2. **Close and reopen app**
3. **Force logout and login again**
4. If still broken → Check server is actually running the new PHP code

---

## 📱 DEPLOYMENT

### To Users
Once verified working locally:
1. Upload new APK to distribution server
2. Notify Bricklayer users to update app
3. Monitor for any issues
4. Track in support tickets

### Rollback Plan
If something goes wrong:
1. Keep previous APK available
2. Can easily switch back if needed
3. Document what went wrong

---

## 📞 NEXT STEPS

1. **Run the rebuild:** `flutter build apk --release`
2. **Install on test device**
3. **Run verification tests** (Test Bricklayer & Electrician questions)
4. **Report back with results**

---

**Status:** Ready for rebuild  
**Estimated Time:** 15-20 minutes for rebuild + testing
