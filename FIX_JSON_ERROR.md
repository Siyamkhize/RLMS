# 🔧 Fix: "Unexpected end of JSON input" Error

## Current Error
```
❌ Export failed: SyntaxError: Failed to execute 'json' on 'Response': 
Unexpected end of JSON input
```

## What This Means
The API is returning an incomplete or empty response, likely due to a PHP error occurring before the JSON is sent.

## Quick Fix Steps

### Step 1: Run Debug Script
Upload and visit: `debug_bulk_export.php`

This will show you:
- ✅ Which files are missing
- ✅ Which directories need permissions
- ✅ What PHP errors are occurring
- ✅ If database connection works

### Step 2: Check Error Log
Look at the file: `bulk_export_errors.log`

This will contain the actual PHP error that's causing the problem.

### Step 3: Common Issues & Fixes

#### Issue 1: temp_reports Directory Missing
**Error**: "Failed to create temp directory"

**Fix**:
```bash
mkdir temp_reports
chmod 755 temp_reports
```

Or via cPanel:
- Create folder: `temp_reports`
- Set permissions: 755

#### Issue 2: ZipArchive Not Available
**Error**: "ZipArchive class not available"

**Fix**: Install PHP zip extension
```bash
# On Ubuntu/Debian
sudo apt-get install php-zip

# On CentOS/RHEL
sudo yum install php-zip

# Then restart Apache/PHP-FPM
sudo service apache2 restart
```

Or contact your hosting provider to enable the zip extension.

#### Issue 3: Database Connection Failed
**Error**: "Database connection failed"

**Fix**: Check `connection.php` file exists and has correct credentials

#### Issue 4: Memory Limit
**Error**: "Allowed memory size exhausted"

**Fix**: Increase PHP memory limit in php.ini or .htaccess:
```
php_value memory_limit 512M
```

#### Issue 5: Execution Timeout
**Error**: "Maximum execution time exceeded"

**Fix**: Increase timeout in .htaccess:
```
php_value max_execution_time 600
```

### Step 4: Test with Small Batch
After fixing issues:
1. Filter to just 2-3 learners
2. Try bulk download
3. Check if it works
4. Gradually increase batch size

### Step 5: Check Browser Console
Open browser developer tools (F12) and check:
- Network tab → Click on bulk_export_api.php request
- Look at Response tab
- See what the actual response is (might show PHP error)

## Diagnostic Commands

### Check if files uploaded:
```bash
ls -la bulk_export_api.php
ls -la bulk_export_with_documents.php
ls -la get_learner_documents.php
```

### Check directory permissions:
```bash
ls -la temp_reports/
chmod 755 temp_reports/
```

### Check PHP extensions:
```bash
php -m | grep zip
php -m | grep mysqli
```

### View error log:
```bash
tail -f bulk_export_errors.log
```

### Test API directly:
```bash
curl -X GET https://rlms.rlms.co.za/bulk_export_api.php
```

Should return:
```json
{"success":true,"message":"Bulk Export API is running"...}
```

## Updated Files

Make sure you've uploaded the LATEST versions of:
1. ✅ `bulk_export_api.php` (with better error handling)
2. ✅ `bulk_export_with_documents.php` (with try-catch blocks)
3. ✅ `get_learner_documents.php`
4. ✅ `bulk_down_register.php`

## Test Sequence

1. **Test API Status**:
   ```
   Visit: https://rlms.rlms.co.za/bulk_export_api.php
   Should see: {"success":true,...}
   ```

2. **Run Debug Script**:
   ```
   Visit: https://rlms.rlms.co.za/debug_bulk_export.php
   Check all tests pass
   ```

3. **Test Small Export**:
   ```
   - Filter to 2-3 learners
   - Click "Bulk Download"
   - Check browser console for errors
   - Check bulk_export_errors.log
   ```

4. **Check Response**:
   ```
   - Open browser DevTools (F12)
   - Network tab
   - Click bulk_export_api.php request
   - View Response tab
   - Should see JSON, not HTML error
   ```

## Expected Working Response

When working correctly, you should see:
```json
{
  "success": true,
  "total_learners": 133,
  "processed": 133,
  "failed": 0,
  "documents_included": {
    "sick_notes": 15,
    "manual_registers": 23
  },
  "zip_file": "bulk_reports_20251030_123456.zip",
  "errors": []
}
```

## Still Not Working?

1. Upload `debug_bulk_export.php`
2. Visit it in browser
3. Take screenshot of results
4. Check `bulk_export_errors.log` file
5. Check browser console (F12 → Console tab)
6. Check browser network tab (F12 → Network tab → bulk_export_api.php → Response)

The debug script will tell you exactly what's wrong!

---

**TL;DR**: 
1. Upload `debug_bulk_export.php`
2. Visit it to see what's wrong
3. Fix the issue it identifies
4. Try again
