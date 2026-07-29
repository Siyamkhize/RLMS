# 🔍 APPENDIX F TROUBLESHOOTING GUIDE

**Problem:** Workplace Observation section not showing data  
**Status:** Endpoints uploaded, but data still not appearing

---

## 🎯 DIAGNOSTIC STEPS

### STEP 1: Test the Diagnostic Endpoint

I've created a test script to diagnose the issue.

**Upload this file:**
- `mobile/test_appendix_f_endpoint.php`

**Then visit:**
```
https://rlms.rlms.co.za/mobile/test_appendix_f_endpoint.php
```

**This will test:**
1. ✅ Does `arplappxe_bricklaying_activities` table exist?
2. ✅ What are the column names?
3. ✅ How many activities are in the table?
4. ✅ Sample activities data
5. ✅ Do Appendix F tables exist?
6. ✅ Can we simulate the actual query?
7. ✅ Database connection working?

**Expected Output:**
```json
{
  "status": "testing",
  "tests": {
    "table_exists": {
      "status": "PASS",
      "table_name": "arplappxe_bricklaying_activities",
      "exists": true
    },
    "table_structure": {
      "status": "INFO",
      "columns": ["activity_id", "activity_number", "activity_name", "ofo_number", "created_at"]
    },
    "activity_count": {
      "status": "PASS",
      "total_activities": 20
    },
    "sample_activities": {
      "status": "INFO",
      "samples": [...]
    },
    ...
  }
}
```

---

### STEP 2: Verify Appendix F Tables Were Created

**In phpMyAdmin, run:**
```sql
SHOW TABLES LIKE 'arpl_appendix_f%';
```

**Should show 3 tables:**
- `arpl_appendix_f_knowledge`
- `arpl_appendix_f_practical_tasks`
- `arpl_appendix_f_workplace_observations`

**If tables DON'T exist:**
You need to execute `create_appendix_f_redesign_tables.sql` in phpMyAdmin.

---

### STEP 3: Test the Actual Endpoint

**Using a tool like Postman or curl:**

```bash
curl -X POST https://rlms.rlms.co.za/mobile/get_appendix_f_data.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID": 11701, "ofoNumber": "641201"}'
```

**Or test in browser console (while on your website):**
```javascript
fetch('https://rlms.rlms.co.za/mobile/get_appendix_f_data.php', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    learnerID: 11701,
    ofoNumber: "641201"
  })
})
.then(r => r.json())
.then(d => console.log(d));
```

**Expected Response:**
```json
{
  "status": "success",
  "data": {
    "knowledge": [],
    "practical": [],
    "workplace_observations": [
      {
        "activity_id": 1,
        "task_observed": "Reinforced Concrete Construction",
        "technical_knowledge": 1,
        "interpretation_of_instructions": 1,
        "team_work_attitude": 1,
        "has_rating": false
      },
      ...
    ]
  }
}
```

---

### STEP 4: Check File Upload Locations

**Verify files are in the correct location:**

1. Login to your server via FTP/cPanel
2. Navigate to `/mobile/` folder
3. Verify these files exist:
   - `get_appendix_f_data.php`
   - `save_appendix_f_data.php`

**Check file permissions:**
Both files should have read permissions (typically 644 or 755).

---

### STEP 5: Check for PHP Errors

**Add error logging to the top of `get_appendix_f_data.php`:**

```php
<?php
// Add these lines at the very top (after opening PHP tag)
ini_set('display_errors', 1);
ini_set('log_errors', 1);
error_reporting(E_ALL);

// Then continue with existing code...
header('Content-Type: application/json');
require_once 'connection.php';
```

**Then check:**
- Browser console for errors
- Server error logs (in cPanel or via SSH)

---

## 🐛 COMMON ISSUES & SOLUTIONS

### Issue 1: 404 Error - File Not Found

**Symptoms:**
- HTTP 404 response
- "File not found" error

**Solutions:**
1. Verify file was uploaded to `/mobile/` folder (not `/mobile/mobile/`)
2. Check file name is exactly: `get_appendix_f_data.php` (no typos)
3. Check file permissions (should be readable)

---

### Issue 2: Database Connection Error

**Symptoms:**
```json
{
  "status": "error",
  "message": "Connection failed..."
}
```

**Solutions:**
1. Verify `connection.php` exists in `/mobile/` folder
2. Check database credentials in `connection.php`
3. Verify database server is running

---

### Issue 3: Table Doesn't Exist

**Symptoms:**
```json
{
  "status": "error",
  "message": "Activities table 'arplappxe_bricklaying_activities' does not exist..."
}
```

