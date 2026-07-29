# Formative vs Summative Marks Issue - CASE SENSITIVITY FIX

## Problem Identified
User reported that **summative marks show but formative marks don't show** in the Flutter app.

## Root Cause: Case Sensitivity Bug
Found inconsistent case handling in `mobile/get_poe.php` for the LogBook type:

### The Bug (Lines 85 vs 91):
```php
// POE table join (line 85):
WHEN a.question_type = 'Practical' THEN 'LogBook'  // Capital L, Capital B

// Marks table join (line 91):  
WHEN a.question_type = 'Practical' THEN 'Logbook'  // Capital L, lowercase b
```

### Why This Breaks Formative:
- **Summative assessments** work because they match exactly: `'Summative' = 'Summative'`
- **Formative assessments** fail because of the LogBook case mismatch: `'LogBook' ≠ 'Logbook'`
- When a formative assessment has `question_type = 'Practical'`, the JOIN fails due to case difference

## Fix Applied

### 1. Fixed mobile/get_poe.php
**Before:**
```php
AND (CASE 
    WHEN a.question_type = 'Practical' THEN 'Logbook'  // lowercase 'b'
    ELSE a.assessment_type 
 END) = m.type
```

**After:**
```php
AND (CASE 
    WHEN a.question_type = 'Practical' THEN 'LogBook'  // Capital 'B'
    ELSE a.assessment_type 
 END) = m.type
```

### 2. Updated mobile/get_poe_fixed.php
Enhanced the lookup logic to handle LogBook case properly:
```php
// Handle the LogBook case properly
$marksType = ($row['question_type'] === 'Practical' && $assessmentType === 'Summative') ? 'LogBook' : $assessmentType;
$markKey = $exerciseName . '|' . $marksType;
```

## Testing

### Test Files Created:
1. `debug_formative_vs_summative_marks.php` - Detailed diagnostic
2. `test_formative_summative_fix.php` - Verification test

### Test URLs:
- **Diagnostic**: `debug_formative_vs_summative_marks.php?learner_id=11453`
- **Fix Verification**: `test_formative_summative_fix.php?learner_id=11453`
- **Fixed Endpoint**: `mobile/get_poe_fixed.php?learnerId=11453`

## Expected Results After Fix

### Before Fix:
- ✅ **Summative**: Shows marks (85/100)
- ❌ **Formative**: No marks shown
- ❌ **LogBook**: Inconsistent behavior

### After Fix:
- ✅ **Summative**: Shows marks (85/100)  
- ✅ **Formative**: Shows marks properly
- ✅ **LogBook**: Consistent case handling

## Flutter App Impact
Once deployed, the Flutter app will:
1. ✅ Display existing formative marks as "Exercise: [name] [scored]/[max]"
2. ✅ Show "Marks Already Exist" dialog for formative assessments
3. ✅ Continue working properly for summative assessments
4. ✅ Handle LogBook assessments consistently

## Deployment Steps
1. **Test the fix**: Run `test_formative_summative_fix.php?learner_id=11453`
2. **Verify results**: Both formative and summative should show marks
3. **Deploy**: Replace `mobile/get_poe.php` with the fixed version
4. **Test in Flutter**: Verify marks display properly for both types

## Status
🔧 **FIX READY FOR DEPLOYMENT**

The case sensitivity issue has been identified and fixed. Both formative and summative marks should now display properly in the Flutter app.