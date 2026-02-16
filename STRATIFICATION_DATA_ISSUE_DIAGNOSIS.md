# Stratification Data Issue - Diagnosis & Fix

## Problem Report

**User Issue:** "now it is sampling accordingly, but now it is not calculating the unit standards and the performance and the marking are not showing correct"

**Status:** Class filtering is working ✅, but stratification metadata (unit standards count, performance level, marking status) is incorrect ❌

---

## What's Working

✅ Class filtering - Moderators only see learners from their allocated classes
✅ Sampling is performed within allocated classes only
✅ Learners are correctly filtered by moderator's classes

---

## What's NOT Working

❌ Unit standards count showing incorrect values (or 0)
❌ Performance level showing incorrect values (or "Not Assessed")
❌ Marking status showing incorrect values (or "Not Marked")

---

## Root Cause Analysis

The issue is likely in one of these areas:

### 1. Temp Table Creation with Class Filtering
When we added class filtering, the temp tables (`temp_learner_marks` and `temp_learner_coverage`) are created based on `temp_poe_learners` which is filtered by moderator's classes. This should work correctly, but we need to verify:

- Are temp tables being created successfully?
- Do they contain data?
- Are the JOINs working correctly?

### 2. Data Extraction from `exercise` Column
The code extracts unit standard IDs from the `exercise` column using:
```sql
FLOOR(SUBSTRING_INDEX(SUBSTRING_INDEX(exercise, '\t', 1), ' ', 1) + 0)
```

This handles formats like:
- "9964 - Apply health..." → 9964
- "3.21\tWhy" → 3
- "14555 Text" → 14555

**Potential Issue:** If the `exercise` column format is different in the filtered data, extraction might fail.

### 3. Performance Calculation Logic
Performance is calculated as:
```sql
AVG(unit_standard_totals.unit_standard_total)
```

Where `unit_standard_total` is the SUM of all SUMMATIVE marks per unit standard.

**Potential Issue:** 
- If there are no SUMMATIVE marks, `avg_marks` will be NULL
- If marks are stored differently, calculation might be wrong

### 4. Unit Standards Coverage Count
Counts DISTINCT unit standards across 3 tables:
- `poe` table
- `marks` table  
- `logbook_marks` table

**Potential Issue:**
- If unit standard IDs are not being extracted correctly
- If the UNION query is not working as expected
- If the filtering is too restrictive

---

## Diagnostic Steps

### Step 1: Test Temp Tables
Run this test to see if temp tables are being created correctly:
```
https://rlms.rlms.co.za/test_temp_tables_issue.php?moderator_id=77
```

This will show:
- How many learners are in `temp_poe_learners`
- How many learners have marks data in `temp_learner_marks`
- How many learners have coverage data in `temp_learner_coverage`
- Sample data from each temp table

### Step 2: Test Individual Learner
Run this test to see detailed calculation for a specific learner:
```
https://rlms.rlms.co.za/test_stratification_data.php?moderator_id=77
```

This will show:
- Unit standards from POE table
- Unit standards from marks table
- Unit standards from logbook_marks table
- Total unique unit standards
- Marking status calculation
- Performance level calculation

### Step 3: Compare with API Response
Compare the diagnostic results with what the API returns:
```
https://rlms.rlms.co.za/get_learners_with_poe_assigned.php?moderator_id=77
```

Look for discrepancies in:
- `poe_count` (unit standards count)
- `marking_status` (Marked/Not Marked)
- `performance_level` (High/Medium/Low/Not Assessed)
- `poe_completeness` (Complete/Partial/Incomplete)

---

## Possible Fixes

### Fix 1: Verify Temp Tables Are Populated
If temp tables are empty or have no data, the issue is in the temp table creation queries.

**Solution:** Ensure the class filtering doesn't exclude all learners.

### Fix 2: Check exercise Column Format
If unit standard extraction is failing, the `exercise` column might have a different format.

**Solution:** Add more flexible extraction logic or handle different formats.

### Fix 3: Verify Marks Data Exists
If learners have no SUMMATIVE marks, performance will be "Not Assessed".

**Solution:** This might be correct behavior. Verify learners actually have summative marks.

### Fix 4: Check Unit Standards Coverage Logic
If unit standards count is 0, the UNION query might not be working.

**Solution:** Test each part of the UNION separately to see which table has data.

---

## Testing Files Created

1. **test_temp_tables_issue.php**
   - Tests if temp tables are created correctly
   - Shows sample data from each temp table
   - Tests the main query with temp table JOINs

2. **test_stratification_data.php**
   - Tests detailed calculation for individual learners
   - Shows unit standards from each table
   - Shows marking status and performance calculation
   - Compares with API response

---

## Expected Behavior

For a learner with complete data:

### Unit Standards Count
- Should count DISTINCT unit standards across all 3 tables
- Range: 0-10 (there are 10 unit standards total)
- Example: If learner has POE for 5 unit standards, marks for 3, and logbook for 2, total unique = 7

### POE Completeness
- **Complete:** 10/10 unit standards covered
- **Partial:** 1-9 unit standards covered
- **Incomplete:** 0 unit standards covered

### Marking Status
- **Marked:** Learner has at least one SUMMATIVE mark
- **Not Marked:** Learner has no SUMMATIVE marks

### Performance Level
- **High:** Average marks >= 70%
- **Medium:** Average marks >= 50% and < 70%
- **Low:** Average marks >= 0% and < 50%
- **Not Assessed:** No SUMMATIVE marks available

---

## Next Steps

1. **Run Diagnostics**
   - Open `test_temp_tables_issue.php` in browser
   - Open `test_stratification_data.php` in browser
   - Review the output

2. **Identify the Issue**
   - Check if temp tables have data
   - Check if unit standards are being extracted correctly
   - Check if marks data exists

3. **Apply Fix**
   - Based on diagnostic results, apply appropriate fix
   - Test with API endpoint
   - Verify in mobile app

4. **Upload Fixed File**
   - Upload corrected `get_learners_with_poe_assigned.php` to server
   - Verify with `check_server_version.php`
   - Test with moderator 77

---

## Files to Check

- `get_learners_with_poe_assigned.php` - Main API file
- `test_temp_tables_issue.php` - Temp tables diagnostic
- `test_stratification_data.php` - Individual learner diagnostic
- `check_server_version.php` - Server version check

---

## Summary

The class filtering is working correctly, but the stratification metadata calculations need to be verified. The diagnostic tools will help identify exactly where the issue is:

- If temp tables are empty → Issue with temp table creation
- If unit standards count is 0 → Issue with unit standard extraction
- If marking status is wrong → Issue with marks query
- If performance is wrong → Issue with performance calculation

Run the diagnostics first, then we can apply the appropriate fix! 🔍
