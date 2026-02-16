# 🔍 Debug Stratification Calculations NOW

## Current Status

✅ **Class filtering is working** - Moderators see only their allocated classes
❌ **Stratification calculations are broken** - Unit standards, performance, and marking status are incorrect

## Quick Diagnosis (3 Steps)

### Step 1: Upload Diagnostic Files

Upload these 2 files to your server:
1. `test_stratification_calculations.php`
2. `test_temp_tables_logic.php`

### Step 2: Run Diagnostic Tests

**Test 1: Check Calculations for a Specific Learner**
```
https://rlms.rlms.co.za/test_stratification_calculations.php?moderator_id=77
```

This will automatically pick a learner and show:
- Unit standards from POE table
- Unit standards from marks table
- Unit standards from logbook_marks table
- Combined count
- Performance level calculation
- Marking status
- What the API should return vs what it actually returns

**Test 2: Check Temp Table Logic**
```
https://rlms.rlms.co.za/test_temp_tables_logic.php?moderator_id=77
```

This will show:
- Moderator's classes
- POE learners count
- Temp table contents
- Final query results
- What values are being calculated

### Step 3: Identify the Issue

Compare the results from both tests:

| What to Check | Where to Look | Expected | If Wrong |
|---------------|---------------|----------|----------|
| Unit Standards Count | Test 1 - Combined count | 1-10 | REGEXP pattern issue |
| Performance Level | Test 1 - Performance calculation | High/Medium/Low | Aggregation issue |
| Marking Status | Test 1 - Summative marks | Marked/Not Marked | Type filter issue |
| Temp Tables | Test 2 - Step 3 & 4 | Populated with data | JOIN issue |

## Common Issues & Quick Fixes

### Issue 1: Unit Standards Count is 0

**Symptom:** `poe_count` is always 0 or NULL

**Cause:** REGEXP pattern not matching exercise format

**Quick Check:**
```sql
SELECT exercise, 
       SUBSTRING_INDEX(SUBSTRING_INDEX(exercise, '\t', 1), ' ', 1) as extracted
FROM marks 
WHERE learnerID = 123 
LIMIT 10;
```

**Fix:** Update the extraction logic in `get_learners_with_poe_assigned.php`

### Issue 2: Performance Level is Always "Not Assessed"

**Symptom:** `performance_level` is always "Not Assessed" even when marks exist

**Cause:** `temp_learner_marks` table is empty or not joining correctly

**Quick Check:**
```sql
SELECT COUNT(*) FROM temp_learner_marks;
```

**Fix:** Check the temp table creation query for summative marks

### Issue 3: Marking Status is Always "Not Marked"

**Symptom:** `marking_status` is always "Not Marked" even when marks exist

**Cause:** Not filtering by `type = 'Summative'` or wrong column name

**Quick Check:**
```sql
SELECT COUNT(*) 
FROM marks 
WHERE type = 'Summative' 
AND learnerID IN (SELECT learnerID FROM temp_poe_learners);
```

**Fix:** Verify the type column and filter in temp_learner_marks query

### Issue 4: All Values are NULL

**Symptom:** All stratification fields are NULL

**Cause:** LEFT JOIN not working, temp tables empty

**Quick Check:**
```sql
SELECT COUNT(*) FROM temp_poe_learners;
SELECT COUNT(*) FROM temp_learner_marks;
SELECT COUNT(*) FROM temp_learner_coverage;
```

**Fix:** Check if temp tables are being created and populated

## Detailed Diagnosis

### What Each Test Shows

**test_stratification_calculations.php:**
- ✅ Shows raw data from each table
- ✅ Shows extraction logic results
- ✅ Shows calculated values
- ✅ Compares with stored values
- ✅ Identifies exact mismatch

**test_temp_tables_logic.php:**
- ✅ Simulates API logic
- ✅ Shows temp table contents
- ✅ Shows final query results
- ✅ Identifies where calculation breaks

### Example Output Analysis

**Good Output:**
```
Unit Standards from POE: 5
Unit Standards from Marks: 3
Unit Standards from Logbook: 2
Combined: 7 unique unit standards
POE Completeness: Partial
Marking Status: Marked
Performance Level: High (75%)
```

**Bad Output:**
```
Unit Standards from POE: 0
Unit Standards from Marks: 0
Unit Standards from Logbook: 0
Combined: 0 unique unit standards
POE Completeness: Incomplete
Marking Status: Not Marked
Performance Level: Not Assessed
```

If you see the bad output, the REGEXP pattern or extraction logic is failing.

## Quick Fix Template

Once you identify the issue, here's how to fix it:

### Fix Template 1: REGEXP Pattern
```php
// OLD (if not working)
AND SUBSTRING_INDEX(SUBSTRING_INDEX(m.exercise, '\t', 1), ' ', 1) REGEXP '^[0-9]'

// NEW (more flexible)
AND m.exercise REGEXP '^[0-9]+'
```

### Fix Template 2: Extraction Logic
```php
// OLD (if not working)
FLOOR(SUBSTRING_INDEX(SUBSTRING_INDEX(m.exercise, '\t', 1), ' ', 1) + 0)

// NEW (simpler)
CAST(REGEXP_SUBSTR(m.exercise, '^[0-9]+') AS UNSIGNED)
```

### Fix Template 3: NULL Handling
```php
// Ensure COALESCE is used
COALESCE(tc.total_unit_standards, 0) as poe_count
COALESCE(tm.unit_standard_count, 0) as unit_standard_count
COALESCE(tm.avg_marks, 0) as avg_marks
```

## Action Plan

1. **Upload diagnostic files** (2 files)
2. **Run Test 1** - Check calculations
3. **Run Test 2** - Check temp tables
4. **Identify issue** - Compare results
5. **Apply fix** - Update `get_learners_with_poe_assigned.php`
6. **Upload fixed file** - Deploy to server
7. **Verify** - Test API again

## Expected Timeline

- Upload files: 2 minutes
- Run tests: 5 minutes
- Identify issue: 5 minutes
- Apply fix: 10 minutes
- Upload & verify: 5 minutes
- **Total: ~30 minutes**

## Need Help?

If you're stuck, provide:
1. Output from `test_stratification_calculations.php`
2. Output from `test_temp_tables_logic.php`
3. Sample exercise values from your database

This will help identify the exact issue and provide a targeted fix.

## Summary

The class filtering is working perfectly. Now we need to fix the stratification calculations. The diagnostic tools will show exactly where the calculation breaks, making it easy to apply the right fix.

**Next Step:** Upload the 2 diagnostic files and run the tests! 🚀
