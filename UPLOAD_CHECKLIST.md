# 📤 Upload Checklist - Background Processing Solution

## ✅ Files to Upload:

### 1. bulk_export_background.php (NEW FILE - REQUIRED!)
**Status**: ⚠️ **MUST UPLOAD THIS FILE**
**Location**: Root directory (same as bulk_down_register.php)
**Purpose**: Handles background processing

### 2. bulk_down_register.php (UPDATED)
**Status**: ✅ Updated with background processing
**Location**: Root directory
**Purpose**: Main page with updated JavaScript

### 3. bulk_export_with_documents.php (UPDATED)
**Status**: ✅ Updated with fast PDF generation
**Location**: Root directory
**Purpose**: Report generation logic

## 🎯 Current Error:

```
Server returned non-JSON response
```

**Cause**: `bulk_export_background.php` is not uploaded to the server yet!

## ✅ After Uploading:

1. **Clear browser cache** (Ctrl+F5 or Cmd+Shift+R)
2. **Test with 5-10 learners first**
3. **Watch progress updates**
4. **ZIP downloads when complete**

## 📊 Expected Behavior:

### Console Logs:
```
📦 Exporting 134 learners...
📅 Date range: 2025-09-01 to 2025-09-30
Starting background export with job ID: job_1234567890
Background job response status: 200
Background job response: {"success":true,"job_id":"job_1234567890"...}
Background job started: job_1234567890
Progress: {status: "processing", processed: 10, percent: 7, ...}
Progress: {status: "processing", processed: 20, percent: 15, ...}
...
Progress: {status: "completed", percent: 100, zip_file: "bulk_reports_..."}
```

### User Sees:
```
Processing in background...
Processing learner 10 of 134...
Processing learner 50 of 134...
Processing learner 100 of 134...
Export completed! Downloading...
[ZIP file downloads]
```

## 🔧 Troubleshooting:

### If still getting "non-JSON response":
1. **Check**: Is `bulk_export_background.php` uploaded?
2. **Check**: File permissions (should be 644)
3. **Check**: File in correct directory
4. **Test**: Visit `https://rlms.rlms.co.za/bulk_export_background.php` directly

### If getting 404:
- File not uploaded or wrong location

### If getting PHP error:
- Check `bulk_export_errors.log`
- Check server error log

## 📁 File Locations:

All files should be in the same directory:
```
/public_html/
├── bulk_down_register.php ← Updated
├── bulk_export_background.php ← NEW (MUST UPLOAD!)
├── bulk_export_with_documents.php ← Updated
├── get_learner_documents.php ← Existing
├── connection.php ← Existing
└── temp_reports/ ← Directory (will be created)
```

## ✅ Verification:

After uploading, verify:
```bash
ls -la bulk_export_background.php
# Should show file size ~3-4 KB
```

Or visit in browser:
```
https://rlms.rlms.co.za/bulk_export_background.php
```
Should show: "No learner IDs provided" (means file exists and PHP works)

---

**CRITICAL**: Upload `bulk_export_background.php` first, then test!
