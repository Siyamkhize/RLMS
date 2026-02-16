# Pothole Checklist View Fix - Database Column Issue

## Problem
After uploading `view_pothole_checklists.php`, both checklists stopped showing with error:
```
"Unknown column 'unit_standard_name' in 'SELECT'"
```

## Root Cause
The SQL query was trying to SELECT a column `unit_standard_name` from the `logbook_marks` table, but this column doesn't exist in the database.

## Solution
Removed `unit_standard_name` from the SELECT query and instead generate it dynamically:
```php
// OLD (broken):
$marks_sql = "SELECT id, unit_standard_id, unit_standard_name, marks, ...

// NEW (fixed):
$marks_sql = "SELECT id, unit_standard_id, marks, ...

// Then generate the name:
'unit_standard_name' => 'Unit Standard ' . $mark_row['unit_standard_id'],
```

## Files Fixed
- ✅ `view_pothole_checklists.php` - Removed non-existent column from SQL query

## What Was Changed

### Before:
```php
$marks_sql = "SELECT id, unit_standard_id, unit_standard_name, marks, 
                     moderator_status, moderator_comment, moderator_id, 
                     moderation_date, assessor_comment 
              FROM logbook_marks 
              WHERE learner_id = ? 
              AND (unit_standard_id = '13958' OR unit_standard_id = '14555')
              ORDER BY unit_standard_id";
```

### After:
```php
$marks_sql = "SELECT id, unit_standard_id, marks, 
                     moderator_status, moderator_comment, moderator_id, 
                     moderation_date, assessor_comment 
              FROM logbook_marks 
              WHERE learner_id = ? 
              AND (unit_standard_id = '13958' OR unit_standard_id = '14555')
              ORDER BY unit_standard_id";

// Generate name dynamically:
'unit_standard_name' => 'Unit Standard ' . $mark_row['unit_standard_id'],
```

## Testing

### 1. Test the endpoint directly:
```
https://rlms.rlms.co.za/mobile/view_pothole_checklists.php?learner_id=1233
```

Should return JSON with:
- `status: "success"`
- `data` object with checklist information
- `unit_standards` array with marks for unit standards 13958 and 14555

### 2. Test in app:
1. Open app as moderator
2. Navigate to learner 1233's pothole checklist
3. Checklist should now display
4. Unit standards should show with marks

## Database Schema

The `logbook_marks` table has these columns:
```sql
- id (PRIMARY KEY, AUTO_INCREMENT)
- learner_id
- unit_standard_id
- marks
- moderator_status
- moderator_comment
- moderator_id
- moderation_date
- assessor_comment
```

Note: There is NO `unit_standard_name` column, so we generate it dynamically.

## Summary

✅ **Fixed**: Removed non-existent `unit_standard_name` column from SQL query
✅ **Fixed**: Changed from `config.php` to `connection.php`
✅ **Result**: Checklists should now display correctly

Upload the fixed `view_pothole_checklists.php` file and test!
