# 🚀 Deployment Checklist - Bulk Download with Documents

## Files to Upload to Server

Upload these files to your server root directory (same location as `bulk_down_register.php`):

### ✅ Required Files (Must Upload)
1. ✅ `bulk_export_api.php` - Main API endpoint
2. ✅ `bulk_export_with_documents.php` - Export processor
3. ✅ `get_learner_documents.php` - Document fetcher

### ✅ Modified Files (Must Upload/Replace)
4. ✅ `bulk_down_register.php` - Updated with new functionality

### 📝 Optional Files (For Testing/Documentation)
5. `test_bulk_documents.php` - Test suite
6. `BULK_DOWNLOAD_WITH_DOCUMENTS.md` - Full documentation
7. `BULK_DOWNLOAD_IMPLEMENTATION_SUMMARY.md` - Summary
8. `QUICK_START_BULK_DOCUMENTS.md` - Quick reference

## Pre-Deployment Checks

### 1. Database Tables
Verify these tables exist:
```sql
SHOW TABLES LIKE 'sick_note';
SHOW TABLES LIKE 'manual_clocking';
SHOW TABLES LIKE 'learnerdetails';
```

### 2. File Directories
Verify these directories exist and are readable:
- `/public_html/mobile/sicknotes/` - For sick notes
- `/public_html/uploads/` - For manual registers
- Create if missing: `temp_reports/` - For temporary files (must be writable)

### 3. PHP Extensions
Verify ZipArchive is installed:
```bash
php -m | grep zip
```

### 4. File Permissions
```bash
# Make temp_reports writable
chmod 755 temp_reports/

# Verify PHP can read document directories
ls -la mobile/sicknotes/
ls -la uploads/
```

## Deployment Steps

### Step 1: Upload Files
Using FTP/SFTP or cPanel File Manager:
1. Upload `bulk_export_api.php`
2. Upload `bulk_export_with_documents.php`
3. Upload `get_learner_documents.php`
4. Replace `bulk_down_register.php` with updated version

### Step 2: Create Temp Directory
```bash
mkdir -p temp_reports
chmod 755 temp_reports
```

### Step 3: Test the API
Open in browser:
```
https://your-domain.com/bulk_export_api.php
```

Should return:
```json
{
  "success": true,
  "message": "Bulk Export API is running",
  "endpoints": {...},
  "timestamp": 1234567890
}
```

### Step 4: Test Document Fetching
Upload `test_bulk_documents.php` and open:
```
https://your-domain.com/test_bulk_documents.php
```

Verify all tests pass.

### Step 5: Test Small Export
1. Go to bulk download page
2. Filter to 5-10 learners
3. Set date range (e.g., September 2025)
4. Click "Bulk Download"
5. Verify ZIP contains:
   - Reports
   - Sick notes (if any)
   - Manual registers (if any)
   - SUMMARY.txt

## Troubleshooting

### Error: "File not found" (404)
**Cause**: Files not uploaded to server
**Fix**: Upload all required files listed above

### Error: "Missing required files"
**Cause**: One or more PHP files missing
**Fix**: Check all 3 required files are uploaded:
- bulk_export_api.php
- bulk_export_with_documents.php
- get_learner_documents.php

### Error: "Database connection failed"
**Cause**: connection.php not found or database issue
**Fix**: Verify connection.php exists and database credentials are correct

### Error: "Failed to create ZIP file"
**Cause**: ZipArchive not installed or temp_reports not writable
**Fix**: 
```bash
# Check ZipArchive
php -m | grep zip

# Fix permissions
chmod 755 temp_reports/
```

### No documents in ZIP
**Cause**: Files don't exist or paths are wrong
**Fix**: Run test_bulk_documents.php to verify:
- Database has records
- Files exist on disk
- Paths are correct

## Verification Commands

### Check Files Uploaded
```bash
ls -la bulk_export_api.php
ls -la bulk_export_with_documents.php
ls -la get_learner_documents.php
ls -la bulk_down_register.php
```

### Check Permissions
```bash
ls -la temp_reports/
ls -la mobile/sicknotes/
ls -la uploads/
```

### Check PHP Version
```bash
php -v
# Should be 7.4 or higher
```

### Check Database Tables
```sql
SELECT COUNT(*) FROM sick_note;
SELECT COUNT(*) FROM manual_clocking;
SELECT COUNT(*) FROM learnerdetails;
```

## Post-Deployment

### 1. Monitor Logs
Check for errors:
```bash
tail -f bulk_export_errors.log
```

### 2. Test with Real Data
- Try small batch (5-10 learners)
- Try medium batch (50 learners)
- Verify ZIP contents

### 3. Performance Check
- Monitor execution time
- Check memory usage
- Verify ZIP file sizes

## Rollback Plan

If issues occur, restore original files:
1. Keep backup of original `bulk_down_register.php`
2. Remove new files if causing issues
3. Restore from backup

## Success Criteria

✅ API endpoint returns JSON response
✅ Test suite passes all tests
✅ Small export completes successfully
✅ ZIP file contains all expected documents
✅ No errors in log files

## Support

If deployment fails:
1. Check error logs: `bulk_export_errors.log`
2. Run test suite: `test_bulk_documents.php`
3. Verify all files uploaded
4. Check file permissions
5. Verify database tables exist

---

**Ready to Deploy?** Follow the steps above in order.
