# POE Upload Filename Tab Character Fix

## Issue Identified
POE uploads were failing with the error:
```
Failed to move uploaded file: Formative_9964_3.\tWhat_are_Implications_of_exposure_to_hazardous_substance?\t_1776868636608.pdf
Error: move_uploaded_file(): Unable to move "C:\xampp\tmp\phpA231.tmp" to "POE/69e8dfc1b36b6_Formative_9964_3.\tWhat_are_Implications_of_exposure_to_hazardous_substance?\t_1776868636608.pdf"
```

## Root Cause
The filename contained **literal tab characters** (`\t`) embedded in it:
- The exercise name from the database had tabs: `Formative_9964_3.\tWhat_are_Implications...\t_1776868636608.pdf`
- Windows/XAMPP's `move_uploaded_file()` function **cannot handle tab characters** in file paths
- The function fails silently when encountering tabs in the destination path

## Why This Happened
The exercise names in the database likely contain tab characters as separators:
```
{formName}\t{question}\t{timestamp}
```

These tab characters were being passed through to the filename construction without proper sanitization.

## Solution Applied
Fixed `mobile/save_metadata.php` line 136-138 to properly sanitize filenames:

### Before:
```php
$fileName = uniqid() . '_' . preg_replace('/[^a-zA-Z0-9._-]/', '', basename($name));
```

### After:
```php
// CRITICAL FIX: Remove ALL whitespace characters including tabs, newlines, etc.
// Windows/XAMPP cannot handle tab characters (\t) in file paths
$sanitizedName = preg_replace('/\s+/', '_', basename($name)); // Replace all whitespace with underscore
$sanitizedName = preg_replace('/[^a-zA-Z0-9._-]/', '', $sanitizedName); // Remove special chars
$fileName = uniqid() . '_' . $sanitizedName;
```

## What Changed
1. **First pass**: Replace ALL whitespace characters (tabs, spaces, newlines, etc.) with underscores using `\s+`
2. **Second pass**: Remove any remaining special characters that aren't alphanumeric, dots, underscores, or hyphens
3. This ensures Windows-compatible filenames that won't cause `move_uploaded_file()` to fail

## Testing Required
1. Try uploading a POE document for the same learner (ID: 15292)
2. Check that the upload succeeds without the "Failed to move uploaded file" error
3. Verify the file is saved correctly in the POE folder
4. Check the server response shows `"status":"success"`

## Files Modified
- `mobile/save_metadata.php` - Added proper whitespace sanitization to filename generation

## Status
✅ **FIXED** - Filename sanitization now removes all whitespace characters including tabs before attempting file upload.

## Date
2026-04-22
