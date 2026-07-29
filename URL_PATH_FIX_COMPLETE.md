# 🔧 URL PATH FIX - DOUBLE /mobile/ REMOVED

**Date:** July 15, 2026  
**Issue:** 404 error caused by double `/mobile/` in URL path

---

## 🔴 ROOT CAUSE IDENTIFIED

The app was constructing URLs with **DOUBLE `/mobile/`** path:

### Before (WRONG):
```dart
Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_toolkit_edits.php')
```

Since `AppConfig.baseUrl` = `https://rlms.rlms.co.za/mobile`, this created:
```
https://rlms.rlms.co.za/mobile/mobile/save_arpl_toolkit_edits.php  ← 404!
```

### After (CORRECT):
```dart
Uri.parse('${AppConfig.baseUrl}/save_arpl_toolkit_edits.php')
```

Now creates:
```
https://rlms.rlms.co.za/mobile/save_arpl_toolkit_edits.php  ← ✅
```

---

## ✅ FIXES APPLIED

### File: `lib/ArplToolkitViewerPage.dart`

**Fix 1 - Line ~289: Appendix B/D/E Save**
```dart
// BEFORE:
Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_toolkit_edits.php')

// AFTER:
Uri.parse('${AppConfig.baseUrl}/save_arpl_toolkit_edits.php')
```

**Fix 2 - Line ~336: Appendix F Save**
```dart
// BEFORE:
Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_appendix_f_assessment.php')

// AFTER:
Uri.parse('${AppConfig.baseUrl}/save_arpl_appendix_f_assessment.php')
```

---

## 📋 WHY THIS HAPPENED

From `lib/config.dart`:
```dart
static const String basePath = '/mobile';

static String get baseUrl {
  final url = includePort
      ? '$serverProtocol://$serverHost:$serverPort$basePath'
      : '$serverProtocol://$serverHost$basePath';
  print('[CONFIG] Base URL: $url');
  return url;
}
```

So `baseUrl` **ALREADY CONTAINS** `/mobile`:
```
baseUrl = "https://rlms.rlms.co.za/mobile"
```

When the code added `/mobile/` again, it created the double path.

---

## 🎯 CORRECT URL PATTERNS

### ✅ CORRECT (Used in most of the app):
```dart
Uri.parse('${AppConfig.baseUrl}/endpoint.php')
// Result: https://rlms.rlms.co.za/mobile/endpoint.php
```

### ✅ CORRECT (Using config properties):
```dart
Uri.parse(AppConfig.saveArplAppendixBUrl)
// Result: https://rlms.rlms.co.za/mobile/save_arpl_appendix_b.php
```

### ❌ WRONG (Double path):
```dart
Uri.parse('${AppConfig.baseUrl}/mobile/endpoint.php')
// Result: https://rlms.rlms.co.za/mobile/mobile/endpoint.php ← 404!
```

---

## 🔍 OTHER FILES CHECKED

I searched for similar issues across the codebase:

```bash
grep -r "baseUrl}/mobile/" lib/
```

**Result:** No other instances found ✅

Only `ArplToolkitViewerPage.dart` had this issue, and both occurrences have been fixed.

---

## 🧪 VERIFICATION

### Test URLs Now Generated:

| Endpoint | Generated URL | Status |
|----------|---------------|--------|
| Toolkit Save (B+D+E) | `https://rlms.rlms.co.za/mobile/save_arpl_toolkit_edits.php` | ✅ CORRECT |
| Appendix F Save | `https://rlms.rlms.co.za/mobile/save_arpl_appendix_f_assessment.php` | ✅ CORRECT |

### Server-Side Verification:

Both files exist on server:
- ✅ `mobile/save_arpl_toolkit_edits.php` (11,420 bytes)
- ✅ `mobile/save_arpl_appendix_f_assessment.php` (exists)

---

## 📱 NEXT STEPS

### 1. Rebuild the APK

Since we changed the Dart code, you **MUST rebuild the APK**:

```bash
flutter clean
flutter build apk --release
```

**APK Location:**
```
build/app/outputs/flutter-apk/app-release.apk
```

### 2. Install New APK

- Uninstall old app from device
- Install new APK: `app-release.apk`
- Login as Facilitator ID 6

### 3. Test the Fix

1. Menu → **View Complete Toolkit**
2. Select **Anele Cele** (Class 797)
3. Edit any rating
4. Tap **Save All Changes**
5. **Expected Result:** Success message (no more 404!) ✅

---

## ⚠️ CRITICAL

**YOU MUST REBUILD AND REINSTALL THE APK!**

The old APK has the wrong URL paths hardcoded. Simply uploading the PHP file won't fix it if you're using the old APK.

### Why Server Endpoint Alone Wasn't Enough:

1. ✅ Server file exists at: `mobile/save_arpl_toolkit_edits.php`
2. ❌ Old APK calls: `mobile/mobile/save_arpl_toolkit_edits.php`
3. 🔧 New APK calls: `mobile/save_arpl_toolkit_edits.php` ← Will work!

---

## 📊 SUMMARY

| Issue | Root Cause | Solution | Status |
|-------|------------|----------|--------|
| 404 Error | Double `/mobile/` in URL | Remove extra `/mobile/` | ✅ FIXED |
| Server File | Was missing | Created and uploaded | ✅ EXISTS |
| App Code | Wrong URL construction | Fixed in ArplToolkitViewerPage | ✅ FIXED |
| **Action Required** | **Old APK still in use** | **Rebuild & reinstall APK** | ⚠️ **PENDING** |

---

## 🎯 EXPECTED RESULT

After rebuilding and installing new APK:

```
OLD APK: https://rlms.rlms.co.za/mobile/mobile/save_arpl_toolkit_edits.php → 404 ❌
NEW APK: https://rlms.rlms.co.za/mobile/save_arpl_toolkit_edits.php → 200 ✅
```

---

**File Modified:** `lib/ArplToolkitViewerPage.dart`  
**Lines Changed:** ~289, ~336  
**Changes:** Removed duplicate `/mobile/` from URL paths  
**Next Step:** REBUILD APK ⚠️  
**Status:** Code fixed, awaiting APK rebuild
