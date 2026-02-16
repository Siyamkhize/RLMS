# Column Name Fix - Logbook Marks Table ✅

## Error Fixed
```
"Unknown column 'learnerID' in 'SELECT'"
```

## Problem
The code was trying to use `learnerID` column in the `logbook_marks` table, but that table uses `learner_id` (lowercase with underscore) instead.

## Database Schema Differences

### Three Tables with Different Column Names:

1. **poe table**: Uses `learnerID` (camelCase)
2. **marks table**: Uses `learnerID` (camelCase) and `exercise` column
3. **logbook_marks table**: Uses `learner_id` (lowercase with underscore) and `unit_standard_id` column

## Solution
Updated the query to use the correct column name with an alias to normalize the output:

### Before (WRONG):
```sql
SELECT DISTINCT learnerID, CONCAT('logbook_', unit_standard_id)
FROM logbook_marks
WHERE marks IS NOT NULL
```

### After (CORRECT):
```sql
SELECT DISTINCT learner_id as learnerID, CONCAT('logbook_', unit_standard_id)
FROM logbook_marks
WHERE marks IS NOT NULL
```

The `as learnerID` alias ensures the output column name matches the other tables in the UNION query.

## Files Updated

1. **get_learners_with_poe_assigned.php** - Main API file
   - Fixed temp_learner_coverage query (line ~155)
   - Changed `learnerID` to `learner_id as learnerID` in logbook_marks UNION
   
2. **test_three_table_coverage.php** - Test script
   - Fixed logbook_marks query to use `learner_id` column
   - Removed `unit_standard_name` column (doesn't exist in table)
   - Updated all three queries to use correct column names

## Complete Query Structure

```sql
CREATE TEMPORARY TABLE temp_learner_coverage AS
SELECT 
    learnerID,
    COUNT(DISTINCT unit_standard_source) as total_unit_standards
FROM (
    -- POE documents (uses learnerID)
    SELECT DISTINCT learnerID, 'poe' as unit_standard_source
    FROM poe 
    WHERE filePath IS NOT NULL AND filePath != ''
    
    UNION
    
    -- Assessment marks (uses learnerID and exercise)
    SELECT DISTINCT learnerID, CONCAT('marks_', exercise) as unit_standard_source
    FROM marks
    WHERE marks_scored IS NOT NULL
    
    UNION
    
    -- Logbook marks (uses learner_id - ALIASED to learnerID)
    SELECT DISTINCT learner_id as learnerID, CONCAT('logbook_', unit_standard_id) as unit_standard_source
    FROM logbook_marks
    WHERE marks IS NOT NULL
) AS all_coverage
GROUP BY learnerID
```

## Deploy Now

Upload the updated files:
```
Upload: get_learners_with_poe_assigned.php
To: /mobile/get_learners_with_poe_assigned.php

Upload: test_three_table_coverage.php
To: /mobile/test_three_table_coverage.php
```

## Test

1. **Test the API:**
```
https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php?moderator_id=YOUR_ID
```

2. **Test the coverage script:**
```
https://rlms.rlms.co.za/mobile/test_three_table_coverage.php?learner_id=1
```

Expected Results:
- ✅ No "Unknown column 'learnerID'" error
- ✅ Query executes successfully
- ✅ Stratification data populated correctly
- ✅ No more "Unknown" values in UI
- ✅ POE completeness calculated across all three tables

## Status
✅ **FIXED** - Column name corrected to match actual database schema

## Summary of Column Name Differences

| Table | Learner Column | Unit Standard Column |
|-------|---------------|---------------------|
| poe | `learnerID` | N/A |
| marks | `learnerID` | `exercise` |
| logbook_marks | `learner_id` | `unit_standard_id` |

**Key Takeaway:** Always check the actual table structure before writing queries. Column naming conventions vary across tables in this database.

---
**Date:** 2026-01-29
**Issue:** Unknown column 'learnerID' in logbook_marks table
**Resolution:** Use `learner_id` with alias for consistency
