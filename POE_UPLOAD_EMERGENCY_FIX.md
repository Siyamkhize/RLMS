# POE Upload Emergency Fix - 500 Error

## Immediate Problem
The server is returning a 500 error before the PHP script can even execute. This means there's a fundamental issue with the server configuration or the PHP file itself.

## Quick Diagnosis

### Option 1: Test with Minimal Script (RECOMMENDED)

Upload `poe_upload_minimal.php` to the server and temporarily update the Flutter app to use it:

**In `lib/config.dart`:**
```dart
// Temporarily change this line:
static const String baseUrl = 'https://rlms.rlms.co.za/mobile';

// To test with minimal script, change upload URL in poe_document_scanner.dart:
// From: '$baseUrl/upload_poe_document.php'
// To: '$baseUrl/poe_upload_minimal.php'
```

**Or create a test from command line:**
```bash
# On your computer, test the minimal script
curl -X POST \
  -F "chunk_index=0" \
  -F "total_chunks=1" \
  -F "file_id=test123" \
  -F "learner_id=TEST001" \
  -F "learner_name=Test User" \
  -F "chunk=@test.pdf" \
  https://rlms.rlms.co.za/mobile/poe_upload_minimal.php
```

Then check the log file on the server:
```bash
cat /path/to/mobile/poe_minimal.log
```

### Option 2: Check Server Error Logs

The real error is in the Apache error log:

```bash
# On the server
sudo tail -50 /var/log/apache2/error.log
# or
sudo tail -50 /var/log/httpd/error_log
```

Look for errors around the time of the upload (10:23:16).

### Option 3: Check PHP Configuration

The issue might be that PHP can't handle the upload size. Check:

```bash
# On the server
php -i | grep -E "upload_max_filesize|post_max_size|memory_limit"
```

If these values are too low (less than 10M), you need to increase them.

## Most Likely Causes

### 1. .htaccess Syntax Error

If you have a `.htaccess` file with `php_value` directives, they might not be supported:

```bash
# On the server
cd /path/to/mobile/
cat .htaccess
```

If it contains `php_value` lines and you're getting 500 errors, try:

```bash
# Temporarily disable .htaccess
mv .htaccess .htaccess_disabled

# Test upload again
# If it works, the .htaccess was the problem
```

**Fix:** Edit `php.ini` instead of `.htaccess`:

```bash
# Find php.ini location
php -i | grep "Loaded Configuration File"

# Edit it (example path)
sudo nano /etc/php/7.4/apache2/php.ini

# Add/update these lines:
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 7200
memory_limit = 256M

# Restart Apache
sudo service apache2 restart
```

### 2. Missing PHP Extensions

Check if required extensions are installed:

```bash
php -m | grep -E "mysqli|fileinfo|json"
```

If any are missing:

```bash
# Ubuntu/Debian
sudo apt-get install php-mysqli php-fileinfo

# CentOS/RHEL
sudo yum install php-mysqli php-fileinfo

# Restart Apache
sudo service apache2 restart
```

### 3. File Permissions

```bash
# On the server
cd /path/to/mobile/
chmod 644 upload_poe_document.php
chmod 644 connection.php
mkdir -p uploads/poe_documents/temp
chmod 777 uploads/poe_documents
chmod 777 uploads/poe_documents/temp
```

### 4. PHP Syntax Error in connection.php

Test if connection.php has syntax errors:

```bash
php -l connection.php
```

If there's an error, it will show the line number.

### 5. Database Connection Failing

The connection.php might be throwing an exception. Test it:

```bash
# On the server
cat > test_connection.php << 'EOF'
<?php
header('Content-Type: application/json');
try {
    require_once 'connection.php';
    echo json_encode(['success' => true, 'message' => 'Connected']);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
?>
EOF

# Test it
curl https://rlms.rlms.co.za/mobile/test_connection.php
```

## Emergency Workaround

If you can't fix the server immediately, use the minimal script without database:

**Create `poe_upload_no_db.php`:**

