# ✅ FINAL GAP CLOSURE CONFIGURATION - COMPLETE

**Date:** July 22, 2026  
**Status:** All files corrected with proper table names

---

## 🎯 COMPLETE SYSTEM ARCHITECTURE

### Database Table Structure:

| Trade | OFO Code | Qualification ID | Unit Standards Table | Records |
|-------|----------|------------------|---------------------|---------|
| **Bricklayer** | 641201 | 65409 | `unitstandard` | 35 ✅ |
| **Electrician** | 671101 | 91761 | `occupational_unit_standards` | ? ⚠️ |
| **Plumber** | 642601 | 65409 | `unitstandard` | 35 ✅ (shared with Bricklayer) |

---

## 🔑 KEY DIFFERENCES

### Electrician is Special:
- ✅ Uses **different table**: `occupational_unit_standards` (NOT `unitstandard`)
- ✅ Uses **different qualification ID**: 91761
- ✅ Has separate qualification framework from Bricklayer/Plumber

### Bricklayer & Plumber Share Everything:
- ✅ Both use `unitstandard` table
- ✅ Both use qualification ID **65409**
- ✅ Both have access to same 35 unit standards
- ✅ This is correct - they're in the same qualification framework

---

## ✅ CORRECTED PHP FILES

### Electrician Files (uses `occupational_unit_standards` table):

**`mobile/get_electrician_gap_unit_standards.php`**
```php
// Queries: occupational_unit_standards WHERE qualification_id = 91761
FROM occupational_unit_standards
WHERE qualification_id = ?
```

**`mobile/save_electrician_gap_closure.php`**
```php
// Inserts FROM: occupational_unit_standards WHERE qualification_id = 91761
FROM occupational_unit_standards us
WHERE us.unit_standard_id IN (...)
AND us.qualification_id = 91761
```

### Plumber Files (uses standard `unitstandard` table):

**`mobile/get_plumber_gap_unit_standards.php`**
```php
// Queries: unitstandard WHERE qualification_id = 65409
FROM unitstandard
WHERE qualification_id = ?
```

**`mobile/save_plumber_gap_closure.php`**
```php
// Inserts FROM: unitstandard WHERE qualification_id = 65409
FROM unitstandard us
WHERE us.unit_standard_id IN (...)
AND us.qualification_id = 65409
```

---

## 📊 DATABASE VERIFICATION

### Check Electrician Unit Standards:
```sql
-- Electrician uses occupational_unit_standards table
SELECT COUNT(*) as count 
FROM occupational_unit_standards 
WHERE qualification_id = 91761;

-- Show sample data
SELECT unit_standard_id, unit_standard_name, credits 
FROM occupational_unit_standards 
WHERE qualification_id = 91761 
LIMIT 10;
```

### Check Bricklayer/Plumber Unit Standards:
```sql
-- Both use standard unitstandard table
SELECT COUNT(*) as count 
FROM unitstandard 
WHERE qualification_id = 65409;

-- Should show 35 records
SELECT unit_standard_id, unit_standard_name, credits 
FROM unitstandard 
WHERE qualification_id = 65409 
LIMIT 10;
```

---

## 🚀 DEPLOYMENT STEPS

### STEP 1: Verify Tables Exist

Run these queries to check both tables:

```sql
-- Check standard table (for Bricklayer & Plumber)
SHOW TABLES LIKE 'unitstandard';

-- Check occupational table (for Electrician)
SHOW TABLES LIKE 'occupational_unit_standards';
```

### STEP 2: Verify Data Exists

```sql
-- Bricklayer & Plumber (should show 35)
SELECT COUNT(*) FROM unitstandard WHERE qualification_id = 65409;

-- Electrician (should show > 0)
SELECT COUNT(*) FROM occupational_unit_standards WHERE qualification_id = 91761;
```

### STEP 3: Create Gap Closure Tables

Run SQL scripts via phpMyAdmin:

**A. Electrician:**
```sql
-- File: create_electrician_gap_closure_tables.sql
-- Creates: arplelectrician_gap_unit_standards
-- Uses: occupational_unit_standards table
```

**B. Plumber:**
```sql
-- File: create_plumber_gap_closure_tables.sql  
-- Creates: arplplumber_gap_unit_standards
-- Uses: unitstandard table
```

### STEP 4: Upload PHP Files

Upload 4 corrected files to production `/mobile/`:

```
✅ get_electrician_gap_unit_standards.php  (queries occupational_unit_standards)
✅ save_electrician_gap_closure.php         (inserts from occupational_unit_standards)
✅ get_plumber_gap_unit_standards.php       (queries unitstandard)
✅ save_plumber_gap_closure.php             (inserts from unitstandard)
```

### STEP 5: Upload Verification Script

Upload and run:
```
https://rlms.rlms.co.za/verify_qualification_ofo_mapping.php
```

