# Deployment Checklist: Assessor "No Classes Found" Fix

## Files to Deploy

### 1. PHP Files (Server)
Upload these files to your server at `https://rlms.rlms.co.za/mobile/`:

- ✅ `get_classes.php` → Upload to `/mobile/get_classes.php`
- ✅ `php/get_classes.php` → Backup copy (optional)

### 2. Flutter App (Mobile)
The following file has been updated and needs to be rebuilt:

- ✅ `lib/AssessorPage.dart` (3 functions updated)

## Deployment Steps

### Step 1: Deploy PHP File to Server
```bash
# Option A: Using FTP/SFTP
# Upload get_classes.php to:
# /home/ezxcmacd/public_html/rlms.rlms.co.za/mobile/get_classes.php

# Option B: Using SSH/SCP
scp get_classes.php user@rlms.rlms.co.za:/path/to/mobile/

# Option C: Using cPanel File Manager
# 1. Log into cPanel
# 2. Navigate to File Manager
# 3. Go to public_html/rlms.rlms.co.za/mobile/
# 4. Upload get_classes.php
```

### Step 2: Test the PHP Endpoint
```bash
# Test with a valid facilitator_id
php test_get_classes.php

# Or test directly in browser:
# https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=1
```

Expected response (success):
```json
[
  {
    "classID": "123",
    "className": "Class Name",
    "siteID": "456",
    "siteName": "Site Name",
    "project_id": "789",
    "Project_name": "Project Name",
    "numberOfLearners": 25
  }
]
```

Expected response (error - no facilitator_id):
```json
{
  "status": "error",
  "message": "facilitator_id parameter is required"
}
```

### Step 3: Rebuild Flutter App
```bash
# Clean build
flutter clean
flutter pub get

# Build APK
flutter build apk --release

# Or build for specific platform
flutter build apk --split-per-abi
```

### Step 4: Install and Test
1. Install the new APK on a test device
2. Log in as an Assessor
3. Verify that classes are now displayed
4. Test the "View" button for each class
5. Check the console logs for any errors

## Verification Checklist

### Server-Side Verification
- [ ] PHP file uploaded to correct location
- [ ] File permissions are correct (644 or 755)
- [ ] Database connection works
- [ ] Endpoint returns valid JSON
- [ ] CORS headers are present
- [ ] Error handling works correctly

### App-Side Verification
- [ ] App builds without errors
- [ ] No diagnostic errors in AssessorPage.dart
- [ ] Login as Assessor works
- [ ] Classes are displayed (not "No classes found")
- [ ] Class information is correct (name, learner count, etc.)
- [ ] "View" button navigates to class details
- [ ] All three sections work:
  - [ ] Main Classes tab
  - [ ] Assessor Feedback section
  - [ ] Pothole Checklist section

## Troubleshooting

### Issue: Still showing "No classes found"
**Check:**
1. Is the PHP file in the correct location?
2. Does the facilitator_id exist in the database?
3. Is the facilitator linked to any classes?
4. Check server error logs
5. Check app console logs

**Debug:**
```sql
-- Check if facilitator exists
SELECT * FROM facilitator WHERE facilitator_id = 'YOUR_ID';

-- Check classes linked to facilitator
SELECT f.facilitator_id, f.classID, c.className 
FROM facilitator f 
LEFT JOIN class c ON f.classID = c.classID 
WHERE f.facilitator_id = 'YOUR_ID';
```

### Issue: Database connection error
**Check:**
1. Is connection.php in the same directory?
2. Are database credentials correct?
3. Is the database server running?
4. Check MySQL error logs

### Issue: JSON parse error in app
**Check:**
1. Is the PHP file returning valid JSON?
2. Are there any PHP errors/warnings in the response?
3. Check the raw response in browser or Postman

## Rollback Plan

If issues occur:

1. **Server-side:** Delete or rename `get_classes.php`
2. **App-side:** Revert to previous APK version
3. **Database:** No database changes were made, so no rollback needed

## Database Schema Reference

```sql
-- Tables involved:
facilitator (facilitator_id, classID, firstName, lastName, role)
class (classID, className, siteID)
sites (siteID, siteName, project_id)
project (project_id, Project_name)
learnerdetails (LearnerID, classID)
```

## Support

If you encounter issues:
1. Check server error logs: `/var/log/apache2/error.log` or `/var/log/nginx/error.log`
2. Check PHP error logs: Usually in the same directory as the PHP file
3. Check app console logs: Use `flutter logs` or Android Studio logcat
4. Review the test file output: `php test_get_classes.php`

## Notes

- The fix assumes facilitators are linked to classes via `facilitator.classID`
- Multiple classes per facilitator require multiple rows in the facilitator table
- The endpoint includes proper CORS headers for cross-origin requests
- All URLs now use AppConfig instead of hardcoded values
- Better error handling and logging has been added
