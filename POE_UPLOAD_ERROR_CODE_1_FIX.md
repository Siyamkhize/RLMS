# POE Upload Error Code 1 - FIXED

## 🐛 Problem

When uploading a 5.67 MB POE document, you get:
```
Upload failed: Exception: Upload failed: Upload error code: 1
```

## 🔍 Root Cause

**PHP Upload Error Code 1** means: **"File exceeds upload_max_filesize directive in php.ini"**

Your server's `upload_max_filesize` is set too low (probably 2M by default), but your file is 5.67 MB.

## ✅ Solution (Choose One)

### Option 1: Use .htaccess (RECOMMENDED - Easiest)

**Step 1:** Create `.htaccess` file in your mobile directory

```bash
cd /path/to/mobile
nano .htaccess
```

**Step 2:** Add these lines:

```apache
php_value upload_max_filesize 200M
php_value post_max_size 200M
php_value max_execution_time 7200
php_value max_input_time 7200
php_value memory_limit 256M
```

**Step 3:** Save and test

```bash
# Save file (Ctrl+O, Enter, Ctrl+X in nano)

# Test upload again from app
```

**Note:** I've created `.htaccess_poe_upload` file for you. Just rename it:
```bash
mv .htaccess_poe_upload .htaccess
```

### Option 2: Edit php.ini (More Permanent)

**Step 1:** Find your php.ini file

```bash
php --ini
# Or
php -i | grep "Loaded Configuration File"
```

Common locations:
- `/etc/php/7.4/apache2/php.ini`
- `/etc/php/8.0/apache2/php.ini`
- `/etc/php/8.1/apache2/php.ini`

**Step 2:** Edit php.ini

```bash
sudo nano /etc/php/8.0/apache2/php.ini
```

**Step 3:** Find and update these lines:

```ini
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 7200
max_input_time = 7200
memory_limit = 256M
```

**Step 4:** Restart web server

```bash
# For Apache
sudo service apache2 restart

# For Nginx with PHP-FPM
sudo service php8.0-fpm restart
sudo service nginx restart
```

**Step 5:** Verify changes

```bash
# Check current settings
php -i | grep upload_max_filesize
php -i | grep post_max_size
```

### Option 3: Quick Test (Temporary)

Visit this URL to check current settings:
```
https://rlms.rlms.co.za/mobile/check_php_upload_limits.php
```

This will show:
- Current upload limits
- What needs to be changed
- Step-by-step instructions

## 🧪 Testing

### Test 1: Check PHP Settings

```bash
# SSH into server
ssh user@rlms.rlms.co.za

# Check current upload limit
php -r "echo ini_get('upload_max_filesize');"

# Should show: 200M (after fix)
```

### Test 2: Upload from App

1. Open app
2. Go to learner details
3. Tap "Scan POE Document"
4. Scan 50 pages
5. Tap "Upload Document"
6. Should upload successfully ✅

### Test 3: Verify Upload

```bash
# Check uploaded files
ls -lh /path/to/mobile/uploads/poe_documents/

# Should see your PDF file
```

## 📊 Understanding Upload Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 0 | Success | No error |
| **1** | **File exceeds upload_max_filesize** | **Increase upload_max_filesize** |
| 2 | File exceeds form MAX_FILE_SIZE | Increase form limit |
| 3 | File partially uploaded | Check network |
| 4 | No file uploaded | Ensure file selected |
| 6 | Missing temp folder | Check server config |
| 7 | Failed to write to disk | Check disk space |
| 8 | PHP extension stopped upload | Check extensions |

## 🎯 Why This Happens

### Default PHP Settings (Too Low):
```ini
upload_max_filesize = 2M    ❌ Too small for POE documents
post_max_size = 8M          ❌ Too small
max_execution_time = 30     ❌ Too short
```

### Required Settings (For POE):
```ini
upload_max_filesize = 200M  ✅ Handles large documents
post_max_size = 200M        ✅ Handles large posts
max_execution_time = 7200   ✅ 2 hours for slow networks
```

## 🔧 Troubleshooting

### Issue 1: .htaccess Not Working

**Symptom:** Added .htaccess but still getting error

**Solution:** Check if AllowOverride is enabled

```bash
# Edit Apache config
sudo nano /etc/apache2/sites-available/000-default.conf

# Add this inside <VirtualHost>:
<Directory /path/to/mobile>
    AllowOverride All
</Directory>

# Restart Apache
sudo service apache2 restart
```

### Issue 2: php.ini Changes Not Applied

**Symptom:** Edited php.ini but settings unchanged

**Solutions:**
1. Make sure you edited the correct php.ini (check with `php --ini`)
2. Restart web server after changes
3. Check for multiple php.ini files (CLI vs Apache)

### Issue 3: Still Getting Error After Fix

**Check:**
1. Verify settings: `php -i | grep upload_max_filesize`
2. Check Apache error log: `tail -f /var/log/apache2/error.log`
3. Ensure file permissions: `chmod 777 uploads/poe_documents`
4. Check disk space: `df -h`

## 📱 App-Side Workaround

If you can't change server settings immediately, use chunked upload for smaller files:

The app already has chunked upload for files > 50MB, but we can lower the threshold:

```dart
// In lib/poe_document_scanner.dart
// Change this line:
const chunkThreshold = 50 * 1024 * 1024; // 50MB

// To this:
const chunkThreshold = 2 * 1024 * 1024; // 2MB
```

This will split your 5.67 MB file into 2MB chunks, bypassing the upload limit.

## ✅ Quick Fix Commands

```bash
# SSH into server
ssh user@rlms.rlms.co.za

# Navigate to mobile directory
cd /path/to/mobile

# Create .htaccess file
cat > .htaccess << 'EOF'
php_value upload_max_filesize 200M
php_value post_max_size 200M
php_value max_execution_time 7200
php_value max_input_time 7200
php_value memory_limit 256M
EOF

# Restart Apache
sudo service apache2 restart

# Test
curl https://rlms.rlms.co.za/mobile/check_php_upload_limits.php
```

## 📞 If Still Not Working

1. **Check server logs:**
   ```bash
   tail -f /var/log/apache2/error.log
   ```

2. **Test with small file first:**
   - Try uploading a 1MB PDF
   - If works, gradually increase size

3. **Contact hosting provider:**
   - Some hosts restrict php_value in .htaccess
   - May need to request increase through control panel

4. **Use chunked upload:**
   - Lower chunk threshold in app
   - Splits file into smaller pieces

## 🎉 Success Indicators

After applying fix, you should see:

1. **In check_php_upload_limits.php:**
   ```
   upload_max_filesize: 200M ✅ OK
   post_max_size: 200M ✅ OK
   ```

2. **In app:**
   ```
   Upload successful!
   Document uploaded successfully!
   ```

3. **On server:**
   ```bash
   ls -lh uploads/poe_documents/
   # Shows your uploaded PDF
   ```

## 📝 Summary

**Problem:** Upload error code 1 (file too large)

**Cause:** Server's upload_max_filesize is 2M, but file is 5.67 MB

**Solution:** Increase upload_max_filesize to 200M using .htaccess or php.ini

**Status:** Fix ready - just apply .htaccess file!

**Files Created:**
- `check_php_upload_limits.php` - Diagnostic tool
- `.htaccess_poe_upload` - Ready-to-use .htaccess file

**Next Steps:**
1. Rename `.htaccess_poe_upload` to `.htaccess`
2. Upload to server
3. Test upload from app
4. Should work! ✅
