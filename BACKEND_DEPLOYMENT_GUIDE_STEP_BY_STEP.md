# 📋 BACKEND DEPLOYMENT - STEP BY STEP GUIDE

**Date:** July 22, 2026  
**Task:** Deploy Gap Closure Backend for Electrician and Plumber

---

## 📦 FILES TO DEPLOY

### SQL Scripts (2 files):
1. ✅ `create_electrician_gap_closure_tables.sql`
2. ✅ `create_plumber_gap_closure_tables.sql`

### PHP Files (5 files):
3. ✅ `mobile/get_electrician_gap_unit_standards.php`
4. ✅ `mobile/save_electrician_gap_closure.php`
5. ✅ `mobile/get_plumber_gap_unit_standards.php`
6. ✅ `mobile/save_plumber_gap_closure.php`
7. ✅ `verify_qualification_ofo_mapping.php` (root folder)

---

## 🎯 STEP 1: VERIFY DATABASE STRUCTURE (5 minutes)

### A. Check Electrician Unit Standards Table

Open phpMyAdmin SQL tab and run:

```sql
-- Check if occupational_unit_standards table exists
SHOW TABLES LIKE 'occupational_unit_standards';

-- Check Electrician data
SELECT COUNT(*) as electrician_count 
FROM occupational_unit_standards 
WHERE qualification_id = 91761;

-- View sample data
SELECT unit_standard_id, unit_standard_name, credits 
FROM occupational_unit_standards 
WHERE qualification_id = 91761 
LIMIT 5;
```

**Expected:** Should show table exists and has records for qualification 91761

### B. Check Bricklayer/Plumber Unit Standards Table

```sql
-- Check if unitstandard table exists
SHOW TABLES LIKE 'unitstandard';

-- Check Bricklayer/Plumber data (same qualification)
SELECT COUNT(*) as bricklayer_plumber_count 
FROM unitstandard 
WHERE qualification_id = 65409;

-- View sample data
SELECT unit_standard_id, unit_standard_name, credits 
FROM unitstandard 
WHERE qualification_id = 65409 
LIMIT 5;
```

**Expected:** Should show 35 records for qualification 65409

### C. Check Access Recommendation Tables

```sql
-- Check all 3 access recommendation tables exist
SHOW TABLES LIKE 'arpl%access_recommendation';

-- Should show:
-- arplbricklayer_access_recommendation
-- arplelectrician_access_recommendation
-- arplplumber_access_recommendation
```

**✅ CHECKPOINT:** All tables exist and have data before proceeding

---

## 🎯 STEP 2: CREATE GAP CLOSURE TABLES (5 minutes)

### A. Create Electrician Gap Unit Standards Table

In phpMyAdmin → SQL tab, copy and paste entire content from:

**File:** `create_electrician_gap_closure_tables.sql`

Key lines:
```sql
CREATE TABLE IF NOT EXISTS arplelectrician_gap_unit_standards (
    id INT(10) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    learner_id INT(11) NOT NULL,
    recommendation_id INT(10) UNSIGNED,
    unit_standard_id VARCHAR(50) NOT NULL,
    unit_standard_name TEXT,
    qualification_id INT(11) NOT NULL DEFAULT 91761,
    ...
);
```

Click "Go" and verify success message.

### B. Create Plumber Gap Unit Standards Table

In phpMyAdmin → SQL tab, copy and paste entire content from:

**File:** `create_plumber_gap_closure_tables.sql`

Key lines:
```sql
CREATE TABLE IF NOT EXISTS arplplumber_gap_unit_standards (
    id INT(10) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    learner_id INT(11) NOT NULL,
    recommendation_id INT(10) UNSIGNED,
    unit_standard_id VARCHAR(50) NOT NULL,
    unit_standard_name TEXT,
    qualification_id INT(11) NOT NULL DEFAULT 65409,
    ...
);
```

Click "Go" and verify success message.

### C. Verify Tables Created

```sql
-- Check both new tables exist
SHOW TABLES LIKE '%gap_unit_standards';

-- Should show:
-- arplbricklayer_gap_unit_standards (already existed)
-- arplelectrician_gap_unit_standards (NEW)
-- arplplumber_gap_unit_standards (NEW)
```

