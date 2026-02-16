# Pothole Marks - Both Unit Standards Fix

## Problem
The API was only returning marks for ONE unit standard instead of BOTH (13958 and 14555).

### Root Cause
The query had `LIMIT 1` which stopped after finding the first unit standard:
```sql
-- OLD (WRONG)
SELECT ... FROM logbook_marks 
WHERE learner_id = ? AND unit_standard_id IN ('13958', '14555')
ORDER BY assessment_date DESC LIMIT 1  -- ❌ Only returns 1 row
```

## Solution
Removed `LIMIT 1` and changed the response structure to return an array of unit standards:

```sql
-- NEW (CORRECT)
SELECT unit_standard_id, marks, moderator_status, ... 
FROM logbook_marks 
WHERE learner_id = ? AND unit_standard_id IN ('13958', '14555')
ORDER BY unit_standard_id ASC  -- ✅ Returns all matching rows
```

## Changes Made

### 1. Query Changes
- Removed `LIMIT 1` to fetch ALL unit standards
- Added `unit_standard_id` to SELECT clause
- Changed ORDER BY to sort by `unit_standard_id` (13958 first, then 14555)

### 2. Response Structure Changes

**Before (Single Mark):**
```json
{
  "marks_scored": 77,
  "moderator_status": "upheld",
  "moderator_comment": "Good work",
  ...
}
```

**After (Array of Unit Standards):**
```json
{
  "unit_standards": [
    {
      "unit_standard_id": "13958",
      "marks": 77,
      "moderator_status": "upheld",
      "moderator_comment": "Good work on 13958",
      "moderator_id": "456",
      "moderation_date": "2026-01-20 10:05:08",
      "assessor_comment": "Well done"
    },
    {
      "unit_standard_id": "14555",
      "marks": 85,
      "moderator_status": "upheld",
      "moderator_comment": "Excellent on 14555",
      "moderator_id": "456",
      "moderation_date": "2026-01-20 10:05:08",
      "assessor_comment": "Great job"
    }
  ]
}
```

## Files Modified

### `php/view_pothole_checklists.php`
Updated both sections (scanned documents and system-generated checklists):

```php
// Fetch ALL unit standards (not just one)
$marks_sql = "SELECT unit_standard_id, marks, moderator_status, moderator_comment, 
                     moderator_id, moderation_date, assessor_comment 
              FROM logbook_marks 
              WHERE learner_id = ? AND unit_standard_id IN ('13958', '14555')
              ORDER BY unit_standard_id ASC";  // No LIMIT!

// Build array of unit standards
if ($marks_result->num_rows > 0) {
    $response_data['unit_standards'] = [];
    while ($marks_row = $marks_result->fetch_assoc()) {
        $response_data['unit_standards'][] = [
            'unit_standard_id' => $marks_row['unit_standard_id'],
            'marks' => (int)$marks_row['marks'],
            'moderator_status' => $marks_row['moderator_status'] ?? '',
            'moderator_comment' => $marks_row['moderator_comment'] ?? '',
            'moderator_id' => $marks_row['moderator_id'] ?? '',
            'moderation_date' => $marks_row['moderation_date'] ?? '',
            'assessor_comment' => $marks_row['assessor_comment'] ?? ''
        ];
    }
}
```

## Testing

Run the test script:
```bash
php test_both_unit_standards.php
```

Expected output:
```
✅ Found 2 unit standard(s):

Unit Standard: 13958
  Marks: 77
  Moderator Status: upheld
  ...

Unit Standard: 14555
  Marks: 85
  Moderator Status: upheld
  ...

✅ SUCCESS: Both unit standards (13958 and 14555) are returned!
```

## Frontend Impact

The frontend (ModeratorPage.dart) will need to be updated to handle the new structure:

**Before:**
```dart
int marks = data['marks_scored'];
String status = data['moderator_status'];
```

**After:**
```dart
List<dynamic> unitStandards = data['unit_standards'] ?? [];
for (var us in unitStandards) {
  String unitId = us['unit_standard_id'];  // "13958" or "14555"
  int marks = us['marks'];
  String status = us['moderator_status'];
  // Display each unit standard separately
}
```

## Benefits

✅ **Complete Data**: Both unit standards (13958 and 14555) are now returned
✅ **Clear Separation**: Each unit standard has its own marks and moderation data
✅ **Flexible**: Can easily add more unit standards in the future
✅ **Backward Compatible**: If only one unit standard exists, array will have 1 item
✅ **Non-Breaking**: Still wrapped in try-catch, won't break if marks don't exist

## Deployment Checklist

1. ✅ Update `php/view_pothole_checklists.php` on server
2. ⏳ Update frontend to handle `unit_standards` array
3. ⏳ Test with learners who have both unit standards marked
4. ⏳ Verify moderator can see both sets of marks separately

## Related Files
- `php/view_pothole_checklists.php` - Backend API (UPDATED)
- `lib/ModeratorPage.dart` - Frontend display (NEEDS UPDATE)
- `test_both_unit_standards.php` - Test script
- `POTHOLE_MARKS_QUERY_FIX.md` - Original fix documentation
