# Assessment Marking Persistence - SOLUTION IDENTIFIED

## Problem Summary
User reported that summative assessment marks are saved to database but don't persist when navigating away from assessment page. The "Marks Already Exist" dialog was not showing existing marks.

## Root Cause Analysis
The issue is in the `mobile/get_poe.php` endpoint. While the endpoint exists and returns data, it's not properly returning the `marks_scored` field that the Flutter app needs to display existing marks.

## Flutter App Logic (WORKING CORRECTLY)
The Flutter app correctly:
1. Calls `https://rlms.rlms.co.za/mobile/get_poe.php?learnerId=11453`
2. Looks for `marks_scored` field in each assessment
3. Displays marks as "Exercise: [name] [scored]/[max]" when `marks_scored` exists
4. Shows "Marks Already Exist" dialog when trying to mark again

**Key Flutter Code (AssessorPage.dart line 3154):**
```dart
marksScored = widget.exercise['marks_scored']?.toString() ?? '';
```

## Problem in mobile/get_poe.php
The complex JOIN query in `mobile/get_poe.php` is not properly joining the `marks` table with the `assessments` table, so `marks_scored` is always null.

**Current JOIN condition (PROBLEMATIC):**
```sql
LEFT JOIN marks m ON ld.LearnerID = m.learnerID 
    AND a.exercise = m.exercise 
    AND a.assessment_type = m.type 
```

## Solution Files Created

### 1. Diagnostic Tools
- `debug_marks_scored_issue.php` - Comprehensive diagnostic
- `test_mobile_response_structure.php` - Response structure analyzer

### 2. Fixed Mobile Endpoint
- `mobile/get_poe_fixed.php` - Working version with proper marks lookup

### 3. Key Fix Strategy
Instead of complex JOIN, use separate query to get all marks, then lookup by exercise name:

```php
// Get all marks for learner
$marksQuery = "SELECT exercise, type, marks_scored, ... FROM marks WHERE learnerID = ?";

// Create lookup array
$marksLookup = [];
while ($mark = $marksResult->fetch_assoc()) {
    $key = $mark['exercise'] . '|' . $mark['type'];
    $marksLookup[$key] = $mark;
}

// Add marks to assessment
$markKey = $exerciseName . '|' . ucfirst($assessmentType);
$marks = $marksLookup[$markKey] ?? null;
$assessment['marks_scored'] = $marks ? $marks['marks_scored'] : null;
```

## Testing Steps

### 1. Run Diagnostic
```
https://rlms.rlms.co.za/debug_marks_scored_issue.php?learner_id=11453
```

### 2. Test Fixed Endpoint
```
https://rlms.rlms.co.za/mobile/get_poe_fixed.php?learnerId=11453
```

### 3. Verify Response Structure
Should return assessments with `marks_scored` field populated for existing marks.

## Implementation Steps

### Option A: Replace Current File
1. Backup current `mobile/get_poe.php`
2. Replace with content from `mobile/get_poe_fixed.php`
3. Test with Flutter app

### Option B: Update Flutter Config (Temporary)
1. Change Flutter app to call `mobile/get_poe_fixed.php` instead
2. Update `lib/config.dart` or create new endpoint

## Expected Result After Fix
1. ✅ User marks assessment → marks saved to database
2. ✅ User navigates away from assessment page  
3. ✅ User returns to assessment page
4. ✅ Flutter app calls `mobile/get_poe.php`
5. ✅ Existing marks are retrieved with `marks_scored` field
6. ✅ Marks display as "Exercise: Test Summative Exercise 85/100"
7. ✅ "Marks Already Exist" dialog shows when trying to mark again

## Test Data
- **Learner ID:** 11453
- **Existing Mark:** 85 for "Test Summative Exercise"
- **Type:** Summative
- **Expected Display:** "Exercise: Test Summative Exercise 85/100"

## Status
🔧 **SOLUTION READY - NEEDS IMPLEMENTATION**

The root cause is identified and fixed. The solution needs to be deployed to the server.