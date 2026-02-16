# Quick Deploy: Pothole Checklist View Feature

## What This Does
Adds the ability to view previously filled pothole checklist forms in the app.

## Files to Upload

### 1. Upload to Server
Upload this file to your PHP directory:
- **php/view_pothole_checklists.php** - Retrieves saved checklists

(Note: save_pothole_checklist.php is also included if you don't have it yet)

### 2. Flutter App
The Flutter code in `lib/potholeChecklistpage.dart` has been updated to:
- Automatically load existing checklists when the page opens
- Display in read-only view mode
- Allow editing with "Edit Checklist" button

## Testing the GET Endpoint

### Quick Test with Browser
Open this URL in your browser (replace with your values):
```
http://your-server.com/php/view_pothole_checklists.php?learner_id=L123&assessor_id=A456&assessment_date=2025-11-05
```

### Expected Response (Success):
```json
{
  "status": "success",
  "data": {
    "learner_name": "John Doe",
    "assessor_name": "Jane Smith",
    "venue": "Training Center",
    "checklist_items": {
      "PRE – OPERATIONAL SAFETY": [
        {
          "label": "Wears appropriate PPE",
          "value": true,
          "notes": "All good"
        }
      ]
    }
  }
}
```

### Expected Response (Not Found):
```json
{
  "status": "error",
  "message": "No checklist found for the specified parameters"
}
```

## How It Works

1. **User opens checklist page** → App calls `view_pothole_checklists.php`
2. **If checklist exists** → Loads data in view mode (read-only)
3. **User clicks "Edit Checklist"** → Enables editing
4. **User clicks "Save Checklist"** → Calls `save_pothole_checklist.php`

## Database Requirements

The endpoint expects this table structure:
```sql
pothole_checklists (
    id,
    learner_id,
    learner_name,
    learner_id_number,
    assessor_id,
    assessor_name,
    assessor_reg_number,
    venue,
    assessment_date,
    learner_signature,
    assessor_signature,
    checklist_items (JSON),
    created_at,
    updated_at
)
```

If you don't have this table, run: `create_pothole_checklist_table.sql`

## Rebuild Flutter App

```bash
flutter clean
flutter pub get
flutter build apk --release
```

## Troubleshooting

**Problem:** "No checklist found" even though data exists
- Check that learner_id, assessor_id, and assessment_date match exactly
- Verify the date format is YYYY-MM-DD

**Problem:** PHP errors
- Check that config.php exists and has correct database credentials
- Verify pothole_checklists table exists
- Check PHP error logs

**Problem:** View mode not working in app
- Make sure you rebuilt the Flutter app after code changes
- Check Flutter console for errors
