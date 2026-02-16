# POE Upload 500 Error Fix

## Problem
POE document chunked uploads are failing with HTTP 500 Internal Server Error on the first chunk.

## Root Cause
The 500 error occurs before the PHP script can return a proper JSON error response. This is typically caused by:
1. PHP fatal errors (syntax errors, missing functions)
2. Apache configuration issues
3. Missing PHP extensions
4. File permission problems
5. .htaccess configuration errors

## Solution

### Step 1: Deploy Fixed Upload Script

Replace the current `upload_poe_document.php` with the fixed version:

```bash
# On the server
cd /path/to/mobile/
cp upload_poe_document.php upload_poe_document_backup.php
cp upload_poe_document_fixed.php upload_poe_document.php
```

The fixed version includes:
- Better error handling that catches fatal errors
- Proper error logging to `poe_upload_errors.log`
- Detailed logging to `poe_upload.log`
- Graceful error responses in JSON format

### Step 2: Check Server Requirements

Run this command on the server to check PHP configuration:

```bash
php -v  # Check PHP version (need 7.0+)
php -m  # Check installed modules (need mysqli, fileinfo)
```

Required PHP extensions:
- mysqli (for database)
- fileinfo (for MIME type detection)
- json (for JSON responses)

### Step 3: Check File Permissions

```bash
# On the server
cd /path/to/mobile/
chmod 755 upload_poe_document.php
chmod 755 connection.php
mkdir -p uploads/poe_documents/temp
chmod 777 uploads/poe_documents/temp
chmod 777 uploads/poe_documents
```

### Step 4: Check .htaccess Configuration

If you have a `.htaccess` file, make sure it doesn't have syntax errors:

```bash
# Test Apache configuration
sudo apachectl configtest

# If errors, check .htaccess
cat .htaccess
```

Common .htaccess issues:
- `php_value` directives not supported (use php.ini instead)
- Syntax errors in rewrite rules
- Missing required modules

If `.htaccess` is causing issues, temporarily rename it:
```bash
mv .htaccess .htaccess_disabled
```

### Step 5: Check PHP Configuration

Create a test file to check current PHP limits:

```bash
# On the server
cat > check_php_config.php << 'EOF'
<?php
header('Content-Type: text/plain');
echo "PHP Version: " . phpversion() . "\n";
echo "upload_max_filesize: " . ini_get('upload_max_filesize') . "\n";
echo "post_max_size: " . ini_get('post_max_size') . "\n";
echo "max_execution_time: " . ini_get('max_execution_time') . "\n";
echo "memory_limit: " . ini_get('memory_limit') . "\n";
echo "file_uploads: " . (ini_get('file_uploads') ? 'enabled' : 'disabled') . "\n";
echo "upload_tmp_dir: " . ini_get('upload_tmp_dir') . "\n";
?>
EOF
```

Access: `https://rlms.rlms.co.za/mobile/check_php_config.php`

If limits are too low, edit `php.ini`:
```bash
sudo nano /etc/php/7.4/apache2/php.ini  # Adjust path for your PHP version

# Find and update these values:
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 7200
memory_limit = 256M

# Restart Apache
sudo service apache2 restart
```

### Step 6: Check Error Logs

After deploying the fix, check the logs:

```bash
# On the server
tail -f /path/to/mobile/poe_upload_errors.log
tail -f /path/to/mobile/poe_upload.log
tail -f /var/log/apache2/error.log
```

### Step 7: Test Upload

Use the test script to verify the fix:

```bash
# On the server
cd /path/to/mobile/
php test_upload_poe_simple.php
```

Or test from the app and check the logs.

## Debugging Steps

### 1. Test Basic PHP Execution

```bash
# On the server
cat > test_basic.php << 'EOF'
<?php
header('Content-Type: application/json');
echo json_encode(['success' => true, 'message' => 'PHP working']);
?>
EOF
```

Access: `https://rlms.rlms.co.za/mobile/test_basic.php`

If this returns 500, PHP itself has issues.

### 2. Test Database Connection

```bash
# On the server
cat > test_db.php << 'EOF'
<?php
header('Content-Type: application/json');
try {
    require_once 'connection.php';
    echo json_encode(['success' => true, 'message' => 'Database connected']);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
?>
EOF
```

Access: `https://rlms.rlms.co.za/mobile/test_db.php`

### 3. Test File Upload

```bash
# On the server
cat > test_upload_basic.php << 'EOF'
<?php
header('Content-Type: application/json');
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    echo json_encode([
        'success' => true,
        'post_count' => count($_POST),
        'files_count' => count($_FILES),
        'post_keys' => array_keys($_POST),
        'files_keys' => array_keys($_FILES)
    ]);
} else {
    echo json_encode(['success' => false, 'message' => 'Use POST method']);
}
?>
EOF
```

Test with curl:
```bash
curl -X POST \
  -F "chunk_index=0" \
  -F "total_chunks=1" \
  -F "file_id=test123" \
  -F "chunk=@/path/to/test.pdf" \
  https://rlms.rlms.co.za/mobile/test_upload_basic.php
```

## Quick Fix Summary

1. **Deploy fixed script**: `upload_poe_document_fixed.php` → `upload_poe_document.php`
2. **Set permissions**: `chmod 777 uploads/poe_documents/temp`
3. **Check PHP config**: Ensure upload limits are high enough
4. **Check logs**: `poe_upload_errors.log` and `poe_upload.log`
5. **Test**: Try uploading from the app again

## Expected Behavior After Fix

- Chunk uploads should return JSON responses (not HTML 500 errors)
- Error messages should be descriptive
- Logs should show detailed information about the upload process
- If errors occur, they should be logged to `poe_upload_errors.log`

## Files Created

1. `upload_poe_document_fixed.php` - Fixed upload script with better error handling
2. `test_upload_poe_simple.php` - Simple test script for debugging
3. `test_chunk_upload_debug.php` - Detailed chunk upload test

## Next Steps

After deploying the fix:
1. Try uploading a POE document from the app
2. Check the logs for any errors
3. If still failing, check Apache error logs
4. Verify PHP extensions are installed
5. Test with the simple test scripts

## Contact

If the issue persists after following these steps, provide:
- Contents of `poe_upload_errors.log`
- Contents of `poe_upload.log`
- Apache error log entries
- Output of `php -v` and `php -m`
- Output of `check_php_config.php`
