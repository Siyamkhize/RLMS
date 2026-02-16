# Quick Deployment Guide - Moderator Pothole Checklist

## Pre-Deployment Checklist

- [ ] Backup database before making changes
- [ ] Backup existing PHP files
- [ ] Backup existing Flutter app

## Step 1: Database Migration

Run this SQL script on your database:

```bash
mysql -u your_username -p your_database < add_moderation_columns_to_pothole_marks.sql
```

Or manually execute:
```sql
ALTER TABLE pothole_checklist_marks 
ADD COLUMN approval_status ENUM('Approved', 'Disapproved') NULL DEFAULT NULL
AFTER comments;

ALTER TABLE pothole_checklist_marks 
ADD COLUMN comment VARCHAR(256) NULL DEFAULT NULL
AFTER approval_status;
```

Verify columns were added:
```sql
DESCRIBE pothole_checklist_marks;
```

## Step 2: Deploy PHP Files

### New File (Create)
```bash
# Upload to server
php/save_pothole_moderation.php → /your/server/path/mobile/save_pothole_moderation.php
```

### Updated File (Replace)
```bash
# Upload to server (overwrites existing)
php/get_pothole_checklist_marks.php → /your/server/path/mobile/get_pothole_checklist_marks.php
```

### Verify PHP Files
Test the endpoints:
```bash
# Test get marks (should return approval_status and comment fields)
curl "https://your-domain.com/mobile/get_pothole_checklist_marks.php?learner_id=TEST&assessor_id=TEST&assessment_date=2026-01-19"

# Test save moderation (should accept POST request)
curl -X POST https://your-domain.com/mobile/save_pothole_moderation.php \
  -H "Content-Type: application/json" \
  -d '{"learner_id":"TEST","assessment_date":"2026-01-19","approval_status":"Approved","comment":"Test"}'
```

## Step 3: Build Flutter App

```bash
# Clean build
flutter clean
flutter pub get

# Build APK
flutter build apk --release

# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

## Step 4: Deploy Flutter App

1. Copy APK to distribution location
2. Install on test device first
3. Test all functionality
4. Deploy to production devices

## Step 5: Testing

### Test as Moderator:

1. **Login**
   - [ ] Login with moderator credentials

2. **Navigate to Pothole Checklist**
   - [ ] Open drawer menu
   - [ ] Click "Pothole Checklist"
   - [ ] Verify class list loads

3. **Select Class**
   - [ ] Click "Select" on a class
   - [ ] Verify learner list loads

4. **Check Button States**
   - [ ] "No Marks" (Grey) - for learners without marks
   - [ ] "Moderate" (Orange) - for learners with marks, not moderated
   - [ ] "View (Approved)" (Green) - for approved marks
   - [ ] "View (Disapproved)" (Red) - for disapproved marks

5. **Test Approval**
   - [ ] Click "Moderate" button
   - [ ] Verify marks display (read-only)
   - [ ] Select "Approved"
   - [ ] Add optional comment
   - [ ] Click "Save Moderation"
   - [ ] Verify success message
   - [ ] Return to list
   - [ ] Verify button now shows "View (Approved)"

6. **Test Disapproval**
   - [ ] Click "Moderate" on another learner
   - [ ] Select "Disapproved"
   - [ ] Try to save without comment (should fail)
   - [ ] Add required comment
   - [ ] Click "Save Moderation"
   - [ ] Verify success message
   - [ ] Return to list
   - [ ] Verify button now shows "View (Disapproved)"

7. **Test View Existing Moderation**
   - [ ] Click on already moderated learner
   - [ ] Verify status and comment display
   - [ ] Verify form is read-only (no edit option)

## Rollback Plan

If issues occur:

### Rollback Database
```sql
-- Remove added columns
ALTER TABLE pothole_checklist_marks DROP COLUMN approval_status;
ALTER TABLE pothole_checklist_marks DROP COLUMN comment;
```

### Rollback PHP Files
```bash
# Restore from backup
cp backup/get_pothole_checklist_marks.php /your/server/path/mobile/
rm /your/server/path/mobile/save_pothole_moderation.php
```

### Rollback Flutter App
```bash
# Reinstall previous APK version
adb install -r previous-version.apk
```

## Troubleshooting

### Issue: "No marks record found"
**Solution:** Assessor needs to mark the learner first

### Issue: PHP file not found (404)
**Solution:** Verify file uploaded to correct path with correct permissions
```bash
chmod 644 /path/to/save_pothole_moderation.php
```

### Issue: Database error
**Solution:** Verify columns exist
```sql
DESCRIBE pothole_checklist_marks;
```

### Issue: App crashes on moderation page
**Solution:** Check Flutter console logs, verify API responses

## Post-Deployment

- [ ] Monitor error logs for first 24 hours
- [ ] Collect user feedback
- [ ] Document any issues encountered
- [ ] Update documentation if needed

## Files Summary

### Created:
- `lib/ModeratorPage.dart` (updated with new pages)
- `php/save_pothole_moderation.php` (new)
- `add_moderation_columns_to_pothole_marks.sql` (new)
- `MODERATOR_POTHOLE_CHECKLIST_IMPLEMENTATION.md` (documentation)
- `DEPLOY_MODERATOR_POTHOLE_CHECKLIST.md` (this file)

### Modified:
- `php/get_pothole_checklist_marks.php` (returns approval_status and comment)

## Success Criteria

Deployment is successful when:
- ✅ Database columns exist
- ✅ PHP endpoints respond correctly
- ✅ App builds without errors
- ✅ Moderators can view marks
- ✅ Moderators can approve/disapprove
- ✅ Status persists correctly
- ✅ No data loss or corruption

## Contact

For support during deployment, refer to:
- `MODERATOR_POTHOLE_CHECKLIST_IMPLEMENTATION.md` for detailed documentation
- Database admin for SQL issues
- Server admin for PHP deployment issues
- Development team for Flutter app issues
