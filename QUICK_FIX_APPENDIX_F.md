# Appendix F 404 Error - Quick Fix Guide

## 🚨 Problem
App shows: `Failed to save Appendix F: 404`

## ✅ Quick Solution (5 Minutes)

### Step 1: Upload These 3 Files to Server
Upload to **`/mobile/`** directory (same place where `save_arpl_toolkit_edits.php` exists):

1. ✅ `mobile/save_appendix_f_data.php` ← **THE MAIN FILE**
2. ✅ `mobile/verify_appendix_f_endpoint.php` ← Diagnostic
3. ✅ `mobile/test_appendix_f_exists.php` ← Diagnostic

### Step 2: Test Verification Endpoint
Open this URL in your browser:
```
https://rlms.rlms.co.za/mobile/verify_appendix_f_endpoint.php
```

**Good Response (means it's working):**
```json
{
  "status": "success",
  "save_file_exists": true,
  "files_in_directory": ["save_appendix_f_data.php", ...]
}
```

**Bad Response:**
- **404 Error** → Files not uploaded or wrong directory
- **`save_file_exists: false`** → Main file missing, re-upload step 1 file #1

### Step 3: Check File Location
Using FTP or File Manager:
```
Your Server Root
└── mobile/
    ├── save_appendix_f_data.php         ← MUST BE HERE
    ├── save_arpl_toolkit_edits.php       ← Compare location with this
    ├── verify_appendix_f_endpoint.php    ← Upload this
    └── test_appendix_f_exists.php        ← Upload this
```

### Step 4: Test from App
1. Open ARPL Toolkit
2. Select learner (Anele Cele, ID 11701)
3. Go to Appendix F tab
4. Edit mode → Make a change
5. Save
6. Check console logs

**Expected:** `✓ Changes saved successfully`

## 📋 Checklist

- [ ] Uploaded `save_appendix_f_data.php` to `/mobile/` directory
- [ ] Uploaded diagnostic files
- [ ] Tested verification URL - got success response
- [ ] Confirmed `save_file_exists: true`
- [ ] File is in same directory as `save_arpl_toolkit_edits.php`
- [ ] Tested from app - save works

## 🔍 Still Not Working?

If verification endpoint returns `save_file_exists: false`:

### Check:
1. **File really uploaded?** Double-check in FTP/File Manager
2. **Correct directory?** Should be in `/mobile/`, not root
3. **Correct filename?** Must be exactly `save_appendix_f_data.php` (case-sensitive)
4. **File permissions?** Should be 644 (like other PHP files)

### Compare with Working File:
- Find `save_arpl_toolkit_edits.php` on server
- Upload `save_appendix_f_data.php` to **exact same directory**
- Both files should have **exact same permissions**

## 📞 Report Back

When you test, please tell me:
1. ✅ What does verification endpoint return? (copy/paste JSON)
2. ✅ Can you see `save_appendix_f_data.php` in file manager? (yes/no)
3. ✅ Is it in same folder as `save_arpl_toolkit_edits.php`? (yes/no)
4. ✅ Does app save work after upload? (yes/no)

## 💡 Why This Happened

The error "404 Not Found" means the web server can't find the PHP file at the URL. Since:
- ✅ Code is correct
- ✅ URL is correct
- ✅ Other endpoints work

The only explanation is the file isn't on the server at the expected location.

## 🎯 Bottom Line

**Upload these 3 files → Test verification URL → Report results**

Then we'll know exactly what's wrong and fix it!
