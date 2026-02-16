# Fixed: Column Name Mismatch

## Error
```
"Unknown column 'uploaded_at' in 'order clause'"
```

## Root Cause
The PHP code was trying to use `uploaded_at` column, but the actual table has `created_at` column.

### Table Structure
```sql
pothole_checklist_scanned_documents
- id
- learner_id
- assessor_id
- document_path
- assessment_date
- created_at  ← This is the actual column name
```

## Fix Applied

### php/view_pothole_checklists.php

**Changed ORDER BY clause:**
```php
// Before:
ORDER BY uploaded_at DESC LIMIT 1

// After:
ORDER BY created_at DESC LIMIT 1
```

**Changed response field:**
```php
// Before:
'uploaded_at' => $row['uploaded_at'] ?? '',

// After:
'created_at' => $row['created_at'] ?? '',
```

## Result
The endpoint will now correctly query and return scanned documents without SQL errors.

## Testing
1. Restart the app (or just retry)
2. Navigate to learner 70's POE tab
3. Should now see the scanned document if it exists
4. No more SQL errors

## Status
✅ **FIXED**

The column name has been corrected. Scanned documents should now be detected and displayed properly.
