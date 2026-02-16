# Performance Percentage Calculation Fix ✅

## User Requirement

> "In order for us to get the correct performance, we need to calculate against the marks that are stored in the assessments table. These marks are for the questions in the exercise that a learner is assessed against, so we need to get our performance level in the marks_scored column in the marks table against the marks in the assessments table."

## Problem

The previous calculation was summing raw `marks_scored` values without considering the total possible marks for each exercise. This gave incorrect performance levels because:
- Different exercises have different total marks (some worth 10, others worth 50, etc.)
- Simply summing marks_scored doesn't give a true percentage
- Performance level should be based on percentage achieved, not raw scores

## Solution Implemented

Calculate **percentage performance** for each exercise by comparing:
- **marks_scored** (from `marks` table) - what the learner achieved
- **marks** (from `assessments` table) - total possible marks for that exercise

### Formula
```
Performance % = (marks_scored / assessments.marks) × 100
```

### Calculation Logic

**For each learner:**
1. Get all summative exercises with marks
2. For each exercise, calculate: `(marks_scored / assessments.marks) × 100`
3. Average the percentages across all exercises in each unit standard
4. Average the unit standard percentages to get overall performance
5. Classify: High (70%+), Medium (50-69%), Low (<50%)

## SQL Implementation

### Before (Incorrect - Raw Scores):
```sql
SELECT 
    m.learnerID,
    CAST(REGEXP_SUBSTR(m.exercise, '[0-9]{4,5}') AS UNSIGNED) as unit_standard_id,
    SUM(m.marks_scored) as unit_standard_total  -- ❌ Raw sum
FROM marks m
GROUP BY m.learnerID, unit_standard_id
```

### After (Correct - Percentage):
```sql
SELECT 
    m.learnerID,
    CAST(REGEXP_SUBSTR(m.exercise, '[0-9]{4,5}') AS UNSIGNED) as unit_standard_id,
    AVG(
        CASE 
            WHEN a.marks IS NOT NULL AND a.marks > 0 
            THEN (m.marks_scored / a.marks) * 100  -- ✅ Percentage
            ELSE m.marks_scored  -- Fallback if no total marks
        END
    ) as unit_standard_percentage
FROM marks m
LEFT JOIN assessments a ON m.exercise = a.exercise
WHERE a.assessment_type = 'Summative'
GROUP BY m.learnerID, unit_standard_id
```

## Example Calculation

### Learner 1231 - Unit Standard 9964

**Exercise 1:** "Define a safe site"
- marks_scored: 8
- assessments.marks: 10
- Percentage: (8/10) × 100 = **80%**

**Exercise 2:** "What are safety hazards?"
- marks_scored: 35
- assessments.marks: 50
- Percentage: (35/50) × 100 = **70%**

**Exercise 3:** "Common sources of incidents"
- marks_scored: 18
- assessments.marks: 20
- Percentage: (18/20) × 100 = **90%**

**Unit Standard 9964 Average:** (80 + 70 + 90) / 3 = **80%** → **High Performance**

### Overall Performance
Average across all 10 unit standards → Final performance level

## Files Updated

### 1. get_learners_with_poe_assigned.php
**Lines 311-340 & 342-371:** Changed calculation from SUM to AVG with percentage

**Key Changes:**
- Changed `SUM(m.marks_scored)` to `AVG((m.marks_scored / a.marks) * 100)`
- Added CASE statement to handle NULL marks in assessments table
- Uses percentage for accurate performance calculation

### 2. test_temp_tables_logic.php
**Lines 98-127 & 129-158:** Changed calculation from SUM to AVG with percentage

**Key Changes:**
- Same percentage calculation as main API
- Allows testing the calculation logic independently

### 3. check_assessments_marks_column.php
**New diagnostic script** to verify:
- Assessments table has `marks` column
- Sample data showing marks_scored vs total marks
- Percentage calculations working correctly

## How It Works

### Step 1: Join Marks with Assessments
```sql
FROM marks m
LEFT JOIN assessments a ON m.exercise = a.exercise
```
- Joins on exercise text to get total marks for each exercise

### Step 2: Calculate Percentage Per Exercise
```sql
CASE 
    WHEN a.marks IS NOT NULL AND a.marks > 0 
    THEN (m.marks_scored / a.marks) * 100
    ELSE m.marks_scored
END
```
- If assessments.marks exists and > 0: Calculate percentage
- Otherwise: Use raw marks_scored as fallback

