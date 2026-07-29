# File Upload Instructions
**Server: https://rlms.rlms.co.za**

---

## 📁 Files to Upload

### 1. ARPL Hierarchy Fix
**File:** `mobile/get_arpl_hierarchy.php`
**Upload to:** `/public_html/mobile/get_arpl_hierarchy.php`
**Action:** Replace existing file

### 2. Sick Note Feature (2 files)
**File 1:** `mobile/get_sick_note_eligible_dates.php`
**Upload to:** `/public_html/mobile/get_sick_note_eligible_dates.php`
**Action:** New file (or replace if exists)

**File 2:** `mobile/submit_sick_note.php`
**Upload to:** `/public_html/mobile/submit_sick_note.php`
**Action:** New file (or replace if exists)

---

## 📂 Server Directory Setup

### Create Sick Note Upload Directory
```bash
# SSH into server or use File Manager
mkdir -p /public_html/uploads/sick_notes
chmod 755 /public_html/uploads/sick_notes
```

**Or via FTP/File Manager:**
1. Navigate to `/public_html/uploads/`
2. Create folder: `sick_notes`
3. Set permissions: `755`

---

## 🔧 Upload Methods

### Method 1: FTP/SFTP (Recommended)
**Tools:** FileZilla, WinSCP, or cPanel File Manager

