# Pothole Marks - Both Unit Standards Fix

## Issue
The API was only returning marks for ONE unit standard instead of BOTH (13958 and 14555).

## Root Cause
The query had `LIMIT 1` which stopped after finding the first unit standard:
```sql
-- WRONG: Only returns one unit standard
SELECT ... FROM logbook_marks 
WHERE learner_id = ? AND unit_standard_id IN ('13958', '14555')
ORDER BY assessment_date DESC LIMIT 1
```

## Solution
Removed `LIMIT 1` and return all matching unit standards as an array:

```sql
-- CORRECT: Returns both unit standards
SELECT unit_standard_id, marks, moderator_status, moderator_comment, moderator_id, moderation_date, assessor_comment 
FROM logbook_marks 
WHERE learner_id = ? AND unit_standard_id IN ('13958', '14555')
ORDER BY unit_standard_id ASC
```

## API Response Change

### Before (WRONG)
```json
{
  "data": {
    "marks_scored": 77,
    "moderator_status": "upheld",
    "moderator_comment": "Good work"
  }
}
```
❌ Only shows marks for ONE unit standard

### After (CORRECT)
```json
{
  "data": {
    "unit_standards": [
      {
        "unit_standard_id": "13958",
        "marks": 77,
        "moderator_status": "upheld",
        "moderator_comment": "Good work on 13958",
        "assessor_comment": "Well done"
      },
      {
        "unit_standard_id": "14555",
        "marks": 85,
        "moderator_status": "upheld",
        "moderator_comment": "Excellent on 14555",
        "assessor_comment": "Great job"
      }
    ]
  }
}
```
✅ Shows marks for BOTH unit standards with clear identification

## Files Modified
- `php/view_pothole_checklists.php` - Updated marks query (both scanned and system sections)
- `test_pothole_marks_query_fix.php` - Test script to verify both unit standards are returned
- `POTHOLE_MARKS_QUERY_FIX.md` - Updated documentation

## Testing
```bash
php test_pothole_marks_query_fix.php
```

Expected output:
```
✅ Unit Standard 1:
   - Unit Standard ID: 13958
   - Marks: 77
   
✅ Unit Standard 2:
   - Unit Standard ID: 14555
   - Marks: 85
```

## Frontend Impact
The frontend (ModeratorPage.dart) will now receive:
- `unit_standards` array instead of flat fields
- Each unit standard clearly identified by `unit_standard_id`
- Separate marks and moderation data for each unit standard

## Deployment
1. Upload `php/view_pothole_checklists.php` to server
2. Update frontend to handle `unit_standards` array
3. Test with learners who have both unit standards marked

## Summary
✅ Both unit standards (13958 and 14555) now returned
✅ Each unit standard has its own marks and moderation data
✅ Clear identification of which marks belong to which unit standard
✅ Non-breaking - still works if marks don't exist
