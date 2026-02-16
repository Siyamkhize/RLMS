# Stratification Data Issue - Summary

## Current Status

### ✅ What's Working
- Class filtering is working correctly
- Moderators only see learners from their allocated classes
- Sampling is performed within allocated classes only
- API returns learners from correct classes

### ❌ What's NOT Working
- Unit standards count showing incorrect values
- Performance level showing incorrect values
- Marking status showing incorrect values

---

## The Issue

After implementing class filtering, the stratification metadata (unit standards count, performance level, marking status) is not being calculated correctly. This suggests the temp tables or calculation logic has an issue.

---

## Diagnostic Tools Created

I've created comprehensive diagnostic tools to identify the exact issue:

### 1. test_temp_tables_issue.php
**Purpose:** Tests if temp tables are being created correctly with class filtering

**What it shows:**
- Number of learners in `temp_poe_learners`
- Number of learners in `temp_learner_marks`
- Number of learners in `temp_learner_coverage`
- Sample data from each temp table
- Main query results with all stratification metadata

**URL:**
```
https://rlms.rlms.co.za/test_temp_tables_issue.php?moderator_id=77
```

### 2. test_stratification_data.php
**Purpose:** Tests detailed calculation for individual learners

**What it shows:**
- Unit standards extracted from POE table
- Unit standards extracted from marks table
- Unit standards extracted from logbook_marks table
- Total unique unit standards count
- Marking status calculation (based on SUMMATIVE marks)
- Performance level calculation (average of summative marks)
- Comparison with expected values

**URL:**
```
https://rlms.rlms.co.za/test_stratification_data.php?moderator_id=77
```

### 3. RUN_STRATIFICATION_DIAGNOSTICS.bat
**Purpose:** Automated batch file to run all diagnostics

**What it does:**
- Opens all diagnostic tools in browser
- Shows what to check for
- Lists common issues and solutions

**Usage:**
```
Double-click RUN_STRATIFICATION_DIAGNOSTICS.bat
```

---

## How to Diagnose

### Step 1: Upload Diagnostic Files
Upload these files to your server:
- `test_temp_tables_issue.php`
- `test_stratification_data.php`

### Step 2: Run Diagnostics
Either:
- Run `RUN_STRATIFICATION_DIAGNOSTICS.bat` (opens all tests)
- Or manually open each test URL in browser

### Step 3: Review Results
Check the diagnostic output for:

**Temp Tables Test:**
- Are temp tables being created?
- Do they contain data?
- How many learners in each table?

**Individual Learner Test:**
- Are unit standards being extracted correctly?
- Is the total count correct?
- Is marking status correct?
- Is performance level correct?

**API Response:**
- Compare with diagnostic results
- Identify discrepancies

### Step 4: Identify the Issue

Based on diagnostic results:

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| Temp tables empty | Class filtering too restrictive | Verify moderator has classes with POE learners |
| Unit standards count = 0 | Exercise column extraction failing | Check exercise column format |
| Always "Not Marked" | No SUMMATIVE marks found | Verify marks table has type='Summative' |
| Always "Not Assessed" | No marks_scored values | Verify marks table has marks_scored data |
| Temp tables have data but API returns wrong values | JOIN or CASE logic issue | Check main query JOINs and CASE statements |

---

## Possible Root Causes

### 1. Temp Table Creation Issue
The temp tables might not be persisting correctly or might be empty due to class filtering.

**Check:** `test_temp_tables_issue.php` - Look at row counts

### 2. Unit Standard Extraction Issue
The `exercise` column format might be different than expected, causing extraction to fail.

**Check:** `test_stratification_data.php` - Look at extracted unit standard IDs

### 3. Marks Data Issue
Learners might not have SUMMATIVE marks, or marks_scored might be NULL.

**Check:** `test_stratification_data.php` - Look at summative marks count

### 4. JOIN Issue
The LEFT JOINs with temp tables might not be working correctly.

**Check:** `test_temp_tables_issue.php` - Look at main query results

---

## Expected Behavior

For a learner with complete data:

### Unit Standards Count (poe_count)
- **Source:** DISTINCT count across poe, marks, logbook_marks tables
- **Range:** 0-10 (there are 10 unit standards total)
- **Example:** If learner has POE for 5 US, marks for 3 US, logbook for 2 US → Total unique = 7

### POE Completeness
- **Complete:** 10/10 unit standards covered
- **Partial:** 1-9 unit standards covered
- **Incomplete:** 0 unit standards covered

### Marking Status
- **Marked:** Has at least one SUMMATIVE mark (type='Summative')
- **Not Marked:** No SUMMATIVE marks

### Performance Level
- **High:** Average marks >= 70%
- **Medium:** Average marks >= 50% and < 70%
- **Low:** Average marks >= 0% and < 50%
- **Not Assessed:** No SUMMATIVE marks available (avg_marks IS NULL)

---

## Next Steps

1. **Upload diagnostic files** to server
   - `test_temp_tables_issue.php`
   - `test_stratification_data.php`

2. **Run diagnostics**
   - Use `RUN_STRATIFICATION_DIAGNOSTICS.bat`
   - Or open URLs manually in browser

3. **Review output**
   - Check temp tables have data
   - Check unit standards are extracted correctly
   - Check marking status is correct
   - Check performance level is correct

4. **Identify the issue**
   - Based on diagnostic results
   - Use the table above to match symptoms to causes

5. **Report findings**
   - Share diagnostic output
   - Describe what you see
   - We'll apply the appropriate fix

6. **Apply fix**
   - Modify `get_learners_with_poe_assigned.php`
   - Upload to server
   - Test again

---

## Files Created

### Diagnostic Tools
- `test_temp_tables_issue.php` - Temp tables diagnostic
- `test_stratification_data.php` - Individual learner diagnostic
- `RUN_STRATIFICATION_DIAGNOSTICS.bat` - Automated test runner

### Documentation
- `STRATIFICATION_DATA_ISSUE_DIAGNOSIS.md` - Detailed diagnosis guide
- `QUICK_DIAGNOSTIC_STRATIFICATION.txt` - Quick reference
- `STRATIFICATION_ISSUE_SUMMARY.md` - This file

---

## Summary

The class filtering is working correctly, but the stratification metadata calculations need to be verified. The diagnostic tools will help us identify exactly where the issue is so we can apply the appropriate fix.

**Action Required:**
1. Upload diagnostic files to server
2. Run `RUN_STRATIFICATION_DIAGNOSTICS.bat`
3. Share the diagnostic output
4. We'll fix the issue based on the results

The diagnostics will tell us exactly what's wrong! 🔍
