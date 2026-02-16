# Fix: Images Showing Success But Not Saving

## Problem
The app shows "images uploaded successfully" but when checking the server, no images appear in the POE table.

## Diagnostic Steps

### Step 1: Check if endpoint is accessible
Run this in your browser:
```
https://rlms.rlms.co.za/mobile/test_upload_simple.php
```

This will check:
- If upload_pothole_evidence.php exists
- If upload directory exists and is writable
- If database connection works
- If POE table exists
- Recent error logs

### Step 2: Check Flutter Console Output
When you upload images, check the Flutter console for these messages:
```
Sending X images for learner [ID]
Request fields: {learnerID: ..., assessorID: ..., assessmentDate: ...}
Request files count: X
Response status: 200
Response data: {"status":"success",...}
Uploaded files: [...]
```

**Key things to look for:**
- Response status should be 200
- Response data should show `"status":"success"`
- `success_count` should match number of images
- `uploaded_files` array should contain file paths

### Step 3: Check Server Logs
SSH into your server and run:
```bash
tail -f /home/username/public_html/logs/php_error_log
```

Then try uploading images. Look for:
- "POST data: ..."
- "FILES data: ..."
- "Processing X file(s) from field: images"
- "Processing file: [filename]"
- "Pothole evidence uploaded: learnerID=..."

### Step 4: Check Database Directly
Run this query in phpMyAdmin or MySQL:
```sql
SELECT * FROM poe 
WHERE type = 'LogBook' 
AND exercise LIKE '%Pothole%' 
ORDER BY id DESC 
LIMIT 10;
```

If you see entries, the upload is working!

### Step 5: Check Upload Directory
SSH into server:
```bash
ls -la uploads/pothole_evidence/
```

Check if files are being created there.

## Common Issues and Fixes

### Issue 1: Files in directory but not in database
**Symptom:** Files exist in `uploads/pothole_evidence/` but no POE table entries

**Cause:** Database INSERT is failing

**Fix:**
1. Check PHP error log for SQL errors
2. Verify POE table has these columns:
   - learnerID (varchar)
   - exercise (varchar/text)
   - type (varchar)
   - filePath (varchar/text)
   - logbook_text (text)

3. Test manual insert:
```sql
INSERT INTO poe (learnerID, exercise, type, filePath, logbook_text) 
VALUES ('TEST', 'Test', 'LogBook', 'test.jpg', 'Test');
```

### Issue 2: No files in directory, no database entries
**Symptom:** Nothing is being saved anywhere

**Possible causes:**
1. Upload directory doesn't exist or isn't writable
2. PHP script isn't receiving the files
3. File validation is rejecting all files

**Fix:**
1. Create directory manually:
```bash
mkdir -p uploads/pothole_evidence
chmod 755 uploads/pothole_evidence
```

2. Check PHP error log for "File rejected" messages

3. Check if files are being sent:
   - Look for "FILES data: Array" in error log
   - Should show `[images] => Array`

### Issue 3: Wrong field name
**Symptom:** Error log shows "No images uploaded" with empty files_keys

**Cause:** PHP isn't receiving files with expected field name

**Fix:** Already handled in code - script checks for both `images` and `images_`

### Issue 4: Success message but success_count = 0
**Symptom:** App shows success but `success_count` is 0

**Cause:** All files failed validation or upload

**Fix:** Check Flutter console for `errors` array in response

## Updated Code Changes

### Flutter (AssessorPage.dart)
Added more detailed logging:
- Prints request fields and file count
- Prints uploaded files details
- Prints any partial errors
- Shows debug info in console

### What to Check in Flutter Console

After uploading, you should see:
```
Sending 3 images for learner 123
Request fields: {learnerID: 123, assessorID: FAC001, assessmentDate: 2025-11-10}
Request files count: 3
Response status: 200
Response data: {"status":"success","message":"3 image(s) uploaded successfully","uploaded_files":[...],"success_count":3,"total_count":3}
Uploaded files: [{original_name: image1.jpg, file_path: uploads/pothole_evidence/pothole_123_2025-11-10_..., poe_id: 456}, ...]
```

If you see this, the upload IS working!

## Verification Steps

After uploading images:

1. **Check Flutter console** - Look for "Uploaded files" with poe_id values
2. **Check database** - Run query to see if entries exist
3. **Check directory** - Verify files are in uploads/pothole_evidence/
4. **Check view page** - Refresh and see if images appear

## If Still Not Working

1. Upload the diagnostic files to server:
   - test_upload_simple.php
   - quick_check_images.php
   - debug_poe_table.php

2. Run test_upload_simple.php first

3. Try uploading ONE small image (< 1MB)

4. Check PHP error log immediately after

5. Share the error log output for further diagnosis

## Testing Checklist

- [ ] Run test_upload_simple.php - all checks pass
- [ ] Upload directory exists and is writable
- [ ] Database connection works
- [ ] POE table exists with correct columns
- [ ] Try uploading 1 small image
- [ ] Check Flutter console for response
- [ ] Check PHP error log for processing messages
- [ ] Check database for new entry
- [ ] Check directory for new file
- [ ] Verify poe_id is returned in response

## Expected Flow

1. User clicks camera icon
2. Selects images
3. Flutter sends multipart request with `images[]` field
4. PHP receives as `$_FILES['images']`
5. PHP validates each file
6. PHP moves file to `uploads/pothole_evidence/`
7. PHP inserts record into POE table
8. PHP returns success with poe_id
9. Flutter shows success message
10. Images appear in view page

If any step fails, check the logs at that point.