```php
<?php
@header('Content-Type: application/json');
@header('Access-Control-Allow-Origin: *');

$log = __DIR__ . '/poe_upload.log';

try {
    if (!isset($_POST['chunk_index'])) {
        throw new Exception('Not a chunked upload');
    }
    
    $chunkIndex = (int)$_POST['chunk_index'];
    $totalChunks = (int)$_POST['total_chunks'];
    $fileId = $_POST['file_id'];
    
    if (!isset($_FILES['chunk'])) {
        throw new Exception('No chunk file');
    }
    
    if ($_FILES['chunk']['error'] !== 0) {
        throw new Exception('Upload error: ' . $_FILES['chunk']['error']);
    }
    
    $dir = __DIR__ . '/uploads/poe_documents/temp/';
    @mkdir($dir, 0777, true);
    
    $chunkPath = $dir . $fileId . '_chunk_' . $chunkIndex;
    
    if (!@move_uploaded_file($_FILES['chunk']['tmp_name'], $chunkPath)) {
        throw new Exception('Failed to save chunk');
    }
    
    @file_put_contents($log, date('Y-m-d H:i:s') . " Chunk $chunkIndex saved\n", FILE_APPEND);
    
    // If last chunk, merge
    if ($chunkIndex === $totalChunks - 1) {
        $learnerId = $_POST['learner_id'];
        $ext = $_POST['file_extension'] ?? 'pdf';
        $fileName = "POE_{$learnerId}_" . time() . "_{$fileId}.{$ext}";
        $finalPath = __DIR__ . '/uploads/poe_documents/' . $fileName;
        
        $final = fopen($finalPath, 'wb');
        for ($i = 0; $i < $totalChunks; $i++) {
            $chunk = $dir . $fileId . '_chunk_' . $i;
            if (file_exists($chunk)) {
                fwrite($final, file_get_contents($chunk));
                unlink($chunk);
            }
        }
        fclose($final);
        
        @file_put_contents($log, date('Y-m-d H:i:s') . " File merged: $fileName\n", FILE_APPEND);
        
        echo json_encode([
            'success' => true,
            'message' => 'Upload complete',
            'file_name' => $fileName,
            'file_size' => filesize($finalPath)
        ]);
    } else {
        echo json_encode([
            'success' => true,
            'message' => 'Chunk received',
            'chunk_index' => $chunkIndex
        ]);
    }
    
} catch (Exception $e) {
    @file_put_contents($log, date('Y-m-d H:i:s') . " ERROR: " . $e->getMessage() . "\n", FILE_APPEND);
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
?>
```

This version:
- No database connection (files saved but not tracked)
- Minimal dependencies
- Should work even with limited PHP configuration

## Action Plan

1. **First**: Check Apache error logs to see the actual error
2. **Second**: Test with `poe_upload_minimal.php` to see if it works
3. **Third**: Check if `.htaccess` is causing issues (disable it temporarily)
4. **Fourth**: Verify PHP configuration (upload limits, extensions)
5. **Fifth**: Test database connection separately

## Quick Commands Summary

```bash
# On the server
cd /path/to/mobile/

# 1. Check Apache error log
sudo tail -50 /var/log/apache2/error.log

# 2. Check PHP configuration
php -i | grep -E "upload_max_filesize|post_max_size"

# 3. Check PHP extensions
php -m | grep -E "mysqli|fileinfo"

# 4. Test PHP syntax
php -l upload_poe_document.php
php -l connection.php

# 5. Disable .htaccess temporarily
mv .htaccess .htaccess_disabled

# 6. Set permissions
chmod 777 uploads/poe_documents/temp

# 7. Check logs after upload attempt
cat poe_minimal.log
```

## What to Send Me

If still not working, send me:
1. Last 20 lines of Apache error log
2. Output of `php -i | grep -E "upload_max_filesize|post_max_size|memory_limit"`
3. Output of `php -m`
4. Contents of `.htaccess` (if it exists)
5. Contents of `poe_minimal.log` after upload attempt
