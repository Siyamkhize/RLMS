# Pothole Checklist Scanning - Deployment Checklist

## Quick Deployment Steps

### 1. Server Setup (5 minutes)

#### A. Create Database Table
```bash
# Login to MySQL
mysql -u root -p

# Select database
USE rlms;

# Run the SQL script
SOURCE create_pothole_checklist_scanned_table.sql;

# Verify table created
SHOW TABLES LIKE 'pothole_checklist_scanned_documents';
DESCRIBE pothole_checklist_scanned_documents;
```

#### B. Upload PHP Files
```bash
# Copy PHP files to server
scp php/upload_scanned_pothole_checklist.php user@server:/path/to/rlms/mobile/
scp php/check_pothole_checklist_status.php user@server:/path/to/rlms/mobile/

# Or via FTP/cPanel file manager
```

#### C. Create Upload Directory
```bash
# On server
cd /path/to/rlms
mkdir -p uploads/pothole_checklists
chmod 777 uploads/pothole_checklists

# Verify permissions
ls -la uploads/
```

### 2. Flutter App (Already Done)
- ✅ Database helper updated
- ✅ UI updated with scanning functionality
- ✅ Offline support implemented
- ✅ No diagnostics errors

### 3. Testing (10 minutes)

#### Test 1: Online Scanning
```
1. Open app with internet
2. Navigate to Pothole Checklist page
3. Click "Open Checklist" button
4. Select "Scan Document"
5. Scan a test document
6. Verify success message
7. Check server uploads folder
```

#### Test 2: Offline Scanning
```
1. Turn off WiFi/Mobile data
2. Navigate to Pothole Checklist page
3. Click "Open Checklist" button
4. Select "Scan Document"
5. Scan a test document
6. Verify saved locally
7. Turn on internet
8. Wait for auto-sync
9. Check server uploads folder
```

#### Test 3: View Scanned Document
```
1. After scanning a document
2. Click "Open Checklist" button
3. Verify "Checklist Found" dialog
4. Click "View Checklist"
5. Verify document opens
```

#### Test 4: Fill Form (Existing)
```
1. Click "Open Checklist" button
2. Select "Fill Form"
3. Complete checklist form
4. Click "Save Checklist"
5. Verify saved successfully
```

---

## Configuration Check

### config.dart
Ensure baseUrl is set correctly:
```dart
class AppConfig {
  static const String baseUrl = 'https://rlms.rlms.co.za/mobile';
  // or for local testing:
  // static const String baseUrl = 'http://192.168.1.100/rlms/mobile';
}
```

### PHP Database Config
Check in both PHP files:
```php
$servername = "localhost";
$username = "root";  // Update if different
$password = "";      // Update if different
$dbname = "rlms";
```

---

## Verification Commands

### Check Database
```sql
-- Check table exists
SELECT COUNT(*) FROM pothole_checklist_scanned_documents;

-- View recent uploads
SELECT * FROM pothole_checklist_scanned_documents 
ORDER BY created_at DESC LIMIT 10;

-- Check for specific learner
SELECT * FROM pothole_checklist_scanned_documents 
WHERE learner_id = 'YOUR_LEARNER_ID';
```

### Check Upload Directory
```bash
# List uploaded files
ls -lh uploads/pothole_checklists/

# Check disk space
df -h

# Check permissions
ls -la uploads/pothole_checklists/
```

### Test API Endpoints
```bash
# Test upload (with curl)
curl -X POST \
  -F "learner_id=123" \
  -F "assessor_id=456" \
  -F "assessment_date=2025-11-04" \
  -F "document=@test.pdf" \
  https://rlms.rlms.co.za/mobile/upload_scanned_pothole_checklist.php

# Test status check
curl "https://rlms.rlms.co.za/mobile/check_pothole_checklist_status.php?learner_id=123&assessor_id=456&assessment_date=2025-11-04"
```

---

## Rollback Plan (If Issues)

### If Server Issues
1. Remove PHP files:
```bash
rm /path/to/rlms/mobile/upload_scanned_pothole_checklist.php
rm /path/to/rlms/mobile/check_pothole_checklist_status.php
```

2. Drop table (optional):
```sql
DROP TABLE IF EXISTS pothole_checklist_scanned_documents;
```

### If App Issues
1. The app will still work with existing form-based checklist
2. Scanning feature will fail gracefully
3. Users can continue using "Fill Form" option

---

## Monitoring

### What to Monitor
1. **Upload directory size**: `du -sh uploads/pothole_checklists/`
2. **Database growth**: Check table size regularly
3. **Failed uploads**: Check app logs
4. **Server errors**: Check PHP error logs

### Log Files
```bash
# PHP error log
tail -f /var/log/apache2/error.log
# or
tail -f /var/log/nginx/error.log

# Check upload errors
grep "upload_scanned_pothole_checklist" /var/log/apache2/error.log
```

---

## Common Issues & Solutions

### Issue: "Failed to save uploaded file"
**Solution**: Check directory permissions
```bash
chmod 777 uploads/pothole_checklists/
chown www-data:www-data uploads/pothole_checklists/
```

### Issue: "Database connection failed"
**Solution**: Verify database credentials in PHP files

### Issue: "Invalid file type"
**Solution**: Ensure scanning PDF or images (JPG/PNG)

### Issue: Scanner not opening
**Solution**: Check camera permissions in app settings

### Issue: Document not syncing
**Solution**: 
1. Check internet connection
2. Verify server URL in config.dart
3. Check PHP upload endpoint is accessible

---

## Performance Tips

1. **Compress Images**: Scanned images are auto-compressed
2. **Clean Old Files**: Periodically delete old scanned documents
3. **Database Maintenance**: Run OPTIMIZE TABLE monthly
4. **Monitor Storage**: Set up alerts for low disk space

---

## Security Checklist

- [ ] Upload directory has proper permissions (777 or 755)
- [ ] PHP files validate file types
- [ ] SQL queries use prepared statements
- [ ] File size limits enforced
- [ ] User authentication checked before upload
- [ ] HTTPS enabled on server
- [ ] Regular backups of uploads directory

---

## Success Criteria

✅ Users can scan physical checklists
✅ Scanned documents save locally (offline)
✅ Documents auto-sync when online
✅ Users can view scanned documents
✅ System checklists still work (form-based)
✅ No errors in app or server logs
✅ Database records created correctly
✅ Files uploaded to server successfully

---

## Next Steps After Deployment

1. **User Training**: Show users how to scan documents
2. **Monitor Usage**: Track how many users use scanning vs form
3. **Gather Feedback**: Ask users about scanning experience
4. **Optimize**: Improve based on usage patterns
5. **Enhance**: Add features like batch scanning, OCR, etc.

---

## Support Contacts

- **Technical Issues**: Check logs and documentation
- **Database Issues**: Review SQL queries and table structure
- **App Issues**: Check Flutter diagnostics
- **Server Issues**: Check PHP error logs and permissions

---

**Deployment Date**: _____________
**Deployed By**: _____________
**Tested By**: _____________
**Status**: ⬜ Pending  ⬜ In Progress  ⬜ Complete

---

## Sign-Off

- [ ] Database table created
- [ ] PHP files uploaded
- [ ] Upload directory created
- [ ] Permissions set correctly
- [ ] API endpoints tested
- [ ] App tested (online)
- [ ] App tested (offline)
- [ ] Documentation reviewed
- [ ] Team trained

**Approved By**: _____________
**Date**: _____________
