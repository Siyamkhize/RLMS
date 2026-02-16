# Deploy view_pothole_checklists.php to Server

## Current Situation

**Local (Your Computer):**
```
workspace/
  └── php/
      └── view_pothole_checklists.php  ← File is here locally
```

**Server:**
```
rlms.rlms.co.za/
  └── mobile/
      └── view_pothole_checklists.php  ← File needs to be here
```

## The Issue

The file `php/view_pothole_checklists.php` exists in your local workspace but needs to be uploaded to the server at:
```
rlms.rlms.co.za/mobile/view_pothole_checklists.php
```

## Deployment Steps

### Option 1: Upload via FTP/SFTP

1. Open your FTP client (FileZilla, WinSCP, etc.)
2. Connect to `rlms.rlms.co.za`
3. Navigate to the `/mobile/` directory
4. Upload `php/view_pothole_checklists.php` from your local workspace
5. Place it directly in `/mobile/` (not in a php subfolder)

**Result:**
```
Server path: /mobile/view_pothole_checklists.php
URL: https://rlms.rlms.co.za/mobile/view_pothole_checklists.php
```

### Option 2: Upload via cPanel File Manager

1. Log into cPanel
2. Open File Manager
3. Navigate to `/public_html/mobile/` (or wherever mobile is located)
4. Click "Upload"
5. Select `php/view_pothole_checklists.php` from your computer
6. Upload it directly to the `/mobile/` directory

### Option 3: Copy Content Manually

If you have access to edit files directly on the server:

1. Log into your server (SSH or cPanel)
2. Navigate to `/mobile/` directory
3. Create/edit `view_pothole_checklists.php`
4. Copy the content from `php/view_pothole_checklists.php`
5. Paste and save

## File Content to Upload

The file is located at: `php/view_pothole_checklists.php`

Make sure you upload the **latest version** with these fixes:
- ✅ Uses `created_at` instead of `uploaded_at`
- ✅ Checks both scanned and system tables
- ✅ Returns type indicator

## Verify Deployment

After uploading, test the endpoint:

**Via Browser:**
```
https://rlms.rlms.co.za/mobile/view_pothole_checklists.php?learner_id=70
```

**Expected Response:**
```json
{
  "status": "success",
  "data": {
    "type": "scanned",
    "learner_id": "70",
    "document_path": "...",
    ...
  }
}
```

Or if no data:
```json
{
  "status": "error",
  "message": "No checklist found for the specified parameters"
}
```

## Important Notes

1. **No php/ subfolder on server** - The file goes directly in `/mobile/`
2. **File permissions** - Make sure the file has read permissions (644)
3. **Database connection** - Verify `config.php` exists in `/mobile/` directory
4. **Test immediately** - After upload, test via browser before testing in app

## After Deployment

Once the file is uploaded to the server:

1. **Restart your Flutter app** (or just retry)
2. **Navigate to a learner's POE tab**
3. **Check debug logs** - Should see successful response
4. **Verify checklist displays** - Should see scanned or system form

## Current File Location

**Local workspace:** `php/view_pothole_checklists.php`
**Server destination:** `/mobile/view_pothole_checklists.php`
**Server URL:** `https://rlms.rlms.co.za/mobile/view_pothole_checklists.php`

## Status

⏳ **AWAITING DEPLOYMENT**

The file has been updated locally with all fixes. It needs to be uploaded to the server to take effect.
