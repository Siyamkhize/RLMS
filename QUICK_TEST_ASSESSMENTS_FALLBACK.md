# Quick Test Guide - Assessments Fallback Fix

## Problem
Learner 1231 has marks for all 10 unit standards, but only 2 were being detected because the assessments table is incomplete.

## Solution
Changed from INNER JOIN (strict) to LEFT JOIN (inclusive) with keyword fallback for exercises not in assessments table.

## Upload Files
```batch
UPLOAD_ASSESSMENTS_FALLBACK_FIX.bat
```

## Test 1: Diagnostic Script
```
http://102.130.118.179/diagnose_learner_1231_summative.php
```

**What to check:**
- Step 4: Should show MORE rows than before (not just 2)
- Step 5: Shows exercises caught by keyword fallback

## Test 2: Temp Tables Logic
```
http://102.130.118.179/test_temp_tables_logic.php?moderator_id=77
```

**What to check - Step 3 (temp_learner_marks):**
- Find learner 1231 in the table
- Unit Standard Count: Should be **10** ✅ (not 2)
- Avg Marks: Should have a value (not NULL) ✅
- Performance Level: Should be High/Medium/Low ✅ (not "Not Assessed")

## Test 3: API Endpoint
```
http://102.130.118.179/get_learners_with_poe_assigned.php?moderator_id=77
```

**What to check - Find learner 1231:**
```json
{
  "LearnerID": 1231,
  "unit_standards_count": 10,  // ✅ Should be 10 (not 2)
  "marking_status": "Marked",   // ✅ Should be Marked
  "performance_level": "High",  // ✅ Should have a level
  "poe_completeness": "Complete"
}
```

## Expected Results

### Before Fix:
- Learner 1231: 2 unit standards ❌
- Performance: Not Assessed ❌
- Marking: Not Marked ❌

### After Fix:
- Learner 1231: 10 unit standards ✅
- Performance: High/Medium/Low ✅
- Marking: Marked ✅

## Reset Assignments (Optional)
To test fresh sampling:
```sql
DELETE FROM moderator_assignments WHERE moderator_id = '77';
```

Then call API again for new assignments with correct data.

## What Changed

**Old (INNER JOIN):**
```sql
INNER JOIN assessments a ON m.exercise = a.exercise
WHERE a.assessment_type = 'Summative'
```
- Only matches 2 exercises (assessments table incomplete)

**New (LEFT JOIN + Fallback):**
```sql
LEFT JOIN assessments a ON m.exercise = a.exercise
WHERE (
    a.assessment_type = 'Summative'  -- Use assessments if available
    OR
    (a.exercise IS NULL AND m.exercise LIKE '%Summative%')  -- Fallback
)
```
- Matches 50+ exercises (includes keyword matches)

## Files Updated
- `get_learners_with_poe_assigned.php` (main API)
- `test_temp_tables_logic.php` (test script)

## Status
✅ Ready to upload and test