### Step 3: Average Per Unit Standard
```sql
AVG(...) as unit_standard_percentage
GROUP BY m.learnerID, unit_standard_id
```
- Averages all exercise percentages within each unit standard

### Step 4: Average Across All Unit Standards
```sql
AVG(unit_standard_totals.unit_standard_percentage) as avg_marks
GROUP BY unit_standard_totals.learnerID
```
- Averages all unit standard percentages for overall performance

### Step 5: Classify Performance Level
```sql
CASE 
    WHEN tm.avg_marks IS NULL THEN 'Not Assessed'
    WHEN tm.avg_marks >= 70 THEN 'High'
    WHEN tm.avg_marks >= 50 THEN 'Medium'
    WHEN tm.avg_marks >= 0 THEN 'Low'
    ELSE 'Not Assessed'
END as performance_level
```

## Expected Results

### Before Fix (Raw Scores):
```
Learner 1231:
- Unit Standard 9964: 61 marks (raw sum)
- Unit Standard 14555: 45 marks (raw sum)
- Average: 53 marks
- Performance: Medium (incorrect - not a percentage!)
```

### After Fix (Percentage):
```
Learner 1231:
- Unit Standard 9964: 80% (average of exercise percentages)
- Unit Standard 14555: 75% (average of exercise percentages)
- Average: 77.5%
- Performance: High ✅ (correct percentage-based classification)
```

## Testing Instructions

### Step 1: Check Assessments Table Structure
```
http://102.130.118.179/check_assessments_marks_column.php
```

**Verify:**
- Assessments table has `marks` column
- Sample data shows marks values (10, 20, 50, etc.)
- Percentage calculations are working

### Step 2: Upload Updated Files
```batch
UPLOAD_PERFORMANCE_PERCENTAGE_FIX.bat
```

### Step 3: Test Temp Tables Logic
```
http://102.130.118.179/test_temp_tables_logic.php?moderator_id=77
```

**Check Step 3 (temp_learner_marks):**
- Avg Marks should now be percentages (0-100)
- Performance Level should be based on percentage thresholds
- High: 70%+, Medium: 50-69%, Low: <50%

### Step 4: Test API Endpoint
```
http://102.130.118.179/get_learners_with_poe_assigned.php?moderator_id=77
```

**Check learner data:**
```json
{
  "LearnerID": 1231,
  "unit_standards_count": 10,
  "performance_level": "High",  // ✅ Based on percentage
  "marking_status": "Marked"
}
```

### Step 5: Reset Assignments (Optional)
To recalculate with new percentage-based performance:
```sql
DELETE FROM moderator_assignments WHERE moderator_id = '77';
```

Then call API again for fresh assignments with correct performance levels.

## Why This Fix Is Correct

1. **Accurate Comparison:** Compares what learner achieved vs what was possible
2. **Fair Assessment:** Normalizes scores across exercises with different total marks
3. **True Percentage:** Performance level based on actual percentage achieved
4. **Proper Stratification:** Learners correctly classified as High/Medium/Low performers

## Impact on Stratification

With percentage-based performance calculation:

### Performance Level Distribution
- **High (70%+):** Learners who achieved 70% or more on average
- **Medium (50-69%):** Learners who achieved 50-69% on average
- **Low (<50%):** Learners who achieved less than 50% on average
- **Not Assessed:** Learners with no summative marks

### Sampling
- Moderators will see accurate performance-based stratification
- 25% sampled from each performance level
- Truly representative of learner achievement

## Database Schema Reference

### marks table
- `learnerID` - Links to learnerdetails
- `exercise` - Exercise name (TEXT)
- `marks_scored` - **Marks achieved by learner** ✅
- `type` - Assessment type (Formative/Summative)

### assessments table
- `exercise` - Exercise name (TEXT)
- `assessment_type` - "Summative" or "Formative"
- `marks` - **Total possible marks for exercise** ✅
- `unit_standard_id` - Unit standard ID

### Join Column
The **`exercise`** column is used to join marks with assessments to get total marks.

## Status: READY FOR TESTING ✅

Both files have been updated with percentage-based performance calculation. The implementation correctly calculates performance as:

**Performance % = (marks_scored / assessments.marks) × 100**

Upload the files and test to verify accurate performance levels!
