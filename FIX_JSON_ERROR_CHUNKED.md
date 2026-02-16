# Fix: JSON Parse Error in Chunked Export

## Error

```
SyntaxError: Unexpected token '<', "<!DOCTYPE "... is not valid JSON
```

## Root Cause

The `bulk_export_chunked.php` API is returning HTML instead of JSON. This happens when:
1. PHP errors occur and display HTML error pages
2. `connection.php` or other includes output HTML
3. Output buffering issues

## Solution Implemented

**Updated**: `bulk_export_chunked.php`

### Changes Made:

1. **Added output buffering at start**
   - Captures any unwanted output from includes
   - Cleans buffers before sending JSON

2. **Added proper JSON headers**
   - Sets `Content-Type: application/json`
   - Adds cache control headers

3. **Added fallback HTML template**
   - If `indivisual.php` doesn't exist, uses fallback
   - Prevents errors from missing template

4. **Better error handling**
   - Suppresses errors during template include
   - Returns fallback on errors

## Files to Upload

1. **bulk_export_chunked.php** (UPDATED - Required)
2. **test_chunked_api.php** (NEW - For testing)

## Testing

### Step 1: Upload Files

```bash
upload bulk_export_chunked.php
upload test_chunked_api.php
```

### Step 2: Test API Directly

Open in browser:
```
https://yoursite.com/test_chunked_api.php
```

Run all 3 tests:
1. **Test 1: Start Session** - Should return valid JSON
2. **Test 2: Check Response Headers** - Should show `application/json`
3. **Test 3: Raw Response** - Should show JSON, not HTML

### Step 3: Check Results

**Success indicators**:
- ✅ Test 1 shows "Success! API returned valid JSON"
- ✅ Content-Type is `application/json`
- ✅ Response starts with `{` not `<!DOCTYPE`

**If still failing**:
- Check PHP error logs
- Look at raw response in Test 3
- Check if `connection.php` has errors

## Common Issues

### Issue 1: Still getting HTML

**Possible causes**:
- PHP syntax error in bulk_export_chunked.php
- Database connection error
- Missing vendor/autoload.php

**Fix**:
```bash
# Check PHP syntax
php -l bulk_export_chunked.php

# Check error logs
tail -f /var/log/php_errors.log

# Check if Composer packages installed
ls -la vendor/autoload.php
```

### Issue 2: "Database connection failed"

**Fix**:
- Verify `connection.php` exists
- Check database credentials
- Test database connection

### Issue 3: "indivisual.php template not found"

**This is OK!** The system will use fallback template.

**To fix** (optional):
- Upload your `indivisual.php` file
- System will automatically use it

## What Was Fixed

### Before (Broken):
```
connection.php outputs HTML
    ↓
bulk_export_chunked.php tries to send JSON
    ↓
HTML + JSON mixed response
    ↓
JavaScript can't parse
    ↓
Error ❌
```

### After (Fixed):
```
Output buffering captures HTML
    ↓
Clean buffers before JSON
    ↓
Set proper JSON headers
    ↓
Send clean JSON response
    ↓
JavaScript parses successfully
    ↓
Works ✅
```

## Verification Steps

1. **Upload updated file**
   ```bash
   upload bulk_export_chunked.php
   ```

2. **Test API**
   ```
   Open: test_chunked_api.php
   Run: Test 1
   ```

3. **Check response**
   - Should see valid JSON
   - Should have session_id
   - Should have total_chunks

4. **Test full workflow**
   - Go to bulk_down_register.php
   - Click "Bulk Download"
   - Should start processing
   - Progress bar should update

## Debug Information

If tests fail, check:

1. **PHP Error Logs**
   ```bash
   tail -f bulk_export_errors.log
   ```

2. **Browser Console**
   - Press F12
   - Look for errors
   - Check network tab

3. **Raw Response**
   - Run Test 3 in test_chunked_api.php
   - Look at first 1000 characters
   - Should start with `{` not `<`

## Success Indicators

When working correctly:

- ✅ test_chunked_api.php Test 1 passes
- ✅ Response is valid JSON
- ✅ Content-Type is application/json
- ✅ No HTML in response
- ✅ Bulk download starts processing
- ✅ Progress bar updates
- ✅ ZIP downloads successfully

## Additional Notes

### About indivisual.php

The system looks for `indivisual.php` to generate reports. If it doesn't exist:
- System uses fallback HTML template
- Reports still generate successfully
- Just won't match your exact original styling

**To use original template**:
- Upload your `indivisual.php` file
- Place in server root directory
- System will automatically detect and use it

### About Fallback Template

The fallback template includes:
- Learner name and details
- ID number and phone
- Site and project information
- Note that it's using fallback

It's basic but functional. For full reports, upload `indivisual.php`.

## Summary

**Problem**: API returning HTML instead of JSON  
**Cause**: Output from includes, missing error handling  
**Fix**: Output buffering, proper headers, fallback template  
**Status**: ✅ Ready to deploy

**Files to upload**:
1. bulk_export_chunked.php (UPDATED)
2. test_chunked_api.php (NEW - for testing)

**Test with**: test_chunked_api.php before using in production

---

**Priority**: Critical (blocks all bulk exports)  
**Estimated fix time**: 2 minutes (upload + test)
