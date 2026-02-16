# Deploy POE Upload Fix - Quick Checklist

## The Problem
Uploading 50-page POE documents fails with: **"Chunk file not found in request"**

## The Solution
Server's `post_max_size` is too small. Need to increase it to 200M.

## Deployment Steps (5 minutes)

### 1. Upload .htaccess File
```bash
# On your local machine, upload this file to the server:
scp .htaccess_poe_upload user@rlms.rlms.co.za:/path/to/mobile/
```

### 2. Rename the File
```bash
# SSH into server
ssh user@rlms.rlms.co.za

# Navigate to mobile directory
cd /path/to/mobile/

# If .htaccess already exists, backup it first
cp .htaccess .htaccess.backup

# Rename the new file
mv .htaccess_poe_upload .htaccess

# Or if .htaccess exists, append to it:
cat .htaccess_poe_upload >> .htaccess
```

### 3. Restart Apache
```bash
sudo service apache2 restart
# or
sudo systemctl restart apache2
```

### 4. Verify Settings
Visit: `https://rlms.rlms.co.za/mobile/check_php_upload_limits.php`

Should show:
- ✅ upload_max_filesize: 200M
- ✅ post_max_size: 200M
- ✅ max_execution_time: 7200

### 5. Test Upload
1. Open app
2. Go to learner's SDP page
3. Click "Scan POE Document"
4. Scan 50 pages
5. Upload
6. **Should work!** ✅

## If .htaccess Doesn't Work

Edit `php.ini` instead:
```bash
# Find php.ini location
php --ini

# Edit it (requires root)
sudo nano /etc/php/8.1/apache2/php.ini

# Change these values:
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 7200
max_input_time = 7200
memory_limit = 256M

# Save and restart Apache
sudo service apache2 restart
```

## Files to Upload

1. `.htaccess_poe_upload` → Rename to `.htaccess`
2. `check_php_upload_limits.php` → For verification

## Expected Result

### Before Fix:
```
Scan 50 pages → Upload → ❌ "Chunk file not found in request"
```

### After Fix:
```
Scan 50 pages → Upload → ✅ "Document uploaded successfully!"
```

## Why This Works

**Problem**: Server's `post_max_size` = 2M (default)
- App sends 2MB chunk + metadata = ~2.5MB total
- Exceeds 2M limit
- PHP drops `$_FILES` array silently
- Server gets metadata but no file

**Solution**: Increase `post_max_size` to 200M
- App sends 2MB chunk + metadata = ~2.5MB total
- Well under 200M limit
- PHP accepts both `$_FILES` and `$_POST`
- Server gets metadata AND file
- Upload succeeds! ✅

## Troubleshooting

### Still failing?
1. Check Apache error logs: `tail -f /var/log/apache2/error.log`
2. Verify `.htaccess` is in correct directory
3. Check Apache allows `.htaccess` overrides
4. Try `php.ini` approach instead

### Timeout errors?
- Verify `max_execution_time` = 7200
- Check network connection

### "File too large"?
- Verify `upload_max_filesize` = 200M
- Check `memory_limit` = 256M

---

**Priority**: CRITICAL
**Time Required**: 5 minutes
**Impact**: Fixes all POE document uploads
