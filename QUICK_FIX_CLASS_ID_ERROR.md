# QUICK FIX: Unknown column 'class_id' Error

## Problem
```
{"status":"error","message":"Unknown column 'class_id' in 'INSERT INTO'"}
```

## Cause
The `moderator_assignments` table was missing the new stratification columns needed for comprehensive sampling.

## Solution
Updated `get_learners_with_poe_assigned.php` to:
1. Check which columns exist using `SHOW COLUMNS`
2. Add missing columns: `class_id`, `site_id`, `stratum_type`, `poe_completeness`, `marking_status`, `performance_level`, `poe_count`
3. Properly log errors instead of suppressing them

## Deploy Now

### 1. Upload File
Upload `get_learners_with_poe_assigned.php` to:
```
https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php
```

### 2. Test
Run from browser:
```
https://rlms.rlms.co.za/mobile/test_sampling_table_fix.php
```

Or test from mobile app:
- Open Moderator page
- Click "Get Learners with POE"
- Should work without errors

## What Happens
1. API checks if table has all required columns
2. Adds any missing columns automatically
3. Performs stratified sampling
4. Stores metadata for fast retrieval
5. Returns learners with stratification info

## Expected Result
```json
{
  "status": "success",
  "data": {
    "total_learners_with_poe": 50,
    "selected_count": 13,
    "sampling_method": "stratified_comprehensive",
    "total_strata": 8,
    "strata_summary": [...]
  }
}
```

## Files
- ✅ `get_learners_with_poe_assigned.php` - FIXED
- ✅ `test_sampling_table_fix.php` - Test script
- ✅ `MODERATION_SAMPLING_CLASS_ID_FIX.md` - Full documentation
- ✅ `DEPLOY_SAMPLING_CLASS_ID_FIX.bat` - Deployment guide

## Status
✅ **READY TO DEPLOY**
