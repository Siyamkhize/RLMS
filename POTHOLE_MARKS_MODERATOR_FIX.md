# Pothole Marks Moderator Fix

## Issue
Pothole checklist marks were not returning in the moderator page because they are stored in the `logbook_marks` table, but the system was looking for them in `pothole_checklist_marks` and `pothole_checklist_scanned` tables.

## Root Cause
The pothole marks are stored in the `logbook_marks` table with a `unit_standard_id` that contains "pothole" in the name. The `view_pothole_checklists.php` endpoint was not fetching marks from this table.

## Database Structure
The `logbook_marks` table structure:
```
Field              Type          Null  Key     Default             Extra
id                 int(11)       NO    PRI     NULL                auto_increment
learner_id         varchar(50)   NO    MUL     NULL                
unit_standard_id   varchar(50)   NO    MUL     NULL                
assessor_id        varchar(50)   NO    MUL     NULL                
marks              int(11)       NO            NULL                
assessment_date    date          NO            NULL                
created_at         timestamp     NO            current_timestamp()
updated_at         timestamp     NO            current_timestamp() on update current_timestamp()
```

Additional columns for moderation:
- `moderator_status` - Stores 'upheld' or 'withdrawn'
- `moderator_comment` - Stores moderator's comment
- `moderator_id` - Stores moderator's ID
- `moderation_date` - Timestamp of moderation
- `assessor_comment` - Stores assessor's comment (a_comment)

## Changes Made

### 1. Updated `php/view_pothole_checklists.php`

#### For Scanned Documents
Added query to fetch marks from `logbook_marks` table:
```php
$marks_sql = "SELECT marks, moderator_status, moderator_comment, assessor_comment 
              FROM logbook_marks 
              WHERE learner_id = ? AND unit_standard_id LIKE '%pothole%'
              ORDER BY assessment_date DESC LIMIT 1";
```

Returns additional fields:
- `marks_scored` - The marks value
- `moderator_status` - Moderation status
- `moderator_comment` - Moderator's comment
- `assessor_comment` - Assessor's comment

#### For System-Generated Checklists
Added the same query to fetch marks for system-generated checklists.

### 2. Updated `save_moderation.php`

Changed pothole checklist moderation to update `logbook_marks` table:
```php
case 'pothole_checklist':
    $table = 'logbook_marks';
    $whereClause = "learner_id = ? AND unit_standard_id LIKE '%pothole%'";
    break;
```

The update query:
```php
$sql = "UPDATE logbook_marks 
        SET moderator_status = ?, 
            moderator_comment = ?,
            moderator_id = ?,
            moderation_date = NOW()
        WHERE learner_id = ? AND unit_standard_id LIKE '%pothole%'";
```

## How It Works

### Data Flow
1. **Assessor marks pothole checklist** → Marks saved to `logbook_marks` table with unit_standard_id containing "pothole"
2. **Moderator views learner** → `view_pothole_checklists.php` fetches:
   - Checklist data from `pothole_checklist_scanned_documents` or `pothole_checklists`
   - Marks data from `logbook_marks` WHERE unit_standard_id LIKE '%pothole%'
3. **Moderator submits moderation** → `save_moderation.php` updates `logbook_marks` table

### ModeratorPage.dart
The Flutter app already handles the data correctly:
- Displays marks in `_buildPotholeChecklistContent()`
- Shows moderator status and comment if they exist
- Provides Uphold/Withdraw buttons via `_buildModerationActions()`
- Calls `_submitModeration()` with assessmentType='pothole_checklist'

## Testing

### Test File Created
`test_pothole_marks_moderator.php` - Comprehensive test script

Usage:
```
test_pothole_marks_moderator.php?learner_id=LEARNER_ID
```

Tests performed:
1. Check `logbook_marks` table for pothole entries
2. Test `view_pothole_checklists.php` endpoint
3. Check all pothole-related tables

### Manual Testing Steps

1. **Verify marks are stored correctly**
   ```sql
   SELECT * FROM logbook_marks 
   WHERE learner_id = 'LEARNER_ID' 
   AND unit_standard_id LIKE '%pothole%';
   ```

2. **Test the endpoint**
   ```
   GET /view_pothole_checklists.php?learner_id=LEARNER_ID
   ```
   
   Expected response should include:
   ```json
   {
     "status": "success",
     "data": {
       "marks_scored": 85,
       "moderator_status": "",
       "moderator_comment": "",
       "assessor_comment": "Good work"
     }
   }
   ```

3. **Test moderation submission**
   ```
   POST /save_moderation.php
   {
     "learnerId": "LEARNER_ID",
     "assessmentType": "pothole_checklist",
     "unitStandardName": "Pothole Checklist",
     "moderatorStatus": "upheld",
     "moderatorComment": "Well done",
     "moderatorId": "MOD123"
   }
   ```

4. **Verify in Flutter app**
   - Login as moderator
   - Navigate to learner's pothole checklist
   - Verify marks are displayed
   - Add moderation comment
   - Click Uphold or Withdraw
   - Verify success message
   - Refresh and verify moderation is saved

## Database Requirements

### Required Columns in logbook_marks
Ensure these columns exist:
```sql
ALTER TABLE logbook_marks 
ADD COLUMN IF NOT EXISTS moderator_status VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_comment TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_id VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderation_date TIMESTAMP NULL DEFAULT NULL,
ADD COLUMN IF NOT EXISTS assessor_comment TEXT DEFAULT NULL;
```

## Files Modified
1. `php/view_pothole_checklists.php` - Added marks fetching from logbook_marks
2. `save_moderation.php` - Updated pothole moderation to use logbook_marks
3. `test_pothole_marks_moderator.php` - Created test file

## Files NOT Modified
- `lib/ModeratorPage.dart` - Already handles the data correctly
- `php/save_pothole_checklist_marks.php` - Still used by assessors (if applicable)
- `php/get_pothole_checklist_marks.php` - May need updating if used elsewhere

## Notes

### Unit Standard ID Pattern
The system identifies pothole marks by checking if `unit_standard_id LIKE '%pothole%'`. This means:
- Unit standard ID must contain the word "pothole" (case-insensitive)
- Examples: "Pothole Checklist", "pothole_assessment", "US_Pothole_123"

### Multiple Pothole Entries
If a learner has multiple pothole assessments:
- The query uses `ORDER BY assessment_date DESC LIMIT 1`
- This returns the most recent assessment
- Consider adding date filtering if needed

### Backward Compatibility
The changes maintain backward compatibility:
- Old pothole_checklist_marks table (if exists) is not affected
- System now checks logbook_marks table for marks
- Existing moderation data remains intact

## Deployment Checklist

- [ ] Backup database
- [ ] Verify logbook_marks table has required columns
- [ ] Deploy updated PHP files
- [ ] Test with sample learner ID
- [ ] Verify marks display in moderator view
- [ ] Test moderation submission
- [ ] Verify moderation is saved correctly
- [ ] Test with multiple moderators
- [ ] Check for any console errors in Flutter app

## Success Criteria
✅ Pothole marks display in moderator page
✅ Moderator can add comments
✅ Moderator can uphold/withdraw
✅ Moderation is saved to logbook_marks table
✅ Existing moderator comments are loaded correctly
✅ No errors in backend or frontend
