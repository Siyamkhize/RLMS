# Performance Calculation Fix - SUM Method Implementation

## Issue
The performance calculation was using **AVG** to calculate percentage per question, then averaging those percentages. This gives incorrect results.

**Example of WRONG calculation:**
- Unit Standard 9964 has 3 questions:
  - Question 1: Scored 3/10 = 30%
  - Question 2: Scored 5/10 = 50%
  - Question 3: Scored 6/10 = 60%
- **WRONG**: AVG(30%, 50%, 60%) = 46.67%

**Example of CORRECT calculation:**
- Unit Standard 9964 has 3 questions:
  - Question 1: Scored 3 marks (out of 10 possible)
  - Question 2: Scored 5 marks (out of 10 possible)
  - Question 3: Scored 6 marks (out of 10 possible)
- **CORRECT**: (3+5+6) / (10+10+10) × 100 = 14/30 × 100 = 46.67%

Wait, that's the same! Let me recalculate with different possible marks:

**Example with different possible marks:**
- Unit Standard 9964 has 3 questions:
  - Question 1: Scored 3 marks (out of 5 possible)
  - Question 2: Scored 5 marks (out of 10 possible)
  - Question 3: Scored 6 marks (out of 15 possible)
- **WRONG**: AVG(3/5×100, 5/10×100, 6/15×100) = AVG(60%, 50%, 40%) = 50%
- **CORRECT**: (3+5+6) / (5+10+15) × 100 = 14/30 × 100 = 46.67%

## Solution
Changed the calculation to:
1. **SUM all marks_scored** for all questions in a unit standard
2. **SUM all assessments.marks** (possible marks) for those questions
3. **Calculate percentage**: (total_scored / total_possible) × 100
4. **Average across all unit standards** to get overall performance

## Changes Made

### File: `get_learners_with_poe_assigned.php`

**Lines ~303-340 (MySQL 8.0+ version):**
```sql
-- BEFORE (WRONG):
AVG(
    CASE 
        WHEN a.marks IS NOT NULL AND a.marks > 0 
        THEN (m.marks_scored / a.marks) * 100
        ELSE m.marks_scored
    END
) as unit_standard_percentage

-- AFTER (CORRECT):
(SUM(m.marks_scored) / SUM(a.marks)) * 100 as unit_standard_percentage
```

**Lines ~342-380 (MySQL 5.7/MariaDB version):**
Same change applied.

### File: `test_temp_tables_logic.php`

**Lines ~90-127 (MySQL 8.0+ version):**
Same change applied.

**Lines ~129-168 (MySQL 5.7/MariaDB version):**
Same change applied.

## How It Works Now

### Step 1: Calculate percentage per unit standard
For each learner and each unit standard:
```sql
SELECT 
    m.learnerID,
    unit_standard_id,
    (SUM(m.marks_scored) / SUM(a.marks)) * 100 as unit_standard_percentage
FROM marks m
LEFT JOIN assessments a ON m.exercise = a.exercise
WHERE ... (summative marks only)
GROUP BY m.learnerID, unit_standard_id
```

### Step 2: Average across all unit standards
```sql
SELECT 
    learnerID,
    COUNT(DISTINCT unit_standard_id) as unit_standard_count,
    AVG(unit_standard_percentage) as avg_marks
FROM unit_standard_totals
GROUP BY learnerID
```

### Step 3: Classify performance level
```sql
CASE 
    WHEN avg_marks IS NULL THEN 'Not Assessed'
    WHEN avg_marks >= 70 THEN 'High'
    WHEN avg_marks >= 50 THEN 'Medium'
    WHEN avg_marks >= 0 THEN 'Low'
    ELSE 'Not Assessed'
END as performance_level
```

## Testing

Run the test script to verify:
```bash
php test_temp_tables_logic.php?moderator_id=77
```

Check that:
1. **Avg Marks** are calculated correctly (SUM method)
2. **Performance Level** matches the avg marks:
   - High: 70%+
   - Medium: 50-69%
   - Low: 0-49%
   - Not Assessed: NULL

## Deployment

Upload both files to the server:
1. `get_learners_with_poe_assigned.php` - Main API
2. `test_temp_tables_logic.php` - Test script

## Status
✅ **COMPLETE** - Performance calculation now uses correct SUM method
