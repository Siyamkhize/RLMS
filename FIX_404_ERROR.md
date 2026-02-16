# 🔴 FIX: 404 Error - Bulk Export API Not Found

## Current Error
```
POST https://rlms.rlms.co.za/bulk_export_api.php 404 (Not Found)
❌ Export failed: SyntaxError: Unexpected token 'F', "File not found." is not valid JSON
```

## Root Cause
The file `bulk_export_api.php` **does not exist on your server** yet.

## Solution (3 Minutes)

### Step 1: Upload These 3 Files to Server
Upload to: `/public_html/` (same location as bulk_down_register.php)

```
✅ bulk_export_api.php
✅ bulk_export_with_documents.php
✅ get_learner_documents.php
```

### Step 2: Replace This File
```
✅ bulk_down_register.php (replace existing)
```

### Step 3: Create Temp Directory
On server, create directory:
```bash
mkdir /public_html/temp_reports
chmod 755 /public_html/temp_reports
```

Or via cPanel File Manager:
- Create new folder: `temp_reports`
- Set permissions: 755

### Step 4: Test
Visit: `https://rlms.rlms.co.za/bulk_export_api.php`

Should see:
```json
{
  "success": true,
  "message": "Bulk Export API is running",
  "endpoints": {...}
}
```

### Step 5: Try Bulk Download Again
- Go to bulk download page
- Filter learners
- Click "Bulk Download"
- Should work now! ✅

## Quick Upload Methods

### Method 1: FTP/SFTP (Recommended)
1. Open FileZilla/WinSCP
2. Connect to rlms.rlms.co.za
3. Navigate to `/public_html/`
4. Drag and drop the 4 files
5. Confirm overwrite for bulk_down_register.php

### Method 2: cPanel File Manager
1. Login to cPanel
2. File Manager → public_html
3. Click "Upload"
4. Select the 4 files
5. Upload

### Method 3: SSH/SCP
```bash
scp bulk_export_api.php user@rlms.rlms.co.za:/public_html/
scp bulk_export_with_documents.php user@rlms.rlms.co.za:/public_html/
scp get_learner_documents.php user@rlms.rlms.co.za:/public_html/
scp bulk_down_register.php user@rlms.rlms.co.za:/public_html/
```

## Files Location

Your local files are here:
```
📁 Your Project Directory
  ├── bulk_export_api.php ← Upload this
  ├── bulk_export_with_documents.php ← Upload this
  ├── get_learner_documents.php ← Upload this
  └── bulk_down_register.php ← Upload this (replace)
```

Server location should be:
```
📁 /public_html/
  ├── bulk_export_api.php ← NEW
  ├── bulk_export_with_documents.php ← NEW
  ├── get_learner_documents.php ← NEW
  ├── bulk_down_register.php ← UPDATED
  └── temp_reports/ ← CREATE THIS FOLDER
```

## Verification Checklist

After uploading, verify:

- [ ] Visit https://rlms.rlms.co.za/bulk_export_api.php
- [ ] Should see JSON response (not 404)
- [ ] temp_reports folder exists
- [ ] Try bulk download with 5 learners
- [ ] ZIP file downloads successfully
- [ ] ZIP contains reports, sick notes, manual registers

## Still Getting 404?

### Check 1: Files Actually Uploaded?
SSH into server and run:
```bash
ls -la /public_html/bulk_export_api.php
ls -la /public_html/bulk_export_with_documents.php
ls -la /public_html/get_learner_documents.php
```

Should show file sizes, not "No such file"

### Check 2: Correct Directory?
Make sure files are in `/public_html/` not `/public_html/subfolder/`

### Check 3: File Permissions?
```bash
chmod 644 /public_html/bulk_export_api.php
chmod 644 /public_html/bulk_export_with_documents.php
chmod 644 /public_html/get_learner_documents.php
```

### Check 4: .htaccess Blocking?
Check if .htaccess has rules blocking .php files

## Expected Result

After uploading, when you click "Bulk Download":

```
✅ Exporting 133 learners with sick notes and manual registers
✅ Date range: 2025-09-01 to 2025-09-30
✅ Export completed successfully!

📊 Summary:
- Total learners: 133
- Successfully processed: 133
- Failed: 0
- Sick notes included: X
- Manual registers included: Y

Downloading ZIP file...
```

## Need Help?

1. Verify files uploaded: `ls -la /public_html/bulk_export_*.php`
2. Check API works: Visit https://rlms.rlms.co.za/bulk_export_api.php
3. Check error log: `tail -f /public_html/bulk_export_errors.log`

---

**TL;DR**: Upload the 3 new PHP files to your server. The 404 error will be fixed.
