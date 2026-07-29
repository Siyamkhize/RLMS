# 🔨 REBUILD APK NOW - URL FIX APPLIED

## ⚠️ CRITICAL: YOU MUST REBUILD THE APK

The 404 error was caused by **wrong URL paths in the Dart code**.

Even though the server file exists, your **old APK** has the wrong URLs hardcoded.

---

## 🔧 WHAT WAS FIXED

**File:** `lib/ArplToolkitViewerPage.dart`

**Problem:**
```dart
// OLD CODE (WRONG):
Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_toolkit_edits.php')
// Creates: https://rlms.rlms.co.za/mobile/mobile/... ← 404!
```

**Solution:**
```dart
// NEW CODE (CORRECT):
Uri.parse('${AppConfig.baseUrl}/save_arpl_toolkit_edits.php')
// Creates: https://rlms.rlms.co.za/mobile/... ← ✅
```

---

## 📱 REBUILD STEPS

### Option 1: Quick Rebuild (Recommended)

```cmd
cd c:\projects\rlmss
flutter clean
flutter build apk --release
```

### Option 2: Full Clean Build

```cmd
cd c:\projects\rlmss
flutter clean
flutter pub get
flutter build apk --release
```

---

## 📦 INSTALL NEW APK

1. **Locate the APK:**
   ```
   c:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk
   ```

2. **Transfer to device:**
   - USB cable, or
   - Email, or
   - WhatsApp, or
   - Google Drive

3. **Install:**
   - Uninstall old app first (optional but recommended)
   - Install `app-release.apk`
   - Allow "Install from Unknown Sources" if prompted

---

## ✅ TEST AFTER INSTALLING NEW APK

1. Login as **Facilitator ID 6**
2. Go to: **Menu → View Complete Toolkit**
3. Select: **Anele Cele (Class 797)**
4. Edit any rating in Appendix B, D, or E
5. Tap: **Save All Changes**
6. **Expected:** Success message ✅ (NO MORE 404!)

---

## 🔍 HOW TO VERIFY URL IS CORRECT

Add this debug line before the POST request in `ArplToolkitViewerPage.dart` (line ~289):

```dart
final url = '${AppConfig.baseUrl}/save_arpl_toolkit_edits.php';
print('🔗 Calling URL: $url');

final response1 = await http.post(
  Uri.parse(url),
  ...
);
```

**Expected console output:**
```
🔗 Calling URL: https://rlms.rlms.co.za/mobile/save_arpl_toolkit_edits.php
```

**NOT:**
```
🔗 Calling URL: https://rlms.rlms.co.za/mobile/mobile/save_arpl_toolkit_edits.php ← WRONG!
```

---

## 📊 BUILD CHECKLIST

- [ ] Run `flutter clean`
- [ ] Run `flutter build apk --release`
- [ ] Build completes successfully
- [ ] APK created in `build/app/outputs/flutter-apk/`
- [ ] Transfer APK to device
- [ ] Uninstall old app (optional)
- [ ] Install new APK
- [ ] Test save functionality
- [ ] Verify no 404 errors

---

## ⏱️ BUILD TIME

- **Clean:** ~30 seconds
- **Build APK:** ~5-10 minutes
- **Total:** ~10 minutes

---

## 🎯 SUMMARY

**Problem:** Old APK calling wrong URL with double `/mobile/`  
**Solution:** Fixed URL paths in `ArplToolkitViewerPage.dart`  
**Action:** Rebuild APK and reinstall  
**Build Command:** `flutter build apk --release`  
**Test:** Menu → View Complete Toolkit → Save  
**Expected:** Success (no 404) ✅

---

**Status:** Ready to rebuild  
**Priority:** 🔴 HIGH  
**Estimated Time:** 10 minutes
