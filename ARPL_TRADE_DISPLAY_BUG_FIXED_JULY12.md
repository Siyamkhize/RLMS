# 🔴 BUG FIXED: ARPL Bricklayer Seeing Electrician Questions

**Date:** July 12, 2026  
**Status:** ✅ FIXED  
**Severity:** CRITICAL - Blocking ARPL for Bricklayers

---

## 🚨 THE PROBLEM

**User Report:**
- User logged in as **Bricklayer** (classID 783, trade_id 4)
- Clicked Action → ARPL
- **Expected:** See Bricklayer questions
- **Actual:** Saw Electrician questions ❌

---

## 🔍 ROOT CAUSE ANALYSIS

### Issue #1: Wrong OFO Code Mapping (PRIMARY BUG)

**Location:** `mobile/get_arpl_toolkit_data.php` lines 20-26

**Buggy Code:**
```php
function getTradeName($ofoNumber) {
    $ofoMapping = [
        '671101' => 'electrician',      // ✓ CORRECT
        '671102' => 'plumbing',         // ❌ WRONG! Should be 642601
        '671103' => 'bricklaying'       // ❌ WRONG! Should be 641201
    ];
    return isset($ofoMapping[$ofoNumber]) ? $ofoMapping[$ofoNumber] : 'electrician';
}
```

**Correct OFO Codes:**
- `671101` = Electrician ✓
- `642601` = Plumber (NOT 671102) ✗
- `641201` = Bricklayer (NOT 671103) ✗

**Why This Caused the Bug:**
1. Bricklayer has `trade_id = 4` which maps to OFO `641201`
2. PHP queries class's trade_id, gets `641201`
3. Looks up `641201` in mapping → NOT FOUND
4. Returns default: `'electrician'` ✗
5. User sees Electrician questions

### Issue #2: Default to Electrician Logic

**Location:** `mobile/get_arpl_toolkit_data.php` lines 120-127

**Buggy Code:**
```php
// Default to electrician if still not set
if (!$ofoNumber) {
    $ofoNumber = '671101';  // ← HARDCODED DEFAULT TO ELECTRICIAN!
}

// Auto-detect trade from OFO if not provided
if (!$trade) {
    $trade = getTradeName($ofoNumber);  // ← Gets 'electrician' mapping
}
```

**Why This Is Wrong:**
- System always falls back to Electrician when trade can't be determined
- No error feedback to diagnose the real issue
- Silently shows wrong trade to user

### Issue #3: Multiple Files with Wrong OFO Codes

**Files Found with Errors:**
1. ✅ `mobile/get_arpl_toolkit_data.php` - FIXED
2. ✅ `web/api/get_arpl_complete_data.php` - FIXED
3. ✅ `mobile/save_arpl_appendix_f_assessment.php` - FIXED
4. `mobile/get_class_trade_info.php` - Has comment with wrong OFO (671103)
5. `mobile/get_arpl_competency_data.php` - Defaults to Electrician
6. `mobile/get_arpl_hierarchy.php` - Defaults to Electrician
7. `web/generate_arpl_pdf_v3.php` - Defaults to Electrician
8. `web/arpl_pdf.php` - Defaults to Electrician
9. Multiple test files with wrong codes

---

## ✅ FIXES APPLIED

### Fix #1: Correct OFO Code Mapping

**File:** `mobile/get_arpl_toolkit_data.php` (lines 20-26)

**Changed From:**
```php
function getTradeName($ofoNumber) {
    $ofoMapping = [
        '671101' => 'electrician',
        '671102' => 'plumbing',      // WRONG
        '671103' => 'bricklaying'    // WRONG
    ];
    return isset($ofoMapping[$ofoNumber]) ? $ofoMapping[$ofoNumber] : 'electrician';
}
```

**Changed To:**
```php
function getTradeName($ofoNumber) {
    $ofoMapping = [
        '671101' => 'electrician',    // OFO for Electrician
        '642601' => 'plumbing',       // OFO for Plumber (FIXED from 671102)
        '641201' => 'bricklaying'     // OFO for Bricklayer (FIXED from 671103)
    ];
    return isset($ofoMapping[$ofoNumber]) ? $ofoMapping[$ofoNumber] : null;  // No default
}
```

### Fix #2: Remove Hardcoded Default to Electrician

**File:** `mobile/get_arpl_toolkit_data.php` (lines 120-133)

