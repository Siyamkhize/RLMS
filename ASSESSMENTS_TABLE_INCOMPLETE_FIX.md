# Assessments Table Incomplete - Fallback Solution

## Problem Discovered

The diagnostic script `diagnose_learner_1231_summative.php` revealed:

- ❌ Learner 1231 has marks for **~200+ different exercises** in the marks table
- ❌ The assessments table only contains **~50 exercises** defined as "Summative"
- ❌ The join `marks.exercise = assessments.exercise` can only match **2 exercises**
- ❌ Result: Only **2 unit standards** are counted instead of the expected **10**

### Root Cause
The `assessments` table is **INCOMPLETE** - it's missing most of the exercises that exist in the `marks` table.

## Solution: Fallback Approach

Since we cannot populate the assessments table immediately, we'll use a **two-tier detection method**:

### Tier 1: Use assessments table (Authoritative)
If the exercise exists in the assessments table, use `assessments.assessment_type`

### Tier 2: Keyword Detection (Fallback)
If the exercise doesn't exist in assessments table, check if the exercise text contains summative keywords:
- "Summative"
- "All Summative Questions"
- "Summative Assessment"

### SQL Implementation

```sql
-- OLD (only uses assessments table - misses most exercises):
INNER JOIN assessments a ON m.exercise = a.exercise
WHERE a.assessment_type = 'Summative'

-- NEW (uses assessments table + keyword fallback):
LEFT JOIN assessments a ON m.exercise = a.exercise
WHERE (
    -- Tier 1: Use assessments table if exercise exists
    a.assessment_type = 'Summative'
    OR
    -- Tier 2: Fallback to keyword detection if exercise not in assessments
    (a.exercise IS NULL AND (
        m.exercise LIKE '%Summative%'
        OR m.exercise LIKE '%All Summative Questions%'
    ))
)
```

## Files to Update

### 1. get_learners_with_poe_assigned.php
**Lines 311 & 356:** Change from INNER JOIN to LEFT JOIN with fallback

### 2. test_temp_tables_logic.php
**Lines 98 & 143:** Change from INNER JOIN to LEFT JOIN with fallback

## Expected Results After Fix

### Before (INNER JOIN only):
```
Learner 1231:
- Exercises in marks table: 200+
- Exercises matched with assessments: 2
- Unit standards detected: 2 ❌
```

### After (LEFT JOIN + Fallback):
```
Learner 1231:
- Exercises in marks table: 200+
- Exercises matched with assessments: 2 (Tier 1)
- Exercises matched with keywords: 50+ (Tier 2)
- Unit standards detected: 10 ✅
```

## Implementation Details

### MySQL 8.0+ Version (with REGEXP_SUBSTR)

```sql
CREATE TEMPORARY TABLE temp_learner_marks AS
SELECT 
    unit_standard_totals.learnerID,
    COUNT(DISTINCT unit_standard_totals.unit_standard_id) as unit_standard_count,
    AVG(unit_standard_totals.unit_standard_total) as avg_marks
FROM (
    SELECT 
        m.learnerID,
        CAST(REGEXP_SUBSTR(m.exercise, '[0-9]{4,5}') AS UNSIGNED) as unit_standard_id,
        SUM(m.marks_scored) as unit_standard_total
    FROM marks m
    INNER JOIN temp_poe_learners tpl ON m.learnerID = tpl.learnerID
    LEFT JOIN assessments a ON m.exercise = a.exercise  -- ✅ Changed to LEFT JOIN
    WHERE m.marks_scored IS NOT NULL
    AND (
        -- Tier 1: Use assessments table if available
        a.assessment_type = 'Summative'
        OR
        -- Tier 2: Fallback to keyword detection
        (a.exercise IS NULL AND (
            m.exercise LIKE '%Summative%'
            OR m.exercise LIKE '%All Summative Questions%'
        ))
    )
    AND m.exercise IS NOT NULL
    AND m.exercise != ''
    AND m.exercise REGEXP '[0-9]{4,5}'
    GROUP BY m.learnerID, unit_standard_id
) AS unit_standard_totals
WHERE unit_standard_id > 0 AND unit_standard_id < 99999
GROUP BY unit_standard_totals.learnerID
```

### MySQL 5.7/MariaDB Version