**✅ CHECKPOINT:** All 3 gap_unit_standards tables exist

---

## 🎯 STEP 3: UPLOAD PHP FILES (10 minutes)

### A. Upload to `/mobile/` Folder

Using FTP, cPanel File Manager, or your hosting control panel:

**Upload these 4 files to:** `https://rlms.rlms.co.za/mobile/`

```
1. get_electrician_gap_unit_standards.php
2. save_electrician_gap_closure.php
3. get_plumber_gap_unit_standards.php
4. save_plumber_gap_closure.php
```

### B. Upload to Root Folder

**Upload this file to:** `https://rlms.rlms.co.za/`

```
5. verify_qualification_ofo_mapping.php
```

### C. Verify Files Uploaded

Open these URLs in browser (should show PHP output, not 404):

```
https://rlms.rlms.co.za/mobile/get_electrician_gap_unit_standards.php
https://rlms.rlms.co.za/mobile/save_electrician_gap_closure.php
https://rlms.rlms.co.za/mobile/get_plumber_gap_unit_standards.php
https://rlms.rlms.co.za/mobile/save_plumber_gap_closure.php
https://rlms.rlms.co.za/verify_qualification_ofo_mapping.php
```

**✅ CHECKPOINT:** All 5 files accessible (may show errors without POST data - that's OK)

---

## 🎯 STEP 4: RUN VERIFICATION SCRIPT (2 minutes)

### Open Verification Page

Open in browser:
```
https://rlms.rlms.co.za/verify_qualification_ofo_mapping.php
```

### What to Look For:

**1. Standard Unit Standards Table (Bricklayer & Plumber):**
- Should show qualification_id 65409
- Should show 35 unit standards

**2. Occupational Unit Standards Table (Electrician):**
- Should show qualification_id 91761
- Should show X unit standards (your data)

**3. ARPL Access Recommendation Tables:**
- All 3 should show as existing
- May show different record counts

**4. Trade Configuration Summary:**
- Bricklayer: OFO 641201 → Qual 65409 → unitstandard table → 35 records
- Electrician: OFO 671101 → Qual 91761 → occupational_unit_standards → X records
- Plumber: OFO 642601 → Qual 65409 → unitstandard table → 35 records

**✅ CHECKPOINT:** All data verified correctly

---

## 🎯 STEP 5: TEST ENDPOINTS (10 minutes)

### Test Method 1: Using Browser

**For GET requests** (will show error but proves file works):
```
https://rlms.rlms.co.za/mobile/get_electrician_gap_unit_standards.php
```

Should show JSON error about missing learnerID (that's correct!)

### Test Method 2: Using Postman or cURL

#### Test Electrician Endpoint:

**Request:**
```bash
curl -X POST https://rlms.rlms.co.za/mobile/get_electrician_gap_unit_standards.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID": 11701, "qualification_id": 91761}'
```

**Expected Response:**
```json
{
  "status": "success",
  "learnerID": 11701,
  "qualification_id": 91761,
  "trade": "electrician",
  "ofo_code": "671101",
  "unit_standards": [...array of unit standards...],
  "selected_unit_standards": [],
  "total_available": X,
  "total_selected": 0
}
```

#### Test Plumber Endpoint:

**Request:**
```bash
curl -X POST https://rlms.rlms.co.za/mobile/get_plumber_gap_unit_standards.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID": 11701, "qualification_id": 65409}'
```

**Expected Response:**
```json
{
  "status": "success",
  "learnerID": 11701,
  "qualification_id": 65409,
  "trade": "plumber",
  "ofo_code": "642601",
  "unit_standards": [...35 unit standards...],
  "selected_unit_standards": [],
  "total_available": 35,
  "total_selected": 0
}
```

**✅ CHECKPOINT:** Both endpoints return success with unit standards

---

## 🎯 STEP 6: TEST SAVE FUNCTIONALITY (Optional - 5 minutes)

### Test Electrician Save:

**Request:**
```bash
curl -X POST https://rlms.rlms.co.za/mobile/save_electrician_gap_closure.php \
  -H "Content-Type: application/json" \
  -d '{
    "learnerID": 11701,
    "recommendations": [
      {"acrid": 1, "status": "Recommended", "remarks": "Test"},
      {"acrid": 2, "status": "Recommended", "remarks": "Test"},
      {"acrid": 3, "status": "Recommended", "remarks": "Test"},
      {"acrid": 4, "status": "Recommended for Gap Closure", "remarks": "Test"}
    ],
    "selected_unit_standards": [],
    "ofo_code": "671101",
    "trade": "electrician"
  }'
```

**Expected Response:**
```json
{
  "status": "success",
  "message": "Electrician gap closure recommendations saved successfully",
  "learner_id": 11701,
  "recommendation_id": X,
  "overall_result_status": "Recommended for Gap Closure",
  "unit_standards_saved": 0,
  "next_action": "gap_closure"
}
```

### Verify Data Saved:

```sql
-- Check recommendations saved
SELECT * FROM arplelectrician_access_recommendation 
WHERE LearnerID = 11701 
ORDER BY ACRID;

-- Should show 4 records (ACRID 1, 2, 3, 4)
```

**✅ CHECKPOINT:** Data saves correctly to database

---

## 📊 DEPLOYMENT CHECKLIST

### Database:
- ☐ Verified `occupational_unit_standards` table exists
- ☐ Verified Electrician has data (qual 91761) in `occupational_unit_standards`
- ☐ Verified Plumber has 35 records (qual 65409) in `unitstandard`
- ☐ Created `arplelectrician_gap_unit_standards` table
- ☐ Created `arplplumber_gap_unit_standards` table
- ☐ All 3 access_recommendation tables exist

### Files:
- ☐ Uploaded `get_electrician_gap_unit_standards.php`
- ☐ Uploaded `save_electrician_gap_closure.php`
- ☐ Uploaded `get_plumber_gap_unit_standards.php`
- ☐ Uploaded `save_plumber_gap_closure.php`
- ☐ Uploaded `verify_qualification_ofo_mapping.php`

### Testing:
- ☐ Ran verification script successfully
- ☐ Tested Electrician get endpoint
- ☐ Tested Plumber get endpoint
- ☐ Both endpoints return unit standards
- ☐ (Optional) Tested save functionality

---

## ✅ SUCCESS CRITERIA

**Backend is ready when:**
1. ✅ All tables exist and have correct structure
2. ✅ Electrician endpoint returns unit standards from `occupational_unit_standards`
3. ✅ Plumber endpoint returns 35 unit standards from `unitstandard`
4. ✅ Both save endpoints work without errors
5. ✅ Data persists correctly in database

---

## ⚠️ TROUBLESHOOTING

### If Electrician Shows 0 Unit Standards:

**Problem:** `occupational_unit_standards` table empty for qualification 91761

**Check:**
```sql
SELECT * FROM occupational_unit_standards WHERE qualification_id = 91761;
```

**Solution:** Need to populate this table with Electrician unit standards data

### If Plumber Shows 0 Unit Standards:

**Problem:** Should NOT happen - shares data with Bricklayer

**Check:**
```sql
SELECT * FROM unitstandard WHERE qualification_id = 65409;
```

**Expected:** Should always show 35 records

### If Endpoint Returns 404:

**Problem:** File not uploaded correctly

**Solution:** 
- Verify file uploaded to correct folder (`/mobile/`)
- Check filename matches exactly (case-sensitive on Linux servers)
- Verify file permissions (644 or 755)

### If Endpoint Returns Database Error:

**Problem:** Table doesn't exist or connection issue

**Solution:**
- Run verification script to check table structure
- Verify `connection.php` has correct database credentials
- Check error message for specific table name

---

## 📞 REPORT BACK WITH:

After completing deployment, let me know:

1. ✅ Verification script results (screenshot or copy/paste)
2. ✅ Electrician endpoint test result (total_available count)
3. ✅ Plumber endpoint test result (should show 35)
4. ⚠️ Any errors encountered

---

**Next Step After Backend Works:** Implement Flutter UI for Electrician and Plumber gap closure

**See:** `FINAL_GAP_CLOSURE_CONFIGURATION.md` for complete technical details
