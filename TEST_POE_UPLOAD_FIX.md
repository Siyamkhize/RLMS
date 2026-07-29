# Test Guide: POE Upload Tab Character Fix

## What Was Fixed
The POE upload was failing because filenames contained literal tab characters (`\t`) which Windows/XAMPP cannot handle in file paths.

## How to Test

### 1. Run the App
```bash
adb logcat -v time | findstr /i "flutter rlmss POE upload sync error failed"
```

### 2. Test POE Upload
1. Open the app on your device
2. Navigate to the learner with ID **15292** (or any learner)
3. Go to the POE tab
4. Try to upload a Formative assessment document
5. Watch the logs for the upload result

### 3. Expected Results

#### ✅ SUCCESS - You should see:
```
Server Response: {"status":"success","message":"Upload successful",...}
```

#### ❌ BEFORE FIX - You would have seen:
```
Server Response: {"status":"error","message":"File processing errors: Failed to move uploaded file: Formative_9964_3.\tWhat_are_Implications_of_exposure_to_hazardous_substance?\t_1776868636608.pdf (Error: move_uploaded_file(): Unable to move...)"}
```

### 4. Verify File on Server
Check that the file was created in the `POE/` folder on your server:
```bash
ls -la POE/
```

You should see a file like:
```
POE/69e8dfc1b36b6_Formative_9964_3_What_are_Implications_of_exposure_to_hazardous_substance_1776868636608.pdf
```

Notice: **No tab characters** - all whitespace replaced with underscores!

### 5. Check Database
The file should also be recorded in the `poe` table:
```sql
SELECT * FROM poe WHERE learnerID = 15292 ORDER BY id DESC LIMIT 5;
```

## What Changed in the Code

### File: `mobile/save_metadata.php`

**Before:**
```php
$fileName = uniqid() . '_' . preg_replace('/[^a-zA-Z0-9._-]/', '', basename($name));
```

**After:**
```php
// CRITICAL FIX: Remove ALL whitespace characters including tabs, newlines, etc.
// Windows/XAMPP cannot handle tab characters (\t) in file paths
$sanitizedName = preg_replace('/\s+/', '_', basename($name)); // Replace all whitespace with underscore
$sanitizedName = preg_replace('/[^a-zA-Z0-9._-]/', '', $sanitizedName); // Remove special chars
$fileName = uniqid() . '_' . $sanitizedName;
```

## Why This Fix Works

1. **First regex** (`/\s+/`): Replaces ALL whitespace characters (tabs, spaces, newlines, carriage returns) with underscores
2. **Second regex** (`/[^a-zA-Z0-9._-]/`): Removes any remaining special characters
3. **Result**: Clean, Windows-compatible filename that `move_uploaded_file()` can handle

## Common Issues

### If upload still fails:
1. Check POE folder permissions: `chmod 777 POE/`
2. Check PHP temp folder: `php -i | grep upload_tmp_dir`
3. Check PHP error log: `tail -f /var/log/php_errors.log`
4. Verify file size is under 15MB limit

### If you see "Retry 1/3" messages:
This is normal retry behavior. The fix should prevent the "Failed to move uploaded file" error.

## Status
✅ **FIX APPLIED** - Ready for testing

## Date
2026-04-22