```sql
CREATE TEMPORARY TABLE temp_learner_marks AS
SELECT 
    unit_standard_totals.learnerID,
    COUNT(DISTINCT unit_standard_totals.unit_standard_id) as unit_standard_count,
    AVG(unit_standard_totals.unit_standard_total) as avg_marks
FROM (
    SELECT 
        m.learnerID,
        CAST(
            SUBSTRING(
                m.exercise,
                LOCATE(
                    SUBSTRING_INDEX(
                        SUBSTRING_INDEX(
                            SUBSTRING_INDEX(m.exercise, ' - ', 2),
                            ' - ',
                            -1
                        ),
                        ' ',
                        1
                    ),
                    m.exercise
                ),
                5
            ) AS UNSIGNED
        ) as unit_standard_id,
        SUM(m.marks_scored) as unit_standard_total
    FROM marks m
    INNER JOIN temp_poe_learners tpl ON m.learnerID = tpl.learnerID
    LEFT JOIN assessments a ON m.exercise = a.exercise  -- ✅ Changed to LEFT JOIN
    WHERE m.marks_scored IS NOT NULL
    AND (
        -- Tier 1: Use assessments table if available
        a.assessment_type = 'Summative'
        OR
        -- Tier 2: Fallback to keyword detection
        (a.exercise IS NULL AND (
            m.exercise LIKE '%Summative%'
            OR m.exercise LIKE '%All Summative Questions%'
        ))
    )
    AND m.exercise IS NOT NULL
    AND m.exercise != ''
    AND m.exercise REGEXP '[0-9]{4,5}'
    GROUP BY m.learnerID, unit_standard_id
) AS unit_standard_totals
WHERE unit_standard_id > 0 AND unit_standard_id < 99999
GROUP BY unit_standard_totals.learnerID
```

## Why This Works

1. **LEFT JOIN instead of INNER JOIN**: Includes all marks, even if exercise doesn't exist in assessments table

2. **Two-Tier Detection**:
   - **Tier 1**: If exercise exists in assessments table (`a.exercise IS NOT NULL`), use `a.assessment_type = 'Summative'`
   - **Tier 2**: If exercise doesn't exist in assessments table (`a.exercise IS NULL`), check if exercise text contains "Summative" keywords

3. **Comprehensive Coverage**: Captures summative marks from both:
   - Exercises defined in assessments table (authoritative)
   - Exercises with "Summative" in their name (fallback)

4. **Accurate Counts**: With all summative marks included, we get:
   - Correct unit standards count (10 instead of 2)
   - Accurate performance levels
   - Proper marking status

## Testing Instructions

### Step 1: Run Diagnostic Script
```
http://102.130.118.179/diagnose_learner_1231_summative.php
```

**Check Step 4:** "Marks + Assessments Join"
- Before fix: 2 rows (only 2 exercises matched)
- After fix: 50+ rows (includes keyword matches)

**Check Step 5:** "Marks Exercises NOT Found in Assessments"
- Before fix: 200+ unmatched exercises
- After fix: Most exercises with "Summative" keyword will be included

### Step 2: Test Temp Tables Logic
```
http://102.130.118.179/test_temp_tables_logic.php?moderator_id=77
```

**Check Step 3:** temp_learner_marks
- Before fix: 2-5 unit standards for learner 1231
- After fix: 10 unit standards for learner 1231 ✅

### Step 3: Test API Endpoint
```
http://102.130.118.179/get_learners_with_poe_assigned.php?moderator_id=77
```

**Check learner 1231 in response:**
```json
{
  "LearnerID": 1231,
  "unit_standards_count": 10,  // ✅ Should be 10 now
  "marking_status": "Marked",
  "performance_level": "High/Medium/Low"  // ✅ Should have a level
}
```

## Long-Term Solution

The proper long-term fix is to **populate the assessments table** with all exercises and their correct assessment types. This fallback approach is a temporary solution until the assessments table is complete.

### To populate assessments table:
```sql
-- Insert missing exercises from marks table
INSERT INTO assessments (exercise, assessment_type)
SELECT DISTINCT 
    m.exercise,
    CASE 
        WHEN m.exercise LIKE '%Summative%' THEN 'Summative'
        WHEN m.exercise LIKE '%Formative%' THEN 'Formative'
        ELSE 'Unknown'
    END as assessment_type
FROM marks m
LEFT JOIN assessments a ON m.exercise = a.exercise
WHERE a.exercise IS NULL
AND m.exercise IS NOT NULL
AND m.exercise != '';
```

## Status: READY TO IMPLEMENT ✅

The fallback approach is ready to be implemented in both files. This will ensure all summative marks are counted, even if the assessments table is incomplete.
