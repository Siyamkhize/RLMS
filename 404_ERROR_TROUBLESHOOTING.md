# 404 Error Troubleshooting Guide

## Problem
Your app shows: "Not Found - The requested URL was not found on this server"

This means the PHP file your app is trying to access doesn't exist or can't be found.

---

## Your Current Configuration

From `lib/config.dart`:
```dart
Server: http://192.168.68.125:8080
Base Path: /assessorReport2/mobile
```

**Full URL Example**: `http://192.168.68.125:8080/assessorReport2/mobile/login.php`

---

## Step 1: Verify Server is Running

### Check if Server is Accessible

1. Open your web browser
2. Go to: `http://192.168.68.125:8080`
3. You should see:
   - ✅ A webpage (server is running)
   - ❌ "Can't reach this page" (server is down)

### If Server is Down:

**For XAMPP**:
```
1. Open XAMPP Control Panel
2. Start Apache
3. Check port 8080 is not blocked
4. Try again
```

**For WAMP**:
```
1. Open WAMP Manager
2. Start All Services
3. Check port 8080 is available
4. Try again
```

---

## Step 2: Verify PHP Files Exist

### Check File Location

Your PHP files should be at:
```
C:\xampp\htdocs\assessorReport2\mobile\
```

Or for WAMP:
```
C:\wamp64\www\assessorReport2\mobile\
```

### Required Files

Check these files exist:
- ✅ `login.php`
- ✅ `sync_fingerprint.php` (in `php/` folder)
- ✅ `get_attendance.php`
- ✅ `clockin.php` (in `clocking/` folder)
- ✅ `clockout.php` (in `clocking/` folder)

### How to Check:

1. Open File Explorer
2. Navigate to your web server folder
3. Go to `assessorReport2/mobile/`
4. Verify files are there

---

## Step 3: Test Specific Endpoint

### Test Login Endpoint

Open browser and go to:
```
http://192.168.68.125:8080/assessorReport2/mobile/login.php
```

