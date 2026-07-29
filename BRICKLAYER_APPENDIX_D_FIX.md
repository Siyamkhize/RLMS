# Bricklayer Appendix D Data Type Fix - July 10, 2026

## Issue Identified

**Error Message:**
```
[ArplToolkitData.fromJson] Error: type 'List<dynamic>' is not a subtype of type 'Map<dynamic, dynamic>'
```

**Root Cause:**
The bricklayer API endpoint (`mobile/get_bricklayer_toolkit_data.php`) was returning appendixD as an **empty array `[]`** instead of an **object `{}`**, causing the Dart model parser to fail when attempting to cast it to `Map<String, String>`.

## Files Modified

### 1. `mobile/get_bricklayer_toolkit_data.php`

**Changes Made:**
- Line 91-108: Refactored appendixD data loading to match electrician pattern
- Changed from building an array to building an object using property assignment
- Now properly creates `(object)[]` and uses `->` operator for property assignment
- Added saved_at metadata from database timestamps

**Before:**
```php
$appendixD = [];
if ($stmt) {
    // ... query execution ...
    if ($row = $result->fetch_assoc()) {
        for ($i = 1; $i <= 22; $i++) {
            $field = 'activity_' . $i;
            if (isset($row[$field])) {
                $appendixD[$field] = $row[$field];  // Array assignment
            }
        }
    }
}
// Then cast to object: (object)$appendixD
```

**After:**
```php
$appendixD = (object)[];  // Initialize as object directly
if ($appendixD_data) {
    for ($i = 1; $i <= 22; $i++) {
        $field = 'activity_' . $i;
        if (isset($appendixD_data[$field])) {
            $appendixD->{$field} = $appendixD_data[$field];  // Object property assignment
        }
    }
    $appendixD->saved_at = $appendixD_data['updated_at'] ?? $appendixD_data['created_at'] ?? null;
}
```

**Key Differences:**
1. Initialize as `(object)[]` before assignment (not after)
2. Use `->` operator for property assignment throughout
3. Consistent with electrician endpoint pattern (proven to work)
4. No intermediate array casting that could cause type issues

## Data Type Verification

### API Response Structure
The API now returns:

```json
{
  "appendixD": {
    "activity_1": "Yes",
    "activity_2": "No",
    "activity_3": "Yes",
    ...
    "activity_22": "Not Applicable",
    "saved_at": "2026-07-10 12:45:00"
  }
}
```

**Type:** Object (not Array)
**Parsed by Dart as:** `Map<String, String>`

## Testing Instructions

### Manual Test Steps:

1. **Install Updated APK**
   - Build: `flutter build apk --release`
   - Install: `adb install -r build/app/outputs/flutter-apk/app-release.apk`

2. **Navigate to Bricklayer Toolkit**
   - Open app
   - Select learner (Bricklaying class)
   - Go to ARPL Toolkit
   - Bricklayer form should load

3. **Monitor Debug Output**
   - Check logcat for: `[BRICKLAYER_TRACE]` and `[ArplToolkitData.fromJson]` logs
   - Expected: `✓ AppendixD parsed` message
   - Error would show: `type 'List<dynamic>' is not a subtype of type 'Map<dynamic, dynamic>'`

4. **Verify Appendix D Tab**
   - Appendix D tab should show practical skills assessment questions
   - Each question displays: Yes/No/Not Applicable buttons
   - If data was saved, previous responses should display

### Debug Log Signatures:

**Success Pattern:**
```
[BRICKLAYER_TRACE] ═══ TYPE CHECKING ═══
[BRICKLAYER_TRACE] appendixD type: _LinkedHashMap
[BRICKLAYER_TRACE] ═══ END TYPE CHECKING ═══
[ArplToolkitData.fromJson] Parsing appendixD...
[ArplToolkitData.fromJson] ✓ AppendixD parsed
[BRICKLAYER_TRACE] ✅ ArplToolkitData parsed successfully
```

**Failure Pattern (would show):**
```
[ArplToolkitData.fromJson] Error: type 'List<dynamic>' is not a subtype of type 'Map<dynamic, dynamic>'
[ArplToolkitData.fromJson] ═══ FATAL ERROR ═══
```

## Database Tables Required

For appendixD data to load, the following table must exist:

```sql
CREATE TABLE IF NOT EXISTS arpl_appendix_d_bricklayer (
    id INT PRIMARY KEY AUTO_INCREMENT,
    learnerID INT NOT NULL,
    activity_1 VARCHAR(50),
    activity_2 VARCHAR(50),
    ... (activity_1 through activity_22)
    activity_22 VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (learnerID) REFERENCES learnerdetails(LearnerID)
);
```

**Expected Values:** "Yes", "No", "Not Applicable", or NULL (empty)

## API Endpoint Details

**Endpoint:** `POST mobile/get_bricklayer_toolkit_data.php`

**Request:**
```json
{
  "learnerID": 70,
  "classID": 783
}
```

**Response (Relevant Section):**
```json
{
  "status": "success",
  "appendixD": {
    "activity_1": "Yes",
    "activity_2": "No",
    ...
  },
  ...
}
```

## Appendix D Display in UI

The bricklayer toolkit now displays Appendix D with:

1. **Section Title:** "Appendix D: PRACTICAL SKILLS ASSESSMENT"
2. **22 Practical Skills Items:**
   - Safety and health procedures
   - Hand and power tools
   - Measuring and marking equipment
   - Reading and interpreting architectural drawings
   - (and 18 more specific to bricklaying)

3. **Response Options:** Yes, No, Not Applicable
4. **Display Mode:** View-only (shows previously saved responses)
5. **Edit Mode:** Allows modification with button selection

## Related Issues Fixed

This fix addresses:
- ✅ Type mismatch error when loading bricklayer toolkit
- ✅ Empty array being returned instead of object
- ✅ Dart model parser failure on appendixD
- ✅ Appendix D tab showing parse error instead of data

## Next Steps

1. **Appendix E Data** - Verify workplace experience activities load correctly
2. **Appendix F Data** - Verify practical assessment section loads
3. **Appendix H Issues** - Similar type fixing may be needed for electrician appendixH

## Files Changed Summary

| File | Lines | Change |
|------|-------|--------|
| `mobile/get_bricklayer_toolkit_data.php` | 91-108 | Fixed appendixD object initialization and property assignment |
| `mobile/get_bricklayer_toolkit_data.php` | 145 | Removed double-cast of appendixD |

---

**Status:** ✅ FIXED  
**Build:** APK rebuilt successfully  
**Version:** 45.9 MB  
**Test Date:** 2026-07-10

