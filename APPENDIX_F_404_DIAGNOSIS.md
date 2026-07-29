# Appendix F 404 Error - Diagnostic Steps

## Problem
Getting 404 error when trying to save Appendix F data:
```
[DEBUG] Response status: 404
[DEBUG] Response body: <!DOCTYPE HTML...>404 Not Found</...>
```

## Expected URL
Based on code analysis:
- **App Config baseUrl**: `https://rlms.rlms.co.za/mobile`
- **Appendix F URL**: `https://rlms.rlms.co.za/mobile/save_appendix_f_data.php`

## Files Created for Diagnosis

### 1. Test Script: `mobile/test_appendix_f_exists.php`
This diagnostic script will tell you:
- Current directory path
- Whether `save_appendix_f_data.php` exists
- Whether it's readable
- What other `save*.php` files exist in the directory

### How to Test:
1. **Upload `mobile/test_appendix_f_exists.php` to server**
2. **Access it via browser**: `https://rlms.rlms.co.za/mobile/test_appendix_f_exists.php`
3. **Check the JSON response**

Expected good response:
```json
{
  "current_directory": "/path/to/rlms/mobile",
  "save_appendix_f_exists": true,
  "save_appendix_f_readable": true,
  "directory_contents": [
    "save_appendix_f_data.php",
    "save_arpl_toolkit_edits.php",
    ...
  ]
}
```

## Possible Causes & Solutions

### Cause 1: File Not Uploaded to Server
**Symptoms**: `save_appendix_f_exists: false`
**Solution**: Upload `mobile/save_appendix_f_data.php` to the server

### Cause 2: Wrong Directory
**Symptoms**: Test script works but actual endpoint doesn't
**Solution**: Check if file is in `/mobile/` directory, not root directory

### Cause 3: File Permissions
**Symptoms**: `save_appendix_f_readable: false`
**Solution**: SSH to server and run:
```bash
chmod 644 /path/to/rlms/mobile/save_appendix_f_data.php
```

### Cause 4: .htaccess Blocking
**Symptoms**: Test script works, but POST request returns 404
**Solution**: Check which `.htaccess` file is active on server:
- Is it `.htaccess` (simple version - should work)
- Is it `.htaccess_secure` (complex version - might have blocking rules)

### Cause 5: Apache Rewrite Rules
**Symptoms**: 404 with HTML error page
**Solution**: Check Apache error logs on server:
```bash
tail -f /var/log/apache2/error.log
```

### Cause 6: Case Sensitivity
**Symptoms**: Works locally but not on server
**Solution**: Linux servers are case-sensitive. Verify exact filename:
- Local: `save_appendix_f_data.php`
- Server: must be EXACTLY `save_appendix_f_data.php` (all lowercase)

## Quick Fix Checklist

1. ✅ **Upload test script** `mobile/test_appendix_f_exists.php`
2. ✅ **Access test URL** and check JSON response
3. ✅ **Verify file exists** on server in `/mobile/` directory
4. ✅ **Check file permissions** (should be 644 or 755)
5. ✅ **Check .htaccess** - use simple version, not secure version for testing
6. ✅ **Test with curl** from terminal:
   ```bash
   curl -X POST https://rlms.rlms.co.za/mobile/save_appendix_f_data.php \
     -H "Content-Type: application/json" \
     -d '{"learnerID": 11701, "ofoNumber": "641201"}'
   ```
7. ✅ **Check Apache logs** if still failing

## What to Report Back

Please test and report:
1. What does `test_appendix_f_exists.php` return?
2. Does `save_arpl_toolkit_edits.php` work? (We know it does)
3. What's different about the two files/URLs?
4. Which `.htaccess` file is currently active on server?

## Next Steps Based on Findings

- **If file doesn't exist**: Upload it
- **If file exists but not readable**: Fix permissions
- **If permissions OK**: Check .htaccess rules
- **If .htaccess OK**: Check Apache configuration
- **If all OK**: There might be a typo in filename on server
