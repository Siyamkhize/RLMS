# Pothole Images Not Appearing - Troubleshooting Guide

## Issue
You uploaded images from the Flutter app but they're not appearing in the POE table on the server.

## Quick Diagnosis

Run these URLs in your browser (replace `LEARNER_ID` with actual learner ID):

### 1. Comprehensive Test
```
https://rlms.rlms.co.za/mobile/test_pothole_evidence_upload.php
```
**What it checks:**
- POE table structure
- Upload directory status
- Existing database entries
- Database insert capability
- PHP error logs

### 2. Check Specific Learner
```
https://rlms.rlms.co.za/mobile/debug_poe_table.php?learner_id=LEARNER_ID
```
**What it shows:**
- All POE records for the learner
- LogBook type records
- Pothole-specific records

### 3. Get Pothole Images API
```
https://rlms.rlms.co.za/mobile/get_pothole_images.php?learner_id=LEARNER_ID
```
**What it returns:**
- JSON response with all pothole images for the learner

### 4. Debug Upload Endpoint
```
https://rlms.rlms.co.za/mobile/test_upload_debug.php
```
**Use with Postman:** Send a POST request with test images to see what data is received.

## Most Likely Causes

### Cause 1: Upload Directory Missing or Not Writable
**Symptoms:** Upload fails with "Failed to move uploaded file" error

**Check:**
```bash
ls -la uploads/pothole_evidence/
```

**Fix:**
```bash
mkdir -p uploads/pothole_evidence
chmod 755 uploads/pothole_evidence
```

### Cause 2: Database Insert Failing
**Symptoms:** Files appear in directory but not in database

**Check:** Look at PHP error log:
```
/home/username/public_html/logs/php_error_log
```

**Common reasons:**
- POE table doesn't have required columns
- Database connection issues
- SQL syntax errors

### Cause 3: Wrong Field Name in Upload
**Symptoms:** "No images uploaded" error

**Status:** ✅ FIXED - The upload script now handles both `images` and `images_` field names

### Cause 4: File Type Validation Too Strict
**Symptoms:** "File is not a valid image type" error

**Status:** ✅ FIXED - Now checks both MIME type and file extension

## How to Test the Upload

### From Flutter App:
1. Open AssessorPage
2. Find a learner in the Pothole Checklist table
3. Click the camera icon to upload images
4. Select multiple images
5. Wait for success message

### Check if it worked:
1. Run: `https://rlms.rlms.co.za/mobile/debug_poe_table.php?learner_id=LEARNER_ID`
2. Look for entries in the "Pothole-related records" section
3. If you see entries, the upload worked!
4. If not, check the comprehensive test for errors

## Expected Database Entry

When images upload successfully, each creates a POE table entry:

| Column | Value |
|--------|-------|
| learnerID | The learner's ID |
| exercise | "Pothole Patching Evidence - 2025-11-10 14:30:45" |
| type | "LogBook" |
| filePath | "uploads/pothole_evidence/pothole_123_2025-11-10_1731247845_abc123.jpg" |
| logbook_text | "Pothole patching evidence uploaded by assessor FAC001 on 2025-11-10" |

## Files Involved

### PHP Files:
- `upload_pothole_evidence.php` - Main upload handler (FIXED)
- `get_pothole_images.php` - Retrieves images for display
- `debug_poe_table.php` - Debug tool for POE table
- `test_pothole_evidence_upload.php` - Comprehensive test
- `test_upload_debug.php` - Simple upload test

### Flutter Files:
- `lib/AssessorPage.dart` - Contains `_uploadPotholeEvidence()` function (line ~5686)
- `lib/AssessorPage.dart` - Contains `PotholeChecklistViewPage` with image display

## What Was Fixed

1. **Field name handling** - Now accepts both `images` and `images_` from $_FILES
2. **File type validation** - Checks both MIME type and file extension
3. **Better error logging** - Logs all upload attempts and errors
4. **Debug tools** - Created multiple diagnostic scripts

## If Images Still Don't Appear

1. **Check the upload is actually being called:**
   - Add print statements in Flutter before/after upload
   - Check if success message appears

2. **Verify the endpoint URL:**
   - Should be: `https://rlms.rlms.co.za/mobile/upload_pothole_evidence.php`
   - Check in AssessorPage.dart line ~5710

3. **Check server logs:**
   ```
   tail -f /home/username/public_html/logs/php_error_log
   ```

4. **Test with Postman:**
   - POST to upload_pothole_evidence.php
   - Add fields: learnerID, assessorID, assessmentDate
   - Add files: images[] (multiple files)

5. **Check POE table structure:**
   ```sql
   DESCRIBE poe;
   ```
   Required columns: learnerID, exercise, type, filePath, logbook_text

## Success Indicators

✅ Files appear in `uploads/pothole_evidence/` directory
✅ Entries appear in POE table with type='LogBook'
✅ `get_pothole_images.php` returns the images
✅ Images display in PotholeChecklistViewPage
✅ No errors in PHP error log

## Contact Points

If you're still having issues, check:
1. Run all diagnostic URLs above
2. Check PHP error log
3. Verify POE table structure
4. Test with a single small image first
