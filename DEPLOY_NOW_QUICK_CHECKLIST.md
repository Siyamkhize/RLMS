# 🚀 QUICK DEPLOYMENT CHECKLIST
**Date:** July 22, 2026  
**Status:** Backend ready, awaiting upload to production

---

## ⚠️ CURRENT ISSUE

You tried to access:
```
https://rlms.rlms.co.za/verify_qualification_ofo_mapping.php
```

**Result:** Shows "nothing" (blank page or 404 error)

**Reason:** The file `verify_qualification_ofo_mapping.php` hasn't been uploaded to your production server yet.

**Local Result:** ✅ Working correctly - shows 35 records for Bricklayer/Plumber, 22 for Electrician

---

## ✅ WHAT YOU NEED TO DO NOW

### STEP 1: Upload 5 PHP Files (5 minutes)

Using FTP, cPanel File Manager, or your hosting control panel:

#### A. Upload to `/mobile/` folder (4 files):

```
1. get_electrician_gap_unit_standards.php
2. save_electrician_gap_closure.php
3. get_plumber_gap_unit_standards.php
4. save_plumber_gap_closure.php
```

**Upload to:** `https://rlms.rlms.co.za/mobile/`

#### B. Upload to root folder (1 file):

```
5. verify_qualification_ofo_mapping.php
```

**Upload to:** `https://rlms.rlms.co.za/` (root directory, same folder as your existing PHP files)

---

### STEP 2: Run SQL Scripts (5 minutes)

Open phpMyAdmin on your production server and run these 2 SQL scripts:

#### A. Create Electrician Gap Closure Table

**File:** `create_electrician_gap_closure_tables.sql`

**Location:** Copy entire file content and paste into phpMyAdmin → SQL tab → Click "Go"

**What it creates:**
- `arplelectrician_gap_unit_standards` table (the access_recommendation table already exists)

#### B. Create Plumber Gap Closure Table

**File:** `create_plumber_gap_closure_tables.sql`

**Location:** Copy entire file content and paste into phpMyAdmin → SQL tab → Click "Go"

**What it creates:**
- `arplplumber_gap_unit_standards` table (the access_recommendation table already exists)

---

### STEP 3: Verify Upload Successful (2 minutes)

Open these URLs in your browser to confirm files uploaded correctly:

#### Verification Script (should show nice HTML page with data):
```
https://rlms.rlms.co.za/verify_qualification_ofo_mapping.php
```

**Expected:** HTML page showing:
- Bricklayer: 35 unit standards in `unitstandard` table
- Electrician: X unit standards in `occupational_unit_standards` table
- Plumber: 35 unit standards in `unitstandard` table (same as Bricklayer)

#### Gap Closure Endpoints (will show errors - that's OK!):
```
https://rlms.rlms.co.za/mobile/get_electrician_gap_unit_standards.php
https://rlms.rlms.co.za/mobile/save_electrician_gap_closure.php
https://rlms.rlms.co.za/mobile/get_plumber_gap_unit_standards.php
https://rlms.rlms.co.za/mobile/save_plumber_gap_closure.php
```

**Expected:** JSON error like `{"status":"error","message":"Missing or invalid learnerID"}`
- ✅ This is GOOD - means the file is accessible and working
- ❌ If you see "404 Not Found" - file wasn't uploaded correctly

---

### STEP 4: Verify Database Has Data (3 minutes)

Run these queries in phpMyAdmin → SQL tab:

#### Check Electrician Unit Standards (uses `occupational_unit_standards` table):
```sql
SELECT COUNT(*) as electrician_count 
FROM occupational_unit_standards 
WHERE qualification_id = 91761;
```

**Expected:** Should show a number > 0 (your local showed 22)

#### Check Plumber Unit Standards (uses `unitstandard` table):
```sql
SELECT COUNT(*) as plumber_count 
FROM unitstandard 
WHERE qualification_id = 65409;
```

**Expected:** Should show 35 (same as Bricklayer)

#### Check Gap Closure Tables Created:
```sql
SHOW TABLES LIKE '%gap_unit_standards';
```

**Expected:** Should show 3 tables:
- `arplbricklayer_gap_unit_standards` (already existed)
- `arplelectrician_gap_unit_standards` (NEW)
- `arplplumber_gap_unit_standards` (NEW)

---

## 📊 SIMPLIFIED CHECKLIST

### Upload Files:
- [ ] Upload `get_electrician_gap_unit_standards.php` to `/mobile/`
- [ ] Upload `save_electrician_gap_closure.php` to `/mobile/`
- [ ] Upload `get_plumber_gap_unit_standards.php` to `/mobile/`
- [ ] Upload `save_plumber_gap_closure.php` to `/mobile/`
- [ ] Upload `verify_qualification_ofo_mapping.php` to root folder

### Run SQL Scripts:
- [ ] Run `create_electrician_gap_closure_tables.sql` in phpMyAdmin
- [ ] Run `create_plumber_gap_closure_tables.sql` in phpMyAdmin

### Verify Everything Works:
- [ ] Open verification script URL - should show HTML page with data
- [ ] Check 4 endpoint URLs - should show JSON errors (not 404)
- [ ] Confirm Electrician has data in `occupational_unit_standards` table
- [ ] Confirm Plumber has 35 records in `unitstandard` table
- [ ] Confirm 2 new gap_unit_standards tables created

---

## ❓ TROUBLESHOOTING

### Problem: Verification script shows "nothing"
**Solution:** File not uploaded yet - upload `verify_qualification_ofo_mapping.php` to root folder

### Problem: Endpoint shows 404 error
**Solution:** File not uploaded to correct folder - check file is in `/mobile/` folder

### Problem: SQL script shows error about table already exists
**Solution:** That's OK! The `CREATE TABLE IF NOT EXISTS` means it will skip if table already exists

### Problem: Electrician shows 0 unit standards
**Solution:** Your production database doesn't have data in `occupational_unit_standards` table for qualification 91761 yet. Need to import this data.

### Problem: Plumber shows 0 unit standards
**Solution:** Your production database doesn't have data in `unitstandard` table for qualification 65409. This is shared with Bricklayer, so if Bricklayer works, Plumber should too.

---

## ✅ SUCCESS CRITERIA

**Backend deployment is complete when:**

1. ✅ Verification script shows HTML page with unit standard counts
2. ✅ Electrician has data in `occupational_unit_standards` (qual 91761)
3. ✅ Plumber has 35 records in `unitstandard` (qual 65409)
4. ✅ 2 new gap_unit_standards tables created successfully
5. ✅ All 4 endpoint files accessible (even if showing JSON errors)

---

## 📞 REPORT BACK

After completing the deployment steps above, share with me:

1. **Verification Script URL Result:**
   - Screenshot or copy/paste what you see at: `https://rlms.rlms.co.za/verify_qualification_ofo_mapping.php`

2. **Unit Standard Counts:**
   - Electrician count from `occupational_unit_standards`: ___
   - Plumber count from `unitstandard`: ___

3. **Any Errors:**
   - Did any SQL scripts fail?
   - Do any endpoints show 404?

---

## 🎯 NEXT STEP AFTER BACKEND WORKS

Once backend is verified and working:
- Implement Flutter UI for Electrician and Plumber gap closure
- Reuse existing Bricklayer gap closure UI pattern
- Build new APK
- Test end-to-end workflow

**For now:** Focus on getting backend deployed and verified!

---

**Files Location on Your Computer:**
- SQL Scripts: `c:\projects\rlmss\`
- PHP Files: `c:\projects\rlmss\mobile\`
- Verification Script: `c:\projects\rlmss\`
