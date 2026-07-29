# Appendix F 404 Error - Fix Instructions

## Problem Summary
The app is trying to save Appendix F data but getting a 404 error, even though you said you uploaded `save_appendix_f_data.php` to the server.

## Current Situation
- ✅ Code is correct - URL construction is proper
- ✅ File exists locally - `mobile/save_appendix_f_data.php`
- ❌ Server returns 404 - File not found on server

## Expected URL
```
https://rlms.rlms.co.za/mobile/save_appendix_f_data.php
```

---

## STEP 1: Verify Endpoint is Reachable

I've created a diagnostic file. Please:

### Upload These Files to Server:
1. **`mobile/verify_appendix_f_endpoint.php`** - Diagnostic script
2. **`mobile/test_appendix_f_exists.php`** - File existence checker
3. **`mobile/save_appendix_f_data.php`** - The actual endpoint (re-upload to be sure)

### Test in Browser:

**Test 1 - Verification Endpoint:**
```
https://rlms.rlms.co.za/mobile/verify_appendix_f_endpoint.php
```

**Expected Good Response:**
```json
{
  "status": "success",
  "message": "Endpoint is reachable!",
  "save_file_exists": true,
  "save_file_path": "/path/to/mobile/save_appendix_f_data.php",
  "files_in_directory": [
    "save_appendix_f_data.php",
    "save_arpl_toolkit_edits.php",
    ...
  ]
}
```

**If you get 404 here:** The `/mobile/` directory setup is wrong
**If `save_file_exists: false`:** The file isn't uploaded or is in wrong location

---

## STEP 2: Check File Location

### Correct Server Structure:
```
/var/www/html/rlms/
├── mobile/
│   ├── save_appendix_f_data.php          ← MUST BE HERE
│   ├── save_arpl_toolkit_edits.php        ← THIS ONE WORKS (compare location)
│   ├── verify_appendix_f_endpoint.php     ← NEW FILE
│   └── test_appendix_f_exists.php         ← NEW FILE
└── ...
```

### Common Mistakes:
❌ **WRONG:** Uploaded to root directory `/rlms/save_appendix_f_data.php`
❌ **WRONG:** Uploaded to `/rlms/mobile/mobile/save_appendix_f_data.php`
✅ **CORRECT:** Uploaded to `/rlms/mobile/save_appendix_f_data.php`

### How to Check:
1. **Via FTP/File Manager:** Navigate to `/public_html/mobile/` or `/var/www/html/rlms/mobile/`
2. **Verify file exists:** `save_appendix_f_data.php` should be in this directory
3. **Compare with working file:** `save_arpl_toolkit_edits.php` is in same directory

---

## STEP 3: Check File Permissions

### Via SSH:
```bash
# Navigate to directory
cd /var/www/html/rlms/mobile/

# Check permissions
ls -la save_appendix_f_data.php

# Should show: -rw-r--r-- (644)
# If not, fix it:
chmod 644 save_appendix_f_data.php
```

### Via FTP/cPanel:
- Right-click file → Properties/Permissions
- Set to: **644** or **rw-r--r--**
- Owner: Read + Write
- Group: Read
- Public: Read

---

## STEP 4: Test with Curl (Optional)

If you have command line access:

```bash
# Test if endpoint is reachable
curl -X POST https://rlms.rlms.co.za/mobile/save_appendix_f_data.php \
  -H "Content-Type: application/json" \
  -d '{
    "learnerID": 11701,
    "ofoNumber": "641201",
    "assessor_id": 6,
    "knowledge": [],
    "practical": [],
    "workplace_observations": []
  }'
```

**Expected Response:**
```json
{
  "status": "success",
  "message": "All sections saved successfully",
  "details": {...}
}
```

---

## STEP 5: Check .htaccess Rules

### Current .htaccess Analysis:
The simple `.htaccess` file should NOT block this file. However, if you're using `.htaccess_secure`, it might have blocking rules.

### Which .htaccess is Active?
Check which file is named exactly `.htaccess` on the server (not `.htaccess_secure` or `.htaccess_poe_fix`).

### Temporary Test:
1. **Rename** `.htaccess` to `.htaccess_backup`
2. **Test** the endpoint again
3. **If it works:** .htaccess was blocking it
4. **If still fails:** Issue is elsewhere (file location/permissions)

---

## STEP 6: Compare with Working Endpoint

**We know this works:**
```
https://rlms.rlms.co.za/mobile/save_arpl_toolkit_edits.php
```

**This doesn't work:**
```
https://rlms.rlms.co.za/mobile/save_appendix_f_data.php
```

### Comparison Checklist:
- [ ] Both files in same directory? (Check with file manager)
- [ ] Same file permissions? (Both should be 644)
- [ ] Same file owner? (Check with `ls -la`)
- [ ] Can you access both in browser? (Try GET request to both URLs)

---

## STEP 7: Check Apache Error Logs

If you have SSH access:

```bash
# Watch Apache error log in real-time
tail -f /var/log/apache2/error.log

# Or check recent errors
tail -50 /var/log/apache2/error.log
```

Then try to save Appendix F from the app and watch for errors.

---

## Most Likely Solutions

### Solution 1: File Not Uploaded (80% probability)
- **Fix:** Re-upload `save_appendix_f_data.php` to `/mobile/` directory
- **Verify:** Check file exists at exact path where `save_arpl_toolkit_edits.php` exists

### Solution 2: Wrong Directory (15% probability)
- **Fix:** Move file from root or wrong subdirectory to `/mobile/`
- **Verify:** Compare paths with working PHP files

### Solution 3: File Permissions (3% probability)
- **Fix:** `chmod 644 save_appendix_f_data.php`
- **Verify:** File permissions match other working PHP files

### Solution 4: Case Sensitivity (2% probability)
- **Fix:** Ensure filename is exactly `save_appendix_f_data.php` (all lowercase)
- **Verify:** Check exact filename on Linux server (case matters!)

---

## What to Report Back

Please test and tell me:

1. **Verification Test Result:**
   - Does `https://rlms.rlms.co.za/mobile/verify_appendix_f_endpoint.php` work?
   - What does it return?

2. **File Location:**
   - Can you see `save_appendix_f_data.php` in file manager?
   - Is it in the same directory as `save_arpl_toolkit_edits.php`?

3. **Direct Access:**
   - What happens when you open `https://rlms.rlms.co.za/mobile/save_appendix_f_data.php` in browser?
   - Do you get 404, blank page, PHP error, or JSON response?

4. **Comparison:**
   - Does `https://rlms.rlms.co.za/mobile/save_arpl_toolkit_edits.php` still work?
   - Any visible differences between the two files on the server?

---

## Quick Debug Checklist

Run through this quickly:

- [ ] Upload `verify_appendix_f_endpoint.php` to server
- [ ] Access verification URL in browser
- [ ] Check response - does `save_file_exists` = true?
- [ ] If false, re-upload `save_appendix_f_data.php` to correct location
- [ ] Check file is in `/mobile/` directory (same as other working PHP files)
- [ ] Check file permissions (644)
- [ ] Test from app again
- [ ] Report results

---

## If Still Not Working

If all the above checks pass but it still doesn't work, then we need to look at:
- Apache virtual host configuration
- mod_rewrite rules
- PHP configuration issues
- Server-level security policies

But 95% of the time, it's simply the file not being in the right place or not uploaded at all.
