# View Pothole Checklist - Dual Source Support

## Overview
Updated `view_pothole_checklists.php` to support viewing both scanned documents and system-generated checklists with priority-based detection.

## Changes Made

### Priority Logic
1. **First Priority**: Checks `pothole_checklist_scanned_documents` table
2. **Second Priority**: Checks `pothole_checklists` + `pothole_checklist_items` tables
3. Returns the first match found

### Response Structure

#### For Scanned Documents (type='scanned')
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "type": "scanned",
    "learner_id": "TEST123",
    "learner_name": "John Doe",
    "assessor_id": "ASS001",
    "assessor_name": "Jane Smith",
    "assessment_date": "2025-11-05",
    "document_path": "uploads/pothole_checklists/document.pdf",
    "uploaded_at": "2025-11-05 10:30:00",
    "notes": "Scanned checklist"
  }
}
```

#### For System-Generated (type='system')
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "type": "system",
    "learner_id": "TEST123",
    "learner_name": "John Doe",
    "learner_id_number": "9001010000000",
    "assessor_id": "ASS001",
    "assessor_name": "Jane Smith",
    "assessor_reg_number": "REG123",
    "venue": "Workshop A",
    "assessment_date": "2025-11-05",
    "learner_signature": "base64...",
    "assessor_signature": "base64...",
    "notes": "System checklist",
    "checklist_items": {
      "Section 1": [
        {
          "label": "Item 1",
          "value": true,
          "notes": "Notes here"
        }
      ]
    },
    "created_at": "2025-11-05 10:00:00",
    "updated_at": "2025-11-05 10:00:00"
  }
}
```

## API Usage

### Endpoint
```
GET php/view_pothole_checklists.php
```

### Parameters
- `learner_id` (required) - The learner's ID
- `assessor_id` (optional) - Filter by assessor
- `assessment_date` (optional) - Filter by specific date

### Examples
```
# Get any checklist for learner
php/view_pothole_checklists.php?learner_id=TEST123

# Get checklist by specific assessor
php/view_pothole_checklists.php?learner_id=TEST123&assessor_id=ASS001

# Get checklist for specific date
php/view_pothole_checklists.php?learner_id=TEST123&assessment_date=2025-11-05
```

## Flutter Integration

The Flutter app can now handle both types by checking the `type` field:

```dart
if (checklistData['type'] == 'scanned') {
  // Navigate to PotholeChecklistScannedViewPage
  // Show PDF viewer with marking interface
} else if (checklistData['type'] == 'system') {
  // Navigate to PotholeChecklistViewPage
  // Show form with all answers
}
```

## Testing

Run the test script:
```bash
php test_view_both_checklists.php
```

## Database Tables Used

1. **pothole_checklist_scanned_documents**
   - Stores scanned PDF documents
   - Fields: id, learner_id, assessor_id, document_path, assessment_date, etc.

2. **pothole_checklists**
   - Stores system-generated checklist metadata
   - Fields: id, learner_id, assessor_id, assessment_date, etc.

3. **pothole_checklist_items**
   - Stores individual checklist items
   - Fields: id, checklist_id, section, label, value, notes

## Benefits

✅ Single endpoint for both checklist types
✅ Priority-based detection (scanned first)
✅ Type indicator for proper Flutter routing
✅ Backward compatible with existing code
✅ Consistent error handling
✅ Flexible filtering options

## Next Steps

The Flutter app (AssessorPage.dart) already uses this endpoint and routes to the appropriate viewer based on the `type` field. No Flutter changes needed!
