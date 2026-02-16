# Fix: ERR_INVALID_RESPONSE on ZIP Download

## Problem

When the bulk export completes, clicking download results in:
```
ERR_INVALID_RESPONSE
The webpage at https://rlms.rlms.co.za/bulk_down_register.php?temp_file=bulk_reports_xxx.zip 
might be temporarily down or it may have moved permanently to a new web address.
```

## Root Cause

The ZIP file download was being interrupted by output buffering or headers already sent from the main page.

## Solution

Created a dedicated download handler that:
1. Cleans all output buffers
2. Sets proper headers for ZIP files
3. Streams the file in chunks
4. Verifies file exists before serving

## Files Updated/Created

### 1. Updated Files

**bulk_down_register.php**
- Enhanced temp_file handler with better headers
- Added Content-Length header
- Disabled compression
- Cleaned output buffers

**bulk_download_chunked.js**
- Changed download URL to use dedicated script
- Added ZIP file verification before download

### 2. New Files

**download_zip.php** (NEW - MUST UPLOAD)
- Dedicated ZIP download handler
- Streams files in 8KB chunks
- Proper error handling
- Detailed logging

**check_zip_file.php** (NEW - OPTIONAL)
- Debug script to verify ZIP files
- Checks file exists, size, validity
- Useful for troubleshooting

## Deployment Steps

### Step 1: Upload New Files

Upload these files to your server:
```
✓ download_zip.php          (NEW - Required)
✓ check_zip_file.php        (NEW - Optional but recommended)
✓ bulk_download_chunked.js  (UPDATED)
✓ bulk_down_register.php    (UPDATED)
```

### Step 2: Set Permissions

```bash
chmod 755 download_zip.php
chmod 755 check_zip_file.php
```

### Step 3: Test

1. Run a small bulk export (10 learners)
2. Wait for completion
3. ZIP should download automatically
4. Verify ZIP opens correctly

## Testing the Fix

### Test 1: Check if ZIP was created

After export completes, open in browser:
```
https://yoursite.com/check_zip_file.php?file=bulk_reports_20251101_105411.zip
```

Should show:
```json
{
  "exists": true,
  "readable": true,
  "size": 12345678,
  "size_formatted": "11.77 MB",
  "valid_zip": true,
  "num_files": 150
}
```

### Test 2: Direct download

Try downloading directly:
```
https://yoursite.com/download_zip.php?file=bulk_reports_20251101_105411.zip
```

Should download the ZIP file immediately.

### Test 3: Full workflow

1. Go to bulk_down_register.php
2. Filter for 10 learners
3. Click "Bulk Download"
4. Wait for progress to complete
5. ZIP should download automatically

## Troubleshooting

### Issue: "File not found" error

**Check**:
```bash
ls -la temp_reports/
```

**Fix**: Verify temp_reports directory exists and has correct permissions:
```bash
mkdir -p temp_reports
chmod 777 temp_reports
```

### Issue: ZIP file is 0 bytes

**Check**: Look at PHP error logs
```bash
tail -f /var/log/php_errors.log
```

**Common causes**:
- Disk space full
- PHP memory limit too low
- mPDF errors

**Fix**:
```php
ini_set('memory_limit', '1024M');
```

### Issue: "Invalid file type" error

**Check**: Verify the filename ends with .zip

**Fix**: The system should only create .zip files. If you see other extensions, check the finalize function in bulk_export_chunked.php

### Issue: Download starts but fails midway

**Check**: File size and server timeout

**Fix**: Increase PHP execution time:
```php
set_time_limit(300); // 5 minutes
```

## How the Fix Works

### Before (Broken)

```
User clicks download
    ↓
bulk_down_register.php?temp_file=xxx.zip
    ↓
Page loads with HTML/CSS/JavaScript
    ↓
Headers already sent
    ↓
Cannot send ZIP file headers
    ↓
ERR_INVALID_RESPONSE ❌
```

### After (Fixed)

```
User clicks download
    ↓
download_zip.php?file=xxx.zip
    ↓
Clean all output buffers
    ↓
Set proper ZIP headers
    ↓
Stream file in chunks
    ↓
Download succeeds ✅
```

## Verification Checklist

After deploying the fix:

- [ ] download_zip.php uploaded
- [ ] check_zip_file.php uploaded
- [ ] bulk_download_chunked.js updated
- [ ] bulk_down_register.php updated
- [ ] Permissions set (755)
- [ ] Test with check_zip_file.php shows file exists
- [ ] Direct download via download_zip.php works
- [ ] Full workflow downloads ZIP automatically
- [ ] ZIP file opens and contains reports
- [ ] No ERR_INVALID_RESPONSE errors

## Additional Improvements

### Auto-cleanup old files

Add to crontab to clean files older than 24 hours:
```bash
0 2 * * * find /path/to/temp_reports/*.zip -mtime +1 -delete
```

### Monitor disk space

```bash
df -h
```

### Check error logs regularly

```bash
tail -f /var/log/php_errors.log | grep -i "zip\|download"
```

## Success Indicators

When working correctly:

1. ✅ Progress completes to 100%
2. ✅ Browser automatically starts download
3. ✅ ZIP file downloads completely
4. ✅ ZIP file opens without errors
5. ✅ ZIP contains all expected files:
   - reports/ folder with PDFs
   - sick_notes/ folder
   - manual_registers/ folder
   - SUMMARY.txt

## Summary

The fix separates the ZIP download into a dedicated handler that:
- Avoids interference from the main page
- Properly sets headers for binary file download
- Streams large files efficiently
- Provides better error handling and logging

**Status**: ✅ Ready to deploy

---

**Files to Upload**:
1. download_zip.php (NEW)
2. check_zip_file.php (NEW)
3. bulk_download_chunked.js (UPDATED)
4. bulk_down_register.php (UPDATED)

**Total deployment time**: 2 minutes
