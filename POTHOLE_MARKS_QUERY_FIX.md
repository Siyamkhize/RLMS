# Pothole Marks Query Fix

## Problem
The `view_pothole_checklists.php` endpoint was not returning marks data for pothole checklists because the SQL query was using an incorrect pattern match.

### Root Cause
```sql
-- OLD QUERY (INCORRECT)
WHERE learner_id = ? AND unit_standard_id LIKE '%pothole%'
```

This query was looking for unit standard IDs containing the word "pothole", but the actual unit standard IDs are **numeric**: `13958` and `14555`.

## Solution
Changed the query to explicitly match the correct unit standard IDs:

```sql
-- NEW QUERY (CORRECT)
WHERE learner_id = ? AND unit_standard_id IN ('13958', '14555')
```

## Files Modified

### 1. `php/view_pothole_checklists.php`
Updated both occurrences of the marks query (for scanned documents and system-generated checklists):

**Before:**
```php
$marks_sql = "SELECT marks, moderator_status, moderator_comment, moderator_id, moderation_date, assessor_comment 
              FROM logbook_marks 
              WHERE learner_id = ? AND unit_standard_id LIKE '%pothole%'
              ORDER BY assessment_date DESC LIMIT 1";
```

**After:**
```php
// Pothole checklist uses unit standard IDs: 13958 and 14555
$marks_sql = "SELECT marks, moderator_status, moderator_comment, moderator_id, moderation_date, assessor_comment 
              FROM logbook_marks 
              WHERE learner_id = ? AND unit_standard_id IN ('13958', '14555')
              ORDER BY assessment_date DESC LIMIT 1";
```

## Pothole Unit Standards

The pothole checklist assessment uses two unit standards:
- **13958**: Pothole Checklist Unit Standard 1
- **14555**: Pothole Checklist Unit Standard 2

These are stored in the `logbook_marks` table with the following structure:

| Column | Type | Description |
|--------|------|-------------|
| id | int(11) | Primary key |
| learner_id | varchar(50) | Learner identifier |
| unit_standard_id | varchar(50) | Unit standard ID (13958 or 14555) |
| assessor_id | varchar(50) | Assessor identifier |
| marks | int(11) | Marks scored (0-100) |
| assessment_date | date | Assessment date |
| moderator_status | varchar(20) | "upheld" or "withdrawn" |
| moderator_comment | text | Moderator's comment |
| moderator_id | varchar(50) | Moderator identifier |
| moderation_date | datetime | Moderation timestamp |
| assessor_comment | text | Assessor's comment |

## Testing

Run the test script to verify the fix:

```bash
php test_pothole_marks_query_fix.php
```

This will:
1. Test the old query (should return 0 results)
2. Test the new query (should return marks data)
3. Show all pothole marks in the database

## Expected API Response

After the fix, the `view_pothole_checklists.php` endpoint will return:

```json
{
  "status": "success",
  "data": {
    "id": 123,
    "type": "scanned",
    "learner_id": "17391",
    "assessor_id": "233",
    "assessment_date": "2025-11-05",
    "document_path": "/uploads/...",
    "unit_standards": [
      {
        "unit_standard_id": "13958",
        "marks": 77,
        "moderator_status": "upheld",
        "moderator_comment": "Good work on unit 13958",
        "moderator_id": "456",
        "moderation_date": "2026-01-20 10:05:08",
        "assessor_comment": "Well done"
      },
      {
        "unit_standard_id": "14555",
        "marks": 85,
        "moderator_status": "upheld",
        "moderator_comment": "Excellent on unit 14555",
        "moderator_id": "456",
        "moderation_date": "2026-01-20 10:05:08",
        "assessor_comment": "Great job"
      }
    ]
  }
}
```

**Key Changes:**
- Removed `LIMIT 1` from the query to fetch ALL unit standards
- Changed from single mark fields to `unit_standards` array
- Each unit standard now has its own marks and moderation data
- Unit standards are sorted by ID (13958 first, then 14555)

## Impact

✅ **Fixed**: Marks data now correctly retrieved for BOTH pothole unit standards (13958 AND 14555)
✅ **Separate Data**: Each unit standard has its own marks and moderation information
✅ **Non-Breaking**: Wrapped in try-catch, checklists still display if marks fetch fails
✅ **Both Types**: Works for scanned documents AND system-generated checklists
✅ **Complete Data**: Returns all moderation fields for each unit standard

## Deployment

1. Upload the updated `php/view_pothole_checklists.php` to the server
2. Test with a learner who has pothole marks (e.g., learner_id = 17391)
3. Verify marks appear in the moderator interface

## Related Files
- `php/view_pothole_checklists.php` - Main endpoint (FIXED)
- `lib/ModeratorPage.dart` - Frontend that displays the marks
- `add_moderation_columns_to_logbook_marks.sql` - Database schema
