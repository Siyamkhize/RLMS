# 🚀 RE-UPLOAD NOW - COLUMN NAME ISSUE FIXED
**Date:** July 22, 2026

---

## ✅ PROBLEM SOLVED

**Your Error:**
```
Fatal error: Unknown column 'unit_standard_id' in 'SELECT'
```

**Cause:** `unitstandard` table uses column `id` (not `unit_standard_id`)

**Solution:** Fixed all files to use correct column names

---

## 📦 FILES TO RE-UPLOAD

All files have been fixed and are ready to re-upload:

### Upload to Root Folder:
```
1. verify_qualification_ofo_mapping.php (FIXED - uses 'id' column)
```

### Upload to `/mobile/` Folder:
```
2. get_electrician_gap_unit_standards.php (Already correct)
3. save_electrician_gap_closure.php (Already correct)
4. get_plumber_gap_unit_standards.php (FIXED - uses 'id' column)
5. save_plumber_gap_closure.php (FIXED - uses 'id' column)
```

---

## 🎯 DO THIS NOW (5 minutes)

### STEP 1: Re-Upload Files

Using cPanel File Manager or FTP:

1. Go to your website root folder
2. Upload `verify_qualification_ofo_mapping.php`
3. Go to `/mobile/` folder
4. Upload all 4 PHP files

### STEP 2: Test Verification Script

Open in browser:
```
https://rlms.rlms.co.za/verify_qualification_ofo_mapping.php
```

**You should see:**
- ✅ Bricklayer/Plumber: 35 unit standards
- ✅ Electrician: 22 unit standards
- ✅ No errors!

---

## ✅ WHAT'S FIXED

| File | What Changed | Status |
|------|-------------|--------|
| verify_qualification_ofo_mapping.php | Uses `id` instead of `unit_standard_id` for unitstandard table | ✅ Fixed |
| get_plumber_gap_unit_standards.php | Query changed to `SELECT id as unit_standard_id FROM unitstandard` | ✅ Fixed |
| save_plumber_gap_closure.php | Uses `us.id` instead of `us.unit_standard_id` in WHERE clause | ✅ Fixed |
| get_electrician_gap_unit_standards.php | Already correct (uses unit_standard_id) | ✅ OK |
| save_electrician_gap_closure.php | Already correct (uses unit_standard_id) | ✅ OK |

---

## 📊 SCHEMA REFERENCE

```
occupational_unit_standards (Electrician):
  - unit_standard_id ← Correct column name
  - unit_standard_name
  - credits
  - qualification_id

unitstandard (Bricklayer & Plumber):
  - id ← Different column name!
  - unit_standard_name
  - credits
  - qualification_id
```

---

## 💡 AFTER RE-UPLOAD

Once verification script works:

1. ✅ Run SQL scripts to create gap_unit_standards tables
2. ✅ Test endpoints
3. ✅ Verify counts match (35 for Plumber, 22 for Electrician)
4. ✅ Continue with deployment

---

**Action:** Re-upload the 5 files now and test the verification script!

**Files are in:** `c:\projects\rlmss\` and `c:\projects\rlmss\mobile\`