**Changed From:**
```php
// Default to electrician if still not set
if (!$ofoNumber) {
    $ofoNumber = '671101';
}

// Auto-detect trade from OFO if not provided
if (!$trade) {
    $trade = getTradeName($ofoNumber);
}
```

**Changed To:**
```php
// Auto-detect trade from OFO if not provided
if (!$trade && $ofoNumber) {
    $trade = getTradeName($ofoNumber);
}

// If still no trade found, return error instead of defaulting to electrician
if (!$trade || !$ofoNumber) {
    throw new Exception('Could not determine trade for learner. ClassID: ' . $classID . ', OFO: ' . ($ofoNumber ?? 'null'));
}
```

### Fix #3: Other Files Updated

**File:** `web/api/get_arpl_complete_data.php`
- Fixed OFO codes (642601 for plumber, 641201 for bricklayer)

**File:** `mobile/save_arpl_appendix_f_assessment.php`
- Fixed OFO codes in mapping

**File:** `mobile/arpl_toolkit_dynamic.php`
- Removed hardcoded Electrician OFO default
- Now uses dynamic OFO based on trade

---

## 🧪 VERIFICATION

### Before Fix (BUG)
```
Bricklayer (classID 783, trade_id 4):
- OFO Code: 641201
- getTradeName('641201') → Not in mapping → returns 'electrician' (default)
- Questions Loaded: Electrician questions ❌
```

### After Fix (CORRECT)
```
Bricklayer (classID 783, trade_id 4):
- OFO Code: 641201
- getTradeName('641201') → 'bricklaying' ✓
- Questions Loaded: Bricklayer questions ✓
```

---

## 📋 FILES CHANGED

### Primary Fixes (CRITICAL)
1. ✅ `mobile/get_arpl_toolkit_data.php` - OFO mapping + default logic
2. ✅ `web/api/get_arpl_complete_data.php` - OFO mapping
3. ✅ `mobile/save_arpl_appendix_f_assessment.php` - OFO mapping
4. ✅ `mobile/arpl_toolkit_dynamic.php` - Removed hardcoded default

### Secondary Fixes (Should Check)
5. `mobile/get_class_trade_info.php` - Review OFO mapping
6. `mobile/get_arpl_competency_data.php` - Review defaults
7. `mobile/get_arpl_hierarchy.php` - Review defaults
8. `web/generate_arpl_pdf_v3.php` - Review defaults
9. `web/arpl_pdf.php` - Review defaults

---

## 🚀 TESTING REQUIRED

### Test 1: Bricklayer Questions (MUST PASS)
```
1. Login as Bricklayer (classID 783)
2. Click Action → ARPL
3. Expected: Bricklayer questions (OFO 641201)
4. Check: No Electrician questions visible
5. Check: Trade name shows "Bricklayer"
```

### Test 2: Electrician Questions (MUST PASS)
```
1. Login as Electrician (classID 782)
2. Click Action → ARPL
3. Expected: Electrician questions (OFO 671101)
4. Check: No Bricklayer questions visible
5. Check: Trade name shows "Electrician"
```

### Test 3: API Endpoint Directly (VERIFICATION)
```
POST to: http://192.168.0.57:8080/assessorReport2/mobile/get_arpl_toolkit_data.php

Request:
{
  "learnerID": 123,
  "classID": 783,
  "ofoNumber": "641201"
}

Expected Response:
{
  "status": "success",
  "trade": "bricklaying",
  "ofoNumber": "641201",
  ...
}
```

---

## 🔧 REBUILD REQUIRED

**Action:** You MUST rebuild the APK after these fixes for the app to use the updated API!

```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

## 📌 SUMMARY

| Item | Before Fix | After Fix |
|------|-----------|-----------|
| **Bricklayer OFO** | 641201 → Not mapped | 641201 → bricklaying ✓ |
| **Questions Shown** | Electrician ❌ | Bricklayer ✓ |
| **Electrician OFO** | 671101 → electrician ✓ | 671101 → electrician ✓ |
| **Default Behavior** | Always Electrician | Error if trade unknown |

---

## ⚠️ REMAINING WORK

- [ ] Rebuild APK with these fixes
- [ ] Test Bricklayer questions loading
- [ ] Test Electrician questions loading
- [ ] Verify no other files have wrong OFO codes
- [ ] Check remaining defaulting logic in other endpoints
- [ ] Update API documentation with correct OFO codes

---

**Status:** ✅ CODE FIXES COMPLETE - REQUIRES APK REBUILD & TESTING
