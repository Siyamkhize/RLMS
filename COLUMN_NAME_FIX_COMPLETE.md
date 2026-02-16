# Column Name Fix - Complete ✅

## Error Fixed
```
"Unknown column 'unit_standard_id' in 'SELECT'"
```

## Problem
The code was trying to use `unit_standard_id` column in the `marks` table, but that column doesn't exist. The marks table uses `exercise` column instead.

## Solution
Updated the query to use the correct column name:

### Before (WRONG):
```sql
SELECT DISTINCT learnerID, CONCAT('marks_', unit_standard_id)
FROM marks
WHERE marks_scored IS NOT NULL
```

### After (CORRECT):
```sql
SELECT DISTINCT learnerID, CONCAT('marks_', exercise)
FROM marks
WHERE marks_scored IS NOT NULL
```

## Marks Table Structure
The actual columns in the marks table are:
- `id` - Primary key
- `learnerID` - Learner identifier
- `exercise` - Exercise/unit standard name
- `so` - Specific outcome
- `marks_scored` - The marks
- `type` - Assessment type (Formative/Summative/Logbook)

## Files Updated
1. **get_learners_with_poe_assigned.php** - Main API file
   - Fixed temp_learner_coverage query to use `exercise` column
   
2. **test_three_table_coverage.php** - Test script
   - Fixed marks table query to use correct columns
   - Updated display to show `exercise` instead of `unit_standard_id`

## Deploy Now
Upload the updated file:
```
Upload: get_learners_with_poe_assigned.php
To: /mobile/get_learners_with_poe_assigned.php
```

## Test
```
https://rlms.rlms.co.za/mobile/get_learners_with_poe_assigned.php?moderator_id=YOUR_ID
```

Expected:
- ✅ No "Unknown column" error
- ✅ Query executes successfully
- ✅ Stratification data populated
- ✅ No more "Unknown" values

## Status
✅ **FIXED** - Column name corrected to match actual database schema

---
**Note:** The marks table uses `exercise` column, not `unit_standard_id`. The logbook_marks table DOES have `unit_standard_id` column, which is why the query works for that table.