**Solutions:**
1. Check table exists: `SHOW TABLES LIKE 'arplappxe_bricklaying_activities';`
2. If table doesn't exist, you need to create it (should already exist from previous ARPL work)
3. Verify table has data: `SELECT COUNT(*) FROM arplappxe_bricklaying_activities;`

---

### Issue 4: Wrong Column Names

**Symptoms:**
```json
{
  "status": "error",
  "message": "Unknown column 'id' in 'SELECT'"
}
```

**Solutions:**
1. This should be fixed in the uploaded file
2. Verify uploaded file is the CORRECTED version using `activity_id` and `activity_name`
3. Check file timestamp to ensure latest version uploaded

---

### Issue 5: Appendix F Tables Don't Exist

**Symptoms:**
Query works but returns SQL error about missing tables

**Solutions:**
1. Execute `create_appendix_f_redesign_tables.sql` in phpMyAdmin
2. Verify tables created: `SHOW TABLES LIKE 'arpl_appendix_f%';`

---

### Issue 6: Empty Response (200 OK but no data)

**Symptoms:**
```json
{
  "status": "success",
  "data": {
    "knowledge": [],
    "practical": [],
    "workplace_observations": []
  }
}
```

**Cause:** Activities table is empty

**Solutions:**
1. Check table has data: `SELECT * FROM arplappxe_bricklaying_activities LIMIT 5;`
2. If empty, you need to populate the activities table

---

### Issue 7: App Shows "Loading..." Forever

**Symptoms:**
- Appendix F tab shows loading spinner
- Never completes

**Solutions:**
1. **Timeout Issue:** App times out after 10 seconds
2. Check Flutter console for timeout message
3. Test endpoint manually (Step 3 above)
4. If endpoint is slow, optimize database queries or add indexes

---

## 📱 APP-SIDE DEBUGGING

### View Console Logs

When testing in the app, check for these console messages:

**Success:**
```
✅ Appendix F loaded: X observations
```

**Timeout:**
```
⚠️ Appendix F load timeout - backend files may not be deployed yet
```

**API Error:**
```
⚠️ Appendix F API error: [error message]
```

**HTTP Error:**
```
⚠️ Appendix F load failed: HTTP 404
```

**Exception:**
```
❌ Error loading Appendix F data: [exception]
```

---

## 🔧 MANUAL DATABASE QUERY TEST

**In phpMyAdmin, run this query directly:**

```sql
SELECT 
    a.activity_id,
    a.activity_name as task_observed,
    COALESCE(wo.technical_knowledge, 1) as technical_knowledge,
    COALESCE(wo.interpretation_of_instructions, 1) as interpretation_of_instructions,
    COALESCE(wo.team_work_attitude, 1) as team_work_attitude,
    wo.id as observation_id
FROM arplappxe_bricklaying_activities a
LEFT JOIN arpl_appendix_f_workplace_observations wo
    ON a.activity_id = wo.activity_id 
    AND wo.learnerID = 11701
    AND wo.ofoNumber = '641201'
ORDER BY a.activity_id ASC
LIMIT 5;
```

**Expected Result:**
- Should return 5 rows
- Each row should have activity_id and activity_name
- observation_id should be NULL (no ratings yet)
- Ratings should default to 1

**If this query fails:**
- Check error message
- Verify table names are correct
- Verify columns exist

---

## ✅ VERIFICATION CHECKLIST

After each fix, verify:

- [ ] Diagnostic endpoint returns PASS for all tests
- [ ] Manual endpoint test returns workplace_observations array
- [ ] Array has activities with correct structure
- [ ] Appendix F tables exist in database
- [ ] Activities table has data (20+ rows)
- [ ] PHP files have no syntax errors
- [ ] File permissions are correct
- [ ] Connection.php is working
- [ ] App loads Appendix F tab without timeout
- [ ] Workplace Observation section shows activities
- [ ] Dropdowns show in edit mode

---

## 🚀 QUICK FIX SUMMARY

**Most Likely Issues:**

1. **Appendix F tables not created**
   - Solution: Execute `create_appendix_f_redesign_tables.sql`

2. **Wrong file uploaded**
   - Solution: Re-upload the CORRECTED `get_appendix_f_data.php`

3. **File uploaded to wrong location**
   - Solution: Move to `/mobile/get_appendix_f_data.php`

4. **Activities table is empty**
   - Solution: Populate activities table (should already exist)

---

## 📞 REPORT RESULTS

After running the diagnostic endpoint, **send me the JSON output** and I can pinpoint the exact issue.

Upload `test_appendix_f_endpoint.php` and visit:
```
https://rlms.rlms.co.za/mobile/test_appendix_f_endpoint.php
```

Copy the entire JSON output and share it.
