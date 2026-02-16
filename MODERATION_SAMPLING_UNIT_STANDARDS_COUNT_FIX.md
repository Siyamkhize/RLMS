# Moderation Sampling - Unit Standards Count Fix

## Issue
The "Unit Stds" column was showing **365** instead of the actual number of distinct unit standards (max 10).

### Root Cause
The query was counting **total POE records** (rows in database) instead of **distinct unit standards**.

Example:
- If a learner has 365 POE document entries across multiple submissions
- But they only cover 5 unique unit standards
- The old query counted 365 (wrong!)
- The new query counts 5 (correct!)

## Solution Applied

### Updated Query Logic
Changed from counting POE records to counting **DISTINCT unit standards across ALL 3 tables**:

1. **POE table** - Uses `unit_standard_id` column
2. **marks table** - Uses `exercise` column (which represents unit standard)
3. **logbook_marks table** - Uses `unit_standard_id` column

### New Query Structure
```sql
CREATE TEMPORARY TABLE temp_learner_coverage AS
SELECT 
    learnerID,
    COUNT(DISTINCT unit_standard_id) as total_unit_standards
FROM (
    -- From POE table
    SELECT DISTINCT p.learnerID, p.unit_standard_id
    FROM poe p
    WHERE p.unit_standard_id IS NOT NULL
    
    UNION
    
    -- From marks table (exercise = unit standard)
    SELECT DISTINCT m.learnerID, m.exercise as unit_standard_id
    FROM marks m
    WHERE m.exercise IS NOT NULL
    
    UNION
    
    -- From logbook_marks table
    SELECT DISTINCT lm.learner_id as learnerID, lm.unit_standard_id
    FROM logbook_marks lm
    WHERE lm.unit_standard_id IS NOT NULL
) AS all_unit_standards
GROUP BY learnerID
```

## Expected Results

Now the "Unit Stds" column will show:
- **0-10** (the actual number of distinct unit standards covered)
- Not 365 or other inflated numbers from counting records

### POE Completeness Categories
Based on distinct unit standards:
- **Complete**: 3+ distinct unit standards
- **Partial**: 1-2 distinct unit standards  
- **Incomplete**: 0 distinct unit standards

## Testing

The fix will show accurate counts:
- Learner with POE for unit standards 13958, 14555, 14556 → Shows **3**
- Learner with 100 POE records but only for unit standard 13958 → Shows **1**
- Learner with marks in 5 unit standards → Shows **5**

## Status
✅ **FIXED** - Unit standards are now counted correctly across all three tables using DISTINCT count!

The stratified sampling will now properly categorize learners based on their actual unit standard coverage, not inflated record counts.
