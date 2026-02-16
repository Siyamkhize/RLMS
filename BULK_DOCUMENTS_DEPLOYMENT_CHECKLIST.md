# Bulk Document Download - Deployment Checklist

## ✅ Implementation Complete

All files have been created and modified. Use this checklist to verify everything is working.

## 📋 Pre-Deployment Checklist

### 1. File Verification
- [ ] `bulk_download_documents.php` exists in root directory
- [ ] `test_bulk_download_documents.php` exists in root directory
- [ ] `bulk_down_register.php` has been modified (button added)
- [ ] `get_learner_documents.php` exists and has required functions

### 2. Directory Permissions
- [ ] `temp_reports/` directory exists
- [ ] `temp_reports/` is writable (chmod 777 or appropriate)
- [ ] Web server can create temporary directories
- [ ] Web server can delete temporary directories

### 3. PHP Extensions
- [ ] ZipArchive extension is installed
- [ ] mysqli extension is installed
- [ ] File operations are enabled

### 4. Database Tables
- [ ] `sick_note` table exists
- [ ] `manual_clocking` table exists
- [ ] `learnerdetails` table exists
- [ ] Tables have required columns

## 🧪 Testing Checklist

### Test 1: Run Test Script
```
http://your-server/test_bulk_download_documents.php
```

Expected Results:
- [ ] ✅ Function availability check passes
- [ ] ✅ Database connection successful
- [ ] ✅ Sample learner found
- [ ] ✅ Document retrieval works
- [ ] ✅ ZipArchive available
- [ ] ✅ Directory permissions OK

### Test 2: Manual Test with Small Dataset
1. [ ] Navigate to `bulk_down_register.php`
2. [ ] Select a site with 5-10 learners
3. [ ] Set date range (e.g., last month)
4. [ ] Click "📈 Generate Report"
5. [ ] Verify learners are displayed
6. [ ] Click "📎 Bulk Download Documents" button
7. [ ] Verify confirmation dialog appears
8. [ ] Verify progress indicator shows
9. [ ] Verify ZIP file downloads
10. [ ] Extract ZIP and verify structure

### Test 3: Verify ZIP Contents
- [ ] ZIP file name format: `Documents_[Site]_[Date].zip`
- [ ] Learner folders exist: `[Surname]_[Name]_[IDNumber]/`
- [ ] Sick notes in `Sick_Notes/` subfolder
- [ ] Manual registers in `Manual_Attendance/` subfolder
- [ ] `DOWNLOAD_SUMMARY.txt` exists
- [ ] File names are properly formatted

### Test 4: Edge Cases
- [ ] Test with learner who has no documents
  - Should create `NO_DOCUMENTS_FOUND.txt`
- [ ] Test with empty date range
  - Should show error message
- [ ] Test without generating report first
  - Should show "No learners found" alert
- [ ] Test with large dataset (50+ learners)
  - Should show progress and complete successfully

## 🔍 Troubleshooting Guide

### Issue: Button Not Visible
**Check:**
- [ ] Browser cache cleared
- [ ] `bulk_down_register.php` saved correctly
- [ ] No JavaScript errors in console (F12)

**Fix:**
- Hard refresh: Ctrl+F5 (Windows) or Cmd+Shift+R (Mac)
- Check browser console for errors

### Issue: "No learners found" Alert
**Check:**
- [ ] Clicked "Generate Report" first
- [ ] Learners are displayed in table
- [ ] Table has class `learner-row`

**Fix:**
- Click "Generate Report" button first
- Verify filters are set correctly

### Issue: ZIP File Not Downloading
**Check:**
- [ ] `temp_reports/` directory exists
- [ ] Directory is writable
- [ ] No PHP errors in error log
- [ ] Browser allows downloads

**Fix:**
```bash
# Create directory if missing
mkdir temp_reports
chmod 777 temp_reports

# Check PHP error log
tail -f /var/log/php_errors.log
```

