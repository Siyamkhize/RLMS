# POE Chunk Upload Failure - Detailed Error Logging Added

## 🐛 Problem Found

From the logs:
```
Chunk 1 response body: {"success":false,"message":"Upload failed: Chunk upload failed","error":"Chunk upload failed"}
```

The server is receiving the chunk but rejecting it with a generic "Chunk upload failed" error.

## 🔍 Root Cause

The PHP code was throwing a generic error without details:
```php
if (!isset($_FILES['chunk']) || $_FILES['chunk']['error'] !== UPLOAD_ERR_OK) {
    throw new Exception('Chunk upload failed');  // ❌ No details!
}
```

This could be:
1. File exceeds upload_max_filesize (most likely - still 2MB on server)
2. Missing temp folder
3. Disk write error
4. PHP extension blocking upload

## ✅ Fix Applied

### Added Detailed Error Messages

```php
if (!isset($_FILES['chunk'])) {
    error_log("POE Upload Error: chunk file not in request");
    throw new Exception('Chunk file not found in request');
}

if ($_FILES['chunk']['error'] !== UPLOAD_ERR_OK) {
    $errorCode = $_FILES['chunk']['error'];
    $errorMessages = [
        UPLOAD_ERR_INI_SIZE => 'Chunk exceeds upload_max_filesize (' . ini_get('upload_max_filesize') . ')',
        UPLOAD_ERR_FORM_SIZE => 'Chunk exceeds form MAX_FILE_SIZE',
        UPLOAD_ERR_PARTIAL => 'Chunk was only partially uploaded',
        UPLOAD_ERR_NO_FILE => 'No chunk file uploaded',
        UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder',
        UPLOAD_ERR_CANT_WRITE => 'Failed to write chunk to disk',
        UPLOAD_ERR_EXTENSION => 'PHP extension stopped chunk upload',
    ];
    
    $errorMsg = isset($errorMessages[$errorCode]) ? 
        $errorMessages[$errorCode] : 
        'Unknown upload error code: ' . $errorCode;
        
    error_log("POE Upload Error: Chunk $chunkIndex failed - $errorMsg");
    throw new Exception('Chunk upload failed: ' . $errorMsg);
}
```

### Added Comprehensive Logging

```php
function handleChunkedUpload($conn, $uploadDir, $maxFileSize) {
    error_log("=== POE Chunked Upload Start ===");
    error_log("POST data: " . print_r($_POST, true));
    error_log("FILES data: " . print_r($_FILES, true));
    error_log("Chunk $chunkIndex of $totalChunks, File ID: $fileId");
    error_log("Learner ID: $learnerId, Name: $learnerName");
    // ... rest of function
}
```

## 🧪 Testing

### Step 1: Upload Updated PHP File

```bash
# Upload to server
scp upload_poe_document.php user@rlms.rlms.co.za:/path/to/mobile/
```

### Step 2: Test Upload from App

```bash
# Watch server logs in real-time
ssh user@rlms.rlms.co.za
tail -f /var/log/apache2/error.log | grep "POE"
```

### Step 3: Try Upload

1. Open app
2. Scan 50 pages
3. Tap "Upload Document"
4. Watch logs for detailed error

### Step 4: Check Test Page

Visit: `https://rlms.rlms.co.za/mobile/test_chunk_upload.php`

This will show:
- Current PHP upload settings
- Upload directory status
- Test upload form
- Recent error log entries

## 📊 Expected Log Output

### If upload_max_filesize is too small:
```
POE Upload Error: Chunk 0 failed - Chunk exceeds upload_max_filesize (2M)
```

**Solution:** Increase upload_max_filesize to 200M

### If temp directory missing:
```
POE Upload Error: Chunk 0 failed - Missing temporary folder
```

**Solution:** Create temp directory

### If disk full:
```
POE Upload Error: Chunk 0 failed - Failed to write chunk to disk
```

**Solution:** Free up disk space

## 🔧 Most Likely Issue: upload_max_filesize

Your chunks are 2MB each, but server's upload_max_filesize is probably still 2M (default).

**Quick Fix:**

Create `.htaccess` in mobile directory:
```apache
php_value upload_max_filesize 200M
php_value post_max_size 200M
php_value max_execution_time 7200
php_value memory_limit 256M
```

Then restart Apache:
```bash
sudo service apache2 restart
```

## 📝 Debugging Steps

### Step 1: Check Current Settings

Visit: `https://rlms.rlms.co.za/mobile/check_php_upload_limits.php`

Look for:
```
upload_max_filesize: 2M  ❌ Too Low
```

### Step 2: Check Error Log

```bash
ssh user@server
tail -f /var/log/apache2/error.log
```

Look for lines like:
```
POE Upload Error: Chunk 0 failed - [specific error]
```

### Step 3: Test Manually

Visit: `https://rlms.rlms.co.za/mobile/test_chunk_upload.php`

Upload a small file (< 1MB) to test if basic upload works.

## ✅ Summary

**Problem:** Chunk upload fails with generic error

**Cause:** Server rejecting chunks (likely upload_max_filesize = 2M)

**Solution:** 
1. ✅ Added detailed error logging to PHP
2. ⏳ Need to increase upload_max_filesize on server
3. ✅ Created test tools to diagnose

**Next Steps:**
1. Upload updated upload_poe_document.php
2. Try upload from app
3. Check error log for specific error
4. Fix based on specific error (likely increase upload_max_filesize)

**Files Updated:**
- `upload_poe_document.php` - Better error messages and logging
- `test_chunk_upload.php` - Test tool for server
- `check_php_upload_limits.php` - Check PHP settings

**Status:** Ready to deploy and get specific error message!
