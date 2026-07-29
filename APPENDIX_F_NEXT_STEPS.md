# Appendix F 404 - Next Diagnostic Steps

## ✅ What We Confirmed
From your diagnostic test results:
- ✅ File `save_appendix_f_data.php` EXISTS on server
- ✅ File is READABLE (permissions OK)
- ✅ File is in CORRECT directory: `/home/rlmsrlmsco/public_html/mobile/`

## ❌ The Mystery
If the file exists and is readable, why does the app get 404?

## 🔍 Possible Causes

### 1. Apache/Web Server Can't Execute the File
- File exists but has PHP syntax errors
- File requires `connection.php` which is blocked or missing
- .htaccess is blocking execution

### 2. URL Mismatch
- App is calling slightly different URL
- Server is case-sensitive and there's a typo
- Rewrite rules are interfering

### 3. CORS or HTTP Method Issue
- Server blocks POST requests to this specific file
- CORS headers missing

---

## 📋 NEXT STEPS - Please Do These Tests

### TEST 1: Upload New Diagnostic Files
Upload these 3 new files to `/mobile/` directory:
1. ✅ `mobile/test_simple_post.php` - Simple POST test
2. ✅ `mobile/check_connection_file.php` - Check connection.php
3. ✅ `mobile/test_appendix_f_post.php` - Test actual endpoint

### TEST 2: Test Simple POST Endpoint in Browser
Open this URL:
```
https://rlms.rlms.co.za/mobile/test_simple_post.php
```

**Expected Response:**
```json
{
  "status": "success",
  "message": "POST request received successfully!",
  "method": "GET",
  "this_file": "test_simple_post.php"
}
```

### TEST 3: Test Connection Check
Open this URL:
```
https://rlms.rlms.co.za/mobile/check_connection_file.php
```

This will tell us:
- Does `connection.php` exist?
- Can `save_appendix_f_data.php` be included/executed?
- What error occurs if any?

### TEST 4: Direct File Access
Try to access the actual file directly in browser:
```
https://rlms.rlms.co.za/mobile/save_appendix_f_data.php
```

**What to look for:**
- ❌ **404 Page** = Server can't find file (Apache config issue)
- ❌ **Blank page** = PHP fatal error (check connection.php)
- ❌ **PHP error message** = Code issue
- ✅ **JSON error** like `{"status":"error","message":"Invalid JSON input"}` = File works! Issue is elsewhere

### TEST 5: Check .htaccess
Look at your active `.htaccess` file in `/mobile/` directory.

**Does it exist?**
- If YES → Temporarily rename it to `.htaccess_backup`
- Test the app again
- If it works → .htaccess was blocking

**Does `/public_html/.htaccess` exist?** (parent directory)
- Check if it has rules that affect `/mobile/` subdirectory

---

## 🎯 Most Likely Issues

### Issue A: connection.php Missing or Blocked (60% probability)
`save_appendix_f_data.php` requires `connection.php` at line 6:
```php
require_once 'connection.php';
```

**If this file is missing or blocked:**
- PHP will throw fatal error
- Web server returns 404 (some servers do this for fatal errors)

**Solution:** Check if `connection.php` exists in `/mobile/` directory

### Issue B: .htaccess Blocking (25% probability)
Some .htaccess rules can block specific files or patterns.

**Solution:** Temporarily disable .htaccess and test

### Issue C: PHP Syntax Error (10% probability)
If there's a syntax error, some servers return 404 instead of 500.

**Solution:** TEST 3 will show this

### Issue D: CORS/Headers Issue (5% probability)
Server blocks POST from app but allows GET from browser.

**Solution:** Check Apache error logs

---

## 📞 What to Report Back

After running the tests above, please tell me:

1. **TEST 2 Result (test_simple_post.php):**
   - Does it work in browser? YES/NO
   - What does it return? (copy/paste JSON)

2. **TEST 3 Result (check_connection_file.php):**
   - Does `connection_php_exists` = true or false?
   - What does `save_file_test` say? (SUCCESS, ERROR, or FATAL_ERROR)
   - If error, what's the `save_file_error` message?

3. **TEST 4 Result (direct file access):**
   - What happens when you open `save_appendix_f_data.php` in browser?
   - 404 page, blank page, PHP error, or JSON error?

4. **.htaccess Check:**
   - Does `.htaccess` exist in `/mobile/` directory? YES/NO
   - If you rename it and test app, does it work? YES/NO

---

## 🔧 Quick Fix Attempts

While we diagnose, try these quick fixes:

### Fix 1: Check connection.php
Make sure `connection.php` exists in `/mobile/` directory. If not, copy it from parent directory:
```bash
cp /home/rlmsrlmsco/public_html/connection.php /home/rlmsrlmsco/public_html/mobile/
```

### Fix 2: Add CORS Headers
Edit `save_appendix_f_data.php` - add these lines at the TOP (after `<?php`):
```php
<?php
// ADD THESE LINES
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}
// END NEW LINES

// Rest of existing code...
header('Content-Type: application/json');
require_once 'connection.php';
...
```

### Fix 3: Check File Permissions
Via SSH, make absolutely sure:
```bash
cd /home/rlmsrlmsco/public_html/mobile
ls -la save_appendix_f_data.php
# Should show: -rw-r--r-- or -rwxr-xr-x

# If not, fix it:
chmod 644 save_appendix_f_data.php
```

---

## 💡 The Bottom Line

The file EXISTS on the server, so the 404 means:
1. **Server can't execute it** (missing dependency, syntax error, or permission)
2. **Server is blocking it** (.htaccess or Apache config)
3. **There's a URL rewrite** changing the path

The diagnostic tests will pinpoint which one it is!