This will show:
- Standard unit standards (Bricklayer & Plumber)
- Occupational unit standards (Electrician)
- Complete OFO-to-Qualification mapping
- Trade-specific configuration

### STEP 6: Test Endpoints

**Test Electrician (occupational_unit_standards):**
```bash
curl -X POST https://rlms.rlms.co.za/mobile/get_electrician_gap_unit_standards.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID": 11701, "qualification_id": 91761}'
```

Expected: Returns unit standards from `occupational_unit_standards` table

**Test Plumber (unitstandard):**
```bash
curl -X POST https://rlms.rlms.co.za/mobile/get_plumber_gap_unit_standards.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID": 11701, "qualification_id": 65409}'
```

Expected: Returns 35 unit standards from `unitstandard` table (same as Bricklayer)

---

## 📋 VERIFICATION CHECKLIST

### Backend Verification:
- ☐ Verify `occupational_unit_standards` table exists
- ☐ Verify Electrician (91761) has data in `occupational_unit_standards`
- ☐ Verify Bricklayer/Plumber (65409) has 35 records in `unitstandard`
- ☐ Create `arplelectrician_gap_unit_standards` table
- ☐ Create `arplplumber_gap_unit_standards` table
- ☐ Upload 4 corrected PHP files
- ☐ Run verification script
- ☐ Test Electrician endpoint
- ☐ Test Plumber endpoint

### Expected Results:
- ☐ Electrician shows X unit standards from `occupational_unit_standards`
- ☐ Plumber shows 35 unit standards from `unitstandard`
- ☐ Both endpoints return `"status": "success"`

---

## ⚙️ HOW IT WORKS

### For Electrician:
1. Assessor selects "Recommended for Gap Closure"
2. Call: `get_electrician_gap_unit_standards.php?qualification_id=91761`
3. Query: `SELECT * FROM occupational_unit_standards WHERE qualification_id = 91761`
4. Returns: List of electrician-specific unit standards
5. Assessor selects unit standards
6. Save: Inserts into `arplelectrician_gap_unit_standards` table

### For Plumber:
1. Assessor selects "Recommended for Gap Closure"
2. Call: `get_plumber_gap_unit_standards.php?qualification_id=65409`
3. Query: `SELECT * FROM unitstandard WHERE qualification_id = 65409`
4. Returns: List of 35 unit standards (same as Bricklayer)
5. Assessor selects unit standards
6. Save: Inserts into `arplplumber_gap_unit_standards` table

---

## 🔍 TROUBLESHOOTING

### If Electrician Shows 0 Unit Standards:

**Problem:** `occupational_unit_standards` table is empty or doesn't have qual ID 91761

**Check:**
```sql
SELECT * FROM occupational_unit_standards WHERE qualification_id = 91761;
```

**Solution:** Add unit standards data to `occupational_unit_standards` table

### If Plumber Shows 0 Unit Standards:

**Problem:** Should NOT happen - uses same qual ID as Bricklayer (65409)

**Check:**
```sql
SELECT * FROM unitstandard WHERE qualification_id = 65409;
```

**Expected:** Should show 35 records (same as Bricklayer)

---

## 📞 FINAL STATUS

| Component | Bricklayer | Electrician | Plumber |
|-----------|-----------|-------------|---------|
| OFO Code | 641201 | 671101 | 642601 |
| Qualification ID | 65409 | 91761 | 65409 |
| Unit Standards Table | `unitstandard` | `occupational_unit_standards` | `unitstandard` |
| Unit Standards Count | 35 ✅ | ? ⚠️ | 35 ✅ |
| Access Table | ✅ Exists | ✅ Exists | ✅ Exists |
| Gap Table | ✅ Exists | ⏳ Create | ⏳ Create |
| PHP Files | ✅ Working | ✅ Corrected | ✅ Corrected |
| Table Name | ✅ Correct | ✅ Corrected | ✅ Correct |

---

## ✅ FILES READY FOR DEPLOYMENT

All files have been corrected with proper table names:

1. ✅ `mobile/get_electrician_gap_unit_standards.php` - Uses `occupational_unit_standards`
2. ✅ `mobile/save_electrician_gap_closure.php` - Uses `occupational_unit_standards`
3. ✅ `mobile/get_plumber_gap_unit_standards.php` - Uses `unitstandard`
4. ✅ `mobile/save_plumber_gap_closure.php` - Uses `unitstandard`
5. ✅ `create_electrician_gap_closure_tables.sql` - Updated with correct table
6. ✅ `create_plumber_gap_closure_tables.sql` - Uses standard table
7. ✅ `verify_qualification_ofo_mapping.php` - Checks both tables

---

**All corrections applied! Ready for deployment!**

**Generated:** July 22, 2026  
**Last Updated:** After correcting Electrician to use `occupational_unit_standards` table
