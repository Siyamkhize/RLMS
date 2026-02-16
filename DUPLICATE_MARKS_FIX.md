# Duplicate Marks Issue Fix - Complete Solution

## Problem Description
When a unit standard has the same exercise/question appearing in both formative and summative assessments, the system was incorrectly treating them as duplicates and preventing the second one from being saved.

### Specific Issue
- User marks formative assessment ✅ (saves correctly)
- User tries to mark summative assessment ❌ (gets "already marked" error)
- System saves formative marks for summative because it thinks they're the same

## Root Cause Analysis
The issue was in the duplicate checking logic in `save_marks.php`:

1. **Type Determination Problem**: The backend was looking up assessment type from database using only exercise name, ignoring the formative/summative context from the Flutter app.

2. **Insufficient Duplicate Check**: The duplicate check was only considering `learnerID + exercise + type`, but when both formative and summative had the same exercise name, they would get the same type from database lookup.

3. **Context Loss**: The original assessment context (formative vs summative) from the Flutter app was being lost during type determination.

## Solution Implemented

### 1. Enhanced Type Determination Logic
```php
// Priority-based type determination:
// 1. Use exercise type context from Flutter app
// 2. Fallback to database lookup
// 3. Infer from exercise name
// 4. Default to appropriate type

if (isset($exercise['type']) && !empty($exercise['type'])) {
    $exerciseTypeContext = $exercise['type'];
    if (stripos($exerciseTypeContext, 'formative') !== false) {
        $actualAssessmentType = 'Formative';
    } elseif (stripos($exerciseTypeContext, 'summative') !== false) {
        $actualAssessmentType = 'Summative';
    } elseif (stripos($exerciseTypeContext, 'logbook') !== false) {
        $actualAssessmentType = 'Logbook';
    }
}
```

### 2. Comprehensive Duplicate Check
```php
// Enhanced duplicate check using all relevant fields:
$checkQuery = $conn->prepare("SELECT id, marks_scored FROM marks WHERE learnerID = ? AND exercise = ? AND type = ? AND so = ?");
$checkQuery->bind_param("isss", $learnerId, $exerciseName, $actualAssessmentType, $specificOutcome);
```

### 3. Key Improvements Made

#### A. Context Preservation
- The system now preserves the original assessment context (formative/summative) from the Flutter app
- Type determination prioritizes the context information over database lookup

#### B. Multi-Level Type Detection
1. **Primary**: Exercise type from Flutter app (`exercise['type']`)
2. **Secondary**: Database lookup from assessments table
3. **Tertiary**: Pattern matching in exercise name
4. **Fallback**: Intelligent default based on original type

#### C. Enhanced Duplicate Detection
- Checks combination of: `learnerID + exercise + type + specific_outcome`
- Provides detailed error messages with existing marks information
- Distinguishes between formative and summative versions of same exercise

## How It Works Now

### Scenario: Same Exercise in Formative and Summative

**Before Fix:**
```
1. Save formative "Exercise 1" → type: "Formative" ✅
2. Save summative "Exercise 1" → type: "Formative" (wrong!) ❌
   Error: "Already marked"
```

**After Fix:**
```
1. Save formative "Exercise 1" → type: "Formative" ✅
2. Save summative "Exercise 1" → type: "Summative" ✅
   Both saved as separate records
```

### Data Flow
```
Flutter App → sends exercise with type context
     ↓
PHP Backend → preserves context during type determination
     ↓
Database → saves with correct type (Formative/Summative/Logbook)
```

## Testing the Fix

### Test Case 1: Same Exercise, Different Types
```json
// Formative
{
  "learnerId": 12345,
  "exercise": {
    "exercise": "Safety Procedures",
    "type": "formative"
  },
  "marksScored": 85,
  "assessmentType": "POE",
  "specific_outcome": ["719", "720"]
}

// Summative  
{
  "learnerId": 12345,
  "exercise": {
    "exercise": "Safety Procedures", 
    "type": "summative"
  },
  "marksScored": 90,
  "assessmentType": "POE",
  "specific_outcome": ["719", "720"]
}
```

**Expected Result**: Both save successfully as separate records.

### Test Case 2: True Duplicate
```json
// First submission
{
  "learnerId": 12345,
  "exercise": {
    "exercise": "Safety Procedures",
    "type": "formative"
  },
  "marksScored": 85,
  "specific_outcome": ["719", "720"]
}

// Duplicate submission
{
  "learnerId": 12345,
  "exercise": {
    "exercise": "Safety Procedures",
    "type": "formative"
  },
  "marksScored": 90,
  "specific_outcome": ["719", "720"]
}
```

**Expected Result**: Second submission rejected with duplicate error.

## Files Modified
- `save_marks.php` - Main fix implementation
- `save_marks_fixed.php` - Backup version
- `test_marks_fix.php` - Test script

## Benefits
✅ Formative and summative assessments are now properly distinguished  
✅ Same exercise can be marked in both contexts  
✅ True duplicates are still prevented  
✅ Better error messages with context  
✅ Comprehensive logging for debugging  
✅ Backward compatible with existing data  

## Deployment Notes
1. Replace existing `save_marks.php` with the fixed version
2. Test with sample data using `test_marks_fix.php`
3. Monitor error logs for any issues
4. Verify database records show correct types

The fix ensures that assessors can now properly mark both formative and summative versions of the same exercise without conflicts.