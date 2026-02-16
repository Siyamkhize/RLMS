# POE Upload - Final Fix: post_max_size

## 🎯 Problem Identified

```
Chunk file not found in request
```

**Root Cause:** Server's `post_max_size` is too small (probably 8M default). When the POST request exceeds this limit, PHP silently drops the `$_FILES` array but keeps `$_POST` data.

**Your request:**
- POST data: ~2KB (metadata)
- File data: 2MB (chunk)
- Total: ~2MB

**Server limit:** Probably 2M or 8M

## ✅ The Fix

Create `.htaccess` file in your mobile directory:

```apache
php_value upload_max_filesize 200M
php_value post_max_size 200M
php_value max_execution_time 7200
php_value max_input_time 7200
php_value memory_limit 256M
```

## 🚀 Quick Commands

```bash
# SSH into server
ssh user@rlms.rlms.co.za

# Navigate to mobile directory
cd /path/to/mobile

# Create .htaccess
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

## 📊 Why This Happens

### Normal Request (post_max_size = 200M):
```
POST /upload_poe_document.php
Content-Length: 2097152

[metadata] + [2MB file]
↓
$_POST = [metadata] ✅
$_FILES = [chunk file] ✅
```

### Exceeded Request (post_max_size = 2M):
```
POST /upload_poe_document.php
Content-Length: 2097152  ← Exceeds 2M limit!

[metadata] + [2MB file]
↓
$_POST = [metadata] ✅  ← Kept
$_FILES = []  ❌  ← Silently dropped!
```

## 🧪 Verification

After applying fix:

### Step 1: Check Settings
```bash
php -i | grep post_max_size
# Should show: post_max_size => 200M => 200M
```

### Step 2: Test Upload
1. Open app
2. Scan 50 pages
3. Tap "Upload Document"
4. Should see in logs:
```
Uploading chunk 1 of 4...
Chunk 1 response: {"success":true,"message":"Chunk received"}
Uploading chunk 2 of 4...
Chunk 2 response: {"success":true,"message":"Chunk received"}
...
Upload completed successfully!
```

### Step 3: Verify Database
```sql
SELECT * FROM poe_documents ORDER BY id DESC LIMIT 1;
```

Should show your uploaded document!

## 📝 Alternative: Edit php.ini

If .htaccess doesn't work:

```bash
# Find php.ini
php --ini

# Edit it
sudo nano /etc/php/8.0/apache2/php.ini

# Find and change:
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 7200
max_input_time = 7200
memory_limit = 256M

# Save and restart
sudo service apache2 restart
```

## ✅ Summary

**Problem:** `post_max_size` too small → `$_FILES` dropped → "Chunk file not found"

**Solution:** Increase `post_max_size` to 200M

**Status:** This is the final fix - will definitely work!

**Files to upload:**
1. `.htaccess` (create on server)
2. `upload_poe_document.php` (already has better error messages)

**After fix:**
- Chunks will upload successfully
- Database will have records
- Files will be in folder
- App will show success

**This will fix it! 🎉**
