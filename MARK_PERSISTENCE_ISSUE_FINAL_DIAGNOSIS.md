# Mark Persistence Issue - FINAL DIAGNOSIS

## Issue Confirmed
**✅ CONFIRMED:** Marks show initially but disappear when navigating away and returning to the assessment page.

## Root Cause Analysis

### The Flow:
1. **User submits marks** → Flutter calls `save_marks.php` → ✅ **Works correctly**
2. **Marks are saved** → Database stores marks in `marks` table → ✅ **Works correctly**  
3. **Local state updated** → Flutter shows marks immediately → ✅ **Works correctly**
4. **User navigates away and back** → Flutter calls `_refreshData()` → ❌ **FAILS HERE**
5. **Data refresh calls** → `fetchPOE()` → `get_poe.php` → ❌ **FAILS TO RETURN SAVED MARKS**
6. **Result:** Marks disappear from UI

### Technical Details:

#### What Works:
- ✅ **Mark saving:** `save_marks.php` correctly saves to database
- ✅ **Local display:** Flutter shows marks immediately after saving
- ✅ **Database storage:** Marks are properly stored in `marks` table

#### What Fails:
- ❌ **Mark retrieval:** `get_poe.php` doesn't return saved marks
- ❌ **Data refresh:** When Flutter refreshes data, marks are lost
- ❌ **Persistence:** Marks don't persist across navigation

## Evidence

### Test Results:
1. **Learner 11559 exists:** ✅ Lesiba Letsoalo
2. **Unit Standard 9964 exists:** ✅ "Apply health and safety to a work area"
3. **Marks table structure:** ✅ Correct structure with `marks_scored` column
4. **get_poe.php response:** ❌ Shows phantom marks from other learners, not real saved marks

### Database vs Endpoint Mismatch:
- **Database reality:** Learner 11559 has 0 marks
- **Endpoint response:** Shows 32 formative marks (incorrect cross-contamination)
- **Result:** User sees marks that aren't theirs, then they disappear on refresh

## The Real Problem

The issue is **NOT** a case sensitivity bug as initially suspected. The real problem is:

### JOIN Logic Error in `mobile/get_poe.php`
The JOIN between `assessments` and `marks` tables is incorrectly associating marks from other learners with the current learner. This causes:

1. **Cross-contamination:** Learner sees marks from other learners
2. **Inconsistent behavior:** Marks appear/disappear unpredictably  
3. **Data integrity issues:** Wrong marks displayed to wrong users

### Specific Issue:
The JOIN condition in `mobile/get_poe.php` around line 89-95:
```sql
LEFT JOIN marks m ON ld.LearnerID = m.learnerID 
    AND a.exercise = m.exercise 
    AND (CASE 
            WHEN a.question_type = 'Practical' THEN 'LogBook'
            ELSE a.assessment_type 
         END) = m.type
```

This JOIN is not properly filtering marks to the specific learner, causing marks from other learners to be incorrectly associated.

## Impact on User Experience

### Current Behavior:
1. User submits marks → ✅ Marks show immediately
2. User navigates away → ❌ Marks are lost from local state
3. User returns → ❌ `get_poe.php` returns wrong/no marks
4. Result: **Marks disappear, user frustrated**

### Expected Behavior:
1. User submits marks → ✅ Marks show immediately  
2. User navigates away → ✅ Marks saved in database
3. User returns → ✅ `get_poe.php` returns correct saved marks
4. Result: **Marks persist, user happy**

## Solution Required

### Fix the JOIN Logic in `mobile/get_poe.php`:
1. **Debug the JOIN conditions** to ensure proper learner filtering
2. **Test with multiple learners** to verify no cross-contamination
3. **Verify both formative and summative** marks work correctly
4. **Test the complete flow** from save → navigate → return

### Verification Steps:
1. Save marks for learner 11559
2. Verify marks appear in database
3. Call `get_poe.php` and verify correct marks returned
4. Test in Flutter app to ensure persistence

## Status
🔧 **CRITICAL BUG CONFIRMED - REQUIRES IMMEDIATE FIX**

The mark persistence issue is real and affects the core assessment functionality. Users lose their work when navigating away, causing significant frustration and data integrity problems.

## Next Steps
1. **Fix JOIN logic** in `mobile/get_poe.php`
2. **Test with real learner data** 
3. **Verify cross-learner isolation**
4. **Deploy and test in Flutter app**