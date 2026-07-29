# ✅ CORRECT OFO CODE AND QUALIFICATION ID MAPPING

**Date:** July 22, 2026  
**Status:** Critical Correction Applied

---

## 🚨 IMPORTANT: OFO ≠ QUALIFICATION ID

**OFO Code** and **Qualification ID** are DIFFERENT values in your system!

### Correct Mapping:

| Trade | OFO Code | Qualification ID | Unit Standards |
|-------|----------|------------------|----------------|
| **Bricklayer** | 641201 | 65409 | ✅ 35 available |
| **Electrician** | 671101 | **91761** | ⚠️ Need to verify |
| **Plumber** | 642601 | **65409** | ✅ 35 available (SAME as Bricklayer) |

---

## 📊 KEY FINDINGS

### 1. Bricklayer
- **OFO Code:** 641201
- **Qualification ID:** 65409
- **Unit Standards:** 35 available ✅
- **Status:** Fully configured

### 2. Electrician
- **OFO Code:** 671101 (NOT the qualification ID!)
- **Qualification ID:** **91761** (this is what we query for unit standards)
- **Unit Standards:** Need to check database
- **Status:** PHP files corrected with qual ID 91761

### 3. Plumber
- **OFO Code:** 642601
- **Qualification ID:** **65409** (SAME AS BRICKLAYER!)
- **Unit Standards:** 35 available (shares with Bricklayer) ✅
- **Status:** PHP files corrected with qual ID 65409

---

## 🔍 WHY PLUMBER = BRICKLAYER QUALIFICATION ID?

Plumber and Bricklayer both use **qualification_id 65409**. This means:

✅ **They share the same unit standards** (35 unit standards)  
✅ **This is correct** if they're part of the same qualification framework  
✅ **No additional unit standards needed for Plumber**

---

## ✅ CORRECTED FILES

All PHP files and SQL scripts have been updated with correct values:

### Electrician Files (qualification_id = 91761):
- ✅ `mobile/get_electrician_gap_unit_standards.php`
- ✅ `mobile/save_electrician_gap_closure.php`
- ✅ `create_electrician_gap_closure_tables.sql`

### Plumber Files (qualification_id = 65409):
- ✅ `mobile/get_plumber_gap_unit_standards.php`
- ✅ `mobile/save_plumber_gap_closure.php`
- ✅ `create_plumber_gap_closure_tables.sql`

---

## 🎯 NEXT STEPS

### STEP 1: Verify Electrician Unit Standards

Run this query to check if Electrician has unit standards:

```sql
SELECT COUNT(*) as electrician_unit_standards 
FROM unitstandard 
WHERE qualification_id = 91761;
```

**If count > 0:** ✅ Electrician is ready  
**If count = 0:** ⚠️ Need to add unit standards for qualification 91761

### STEP 2: Run Verification Script

Upload and run:
```
https://rlms.rlms.co.za/verify_qualification_ofo_mapping.php
```

This will show:
- All qualification IDs with unit standards
- OFO codes in use
- Complete mapping verification

### STEP 3: Create Missing Database Tables

Run SQL scripts via phpMyAdmin:
- `create_electrician_gap_closure_tables.sql` (uses qual ID 91761)
- `create_plumber_gap_closure_tables.sql` (uses qual ID 65409)

### STEP 4: Upload Corrected PHP Files

Upload to production `/mobile/`:
- `get_electrician_gap_unit_standards.php`
- `save_electrician_gap_closure.php`
- `get_plumber_gap_unit_standards.php`
- `save_plumber_gap_closure.php`

---

## 📋 VERIFICATION CHECKLIST

After completing steps above:

☐ Run `verify_qualification_ofo_mapping.php`  
☐ Confirm Electrician (91761) has unit standards  
☐ Confirm Plumber (65409) shows 35 unit standards  
☐ Create missing gap_unit_standards tables  
☐ Upload 4 corrected PHP files  
☐ Test Electrician endpoint with qualification_id 91761  
☐ Test Plumber endpoint with qualification_id 65409  

---

## 🔧 HOW THE SYSTEM WORKS

### Database Tables:

**Access Recommendation Tables** (store OFO codes):
- `arplbricklayer_access_recommendation` → OFOCode = '641201'
- `arplelectrician_access_recommendation` → OFOCode = '671101'
- `arplplumber_access_recommendation` → OFOCode = '642601'

**Gap Unit Standards Tables** (store qualification IDs):
- `arplbricklayer_gap_unit_standards` → qualification_id = 65409
- `arplelectrician_gap_unit_standards` → qualification_id = 91761
- `arplplumber_gap_unit_standards` → qualification_id = 65409

### When Gap Closure is Selected:

1. Assessor selects "Recommended for Gap Closure" in Appendix H
2. System reads learner's **OFO code** (from class/trade)
3. PHP endpoint queries **qualification_id** to get unit standards
4. Returns list of available unit standards for that qualification
5. Assessor selects which unit standards learner needs
6. System saves to trade-specific gap_unit_standards table

### Example Flow for Electrician:

1. Learner has OFO code **671101** (Electrician)
2. Call `get_electrician_gap_unit_standards.php?qualification_id=91761`
3. Query: `SELECT * FROM unitstandard WHERE qualification_id = 91761`
4. Returns list of electrician unit standards
5. Assessor selects unit standards
6. Saves to `arplelectrician_gap_unit_standards` table

---

## ⚠️ COMMON MISTAKE TO AVOID

❌ **WRONG:** Using OFO code as qualification ID  
```sql
SELECT * FROM unitstandard WHERE qualification_id = 671101
-- This would fail for Electrician because qual ID is 91761, not 671101!
```

✅ **CORRECT:** Use proper qualification ID  
```sql
SELECT * FROM unitstandard WHERE qualification_id = 91761
-- This correctly queries Electrician unit standards
```

---

## 📞 STATUS SUMMARY

| Component | Bricklayer | Electrician | Plumber |
|-----------|-----------|-------------|---------|
| OFO Code | 641201 | 671101 | 642601 |
| Qualification ID | 65409 | **91761** | **65409** |
| Unit Standards | ✅ 35 | ⚠️ Check DB | ✅ 35 (shared) |
| Access Table | ✅ Exists | ✅ Exists | ✅ Exists |
| Gap Table | ✅ Exists | ⏳ Create | ⏳ Create |
| PHP Files | ✅ Working | ✅ Corrected | ✅ Corrected |

---

**Generated:** July 22, 2026  
**Last Updated:** After correcting qualification ID mapping
