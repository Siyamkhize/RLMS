# Deployment Guide: Case Sensitivity Fix

## Current Status
- ✅ **Issue identified**: Case sensitivity bug in `mobile/get_poe.php` line 91
- ✅ **Fix applied locally**: Changed `'Logbook'` to `'LogBook'` 
- ❌ **Server not updated**: Fix needs to be deployed to live server

## The Fix Required

In `mobile/get_poe.php` on the server, change **line 91** from:
```php
// BEFORE (incorrect):
AND (CASE 
    WHEN a.question_type = 'Practical' THEN 'Logbook'  // lowercase 'b'
    ELSE a.assessment_type 
 END) = m.type
```

To:
```php
// AFTER (correct):
AND (CASE 
    WHEN a.question_type = 'Practical' THEN 'LogBook'  // Capital 'B'
    ELSE a.assessment_type 
 END) = m.type
```

## Why This Fixes the Issue

**Current Problem:**
- Line 85: POE table uses `'LogBook'` (Capital B)
- Line 91: Marks table uses `'Logbook'` (lowercase b)
- **Result**: JOIN fails due to case mismatch

**After Fix:**
- Both lines use `'LogBook'` (Capital B)
- **Result**: JOIN works properly for all assessment types

## Testing After Deployment

### 1. Test Current Learner (11453)
- Has: 1 Summative mark ("Test Summative Exercise 10:30:15 = 85")
- Expected: Should continue to work (already working)

### 2. Test with Formative Marks
- Find a learner with Formative marks
- Expected: Should now show formative marks properly

### 3. Verification URLs
- **Original endpoint**: `https://rlms.rlms.co.za/mobile/get_poe.php?learnerId=11453`
- **Test script**: `https://rlms.rlms.co.za/test_formative_summative_fix.php?learner_id=11453`

## Expected Results After Fix

### Before Fix:
```json
{
  "pathways": {
    "pathway_name": {
      "qualifications": {
        "qualification_name": {
          "unitstandards": {
            "unit_name": {
              "formative": [
                {
                  "exercise": "Some Formative Exercise",
                  "marks_scored": null  // ❌ Missing due to case mismatch
                }
              ],
              "summative": [
                {
                  "exercise": "Test Summative Exercise 10:30:15",
                  "marks_scored": "85"  // ✅ Works (no case issue)
                }
              ]
            }
          }
        }
      }
    }
  }
}
```

### After Fix:
```json
{
  "pathways": {
    "pathway_name": {
      "qualifications": {
        "qualification_name": {
          "unitstandards": {
            "unit_name": {
              "formative": [
                {
                  "exercise": "Some Formative Exercise",
                  "marks_scored": "75"  // ✅ Now works!
                }
              ],
              "summative": [
                {
                  "exercise": "Test Summative Exercise 10:30:15", 
                  "marks_scored": "85"  // ✅ Still works
                }
              ]
            }
          }
        }
      }
    }
  }
}
```

## Flutter App Impact

Once deployed, the Flutter app will:
1. ✅ **Continue showing summative marks** (no change)
2. ✅ **Start showing formative marks** (new functionality)
3. ✅ **Display "Marks Already Exist" dialog** for both types
4. ✅ **Show marks as "Exercise: [name] [scored]/[max]"** format

## Deployment Steps

1. **Backup current file**: Save current `mobile/get_poe.php`
2. **Apply the fix**: Change line 91 as shown above
3. **Test immediately**: Run test script to verify
4. **Monitor**: Check Flutter app behavior

## Rollback Plan

If issues occur, revert line 91 back to:
```php
WHEN a.question_type = 'Practical' THEN 'Logbook'  // lowercase 'b'
```

## Status
🔧 **READY FOR DEPLOYMENT**

The fix is simple, safe, and will resolve the formative vs summative marks display issue.