# POE Upload "Chunk File Not Found" Error - FIXED

## Problem Summary

When uploading the first batch of 50 pages, you get an error: **"Chunk file not found in request"**

## Root Cause

The server's `post_max_size` PHP setting is too small (probably 2M or 8M default). When a POST request exceeds this limit, PHP **silently drops the `$_FILES` array** but keeps the `$_POST` data.

Result:
- ✅ Server receives metadata (learner_id, chunk_index, etc.)
- ❌ Server does NOT receive the actual file chunk
- ❌ Upload fails with "Chunk file not found in request"

## The Fix

### Step 1: Upload .htaccess File

1. Upload the file `.htaccess_poe_upload` to your server at:
   ```
   rlms.rlms.co.za/mobile/
   ```

2. Rename it to `.htaccess` (remove the `_poe_upload` suffix)

3. If you already have a `.htaccess` file on the server:
   - **DON'T replace it**
   - Open your existing `.htaccess` file
   - **ADD** these lines to it:

```apache
# POE Document Upload Configuration
php_value upload_max_filesize 200M
php_value post_max_size 200M
php_value max_execution_time 7200
php_value max_input_time 7200
php_value memory_limit 256M
php_value max_input_vars 5000
php_value default_socket_timeout 7200
```

### Step 2: Restart Apache

SSH into your server and run:
```bash
sudo service apache2 restart
```

Or if using a different web server:
```bash
sudo systemctl restart apache2
```

### Step 3: Verify the Fix

1. Upload `check_php_upload_limits.php` to your server
2. Visit: `https://rlms.rlms.co.za/mobile/check_php_upload_limits.php`
3. Verify these values:
   - ✅ `upload_max_filesize`: 200M
   - ✅ `post_max_size`: 200M
   - ✅ `max_execution_time`: 7200
   - ✅ `memory_limit`: 256M

### Step 4: Test Upload

1. Open the app
2. Go to a learner's SDP page
3. Click "Scan POE Document"
4. Scan 50 pages
5. Click "Upload Document"
6. **Should now work!** ✅

## Why This Happens

### Before Fix:
```
App sends: 2.5MB chunk + metadata
↓
Server's post_max_size = 2M (too small!)
↓
PHP drops $_FILES array (silently!)
↓
Server receives: metadata only, no file
↓
Error: "Chunk file not found in request"
```

### After Fix:
```
App sends: 2.5MB chunk + metadata
↓
Server's post_max_size = 200M (plenty of room!)
↓
PHP accepts both $_FILES and $_POST
↓
Server receives: metadata + file chunk
↓
Success! ✅
```

## Technical Details

### Why post_max_size Matters

The `post_max_size` setting controls the **total size** of the entire POST request, which includes:
- File data (the chunk)
- Form fields (metadata)
- HTTP headers
- Multipart boundaries

If the total exceeds `post_max_size`, PHP silently drops `$_FILES` but keeps `$_POST`.

### Why We Use 2MB Chunks

- Server default `post_max_size` is often 2M or 8M
- We use 2MB chunks to stay under most default limits
- But with metadata + headers, a 2MB chunk becomes ~2.5MB total
- This exceeds the 2M default, causing the error
- Solution: Increase `post_max_size` to 200M

### Why We Need .htaccess

PHP settings can be configured in multiple places:
1. `php.ini` (global, requires root access)
2. `.htaccess` (per-directory, no root needed)
3. `ini_set()` in PHP code (limited, doesn't work for upload limits)

The `.htaccess` approach is best because:
- ✅ No root access needed
- ✅ Only affects your app directory
- ✅ Can be version controlled
- ✅ Works for upload limits (unlike `ini_set()`)

## Alternative: If .htaccess Doesn't Work

If your server doesn't allow `.htaccess` overrides, you'll need to edit `php.ini`:

1. Find your `php.ini` file:
   ```bash
   php --ini
   ```

2. Edit it (requires root):
   ```bash
   sudo nano /etc/php/8.1/apache2/php.ini
   ```

3. Find and change these lines:
   ```ini
   upload_max_filesize = 200M
   post_max_size = 200M
   max_execution_time = 7200
   max_input_time = 7200
   memory_limit = 256M
   ```

4. Restart Apache:
   ```bash
   sudo service apache2 restart
   ```

## Files Involved

- `.htaccess_poe_upload` - Server configuration (rename to `.htaccess`)
- `upload_poe_document.php` - Upload handler (already has 2-hour timeout)
- `lib/poe_document_scanner.dart` - Flutter app (uses 2MB chunks)
- `check_php_upload_limits.php` - Verification tool

## Expected Behavior After Fix

### Small Files (< 3MB):
- Direct upload (single request)
- Fast and simple

### Large Files (> 3MB):
- Chunked upload (2MB chunks)
- Progress indicator shows percentage
- Each chunk uploads successfully
- Final chunk merges all chunks into one PDF
- Database record created
- Success message shown
- Scanner screen closes automatically

## Troubleshooting

### Still Getting "Chunk File Not Found"?

1. Check `.htaccess` is in the correct directory
2. Verify Apache allows `.htaccess` overrides
3. Check Apache error logs: `tail -f /var/log/apache2/error.log`
4. Try the `php.ini` approach instead

### Upload Times Out?

- Check `max_execution_time` is 7200
- Check `default_socket_timeout` is 7200
- Verify network connection is stable

### "File Too Large" Error?

- Check `upload_max_filesize` is 200M
- Check `post_max_size` is 200M
- Check `memory_limit` is 256M

## Success Criteria

✅ Can scan 50-page documents
✅ Can upload without "chunk file not found" error
✅ Progress indicator shows upload progress
✅ Document appears in database
✅ PDF file saved in uploads/poe_documents/
✅ Can scan multiple batches (Part 1, Part 2, etc.)
✅ Scanner doesn't crash on second scan

## Next Steps

After this fix is deployed:
1. Test uploading 50-page document
2. Test uploading 100-page document
3. Test scanning multiple batches (Part 1, Part 2, Part 3)
4. Test merging multiple parts into one PDF (future feature)

---

**Status**: Ready to deploy
**Priority**: CRITICAL - Blocks all POE uploads
**Estimated Fix Time**: 5 minutes