**Steps:**
1. Connect to server: `rlms.rlms.co.za`
2. Navigate to `/public_html/mobile/`
3. Upload the 3 PHP files
4. Set file permissions to `644` (if not already set)
5. Navigate to `/public_html/uploads/`
6. Create `sick_notes` folder (if doesn't exist)
7. Set folder permissions to `755`

### Method 2: cPanel File Manager
1. Login to cPanel
2. Open File Manager
3. Navigate to `public_html/mobile/`
4. Click "Upload"
5. Select the 3 PHP files from local directory
6. Wait for upload to complete
7. Navigate to `public_html/uploads/`
8. Create `sick_notes` folder
9. Right-click folder → Permissions → Set to `755`

### Method 3: Git (if server has Git access)
```bash
# On server
cd /public_html/mobile/
git pull origin main
# or copy files manually
```

---

## ✅ Verification After Upload

### Test ARPL Hierarchy Fix
**Endpoint:** `https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701`

**Expected response:**
```json
{
  "pathways": {
    "ARPL": {
      "qualifications": {
        "Bricklayer": {
          "theory_papers": {...},
          "practical_papers": {...}
        }
      }
    }
  },
  "_debug": [
    "Found learner: ...",
    "Found class with trade_id: 1",
    "From arpl_trades table - Trade: Bricklayer, OFO: 641201",
    "Final trade selected: Bricklayer (OFO: 641201)"
  ]
}
```

**Check for:**
- `"Bricklayer"` in qualifications (not "Electrician")
- Debug logs showing "From arpl_trades table - Trade: Bricklayer"

### Test Sick Note Eligibility Endpoint
**Endpoint:** `https://rlms.rlms.co.za/mobile/get_sick_note_eligible_dates.php`

**Method:** POST
**Body:**
```
learner_id=11701
```

**Expected response:**
```json
{
  "status": "success",
  "is_eligible": true,
  "dates": [
    {
      "date": "2026-07-23",
      "formatted": "Wed, 23 Jul 2026",
      "is_selectable": true
    },
    ...
  ],
  "message": "Eligible to upload sick note"
}
```

### Test Sick Note Submit Endpoint
**Endpoint:** `https://rlms.rlms.co.za/mobile/submit_sick_note.php`

**Method:** POST (multipart/form-data)
**Body:**
```
learner_id=11701
date_from=2026-07-22
date_to=2026-07-22
practice_name=Test Clinic
practitioner_name=Dr. Test
document=[PDF file]
```

**Expected response:**
```json
{
  "status": "success",
  "message": "Sick note submitted successfully and is pending approval.",
  "note_id": 1,
  "date_from": "2026-07-22",
  "date_to": "2026-07-22",
  "document_path": "uploads/sick_notes/sick_note_11701_20260723_123456.pdf"
}
```

---

## 🐛 Troubleshooting

### ARPL Hierarchy Returns Electrician Instead of Bricklayer
**Possible causes:**
1. File not uploaded correctly
2. Old PHP file cached (clear PHP opcache)
3. Database issue - check `arpl_trades` table:
   ```sql
   SELECT * FROM arpl_trades;
   ```
4. Class missing `trade_id`:
   ```sql
   SELECT classID, className, trade_id FROM class WHERE classID = 797;
   ```

**Solution:**
- Re-upload file
- Clear server cache: `php artisan cache:clear` (if Laravel) or restart PHP-FPM
- Check PHP error logs: `/var/log/php_errors.log`

### Sick Note Upload Fails
**Possible causes:**
1. Directory doesn't exist: `/public_html/uploads/sick_notes/`
2. Directory permissions wrong (needs 755)
3. PHP file size limit too small
4. Connection to database failed

**Solution:**
- Create directory and set permissions
- Check PHP settings:
  ```ini
  upload_max_filesize = 10M
  post_max_size = 10M
  ```
- Check PHP error logs

### "Invalid learner ID" Error
**Cause:** POST data not received correctly

**Solution:**
- Check request Content-Type: `application/x-www-form-urlencoded` or `multipart/form-data`
- Check PHP input handling in code

---

## 📞 Quick Test Commands

### Test with cURL (ARPL Hierarchy)
```bash
curl "https://rlms.rlms.co.za/mobile/get_arpl_hierarchy.php?learner_id=11701"
```

### Test with cURL (Sick Note Eligibility)
```bash
curl -X POST https://rlms.rlms.co.za/mobile/get_sick_note_eligible_dates.php \
  -d "learner_id=11701"
```

### Test with cURL (Sick Note Submit)
```bash
curl -X POST https://rlms.rlms.co.za/mobile/submit_sick_note.php \
  -F "learner_id=11701" \
  -F "date_from=2026-07-22" \
  -F "date_to=2026-07-22" \
  -F "practice_name=Test Clinic" \
  -F "practitioner_name=Dr. Test" \
  -F "document=@sick_note.pdf"
```

---

## 📱 Device Testing

### After Upload, Test on Device:
1. **ARPL Hierarchy:**
   - Login as ARPL Assessor
   - Navigate to class with Bricklayer trade
   - Click learner → View ARPL breakdown
   - Verify cards show "Bricklayer" not "Electrician"
   - Check logcat: `adb logcat | findstr ARPL`

2. **Sick Note:**
   - Login as learner (ID: 11701 or any learner with clocking history)
   - Navigate to Sick Note page
   - Verify eligible dates show correctly
   - Try uploading a PDF sick note
   - Verify success message appears
   - Check database: `SELECT * FROM sick_note WHERE learner_id = 11701;`

---

## 🎯 Success Criteria

### ARPL Hierarchy Fix Success:
- ✅ Cards show correct trade name from database
- ✅ Debug logs show "From arpl_trades table - Trade: [TradeName]"
- ✅ No more hardcoded "Electrician" for non-electrician trades

### Sick Note Feature Success:
- ✅ First-time learners rejected with proper message
- ✅ Eligible dates calculated correctly (last 5 working days)
- ✅ PDF upload works and file saved to server
- ✅ Record inserted into `sick_note` table with status='PENDING'
- ✅ Validation prevents duplicate uploads for same date

---

## 📝 Database Queries for Verification

### Check ARPL Trades Table
```sql
SELECT * FROM arpl_trades;
```

### Check Class Trade Assignment
```sql
SELECT c.classID, c.className, c.trade_id, t.trade_name, t.ofo_number
FROM class c
LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
WHERE c.classID = 797;
```

### Check Learner Clocking History (for sick note eligibility)
```sql
SELECT COUNT(*) as count FROM learner_clocking WHERE LearnerID = 11701;
```

### Check Sick Note Records
```sql
SELECT * FROM sick_note WHERE learner_id = 11701 ORDER BY upload_date DESC;
```

### Check Manual Clocking Records
```sql
SELECT * FROM manual_clocking WHERE LearnerID = 11701 ORDER BY clock_date DESC;
```

---

## ⚠️ Important Notes

1. **Backup before upload:** Always backup existing files before replacing
2. **Test on staging first:** If server has staging environment, test there first
3. **Monitor logs:** Watch PHP error logs during testing
4. **Clear cache:** Clear PHP opcache after upload if changes don't reflect
5. **Database connection:** Verify `connection.php` is working correctly

---

## 📧 Contact for Issues

If upload fails or testing reveals issues, check:
1. Server PHP error logs
2. Database connection settings
3. File permissions (PHP files: 644, directories: 755)
4. PHP version compatibility (requires PHP 7.4+)
