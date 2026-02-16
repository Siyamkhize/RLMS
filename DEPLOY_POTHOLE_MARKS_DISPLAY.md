# Deploy Pothole Marks Display - Quick Guide

## Status: ✅ READY TO TEST

The pothole checklist marks display feature is **already implemented** in `php/view_pothole_checklists.php`. Both scanned documents and system-generated checklists now fetch and return marks data.

## What's Already Done

✅ Marks fetching added to scanned documents section (line 76-99)
✅ Marks fetching added to system-generated checklists section (line 192-215)
✅ Error handling in place (won't break if marks don't exist)
✅ Correct column name used (`assessor_comment` not `a_comment`)
✅ Proper query using `LIKE '%pothole%'` to match unit standards

## Quick Test

### Step 1: Run Test Script
```bash
# Open in browser:
http://your-server/test_view_pothole_with_marks.php
```

This will:
- Check if pothole marks exist in database
- Test the API endpoint
- Show sample data
- Verify marks are being returned

### Step 2: Test API Directly
```bash
# Replace L001 with actual learner ID
curl "http://your-server/php/view_pothole_checklists.php?learner_id=L001"
```

Expected response should include:
```json
{
  "status": "success",
  "data": {
    ...
    "marks_scored": 85,
    "moderator_status": "upheld",
    "moderator_comment": "Good work",
    "moderator_id": "M001",
    "moderation_date": "2024-01-16 14:20:00"
  }
}
```

### Step 3: Test in Flutter App
1. Open Moderator Page
2. Select a class
3. Select a learner with pothole checklist
4. Navigate to LogBook section
5. Verify marks are displayed for pothole checklist

## If Marks Don't Show

### Check 1: Database Has Marks
```sql
SELECT learner_id, unit_standard_id, marks, assessor_comment, moderator_status 
FROM logbook_marks 
WHERE unit_standard_id LIKE '%pothole%' 
LIMIT 10;
```

If no results:
- Marks haven't been entered yet
- Unit standard ID doesn't contain "pothole"
- Check unit standards 13958 and 14555

### Check 2: API Returns Marks
```bash
# Use a learner ID from the database query above
curl "http://your-server/php/view_pothole_checklists.php?learner_id=LEARNER_ID_HERE"
```

If `marks_scored` is missing:
- Check PHP error logs
- Verify database connection
- Check if learner has checklist (scanned or system)

### Check 3: Flutter Displays Marks
- Check Flutter console for errors
- Verify `get_poe.php` includes logbook_marks data
- Check ModeratorPage.dart is parsing marks correctly

## Database Structure Reference

### logbook_marks Table
```sql
CREATE TABLE logbook_marks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  learner_id VARCHAR(50) NOT NULL,
  unit_standard_id VARCHAR(50) NOT NULL,
  assessor_id VARCHAR(50) NOT NULL,
  marks INT NOT NULL,
  assessment_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  moderator_status VARCHAR(50) NULL,
  moderator_comment TEXT NULL,
  moderator_id VARCHAR(50) NULL,
  moderation_date TIMESTAMP NULL,
  assessor_comment TEXT NULL
);
```

### Key Points
- Pothole marks have `unit_standard_id` containing "pothole" (e.g., "13958", "14555")
- Column name is `assessor_comment` (NOT `a_comment`)
- Marks are stored as INT (0-100)

## Files Involved

### Backend (PHP)
- `php/view_pothole_checklists.php` - Returns checklist with marks ✅ UPDATED
- `save_moderation.php` - Saves moderator status/comments
- `get_poe.php` - Returns all POE data including logbook_marks

### Frontend (Flutter)
- `lib/ModeratorPage.dart` - Displays marks in LogBook section
- Lines 750-820 handle pothole checklist display

### Database
- `logbook_marks` - Stores pothole checklist marks
- `pothole_checklist_scanned_documents` - Stores scanned PDFs
- `pothole_checklists` - Stores system-generated checklists

## Success Indicators

✅ Test script shows marks in database
✅ API returns `marks_scored` field
✅ Flutter app displays marks in LogBook section
✅ Moderator can see and update status/comments
✅ Checklists display even when marks don't exist

## Common Issues

### Issue: "Marks not showing but checklist shows"
**Solution**: Marks might not exist in database yet. Check:
```sql
SELECT * FROM logbook_marks WHERE learner_id = 'YOUR_ID' AND unit_standard_id LIKE '%pothole%';
```

### Issue: "Checklists not showing at all"
**Solution**: Check if learner has any checklist:
```sql
-- Check scanned
SELECT * FROM pothole_checklist_scanned_documents WHERE learner_id = 'YOUR_ID';

-- Check system-generated
SELECT * FROM pothole_checklists WHERE learner_id = 'YOUR_ID';
```

### Issue: "API returns error"
**Solution**: Check PHP error logs:
```bash
tail -f /var/log/apache2/error.log
# or
tail -f /var/log/php_errors.log
```

## Deployment Steps

1. ✅ Code is already deployed in `php/view_pothole_checklists.php`
2. ⏳ Run test script to verify
3. ⏳ Test with real learner data
4. ⏳ Verify in Flutter app
5. ⏳ Mark as complete

## Contact Points

If issues persist:
1. Check `POTHOLE_MARKS_DISPLAY_COMPLETE.md` for detailed documentation
2. Run `test_view_pothole_with_marks.php` for diagnostics
3. Check database structure matches expected schema
4. Verify unit_standard_id contains "pothole" for pothole checklists

---

**Last Updated**: 2024-01-20
**Status**: Implementation Complete, Ready for Testing
