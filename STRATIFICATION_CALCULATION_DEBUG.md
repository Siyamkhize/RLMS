# Stratification Calculation Debug Guide

## Problem

After implementing class filtering, the system is now sampling correctly based on moderator's allocated classes, but:
- Unit standards count is not calculating correctly
- Performance level is not showing correctly
- Marking status is not showing correctly

## Root Cause

The issue is likely in the temp table queries in `get_learners_with_poe_assigned.php` that calculate:
1. `temp_learner_marks` - Performance level and marking status
2. `temp_learner_coverage` - Unit standards count

## Diagnostic Tools

### 1. Test Stratification Calculations
```
https://rlms.rlms.co.za/test_stratification_calculations.php?moderator_id=77
```

This will:
- Show unit standards from each table (poe, marks, logbook_marks)
- Calculate combined unit standards count
- Calculate performance level from summative marks
- Determine marking status
- Compare with stored values in moderator_assignments table

### 2. Test Temp Tables Logic
```
https://rlms.rlms.co.za/test_temp_tables_logic.php?moderator_id=77
```

This will:
- Simulate the exact temp table creation process
- Show what each temp table contains
- Display the final query results
- Help identify where the calculation breaks

## What to Check

### Unit Standards Count (poe_count)

**Expected:**
- Count DISTINCT unit standards across ALL 3 tables:
  - `poe` table
  - `marks` table
  - `logbook_marks` table
- Extract numeric ID from exercise column (e.g., "9964 - Apply health..." → 9964)
- Handle both tab and space delimiters

**Possible Issues:**
- REGEXP pattern not matching exercise format
- SUBSTRING_INDEX extraction failing
- FLOOR conversion not working
- Missing data in one of the tables
- Wrong JOIN conditions

### Performance Level

**Expected:**
- Calculate from SUMMATIVE marks only
- For each unit standard, SUM all summative marks
- Average across all unit standards
- High: 70%+, Medium: 50-69%, Low: 0-49%, Not Assessed: NULL

**Possible Issues:**
- Not filtering by type = 'Summative'
- Wrong aggregation (should be SUM per unit standard, then AVG)
- NULL handling incorrect
- Wrong CASE statement thresholds

### Marking Status

**Expected:**
- Marked: Has at least one summative mark
- Not Marked: No summative marks

**Possible Issues:**
- Checking wrong table
- Not filtering by type = 'Summative'
- NULL handling incorrect

## Common Issues

### Issue 1: Exercise Column Format
The exercise column might have different formats:
- "9964 - Apply health and safety practices"
- "9964\tApply health and safety practices"
- "3.21\tWhy is it important..."
- "Exercise 1"

**Solution:** The REGEXP pattern should match numeric IDs only:
```sql
SUBSTRING_INDEX(SUBSTRING_INDEX(m.exercise, '\t', 1), ' ', 1) REGEXP '^[0-9]'
```

### Issue 2: Temp Table Not Populated
If temp tables are empty, the LEFT JOIN will return NULL values.

**Check:**
```sql
SELECT COUNT(*) FROM temp_learner_marks;
SELECT COUNT(*) FROM temp_learner_coverage;
```

### Issue 3: Class Filter Breaking Queries
After adding class filtering, the temp tables might not be getting populated correctly.

**Check:** Ensure the class filter is applied correctly in the POE learners query.

### Issue 4: Data Type Mismatch
The learner_id column might be different types in different tables:
- `learnerdetails.LearnerID` - INT
- `marks.learnerID` - INT
- `logbook_marks.learner_id` - INT or VARCHAR

**Solution:** Ensure consistent data types in JOINs.

## Testing Steps

### Step 1: Run Diagnostic Tests
1. Open `test_stratification_calculations.php?moderator_id=77`
2. Note the calculated values
3. Compare with what the API returns

### Step 2: Check Temp Tables
1. Open `test_temp_tables_logic.php?moderator_id=77`
2. Check if temp tables are populated
3. Verify the final query results

### Step 3: Check API Response
1. Open `get_learners_with_poe_assigned.php?moderator_id=77`
2. Check the returned values for:
   - `poe_count` (unit_standards_count)
   - `poe_completeness`
   - `marking_status`
   - `performance_level`

### Step 4: Compare Values
Create a comparison table:

| Field | Expected | API Returns | Match? |
|-------|----------|-------------|--------|
| poe_count | X | Y | ✅/❌ |
| poe_completeness | Complete/Partial/Incomplete | ? | ✅/❌ |
| marking_status | Marked/Not Marked | ? | ✅/❌ |
| performance_level | High/Medium/Low/Not Assessed | ? | ✅/❌ |

## Possible Fixes

### Fix 1: Update REGEXP Pattern
If exercise format is different, update the pattern:
```sql
-- Current
SUBSTRING_INDEX(SUBSTRING_INDEX(m.exercise, '\t', 1), ' ', 1) REGEXP '^[0-9]'

-- Alternative (more flexible)
m.exercise REGEXP '^[0-9]+'
```

### Fix 2: Add Debug Logging
Add temporary logging to see what's being extracted:
```sql
SELECT 
    exercise,
    SUBSTRING_INDEX(SUBSTRING_INDEX(exercise, '\t', 1), ' ', 1) as extracted,
    FLOOR(SUBSTRING_INDEX(SUBSTRING_INDEX(exercise, '\t', 1), ' ', 1) + 0) as unit_standard_id
FROM marks
WHERE learnerID = 123
LIMIT 10;
```

### Fix 3: Check NULL Handling
Ensure COALESCE is used correctly:
```sql
COALESCE(tc.total_unit_standards, 0) as poe_count
```

### Fix 4: Verify JOIN Conditions
Ensure all JOINs are correct:
```sql
LEFT JOIN temp_learner_marks tm ON l.LearnerID = tm.learnerID
LEFT JOIN temp_learner_coverage tc ON l.LearnerID = tc.learnerID
```

## Expected Behavior

For a learner with:
- 5 POE documents covering 5 unit standards
- 3 assessment marks covering 3 unit standards
- 2 logbook marks covering 2 unit standards
- Total: 7 unique unit standards (some overlap)

**Expected Results:**
- `poe_count`: 7
- `poe_completeness`: Partial (1-9 unit standards)
- `marking_status`: Marked (has summative marks)
- `performance_level`: High/Medium/Low (based on average)

## Next Steps

1. **Upload diagnostic files** to server:
   - `test_stratification_calculations.php`
   - `test_temp_tables_logic.php`

2. **Run tests** and collect results

3. **Identify the issue**:
   - Is it the REGEXP pattern?
   - Is it the extraction logic?
   - Is it the aggregation?
   - Is it the NULL handling?

4. **Fix the issue** in `get_learners_with_poe_assigned.php`

5. **Re-test** to verify the fix

6. **Upload fixed file** to server

## Files Involved

- `get_learners_with_poe_assigned.php` - Main API file (needs fixing)
- `test_stratification_calculations.php` - Diagnostic tool (upload to server)
- `test_temp_tables_logic.php` - Temp table test (upload to server)

## Summary

The class filtering is working correctly, but the stratification calculations (unit standards count, performance level, marking status) are not calculating correctly. Use the diagnostic tools to identify where the calculation breaks, then fix the temp table queries in `get_learners_with_poe_assigned.php`.
