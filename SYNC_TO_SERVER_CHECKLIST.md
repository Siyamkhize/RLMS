# Server Sync Setup Checklist

## Issue
Scanned documents are saving locally but not syncing to the server.

## Possible Causes & Solutions

### 1. Database Table Not Created
**Check**: Does the `pothole_checklist_scanned_documents` table exist?

```sql
-- Run this on your MySQL server
USE rlms;
SHOW TABLES LIKE 'pothole_checklist_scanned_documents';
```

**If table doesn't exist**, run:
```bash
mysql -u root -p rlms < create_pothole_checklist_scanned_table.sql
```

### 2. PHP File Not Uploaded
**Check**: Does the PHP file exist on the server?

```bash
# Check if file exists
ls -la /path/to/rlms/mobile/upload_scanned_pothole_checklist.php
```

**If file doesn't exist**, upload it:
- Upload `php/upload_scanned_pothole_checklist.php` to `/mobile/` directory on server

### 3. Upload Directory Not Created
**Check**: Does the uploads directory exist with correct permissions?

```bash
# Check directory
ls -la /path/to/rlms/uploads/pothole_checklists/
```

**If directory doesn't exist**, create it:
```bash
mkdir -p /path/to/rlms/uploads/pothole_checklists
chmod 777 /path/to/rlms/uploads/pothole_checklists
```

### 4. No Internet Connection
**Check**: Is the device online?

The app will save locally and sync later when online. Check the logs:
```
[SYNC] Starting sync for learner: xxx
[SYNC] ERROR: ... (will show the error)
```

### 5. Server URL Incorrect
**Check**: Is the base URL correct in config.dart?

Should be:
```dart
static const String baseUrl = 'https://rlms.rlms.co.za/mobile';
```

### 6. PHP Errors
**Check**: Are there PHP errors?

Look at server error logs:
```bash
tail -f /var/log/apache2/error.log
# or
tail -f /var/log/nginx/error.log
```

## How to Debug

### Step 1: Check App Logs
After scanning, check the Flutter console for:
```
[SYNC] Starting sync for learner: xxx
[SYNC] Document path: /data/...
[SYNC] File exists, size: xxx bytes
[SYNC] Uploading to: https://...
[SYNC] Sending request...
[SYNC] Response status: 200
[SYNC] ✅ Document synced successfully
```

### Step 2: Test PHP Endpoint
Test the upload endpoint with curl:

```bash
curl -X POST \
  -F "learner_id=12345" \
  -F "assessor_id=67890" \
  -F "assessment_date=2025-11-04" \
  -F "document=@test.pdf" \
  https://rlms.rlms.co.za/mobile/upload_scanned_pothole_checklist.php
```

Expected response:
```json
{
  "status": "success",
  "message": "Scanned document uploaded successfully",
  "file_path": "/uploads/pothole_checklists/pothole_checklist_12345_xxx.pdf"
}
```

### Step 3: Check Database
After successful upload, check the database:

```sql
SELECT * FROM pothole_checklist_scanned_documents 
ORDER BY created_at DESC 
LIMIT 5;
```

Should show the uploaded document record.

### Step 4: Check File on Server
Verify the file was uploaded:

```bash
ls -lh /path/to/rlms/uploads/pothole_checklists/
```

Should show the PDF file.

## Quick Setup Script

Run this on your server to set everything up:

```bash
#!/bin/bash

# 1. Create database table
mysql -u root -p rlms < create_pothole_checklist_scanned_table.sql

# 2. Create upload directory
mkdir -p /var/www/html/rlms/uploads/pothole_checklists
chmod 777 /var/www/html/rlms/uploads/pothole_checklists

# 3. Verify PHP file exists
ls -la /var/www/html/rlms/mobile/upload_scanned_pothole_checklist.php

echo "Setup complete!"
```

## Common Error Messages

### "Database connection failed"
- Check MySQL is running
- Verify database credentials in PHP file
- Ensure database 'rlms' exists

### "No file uploaded or upload error"
- Check file size limits in php.ini
- Verify upload_max_filesize and post_max_size
- Check file permissions

### "Invalid file type"
- Only PDF, JPG, PNG allowed
- Check file MIME type

### "Failed to save uploaded file"
- Check directory permissions (should be 777)
- Verify disk space available
- Check SELinux settings (if enabled)

## Testing Checklist

- [ ] Database table created
- [ ] PHP file uploaded to server
- [ ] Upload directory created with permissions
- [ ] Device has internet connection
- [ ] Base URL is correct in config.dart
- [ ] Test upload with curl works
- [ ] App logs show successful sync
- [ ] Database record created
- [ ] File exists on server
- [ ] Can view scanned document

## Status Indicators

### ✅ Working
```
[SYNC] ✅ Document synced successfully
```
Database has record, file on server, can view document.

### ⏳ Pending
```
[SYNC] Starting sync...
```
Still uploading, wait for completion.

### ❌ Failed
```
[SYNC] ❌ Upload failed with status 500
[SYNC] ❌ Error syncing document: ...
```
Check error message and follow troubleshooting steps above.

## Next Steps

1. **Check app logs** after scanning
2. **Verify server setup** (table, directory, PHP file)
3. **Test with curl** to isolate issue
4. **Check database** for records
5. **Verify files** on server

---

**Note**: The app will continue to work offline. Documents are saved locally and will sync automatically when connection is restored.
