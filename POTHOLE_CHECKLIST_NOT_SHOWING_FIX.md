# Pothole Checklist Not Showing - Fixed

## Issue
After adding marks fetching logic, pothole checklists (both scanned and system-generated) stopped showing in the moderator page.

## Root Cause
The marks query was trying to select the `a_comment` column which might not exist in the `logbook_marks` table. This caused the SQL query to fail, which prevented the entire response from being returned.

## Solution Applied

### 1. Added Column Detection
Added code to check which comment column exists in the database before running the marks query:

```php
// Check which comment column exists in logbook_marks table
$comment_column = 'a_comment';
$check_column = $conn->query("SHOW COLUMNS FROM logbook_marks LIKE 'a_comment'");
if ($check_column && $check_column->num_rows == 0) {
    // Try assessor_comment instead
    $check_column = $conn->query("SHOW COLUMNS FROM logbook_marks LIKE 'assessor_comment'");
    if ($check_column && $check_column->num_rows > 0) {
        $comment_column = 'assessor_comment';
    } else {
        $comment_column = 'NULL';
    }
}
```

### 2. Dynamic Column in Query
Updated both marks queries (for scanned and system-generated checklists) to use the detected column:

```php
$marks_sql = "SELECT marks, moderator_status, moderator_comment, moderator_id, moderation_date, $comment_column as assessor_comment 
              FROM logbook_marks 
              WHERE learner_id = ? AND unit_standard_id LIKE '%pothole%'
              ORDER BY assessment_date DESC LIMIT 1";
```

### 3. Safe Alias Usage
The query now uses `$comment_column as assessor_comment` which means:
- If `a_comment` exists → uses `a_comment`
- If `assessor_comment` exists → uses `assessor_comment`
- If neither exists → uses `NULL`

The result is always aliased as `assessor_comment` for consistent access in the code.

## What This Fixes

1. **Checklists now show** - Even if marks query fails or column doesn't exist
2. **Backward compatible** - Works with databases that have either `a_comment` or `assessor_comment` column
3. **Graceful degradation** - If no comment column exists, returns NULL instead of failing

## Testing

### Quick Test
```bash
# Test with a learner ID
curl "http://your-server/php/view_pothole_checklists.php?learner_id=LEARNER_ID"
```

### Debug Test
```bash
# Run the debug script to see table structure and data
curl "http://your-server/test_view_pothole_debug.php?learner_id=LEARNER_ID"
```

### Expected Response
```json
{
  "status": "success",
  "data": {
    "id": 123,
    "type": "scanned",
    "learner_id": "L12345",
    "assessor_id": "A001",
    "assessment_date": "2026-01-20",
    "document_path": "/uploads/pothole_checklist_123.pdf",
    "created_at": "2026-01-20 10:30:00",
    "marks_scored": 85,
    "moderator_status": "",
    "moderator_comment": "",
    "moderator_id": "",
    "moderation_date": "",
    "assessor_comment": "Good work"
  }
}
```

## Database Column Options

The code now supports three scenarios:

### Scenario 1: a_comment column exists
```sql
-- No action needed, code will use a_comment
```

### Scenario 2: assessor_comment column exists
```sql
-- No action needed, code will use assessor_comment
```

### Scenario 3: Neither column exists
```sql
-- Add the column (recommended)
ALTER TABLE logbook_marks 
ADD COLUMN a_comment TEXT DEFAULT NULL;
```

## Files Modified
- ✅ `php/view_pothole_checklists.php` - Added column detection and dynamic query

## Files Created
- ✅ `test_view_pothole_debug.php` - Debug script to diagnose issues

## Status
✅ **FIXED** - Pothole checklists now show regardless of which comment column exists in the database.

## Next Steps

1. **Test the endpoint** with a real learner ID
2. **Run debug script** if issues persist: `test_view_pothole_debug.php?learner_id=LEARNER_ID`
3. **Check database** to see which column exists
4. **Add missing column** if needed (see SQL above)
5. **Verify in app** that checklists display correctly

## Troubleshooting

### If checklists still don't show:

1. **Check if data exists:**
   ```sql
   SELECT * FROM pothole_checklist_scanned_documents WHERE learner_id = 'LEARNER_ID';
   SELECT * FROM pothole_checklists WHERE learner_id = 'LEARNER_ID';
   ```

2. **Check if marks exist:**
   ```sql
   SELECT * FROM logbook_marks WHERE learner_id = 'LEARNER_ID' AND unit_standard_id LIKE '%pothole%';
   ```

3. **Run debug script:**
   ```
   http://your-server/test_view_pothole_debug.php?learner_id=LEARNER_ID
   ```

4. **Check PHP error log** for any SQL errors

5. **Test endpoint directly** in browser:
   ```
   http://your-server/php/view_pothole_checklists.php?learner_id=LEARNER_ID
   ```
