# POE Upload - Fixed! (Almost There)

## Problem Solved
✅ The `.htaccess` file was causing 500 errors - now disabled
✅ PHP scripts are working
✅ Database table exists with correct structure
✅ Getting proper JSON error responses

## Current Issue
❌ "Chunk file not found" error

The PHP script is looking for `$_FILES['chunk']` but not finding it.

## Root Cause
The chunk file is not being received by the PHP script. This could be because:
1. The multipart form data isn't being sent correctly
2. The field name doesn't match
3. The chunk size exceeds PHP limits

## Check the Log
On the server, check this file:
```
/path/to/mobile/poe_upload_safe.log
```

It will show exactly what POST data and FILES data the server is receiving.

## Quick Fix - Check What's Being Received

The `upload_poe_document_safe.php` logs everything. Check the log to see:
- What POST keys are being sent
- What FILES keys are being sent
- The exact error message

## Expected POST Data
```
chunk_index: 0
total_chunks: 4
file_id: 1766479931341
learner_id: TEST001
learner_name: Test User
document_type: POE
page_count: 10
file_extension: pdf
```

## Expected FILES Data
```
chunk: [binary data]
```

## If Chunk is Missing
The issue is that the HTTP request isn't including the file properly. This could be:
1. **Content-Type header** - Must be `multipart/form-data`
2. **Chunk size too large** - Even though we set limits, the web server might have its own limits
3. **Request timeout** - The chunk upload is timing out before completing

## Solution: Check Server Logs

1. **Check upload log:**
   ```bash
   cat /path/to/mobile/poe_upload_safe.log
   ```

2. **Check Apache error log:**
   ```bash
   tail -50 /var/log/apache2/error.log
   ```

3. **Check PHP error log:**
   ```bash
   tail -50 /var/log/php_errors.log
   ```

## What the Log Should Show

**Success:**
```
2025-12-23 10:52:11 === Upload started ===
2025-12-23 10:52:11 Including connection.php
2025-12-23 10:52:11 Database connected
2025-12-23 10:52:11 Table exists
2025-12-23 10:52:11 Upload directory ready
2025-12-23 10:52:11 Is chunked: yes
2025-12-23 10:52:11 Chunk 0 of 4, ID: 1766479931341
2025-12-23 10:52:11 Chunk file valid, size: 2097152
```

**Current (Failure):**
```
2025-12-23 10:52:11 === Upload started ===
2025-12-23 10:52:11 Including connection.php
2025-12-23 10:52:11 Database connected
2025-12-23 10:52:11 Table exists
2025-12-23 10:52:11 Upload directory ready
2025-12-23 10:52:11 Is chunked: yes
2025-12-23 10:52:11 Chunk 0 of 4, ID: 1766479931341
2025-12-23 10:52:11 ERROR: Chunk file not found in request
```

This tells us the POST data is being received but the FILES data is not.

## Possible Causes

### 1. Web Server Upload Limit
Even though we set PHP limits, Apache/Nginx might have its own limits.

**For Apache**, check `/etc/apache2/apache2.conf`:
```apache
LimitRequestBody 209715200  # 200MB in bytes
```

**For Nginx**, check `/etc/nginx/nginx.conf`:
```nginx
client_max_body_size 200M;
```

### 2. PHP-FPM Limits (if using PHP-FPM)
Check `/etc/php/7.4/fpm/php.ini`:
```ini
upload_max_filesize = 200M
post_max_size = 200M
```

Then restart PHP-FPM:
```bash
sudo service php7.4-fpm restart
```

### 3. Request Timeout
The chunk upload might be timing out. Check Apache timeout:
```apache
Timeout 7200
```

## Next Steps

1. **Check the log file** - This will tell us exactly what's being received
2. **Verify chunk is being sent** - The Flutter app logs show it's sending, but is it arriving?
3. **Check web server limits** - Apache/Nginx might be blocking large uploads
4. **Test with smaller chunk** - Try reducing chunk size to 1MB to see if it works

## Test with Smaller Chunks

If the issue is chunk size, we can reduce it in the Flutter app. The current chunk size is 2MB. Try 1MB or 512KB.

## Files Deployed
- ✅ `upload_poe_document_safe.php` - With detailed logging
- ✅ `poe_documents` table - Created and verified
- ✅ `.htaccess` - Disabled (was causing 500 errors)
- ✅ PHP limits - Increased via MultiPHP INI

## What to Send Me
To help debug further, send me:
1. Contents of `/path/to/mobile/poe_upload_safe.log`
2. Last 20 lines of Apache error log
3. Output of `php -i | grep upload_max_filesize`
4. Output of `php -i | grep post_max_size`

This will tell us exactly where the chunk is getting lost!
