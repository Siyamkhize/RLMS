# Appendix B Foreign Key Constraint Fix

**Date:** July 15, 2026  
**Issue:** Appendix B save fails with foreign key constraint error  
**Status:** 🔧 FIX READY - NEEDS EXECUTION

---

## 🔴 THE PROBLEM

When saving Appendix B ratings for **Bricklayer (OFO 641201)**, the app shows this error:

```
Exception: Cannot add or update a child row: a foreign key constraint fails 
(`rlmsrlmsco_ezcomptech`.`rlms`.`arplappxb_activity_ratings`, 
CONSTRAINT `arplappxb_activity_ratings_ibfk_3` 
FOREIGN KEY (`activity_id`) REFERENCES `arplappxb_plumbing_activities` (`activity_id`))
```

### Root Cause
The `arplappxb_activity_ratings` table has a foreign key constraint that forces `activity_id` to reference **`arplappxb_plumbing_activities`**.

This is **WRONG** because:
- The table stores ratings for **ALL trades** (Bricklayer, Plumber, Electrician)
- Each trade has its own activities table:
  - `641201` (Bricklayer) → `arplappxb_bricklaying_activities`
  - `671101` (Electrician) → `arplappxb_electrician_activities`
  - `671201` (Plumber) → `arplappxb_plumbing_activities`

When saving a Bricklayer rating, the foreign key check fails because it's looking for the activity_id in the **Plumber** activities table!

---

## ✅ THE SOLUTION

**Remove the problematic foreign key constraint** from `arplappxb_activity_ratings`.

The table should use **application-level logic** (via `ofo_number` field) to determine which activities table to reference, NOT database constraints.

---

## 🛠️ HOW TO FIX

### Option 1: Run the PHP Fix Script (RECOMMENDED)
```bash
# Upload the fix script to your server
https://rlms.rlms.co.za/mobile/fix_appendix_b_constraint.php

# Run it once via browser or curl
curl https://rlms.rlms.co.za/mobile/fix_appendix_b_constraint.php
```

This script will:
1. Detect all foreign key constraints on `arplappxb_activity_ratings`
2. Drop any constraints that reference trade-specific activities tables
3. Verify the fix was successful
4. Return a detailed log of what was done

### Option 2: Run SQL Manually
```sql
-- Find the constraint name
SELECT 
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'rlms'
AND TABLE_NAME = 'arplappxb_activity_ratings'
AND REFERENCED_TABLE_NAME IS NOT NULL;

-- Drop the problematic constraint (adjust name if different)
ALTER TABLE arplappxb_activity_ratings 
DROP FOREIGN KEY arplappxb_activity_ratings_ibfk_3;

-- Verify it's gone
SELECT 
    CONSTRAINT_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'rlms'
AND TABLE_NAME = 'arplappxb_activity_ratings'
AND REFERENCED_TABLE_NAME IS NOT NULL;
-- Should return no rows
```

---

## 🔄 TEMPORARY WORKAROUND (Already Implemented)

The updated `save_arpl_toolkit_edits.php` now includes a temporary workaround:
```php
// Temporarily disable foreign key checks
$conn->query("SET FOREIGN_KEY_CHECKS = 0");

// ... save data ...

// Re-enable foreign key checks
$conn->query("SET FOREIGN_KEY_CHECKS = 1");
```

This allows saves to work **temporarily**, but the proper fix is to remove the constraint permanently.

---

## 📊 DATABASE DESIGN PRINCIPLE

**CORRECT Design:**
```
arplappxb_activity_ratings
├── learnerID
├── ofo_number ← Determines which activities table to reference
├── activity_id ← NO foreign key constraint
├── rating
└── comments
```

**Application Logic (Not DB Constraint):**
- If `ofo_number = '641201'` → activity_id references `arplappxb_bricklaying_activities`
- If `ofo_number = '671101'` → activity_id references `arplappxb_electrician_activities`
- If `ofo_number = '671201'` → activity_id references `arplappxb_plumbing_activities`

---

## 🧪 TESTING AFTER FIX

1. **Run the fix script:**
   ```
   https://rlms.rlms.co.za/mobile/fix_appendix_b_constraint.php
   ```

2. **Upload updated save script:**
   - `mobile/save_arpl_toolkit_edits.php` (already has workaround)

3. **Test in app:**
   - Login as Facilitator ID 6
   - Menu → View Complete Toolkit
   - Select learner: Anele Cele (Bricklayer, OFO 641201)
   - Edit Appendix B ratings
   - Tap "Save All Changes"
   - Should now save successfully! ✓

4. **Verify in database:**
   ```sql
   SELECT * FROM arplappxb_activity_ratings 
   WHERE learnerID = 11701 AND ofo_number = '641201';
   ```

---

## 📁 FILES CREATED

1. **`mobile/fix_appendix_b_constraint.php`** - Automated fix script
2. **`fix_appendix_b_foreign_key.sql`** - SQL commands (manual approach)
3. **`mobile/check_arpl_table_schemas.php`** - Diagnostic tool
4. **`mobile/save_arpl_toolkit_edits.php`** - Updated with temporary workaround

---

## 🎯 ACTION REQUIRED

### STEP 1: Upload Files
```
UPLOAD TO SERVER:
✓ mobile/save_arpl_toolkit_edits.php (updated with FK workaround)
✓ mobile/fix_appendix_b_constraint.php (fix script)
✓ mobile/check_arpl_table_schemas.php (diagnostic)
```

### STEP 2: Run Fix (Choose One)
**Option A - PHP Script (Recommended):**
```bash
https://rlms.rlms.co.za/mobile/fix_appendix_b_constraint.php
```

**Option B - SQL (If you have DB access):**
```sql
ALTER TABLE arplappxb_activity_ratings DROP FOREIGN KEY arplappxb_activity_ratings_ibfk_3;
```

### STEP 3: Test
- Test saving Appendix B in the app
- Should work for all trades now

---

## ✅ SUCCESS CRITERIA

After fix:
- ✓ Appendix B saves successfully for Bricklayer (641201)
- ✓ Appendix B saves successfully for Plumber (671201)
- ✓ Appendix B saves successfully for Electrician (671101)
- ✓ No foreign key constraint errors
- ✓ Appendix D and E continue to work

---

**Created:** July 15, 2026  
**Last Updated:** July 15, 2026  
**Status:** Ready for deployment

