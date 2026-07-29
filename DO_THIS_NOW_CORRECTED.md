# 🎯 DO THIS NOW - CORRECTED VERSION

**All files updated with correct qualification IDs!**

---

## ✅ WHAT I CORRECTED

Fixed all PHP files and SQL scripts with **correct qualification IDs**:

| Trade | OFO Code | Qualification ID | Unit Standards |
|-------|----------|------------------|----------------|
| Bricklayer | 641201 | 65409 | 35 available ✅ |
| Electrician | 671101 | **91761** | Need to check |
| Plumber | 642601 | **65409** | 35 available ✅ (same as Bricklayer) |

---

## 🚀 YOUR ACTION ITEMS

### 1️⃣ VERIFY ELECTRICIAN UNIT STANDARDS (2 minutes)

Run this SQL query in phpMyAdmin:

```sql
SELECT COUNT(*) as count FROM unitstandard WHERE qualification_id = 91761;
```

**If count > 0:** ✅ Electrician is ready!  
**If count = 0:** ⚠️ You need to add unit standards for qualification 91761

### 2️⃣ RUN VERIFICATION SCRIPT (2 minutes)

Upload `verify_qualification_ofo_mapping.php` to production, then open:
```
https://rlms.rlms.co.za/verify_qualification_ofo_mapping.php
```

This will show you:
- All qualification IDs with unit standards
- Complete OFO-to-Qualification mapping
- Verification of your configuration

### 3️⃣ CREATE DATABASE TABLES (5 minutes)

Run these 2 SQL scripts via phpMyAdmin:

**A. Electrician Gap Closure Table:**
```sql
-- Copy from: create_electrician_gap_closure_tables.sql
-- Uses qualification_id = 91761 ✅
```

**B. Plumber Gap Closure Table:**
```sql
-- Copy from: create_plumber_gap_closure_tables.sql
-- Uses qualification_id = 65409 ✅ (same as Bricklayer)
```

### 4️⃣ UPLOAD 4 PHP FILES (5 minutes)

Upload to `https://rlms.rlms.co.za/mobile/`:

```
✅ mobile/get_electrician_gap_unit_standards.php (uses qual ID 91761)
✅ mobile/save_electrician_gap_closure.php (uses qual ID 91761)
✅ mobile/get_plumber_gap_unit_standards.php (uses qual ID 65409)
✅ mobile/save_plumber_gap_closure.php (uses qual ID 65409)
```

### 5️⃣ TEST ENDPOINTS (5 minutes)

**Test Electrician:**
```bash
curl -X POST https://rlms.rlms.co.za/mobile/get_electrician_gap_unit_standards.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID": 11701, "qualification_id": 91761}'
```

**Test Plumber:**
```bash
curl -X POST https://rlms.rlms.co.za/mobile/get_plumber_gap_unit_standards.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID": 11701, "qualification_id": 65409}'
```

**Expected Result:** Both should return unit standards (Plumber will show 35, Electrician depends on your data)

---

## ✅ EXPECTED RESULTS

### Plumber (qualification_id 65409):
```json
{
  "status": "success",
  "qualification_id": 65409,
  "trade": "plumber",
  "ofo_code": "642601",
  "unit_standards": [...35 unit standards...],
  "total_available": 35
}
```

### Electrician (qualification_id 91761):
```json
{
  "status": "success",
  "qualification_id": 91761,
  "trade": "electrician",
  "ofo_code": "671101",
  "unit_standards": [...],
  "total_available": X
}
```

---

## 📋 CHECKLIST

- ☐ Verify Electrician has unit standards (qual ID 91761)
- ☐ Run verification script
- ☐ Create Electrician gap_unit_standards table
- ☐ Create Plumber gap_unit_standards table
- ☐ Upload 4 corrected PHP files
- ☐ Test Electrician endpoint
- ☐ Test Plumber endpoint
- ☐ Verify Plumber shows 35 unit standards

---

## 📞 TELL ME WHEN DONE

Let me know the results of:
1. Electrician unit standards count (from Step 1)
2. Verification script output (from Step 2)
3. Endpoint test results (from Step 5)

---

**All files are now corrected with proper qualification IDs!**

**See:** `CORRECT_OFO_QUALIFICATION_MAPPING.md` for full details
