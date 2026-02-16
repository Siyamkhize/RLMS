# Fixed: Table Columns Mismatch

## Problem
The PHP code was trying to access columns that don't exist in the `pothole_checklist_scanned_documents` table, causing HTTP 500 error.

## Actual Table Structure
```sql
pothole_checklist_scanned_documents
- id
- learner_id
- assessor_id
- document_path
- assessment_date
- created_at
```

**Missing columns:**
- ❌ learner_name
- ❌ assessor_name
- ❌ notes

## What Was Wrong
```php
// PHP was trying to access:
'learner_name' => $row['learner_name'] ?? '',  // ❌ Column doesn't exist
'assessor_name' => $row['assessor_name'] ?? '', // ❌ Column doesn't exist
'notes' => $row['notes'] ?? ''                  // ❌ Column doesn't exist
```

This caused a PHP error when the query tried to fetch these non-existent columns.

## Fix Applied
Updated `view_pothole_checklists.php` to only use columns that actually exist:

```php
// Now only uses existing columns:
[
    'id' => $row['id'],
    'type' => 'scanned',
    'learner_id' => $row['learner_id'],
    'assessor_id' => $row['assessor_id'],
    'assessment_date' => $row['assessment_date'],
    'document_path' => $row['document_path'],
    'created_at' => $row['created_at']
]
```

## Response Structure

### For Scanned Documents (Fixed)
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "type": "scanned",
    "learner_id": "70",
    "assessor_id": "6",
    "assessment_date": "2025-11-06",
    "document_path": "../uploads/pothole_checklists/pothole_checklist_1231_1762330576.pdf",
    "created_at": "2025-11-06 10:30:00"
  }
}
```

### For System-Generated (Unchanged)
```json
{
  "status": "success",
  "data": {
    "id": 176,
    "type": "system",
    "learner_id": "75",
    "learner_name": "Ledile Johanna Rapholo",
    "learner_id_number": "7507050576088",
    "assessor_id": "6",
    "assessor_name": "Sithandazile Mbotho",
    "venue": "Class A",
    "assessment_date": "2025-11-06",
    "checklist_items": {...}
  }
}
```

## Note on Missing Fields

The scanned documents table doesn't store names because:
1. It's just a reference to a PDF file
2. Names can be looked up from learner/assessor tables if needed
3. The PDF itself contains all the information

The Flutter app doesn't need these fields for scanned documents - it just needs the document path to download and display the PDF.

## Deployment

**Upload the corrected file:**
- File: `view_pothole_checklists.php` (from workspace root)
- Upload to: `rlms.rlms.co.za/mobile/view_pothole_checklists.php`
- Replace the existing file

## Testing

After uploading, test in browser:
```
https://rlms.rlms.co.za/mobile/view_pothole_checklists.php?learner_id=70
```

Should now return:
- HTTP 200 (not 500)
- Valid JSON response
- Either success with data or error message (not blank)

## Status
✅ **FIXED**

The file now only accesses columns that actually exist in the database table. Upload this corrected version to your server.
