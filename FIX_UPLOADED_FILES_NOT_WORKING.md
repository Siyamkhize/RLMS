# 🔧 FIX: Uploaded Files Not Working on Production
**Date:** July 22, 2026  
**Problem:** Files work locally but show "nothing" on production server

---

## 🎯 YOUR SITUATION

### What Happened:
- ✅ You uploaded `verify_qualification_ofo_mapping.php` to production
- ✅ File works perfectly on local computer
- ❌ File shows "nothing" when accessed on production server at:
  ```
  https://rlms.rlms.co.za/verify_qualification_ofo_mapping.php
  ```

### Possible Causes:
1. **File uploaded to wrong location**
2. **File permissions incorrect** (PHP can't execute it)
3. **PHP errors are hidden** (script crashes silently)
4. **Database connection failing** on production
5. **Syntax error** in PHP code

---

## 🛠️ SOLUTION: Step-by-Step Fix

### STEP 1: Upload Simple Test Script (2 minutes)

I've created a simpler test script to diagnose the issue.

**Upload this file:**
```
test_connection_simple.php
```

**To:** Root folder (same location as `verify_qualification_ofo_mapping.php`)

**Then open:**
```
https://rlms.rlms.co.za/test_connection_simple.php
```

**What You Should See:**

✅ **If Working Correctly:**
```
PHP is working!
PHP Version: 7.4.x (or 8.x)

✅ connection.php file found
✅ connection.php included successfully

✅ Database connection exists
✅ Connected to database: your_database_name

Checking Tables:
✅ Table exists: unitstandard
✅ Table exists: arplbricklayer_access_recommendation
...

Checking Data:
✅ Bricklayer/Plumber unit standards (qual 65409): 35 records
✅ Electrician unit standards (qual 91761): 22 records

✅ Test Complete
```

❌ **If Still Shows Nothing:**
- File not uploaded correctly
- PHP not working on server
- Try STEP 2

---

### STEP 2: Check File Location and Permissions

#### A. Verify File Location

Using cPanel File Manager or FTP:

1. **Navigate to your website root folder**
   - Usually: `/public_html/` or `/www/`

2. **Check these files exist:**
   - ✅ `connection.php` (should already exist)
   - ✅ `test_connection_simple.php` (you just uploaded)
   - ✅ `verify_qualification_ofo_mapping.php` (you uploaded earlier)

3. **If files are missing:**
   - Re-upload them to the correct folder

#### B. Check File Permissions

In cPanel File Manager:

1. **Right-click each file** → Select "Change Permissions"

2. **Set permissions to:** `644` or `755`
   - Owner: Read + Write
   - Group: Read
   - Public: Read

3. **Click "Change Permissions"**

---

### STEP 3: Check PHP Error Logs

#### In cPanel:

1. **Find "Error Log" or "Logs"** in cPanel

2. **Open error_log file**

3. **Look for recent errors** mentioning:
   - `verify_qualification_ofo_mapping.php`
   - `test_connection_simple.php`
   - Database connection errors
   - PHP syntax errors

4. **Share any errors you find** so I can help fix them

---

### STEP 4: Test Database Connection Separately

Create a very simple test file:

**Create file:** `test_db.php`

```php
<?php
echo "PHP works!<br>";

if (file_exists('connection.php')) {
    echo "connection.php found<br>";
    include('connection.php');
    
    if ($conn) {
        echo "Database connected!<br>";
        $result = $conn->query("SELECT COUNT(*) as cnt FROM unitstandard WHERE qualification_id = 65409");
        if ($result) {
            $row = $result->fetch_assoc();
            echo "Bricklayer/Plumber records: " . $row['cnt'];
        }
    } else {
        echo "Database NOT connected!";
    }
} else {
    echo "connection.php NOT found!";
}
?>
```

Upload and test: `https://rlms.rlms.co.za/test_db.php`

---

### STEP 5: Re-Upload Fixed Verification Script

I've updated `verify_qualification_ofo_mapping.php` with:
- ✅ Error reporting enabled
- ✅ Better error messages
- ✅ Connection checks

**Re-upload the updated file** from:
```
c:\projects\rlmss\verify_qualification_ofo_mapping.php
```

**Then test again:**
```
https://rlms.rlms.co.za/verify_qualification_ofo_mapping.php
```

---

## 🔍 COMMON PROBLEMS & SOLUTIONS

### Problem 1: "Nothing" Shows - Blank Page

**Cause:** PHP errors are hidden

**Solution:**
1. Upload `test_connection_simple.php`
2. Check if that works
3. If not, check error logs
4. Enable error display in PHP

---

### Problem 2: "connection.php not found"

**Cause:** File uploaded to wrong location

**Solution:**
1. Find where your existing PHP files are
2. Look for `connection.php` in that folder
3. Upload new files to SAME folder
4. Your `mobile` folder should be inside that folder

---

### Problem 3: "Database connection failed"

**Cause:** Production database credentials different from local

**Solution:**
1. Check your production `connection.php` has correct:
   - Database host
   - Database name
   - Username
   - Password
2. Don't overwrite production `connection.php`!

---

### Problem 4: "Access Denied" or Permission Error

**Cause:** File permissions too restrictive

**Solution:**
1. Change file permissions to `644` or `755`
2. Check folder permissions are `755`

---

### Problem 5: "Call to undefined function"

**Cause:** Missing PHP extensions

**Solution:**
1. Check PHP version: should be 7.4 or 8.x
2. Enable mysqli extension in PHP settings
3. Contact hosting support if needed

---

## 📋 DIAGNOSTIC CHECKLIST

Work through this checklist:

- [ ] **Step 1:** Upload `test_connection_simple.php`
- [ ] **Step 2:** Open test script URL in browser
- [ ] **Step 3:** See if it displays anything
- [ ] **Step 4:** Check file permissions (644 or 755)
- [ ] **Step 5:** Check error logs for PHP errors
- [ ] **Step 6:** Re-upload updated `verify_qualification_ofo_mapping.php`
- [ ] **Step 7:** Test again

---

## 🆘 WHAT TO SHARE

If still not working, share this info:

### 1. What You See:
```
When I open: https://rlms.rlms.co.za/test_connection_simple.php
I see: [COPY/PASTE EXACTLY WHAT YOU SEE]
```

### 2. File Location:
```
Files uploaded to: [FOLDER PATH]
connection.php exists: [YES/NO]
File permissions: [PERMISSION NUMBER]
```

### 3. Hosting Details:
```
Hosting provider: [NAME]
PHP version: [VERSION from cPanel]
Control panel: [cPanel / Plesk / Other]
```

### 4. Error Logs:
```
Recent errors from error_log:
[COPY/PASTE ANY ERRORS]
```

---

## ✅ SUCCESS INDICATORS

### Test Script Working:
- Shows "PHP is working!"
- Shows "✅ Database connection exists"
- Shows table counts
- Shows unit standard counts

### Verification Script Working:
- Shows HTML page with tables
- Shows Bricklayer/Plumber: 35 records
- Shows Electrician: X records
- Shows trade configuration summary

---

## 🎯 NEXT STEPS AFTER FIXING

Once test script works:

1. ✅ Upload all 4 gap closure PHP files to `/mobile/`
2. ✅ Run SQL scripts to create tables
3. ✅ Test endpoints
4. ✅ Proceed with deployment

**But first:** Get the test script working so we know the basic setup is correct!

---

## 💡 QUICK TIPS

### Uploading Files via cPanel:

1. **Log into cPanel**
2. **Click "File Manager"**
3. **Navigate to your website root** (usually `public_html`)
4. **Click "Upload" button at top**
5. **Select file from computer**
6. **Wait for upload to complete**
7. **Check file appears in file list**
8. **Right-click → Permissions → Set to 644**
9. **Test URL in browser**

### Uploading Files via FTP:

1. **Connect with FTP client** (FileZilla, WinSCP)
2. **Navigate to website root on server side** (right panel)
3. **Navigate to local files on computer side** (left panel)
4. **Drag file from left to right**
5. **Wait for transfer to complete**
6. **Right-click → File Permissions → 644**
7. **Test URL in browser**

---

**Start here:** Upload `test_connection_simple.php` and tell me what you see!

This will help us diagnose why the uploaded files aren't working on your production server.