### Issue: Empty ZIP or Missing Files
**Check:**
- [ ] Documents exist in database
- [ ] File paths in database are correct
- [ ] Files exist on server
- [ ] File permissions allow reading

**Fix:**
- Check database: `SELECT * FROM sick_note WHERE learner_id = [ID]`
- Verify file paths: Check if files exist at specified locations
- Check file permissions: `ls -la mobile/sicknotes/`

### Issue: Progress Bar Stuck
**Check:**
- [ ] No PHP errors
- [ ] Server not timing out
- [ ] Database connection stable

**Fix:**
- Check browser console (F12) for errors
- Check PHP error log
- Reduce number of learners in test

## 📊 Performance Benchmarks

Expected processing times:

| Learners | Documents | Time     |
|----------|-----------|----------|
| 1-10     | 0-50      | 2-5 sec  |
| 10-50    | 50-200    | 5-15 sec |
| 50-100   | 200-500   | 15-30 sec|
| 100-200  | 500-1000  | 30-60 sec|
| 200+     | 1000+     | 1-2 min  |

If times are significantly longer:
- [ ] Check server resources (CPU, memory)
- [ ] Check database performance
- [ ] Check file system speed
- [ ] Consider optimizing queries

## 🔒 Security Checklist

- [ ] Only authenticated users can access
- [ ] Learner IDs are validated (integer only)
- [ ] File paths are sanitized
- [ ] SQL injection prevented (prepared statements)
- [ ] Temporary files are cleaned up
- [ ] Error messages don't expose sensitive info
- [ ] File operations are logged

## 📝 Documentation Checklist

- [ ] `BULK_DOCUMENT_DOWNLOAD_GUIDE.md` - User guide
- [ ] `BULK_DOCUMENTS_IMPLEMENTATION_SUMMARY.md` - Technical details
- [ ] `BULK_DOCUMENTS_QUICK_START.md` - Quick reference
- [ ] `BULK_DOCUMENTS_FLOW.txt` - System flow diagram
- [ ] `BULK_DOCUMENTS_DEPLOYMENT_CHECKLIST.md` - This file

## 🚀 Go-Live Checklist

### Before Go-Live
- [ ] All tests passed
- [ ] Performance acceptable
- [ ] Security verified
- [ ] Documentation complete
- [ ] Backup created
- [ ] Rollback plan ready

### Go-Live Steps
1. [ ] Deploy files to production server
2. [ ] Verify file permissions
3. [ ] Run test script on production
4. [ ] Test with small dataset
5. [ ] Monitor error logs
6. [ ] Inform users of new feature

### After Go-Live
- [ ] Monitor usage
- [ ] Check error logs daily (first week)
- [ ] Gather user feedback
- [ ] Document any issues
- [ ] Plan improvements

## 📞 Support Information

### Common User Questions

**Q: How do I use this feature?**
A: See `BULK_DOCUMENTS_QUICK_START.md`

**Q: What documents are included?**
A: Sick notes and manual attendance registers within the selected date range

**Q: How long does it take?**
A: Depends on number of learners (see Performance Benchmarks above)

**Q: Can I select specific learners?**
A: Currently downloads all filtered learners. Use filters to narrow down.

**Q: What if a learner has no documents?**
A: A `NO_DOCUMENTS_FOUND.txt` file is created in their folder

### Technical Support

**Error Logs:**
- PHP errors: Check server error log
- JavaScript errors: Check browser console (F12)
- Database errors: Check MySQL error log

**Debug Mode:**
Add to `bulk_download_documents.php`:
```php
error_reporting(E_ALL);
ini_set('display_errors', 1);
```

**Verbose Logging:**
Check error_log() calls in:
- `bulk_download_documents.php`
- `get_learner_documents.php`

## ✅ Final Sign-Off

- [ ] All tests passed
- [ ] Documentation reviewed
- [ ] Users trained
- [ ] Support team briefed
- [ ] Monitoring in place
- [ ] Feature is LIVE! 🎉

---

**Deployment Date:** _________________

**Deployed By:** _________________

**Verified By:** _________________

**Notes:**
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
