# QUICK FIX: Upload Directory Missing

## Problem Found
The upload directory `uploads/pothole_evidence/` doesn't exist on the server, which is why images aren't being saved.

## Solution

### Option 1: Automatic Fix (Easiest)
1. Upload `create_upload_directory.php` to your server
2. Visit: `https://rlms.rlms.co.za/mobile/create_upload_directory.php`
3. The script will create the directory automatically
4. Verify it shows "SUCCESS! Directory is ready for uploads"

### Option 2: Manual Fix (If automatic fails)
SSH into your server and run:
```bash
cd /home/username/public_html/mobile
mkdir -p uploads/pothole_evidence
chmod 755 uploads/pothole_evidence
```

Verify:
```bash
ls -la uploads/
```

You should see:
```
drwxr-xr-x  2 username username 4096 Nov 10 14:45 pothole_evidence
```

## What Was Fixed

### 1. Updated upload_pothole_evidence.php
**Before:** Directory creation failed silently
```php
if (!file_exists($uploadDir)) {
    mkdir($uploadDir, 0755, true);  // No error checking!
}
```

**After:** Proper error handling
```php
if (!file_exists($uploadDir)) {
    if (!mkdir($uploadDir, 0755, true)) {
        // Return error to app
        echo json_encode(['status' => 'error', 'message' => 'Failed to create upload directory']);
        exit;
    }
}

// Also check if writable
if (!is_writable($uploadDir)) {
    echo json_encode(['status' => 'error', 'message' => 'Upload directory is not writable']);
    exit;
}
```

### 2. Created diagnostic script
`create_upload_directory.php` - Automatically creates the directory and tests it

## Testing After Fix

1. **Run the fix:**
   ```
   https://rlms.rlms.co.za/mobile/create_upload_directory.php
   ```

2. **Verify status:**
   ```
   https://rlms.rlms.co.za/mobile/check_upload_status.php
   ```
   
   Should show:
   ```json
   {
     "upload_directory": {
       "exists": true,
       "writable": true
     },
     "overall": "OK"
   }
   ```

3. **Try uploading images from the app**

4. **Check status again:**
   ```
   https://rlms.rlms.co.za/mobile/check_upload_status.php
   ```
   
   Should show:
   ```json
   {
     "upload_directory": {
       "file_count": 3  // or however many you uploaded
     },
     "database": {
       "pothole_entries": 3
     },
     "sync_status": {
       "in_sync": true
     }
   }
   ```

## Why This Happened

The upload script tried to create the directory with `mkdir()` but:
1. The parent `uploads/` directory might not exist
2. PHP might not have permission to create directories
3. The script didn't check if `mkdir()` succeeded
4. It continued processing and showed "success" even though files couldn't be saved

## Files to Upload

Make sure these files are on your server:
1. ✅ `upload_pothole_evidence.php` (updated with error handling)
2. ✅ `create_upload_directory.php` (new - creates directory)
3. ✅ `check_upload_status.php` (new - checks status)

## Expected Behavior After Fix

### Before Fix:
- App shows "3 images uploaded successfully"
- No files in directory
- No database entries
- No error messages

### After Fix:
- If directory doesn't exist: App shows error "Failed to create upload directory"
- If directory not writable: App shows error "Upload directory is not writable"
- If everything OK: Files are saved and database entries created

## Verification Checklist

- [ ] Upload `create_upload_directory.php` to server
- [ ] Run it in browser - should show SUCCESS
- [ ] Upload `upload_pothole_evidence.php` (updated version)
- [ ] Run `check_upload_status.php` - should show "OK"
- [ ] Try uploading 1 image from app
- [ ] Check Flutter console for response
- [ ] Run `check_upload_status.php` again - should show 1 file and 1 database entry
- [ ] Images appear in view page

## If Still Not Working

If `create_upload_directory.php` fails to create the directory:

1. Check if `uploads/` parent directory exists
2. Check PHP user permissions
3. Use manual fix (SSH method above)
4. Contact hosting provider if permissions issue

## Next Steps

1. Upload the updated `upload_pothole_evidence.php`
2. Run `create_upload_directory.php`
3. Try uploading images
4. They should now work!
