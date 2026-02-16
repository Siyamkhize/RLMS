# Diagnose: Both Marks Not Showing

## Problem
The API is not showing marks for both unit standards (13958 and 14555).

## Possible Causes

### 1. Only ONE Unit Standard Has Marks in Database
**Most Likely Cause**: The database only has marks for ONE unit standard, not both.

**Check:**
```sql
SELECT 
    learner_id,
    unit_standard_id,
    marks,
    assessment_date
FROM logbook_marks 
WHERE learner_id = 'YOUR_LEARNER_ID' 
  AND unit_standard_id IN ('13958', '14555')
ORDER BY unit_standard_id ASC;
```

**Expected Result:** 2 rows (one for 13958, one for 14555)
**If you see:** Only 1 row → Only one unit standard has been marked

**Solution:** The assessor needs to mark BOTH unit standards:
- Unit Standard 13958
- Unit Standard 14555

### 2. Frontend Not Displaying Array Correctly
The backend returns an array, but the frontend might not be handling it.

**Backend Response:**
```json
{
  "unit_standards": [
    {"unit_standard_id": "13958", "marks": 77, ...},
    {"unit_standard_id": "14555", "marks": 85", ...}
  ]
}
```

**Frontend Code Needed:**
```dart
List<dynamic> unitStandards = data['unit_standards'] ?? [];
for (var us in unitStandards) {
  String unitId = us['unit_standard_id'];
  int marks = us['marks'];
  // Display each unit standard
}
```

### 3. Old Cached Response
The frontend might be showing cached data from before the fix.

**Solution:**
- Clear app cache
- Restart the app
- Force refresh the data

## Diagnostic Steps

### Step 1: Check Database
Run this SQL query:
```sql
SELECT COUNT(*) as count, unit_standard_id
FROM logbook_marks 
WHERE learner_id = 'YOUR_LEARNER_ID' 
  AND unit_standard_id IN ('13958', '14555')
GROUP BY unit_standard_id;
```

**Results:**
- If count = 2 (one for each unit standard) → Database is correct, check frontend
- If count = 1 → Only one unit standard has marks, assessor needs to mark the other
- If count = 0 → No marks at all

### Step 2: Test API Directly
Test the API endpoint directly in browser or Postman:
```
GET http://your-server/php/view_pothole_checklists.php?learner_id=17391
```

**Check Response:**
- Does `unit_standards` array exist?
- How many items in the array?
- Are both unit standards present?

### Step 3: Check Frontend Code
Look at how the frontend handles the response:

**Old Code (Wrong):**
```dart
int marks = data['marks_scored'];  // Only gets one mark
```

**New Code (Correct):**
```dart
List<dynamic> unitStandards = data['unit_standards'] ?? [];
// Loop through all unit standards
```

## Common Scenarios

### Scenario A: Database Has Both Marks, Frontend Shows One
**Cause:** Frontend not updated to handle array
**Solution:** Update frontend code to loop through `unit_standards` array

### Scenario B: Database Has One Mark, Frontend Shows One
**Cause:** Assessor only marked one unit standard
**Solution:** Assessor needs to mark the second unit standard

### Scenario C: API Returns Both, Frontend Shows One
**Cause:** Frontend only displaying first item in array
**Solution:** Update frontend to display ALL items in array

## Quick Test

### Test 1: Check Raw Database
```sql
-- Should return 2 rows
SELECT * FROM logbook_marks 
WHERE learner_id = '17391' 
  AND unit_standard_id IN ('13958', '14555');
```

### Test 2: Check API Response
```bash
curl "http://your-server/php/view_pothole_checklists.php?learner_id=17391"
```

Look for:
```json
{
  "data": {
    "unit_standards": [
      {...},  // First unit standard
      {...}   // Second unit standard
    ]
  }
}
```

### Test 3: Check Frontend
Add debug print in Flutter:
```dart
print('Unit Standards Count: ${data['unit_standards']?.length}');
print('Unit Standards: ${data['unit_standards']}');
```

## Solution Based on Diagnosis

### If Database Has Only 1 Mark:
The assessor needs to mark BOTH unit standards. The system is working correctly, but only one assessment has been completed.

### If Database Has 2 Marks, API Returns 1:
There's a bug in the PHP code. Check that `LIMIT 1` was removed from the query.

### If API Returns 2, Frontend Shows 1:
Update the frontend to loop through the array:

```dart
// Get the array
List<dynamic> unitStandards = data['unit_standards'] ?? [];

// Display each one
for (var us in unitStandards) {
  Widget buildUnitStandardCard(us);
}
```

## Files to Check

1. **Backend:** `php/view_pothole_checklists.php`
   - Verify no `LIMIT 1` in query
   - Verify `while` loop builds array

2. **Frontend:** `lib/ModeratorPage.dart`
   - Check how `unit_standards` is accessed
   - Verify loop through all items

3. **Database:** `logbook_marks` table
   - Check if both unit standards exist
   - Verify learner_id matches

## Expected Behavior

When working correctly:
1. Database has 2 rows (one for each unit standard)
2. API returns array with 2 items
3. Frontend displays 2 separate cards/sections
4. Each shows its own marks and moderation data
