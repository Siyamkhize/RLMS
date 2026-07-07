# Assessment Marking Issue CONFIRMED - Learner 11559

## Issue Summary
**CONFIRMED BUG:** The `mobile/get_poe.php` endpoint is incorrectly showing marks for learner 11559 (Lesiba Letsoalo) who has NO marks in the database.

## Evidence

### Database Reality:
- ✅ **Learner exists:** 11559 - Lesiba Letsoalo
- ✅ **Unit Standard 9964 exists** in project: "Apply health and safety to a work area"
- ❌ **Zero marks in marks table** for learner 11559
- ✅ **Project pathway correct:** Project ID 76, Class ID 161, Site ID 384

### Endpoint Response:
- ❌ **Shows 32/266 formative marks** (INCORRECT - should be 0)
- ✅ **Shows 0/332 summative marks** (CORRECT)
- ✅ **Shows 0/7 logbook marks** (CORRECT)

### Examples of Incorrect Data:
The endpoint incorrectly shows these marks for learner 11559:
- "Define a safe site" - ✅ 4/4
- "Define the term 'hazards'" - ✅ 3/3  
- "What are safety hazards?" - ✅ 4/6
- "List at least four types of hazards" - ✅ 4/4

## Root Cause Analysis

The issue is in the JOIN logic in `mobile/get_poe.php`. The query is incorrectly associating marks from other learners with learner 11559.

### Suspected Issues:
1. **Incorrect JOIN conditions** between assessments and marks tables
2. **Missing learner ID filter** in one of the JOINs
3. **Cross-contamination** where marks from other learners are being pulled

## Impact

### Current Problem:
- ✅ **Summative marks work correctly** (showing 0 when no marks exist)
- ❌ **Formative marks show incorrectly** (showing marks from other learners)
- ❌ **"Marks Already Exist" dialog** would trigger incorrectly for formative assessments
- ❌ **Users see phantom marks** that don't belong to them

### Flutter App Impact:
- Users see existing marks that aren't theirs
- Confusion about assessment completion status
- Incorrect "Marks Already Exist" dialogs
- Data integrity issues

## Technical Details

### Query Analysis Needed:
The JOIN between `assessments` and `marks` tables in `mobile/get_poe.php` needs investigation:

```sql
LEFT JOIN marks m ON ld.LearnerID = m.learnerID 
    AND a.exercise = m.exercise 
    AND (CASE 
            WHEN a.question_type = 'Practical' THEN 'LogBook'
            ELSE a.assessment_type 
         END) = m.type
```

### Hypothesis:
The JOIN condition might be missing a proper filter, causing marks from other learners to be incorrectly associated with learner 11559.

## Next Steps

1. **Debug the JOIN logic** in `mobile/get_poe.php`
2. **Identify why formative marks are cross-contaminating**
3. **Fix the JOIN conditions** to ensure learner-specific marks only
4. **Test with multiple learners** to verify the fix
5. **Verify summative marks continue working** (they seem correct)

## Status
🔧 **CONFIRMED BUG - NEEDS IMMEDIATE FIX**

The assessment marking persistence issue is real and affects formative assessments specifically. The system is showing marks from other learners, creating data integrity problems.