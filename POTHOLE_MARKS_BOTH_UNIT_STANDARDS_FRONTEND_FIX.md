# Pothole Marks - Both Unit Standards Frontend Fix

## Problem
The frontend was only displaying marks for ONE unit standard instead of BOTH (13958 and 14555) even though the backend was correctly returning both.

## Root Cause
The frontend code was accessing the OLD response format:
```dart
String marksScored = data?['marks_scored']?.toString() ?? '';
```

But the backend was updated to return the NEW format:
```json
{
  "unit_standards": [
    {"unit_standard_id": "13958", "marks": 43, ...},
    {"unit_standard_id": "14555", "marks": 49", ...}
  ]
}
```

## Solution
Updated `lib/ModeratorPage.dart` in the `_buildPotholeChecklistContent()` method to:
1. Extract the `unit_standards` array from the response
2. Loop through each unit standard
3. Display each one in its own card with marks and moderation data

## Changes Made

### File: `lib/ModeratorPage.dart`

**Before (Lines 1004-1079):**
```dart
String moderatorStatus = data?['moderator_status'] ?? '';
String moderatorComment = data?['moderator_comment'] ?? '';
String assessorComment = data?['assessor_comment'] ?? '';
String marksScored = data?['marks_scored']?.toString() ?? '';

return Column(
  children: [
    ListTile(
      subtitle: marksScored.isNotEmpty 
          ? Text('Marks: $marksScored')
          : const Text('Tap to view'),
    ),
    // Single moderator status display
    if (moderatorStatus.isNotEmpty) ...[
      // Display single status
    ],
  ],
);
```

**After:**
```dart
// Get unit standards array (new format)
List<dynamic> unitStandards = data?['unit_standards'] ?? [];

return Column(
  children: [
    ListTile(
      subtitle: unitStandards.isNotEmpty 
          ? Text('${unitStandards.length} Unit Standard(s) marked')
          : const Text('Tap to view'),
    ),
    
    // Display each unit standard separately
    if (unitStandards.isNotEmpty)
      ...unitStandards.map((us) {
        String unitId = us['unit_standard_id'] ?? '';
        int marks = us['marks'] ?? 0;
        String moderatorStatus = us['moderator_status'] ?? '';
        String moderatorComment = us['moderator_comment'] ?? '';
        String assessorComment = us['assessor_comment'] ?? '';
        
        return Card(
          child: Column(
            children: [
              // Unit Standard Header
              Text('Unit Standard: $unitId'),
              
              // Marks
              Text('Marks: $marks / 100'),
              
              // Assessor Comment (if available)
              if (assessorComment.isNotEmpty) ...[
                Container(/* Assessor comment display */),
              ],
              
              // Moderator Status (if available)
              if (moderatorStatus.isNotEmpty) ...[
                Container(/* Moderator status display */),
              ],
            ],
          ),
        );
      }).toList(),
  ],
);
```

## Visual Result

### Before Fix:
```
Pothole Checklist
├─ Scanned Document
│  └─ Marks: 43  (only showing first unit standard)
└─ Moderation Status: UPHELD
```

### After Fix:
```
Pothole Checklist
├─ Scanned Document
│  └─ 2 Unit Standard(s) marked
│
├─ Unit Standard: 13958
│  ├─ Marks: 43 / 100
│  ├─ Assessor Comment: "Check all"
│  └─ Status: UPHELD
│
└─ Unit Standard: 14555
   ├─ Marks: 49 / 100
   ├─ Assessor Comment: "Well done"
   └─ Status: UPHELD
```

## Key Features

✅ **Displays Both Unit Standards**: Each unit standard (13958 and 14555) is shown separately
✅ **Individual Marks**: Each unit standard shows its own marks out of 100
✅ **Separate Comments**: Assessor and moderator comments are shown per unit standard
✅ **Individual Status**: Each unit standard can have its own moderation status (upheld/withdrawn)
✅ **Clear Visual Separation**: Each unit standard is in its own card for easy reading
✅ **Backward Compatible**: If only one unit standard exists, it still displays correctly

## Testing

### Test Case 1: Both Unit Standards Marked
**Database:**
```sql
SELECT * FROM logbook_marks 
WHERE learner_id = '1233' 
  AND unit_standard_id IN ('13958', '14555');
```

**Expected Result:**
- 2 rows returned
- Frontend displays 2 separate cards
- Each card shows correct marks and comments

### Test Case 2: Only One Unit Standard Marked
**Database:**
```sql
-- Only one row exists
```

**Expected Result:**
- 1 row returned
- Frontend displays 1 card
- No error or crash

### Test Case 3: No Marks Yet
**Database:**
```sql
-- No rows exist
```

**Expected Result:**
- Empty array returned
- Frontend shows "Tap to view" message
- No marks displayed

## Deployment Checklist

1. ✅ Backend updated (`php/view_pothole_checklists.php`) - COMPLETE
2. ✅ Frontend updated (`lib/ModeratorPage.dart`) - COMPLETE
3. ⏳ Test with real data (learner with both unit standards marked)
4. ⏳ Verify moderator can see both sets of marks
5. ⏳ Test moderation actions work for each unit standard
6. ⏳ Build and deploy APK

## Related Files
- `php/view_pothole_checklists.php` - Backend API (returns unit_standards array)
- `lib/ModeratorPage.dart` - Frontend display (updated to handle array)
- `POTHOLE_BOTH_UNIT_STANDARDS_FIX.md` - Backend fix documentation
- `DIAGNOSE_BOTH_MARKS_NOT_SHOWING.md` - Diagnostic guide

## Notes

- The fix only affects the **Pothole Checklist** section in the Moderator page
- The **LogBook** section is separate and already handles multiple unit standards correctly
- The moderation actions (`_buildModerationActions`) now receive the full array of unit standards
- Each unit standard can be moderated independently