**Expected Results**:
- ✅ Shows PHP code or JSON response (file exists)
- ❌ "404 Not Found" (file doesn't exist)

### Test Fingerprint Sync Endpoint

```
http://192.168.68.125:8080/assessorReport2/mobile/php/sync_fingerprint.php
```

**Expected Results**:
- ✅ Shows error message or JSON (file exists)
- ❌ "404 Not Found" (file doesn't exist)

---

## Step 4: Common 404 Causes

### Cause 1: Wrong Base Path

**Problem**: Path in config doesn't match actual folder structure

**Check**:
```
Config says: /assessorReport2/mobile
Actual folder: /assessorReport/mobile (missing '2')
```

**Fix**: Update `lib/config.dart` line 17:
```dart
static const String basePath = '/assessorReport/mobile'; // Remove '2' if needed
```

---

### Cause 2: Files in Wrong Location

**Problem**: PHP files are in root, not in `mobile/` folder

**Check**:
```
Wrong: C:\xampp\htdocs\login.php
Right: C:\xampp\htdocs\assessorReport2\mobile\login.php
```

**Fix**: Move all PHP files to correct folder

---

### Cause 3: Missing Subfolders

**Problem**: Some endpoints use subfolders that don't exist

**Required Folder Structure**:
```
assessorReport2/
├── mobile/
│   ├── login.php
│   ├── get_attendance.php
│   ├── php/
│   │   └── sync_fingerprint.php
│   ├── clocking/
│   │   ├── clockin.php
│   │   └── clockout.php
│   └── ... other files
```

**Fix**: Create missing folders and move files

---

### Cause 4: Case Sensitivity

**Problem**: Linux servers are case-sensitive

**Check**:
```
Config: /assessorReport2/mobile/Login.php (capital L)
Actual: /assessorReport2/mobile/login.php (lowercase l)
```

**Fix**: Make sure case matches exactly

---

## Step 5: Quick Diagnostic Test

### Create Test File

1. Create file: `C:\xampp\htdocs\assessorReport2\mobile\test.php`
2. Add this code:
```php
<?php
echo json_encode([
    'success' => true,
    'message' => 'Server is working!',
    'timestamp' => date('Y-m-d H:i:s')
]);
?>
```

3. Open browser: `http://192.168.68.125:8080/assessorReport2/mobile/test.php`

**Expected Result**:
```json
{"success":true,"message":"Server is working!","timestamp":"2024-02-24 10:30:00"}
```

**If this works**: Server is fine, other files are missing
**If this fails**: Server configuration issue

---

## Step 6: Check Apache Configuration

### Verify Port 8080

1. Open XAMPP Control Panel
2. Click "Config" next to Apache
3. Select "httpd.conf"
4. Find line: `Listen 8080`
5. Make sure it says 8080, not 80

### Verify Document Root

In same file, find:
```apache
DocumentRoot "C:/xampp/htdocs"
<Directory "C:/xampp/htdocs">
```

Make sure path is correct for your system.

---

## Step 7: Check .htaccess Files

### Problem: .htaccess Blocking Access

Check if you have `.htaccess` files that might be blocking access:

**Location**: `C:\xampp\htdocs\assessorReport2\mobile\.htaccess`

**If it exists**, check for:
```apache
# Bad - blocks everything
Deny from all

# Good - allows access
Allow from all
```

**Fix**: Remove or rename `.htaccess` temporarily to test

---

## Step 8: Enable Apache Error Logs

### Find Error Details

1. Open XAMPP Control Panel
2. Click "Logs" next to Apache
3. Select "Error Log"
4. Look for 404 errors with file paths
5. This will show exactly which file is missing

**Example Error**:
```
[error] File does not exist: C:/xampp/htdocs/assessorReport2/mobile/sync_fingerprint.php
```

This tells you exactly what's wrong!

---

## Step 9: Verify Fingerprint Sync Specifically

Since you mentioned both scanners are working, you might be trying to sync fingerprints to server.

### Check Fingerprint Sync File

**File**: `php/sync_fingerprint.php`
**Full Path**: `C:\xampp\htdocs\assessorReport2\mobile\php\sync_fingerprint.php`

**Test URL**: `http://192.168.68.125:8080/assessorReport2/mobile/php/sync_fingerprint.php`

### If File is Missing:

I can see the file exists in your project. You need to copy it to your server:

**From**: Your project folder `php/sync_fingerprint.php`
**To**: `C:\xampp\htdocs\assessorReport2\mobile\php\sync_fingerprint.php`

---

## Step 10: Common Solutions

### Solution 1: Copy All PHP Files

```
1. Go to your project folder
2. Find all .php files
3. Copy them to: C:\xampp\htdocs\assessorReport2\mobile\
4. Maintain folder structure (php/, clocking/, etc.)
5. Restart Apache
6. Test again
```

### Solution 2: Update Config Path

If your files are in a different location:

**Edit**: `lib/config.dart` line 17
```dart
// Change from:
static const String basePath = '/assessorReport2/mobile';

// To your actual path:
static const String basePath = '/your_actual_path/mobile';
```

Then rebuild app:
```bash
flutter clean
flutter pub get
flutter run
```

### Solution 3: Use Different Port

If port 8080 is blocked:

**Edit**: `lib/config.dart` line 16
```dart
// Change from:
static const int serverPort = 8080;

// To:
static const int serverPort = 80; // Standard HTTP port
```

Then rebuild app.

---

## Quick Checklist

Before asking for more help, verify:

- [ ] Server is running (XAMPP/WAMP started)
- [ ] Can access `http://192.168.68.125:8080` in browser
- [ ] PHP files exist in correct folder
- [ ] Folder structure matches config
- [ ] Port 8080 is not blocked by firewall
- [ ] Apache error log checked for details
- [ ] Test file works (Step 5)

---

## What to Tell Me

If still not working, tell me:

1. **What were you doing when error occurred?**
   - Syncing fingerprints?
   - Logging in?
   - Clocking in/out?
   - Other feature?

2. **What does browser show?**
   - Test URL: `http://192.168.68.125:8080/assessorReport2/mobile/test.php`
   - Result: (paste what you see)

3. **What's in Apache error log?**
   - Last few lines showing 404 errors

4. **Where are your PHP files?**
   - Full path: (e.g., C:\xampp\htdocs\...)

With this info, I can give you exact fix!

---

## Most Likely Cause

Based on your setup, the most likely issue is:

**PHP files are not copied to your web server folder**

**Quick Fix**:
```
1. Copy all .php files from your project
2. Paste to: C:\xampp\htdocs\assessorReport2\mobile\
3. Keep folder structure (php/, clocking/, etc.)
4. Restart Apache
5. Test: http://192.168.68.125:8080/assessorReport2/mobile/test.php
```

This should fix the 404 error!

---

## Scanner Status (Confirmed Working)

Your scanners are working fine:
- ✅ ZKTeco: Working
- ✅ Futronic: Working
- ✅ Dual mode: Supported

The 404 error is only about server files, not scanners.
