# Deploy Pothole Checklist Marking Feature

## Quick Deployment Guide

### Step 1: Create Database Table
Run this SQL in phpMyAdmin or MySQL:

```bash
mysql -u your_username -p your_database < create_pothole_checklist_marks_table.sql
```

Or copy/paste the SQL from `create_pothole_checklist_marks_table.sql`

### Step 2: Upload PHP Files
Upload these files to your server's `php/` directory:
- `php/save_pothole_checklist_marks.php`
- `php/get_pothole_checklist_marks.php`

### Step 3: Rebuild Flutter App
```bash
flutter clean
flutter pub get
flutter build apk --release
```

## What's New

### In the Marking Section
When assessors open a learner's marking page, they now see:

1. **Formative** (existing)
2. **Summative** (existing)
3. **LogBook** (existing)
4. **Pothole Checklist** ⭐ NEW!

### Pothole Checklist Features
- Automatically detects if checklist exists
- Shows scanned PDFs or system forms
- Allows viewing before marking
- Provides marks input (0-100)
- Allows assessor comments
- Saves marks to database

## Testing

### Test the Endpoints

**Save Marks:**
```bash
curl -X POST http://your-server.com/php/save_pothole_checklist_marks.php \
  -H "Content-Type: application/json" \
  -d '{
    "learner_id": "L123",
    "assessor_id": "A456",
    "assessment_date": "2025-11-05",
    "marks": 85,
    "comments": "Excellent work"
  }'
```

**Get Marks:**
```bash
curl "http://your-server.com/php/get_pothole_checklist_marks.php?learner_id=L123&assessor_id=A456&assessment_date=2025-11-05"
```

### Test in App

1. Open AssessorPage
2. Select a learner who has a pothole checklist
3. Navigate to marking section
4. Expand "Pothole Checklist"
5. Should see checklist type and view button
6. Tap to view checklist
7. Enter marks and comments
8. Submit

## Troubleshooting

### "No pothole checklist found"
- Verify learner has actually filled a checklist
- Check the date (uses today's date by default)
- Verify `view_pothole_checklists.php` is working

### Marks not saving
- Check PHP error logs
- Verify database table exists
- Test endpoint with curl
- Check network connectivity

### Can't view checklist
- For scanned: Verify PDF file exists on device
- For system: Check `view_pothole_checklists.php` endpoint
- Check console for errors

## Files Modified

- `lib/AssessorPage.dart` - Added pothole checklist section

## Files Created

- `php/save_pothole_checklist_marks.php` - Save marks endpoint
- `php/get_pothole_checklist_marks.php` - Get marks endpoint
- `create_pothole_checklist_marks_table.sql` - Database table
- `POTHOLE_CHECKLIST_MARKING_FEATURE.md` - Feature documentation
- `DEPLOY_POTHOLE_MARKING.md` - This deployment guide

## Complete!

The pothole checklist marking feature is now integrated into the assessment workflow!
