# Pothole Checklist Logbook Marks Fix

## Issue
Pothole checklist marks were not appearing in the moderator page because they are stored in the `logbook_marks` table, but the system was only checking separate pothole-specific tables.

## Root Cause
- Pothole checklist marks are stored in `logbook_marks` table with unit_standard_id values of **13958** and **14555**
- The `get_poe.php` endpoint was not fetching logbook marks
- The ModeratorPage was not displaying logbook marks from the `logbook_marks` table

## Solution

### 1. Backend Changes (`get_poe.php`)

Added a new query to fetch logbook marks (including pothole checklist):

```php
// Fetch logbook marks (including pothole checklist marks)
// Pothole checklist uses unit standard IDs: 13958 and 14555
$logbookStmt = $conn->prepare("
    SELECT 
        lm.learner_id,
        lm.unit_standard_id,
        lm.assessor_id,
        lm.marks,
        lm.assessment_date,
        lm.moderator_status,
        lm.moderator_comment,
        lm.moderator_id,
        lm.moderation_date,
        lm.a_comment,
        us.unitstandard_name
    FROM logbook_marks lm
    LEFT JOIN unitstandard us ON lm.unit_standard_id = us.unitstandard_id
    WHERE lm.learner_id = ?
    ORDER BY lm.unit_standard_id
");
```

The response now includes a `logbook_marks` array with all logbook marks including pothole checklist.

### 2. Frontend Changes (`lib/ModeratorPage.dart`)

Modified `_buildLogBookSection` to:
1. Fetch logbook marks from the `logbook_marks` array in the POE response
2. Identify pothole checklist items (unit standards 13958 and 14555)
3. Display them in the LogBook section with proper formatting
4. Include moderator comment functionality for each logbook item

```dart
// Also add logbook marks from the logbook_marks array (includes pothole checklist)
List<dynamic> logbookMarks = poeData['logbook_marks'] ?? [];
for (var mark in logbookMarks) {
  String unitStandardId = mark['unit_standard_id'] ?? '';
  String unitStandardName = mark['unit_standard_name'] ?? 'Unit Standard $unitStandardId';
  
  // Check if this is pothole checklist (unit standards 13958 or 14555)
  bool isPotholeChecklist = unitStandardId == '13958' || unitStandardId == '14555';
  
  allLogbookItems.add({
    'unitStandardName': unitStandardName,
    'unitStandardId': unitStandardId,
    'isPotholeChecklist': isPotholeChecklist,
    'logbookItems': [
      {
        'id': unitStandardId,
        'exercise_name': isPotholeChecklist ? 'Pothole Checklist' : unitStandardName,
        'marks_scored': mark['marks'],
        'total_marks': 100,
        'moderator_status': mark['moderator_status'] ?? '',
        'moderator_comment': mark['moderator_comment'] ?? '',
        'a_comment': mark['a_comment'] ?? '',
        'assessment_date': mark['assessment_date'] ?? '',
      }
    ],
  });
}
```

## Database Structure

### logbook_marks Table
| Field | Type | Description |
|-------|------|-------------|
| id | int(11) | Primary key, auto-increment |
| learner_id | varchar(50) | Learner identifier |
| unit_standard_id | varchar(50) | Unit standard ID (13958 or 14555 for pothole) |
| assessor_id | varchar(50) | Assessor identifier |
| marks | int(11) | Marks scored (0-100) |
| assessment_date | date | Date of assessment |
| moderator_status | varchar(50) | Moderation status (upheld/withdrawn) |
| moderator_comment | text | Moderator's comment |
| moderator_id | varchar(50) | Moderator identifier |
| moderation_date | timestamp | Date of moderation |
| a_comment | text | Assessor's comment |
| created_at | timestamp | Record creation time |
| updated_at | timestamp | Record update time |

## Pothole Checklist Unit Standards
- **13958**: Pothole Checklist Unit Standard 1
- **14555**: Pothole Checklist Unit Standard 2

## Files Modified
1. `get_poe.php` - Added logbook marks query and response
2. `lib/ModeratorPage.dart` - Updated `_buildLogBookSection` to display logbook marks

## Testing Steps

1. **Verify Backend**:
   ```bash
   # Test the endpoint
   curl "http://your-server/get_poe.php?learnerId=TEST_LEARNER_ID"
   ```
   - Verify response includes `logbook_marks` array
   - Check that pothole checklist marks (unit standards 13958, 14555) are included

2. **Verify Frontend**:
   - Login as moderator
   - Navigate to a learner with pothole checklist marks
   - Expand "LogBook" section
   - Verify pothole checklist items appear with:
     - Unit standard name
     - Marks scored
     - Moderator comment input field
     - Uphold/Withdraw buttons

3. **Test Moderation**:
   - Add a moderator comment
   - Click "Uphold" or "Withdraw"
   - Verify success message
   - Refresh and verify comment is saved
   - Verify moderation status is displayed

## Benefits
- ✅ Pothole checklist marks now visible in moderator view
- ✅ Moderators can comment on pothole checklist assessments
- ✅ Moderators can uphold or withdraw pothole checklist marks
- ✅ Consistent with other logbook items
- ✅ No database schema changes required
- ✅ Backward compatible with existing data

## Notes
- The pothole checklist marks are displayed in the LogBook section alongside other logbook items
- Each pothole checklist unit standard (13958, 14555) appears as a separate item
- Moderators can comment once per unit standard
- The existing pothole checklist section (scanned documents) remains unchanged
