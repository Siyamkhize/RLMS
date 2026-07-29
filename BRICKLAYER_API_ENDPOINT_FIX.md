# BRICKLAYER API ENDPOINT FIX - COMPLETE

**Date:** July 10, 2026  
**Status:** FIXED ✅  
**APK Version:** 45.8 MB (Release Build)

---

## Problem

**Error:** "type 'List<dynamic>' is not a subtype of type 'Map<dynamic, dynamic>'"  
**Page:** ArplToolkitBricklayerPage  
**Cause:** Wrong API endpoint being called

---

## Root Cause

The bricklayer toolkit page was calling the **generic electrician API** instead of the **bricklayer-specific API**:

**Wrong:**
```dart
Uri.parse(AppConfig.getArplToolkitDataUrl)  // Points to: get_arpl_toolkit_data.php (electrician/plumber generic)
```

**Correct:**
```dart
Uri.parse(AppConfig.getBricklayerToolkitDataUrl)  // Points to: get_bricklayer_toolkit_data.php
```

---

## Fix Applied

**File:** `lib/ArplToolkitBricklayerPage.dart` (Line 125)

Changed the API endpoint from generic to bricklayer-specific:

```dart
// BEFORE
final response = await http.post(
  Uri.parse(AppConfig.getArplToolkitDataUrl),  // ❌ Wrong - generic API
  ...
);

// AFTER
final response = await http.post(
  Uri.parse(AppConfig.getBricklayerToolkitDataUrl),  // ✅ Correct - bricklayer API
  ...
);
```

---

## Why This Matters

**API Endpoints:**
- `get_arpl_toolkit_data.php` - Generic electrician/plumber toolkit (uses trade classification)
- `get_bricklayer_toolkit_data.php` - **Bricklayer-specific** toolkit (uses bricklayer OFO 641201 for workplace activities)

**Response Structure:**
The bricklayer API returns data that includes:
- ✅ Appendix B: 17 theory activities
- ✅ Appendix E: 15 workplace observation activities (OFO 641201)

---

## Data Flow - CORRECTED

```
Learner opens Bricklayer Toolkit
  ↓
ArplToolkitBricklayerPage loads
  ↓
Calls: getBricklayerToolkitDataUrl (get_bricklayer_toolkit_data.php)
  ↓
API returns proper response with:
  - appendixB: [array of 17 activities]
  - appendixE: [array of 15 activities]  ← Uses OFO 641201
  - appendixH: {...}
  ↓
ArplToolkitData.fromJson() parses correctly
  ↓
UI displays all appendices
```

---

## Verification

✅ **API Endpoint:** Now calls `get_bricklayer_toolkit_data.php`  
✅ **AppendixE:** Returns 15 workplace activities  
✅ **AppendixF:** Displays workplace observations  
✅ **Flutter Build:** Successful (45.8 MB)  
✅ **Installation:** SUCCESS  

---

## Files Modified

1. `lib/ArplToolkitBricklayerPage.dart` - Line 125: Changed endpoint to `getBricklayerToolkitDataUrl`

---

## Expected Behavior

When bricklayer learner opens toolkit:

1. **Appendix B:** Shows 17 theory activities ✅
2. **Appendix E:** Shows 15 workplace observation activities ✅
3. **Appendix F:** Displays workplace observations in card format ✅
4. **No errors:** Data loads successfully ✅

---

**APK Ready:** `build/app/outputs/flutter-apk/app-release.apk` ✅  
**Installation Status:** SUCCESS ✅
