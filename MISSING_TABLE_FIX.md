# Missing Table Fix - arpl_evaluation_criteria

## DIAGNOSTIC RESULTS

✅ **Good News**: All ARPL Bricklayer tables exist EXCEPT one!

### Tables Status:
- ✅ `arplappxb_activity_ratings` (Appendix B - Unified) - EXISTS
- ✅ `arpl_appendix_d` (Appendix D - Unified) - EXISTS  
- ✅ `arpl_appendix_f` (Appendix F - Unified) - EXISTS
- ✅ `arplappxb_bricklaying_activities` (Bricklayer activities) - EXISTS (104 rows)
- ✅ `arplappxe_bricklaying_activity_ratings` (Appendix E) - EXISTS
- ❌ **`arpl_evaluation_criteria`** - **MISSING** ← THIS IS THE PROBLEM

## THE ISSUE

The **404 errors** you mentioned are actually **database errors**, not missing PHP files.

When you try to save evaluation criteria (final EISA recommendation), the app calls:
```
save_arpl_criteria.php
```

This endpoint tries to INSERT/UPDATE into:
```
arpl_evaluation_criteria
```

But this table **doesn't exist** on the ONLINE server, so the save fails.

## THE FIX

Run this SQL on the ONLINE database:

### Option 1: Using phpMyAdmin

1. Login to cPanel
2. Open **phpMyAdmin**
3. Select your database
4. Click **SQL** tab
5. Copy and paste the SQL from `create_arpl_evaluation_criteria_table.sql`
6. Click **Go**
7. Done!

### Option 2: Upload SQL File

1. Upload `create_arpl_evaluation_criteria_table.sql` to server
2. SSH into server (or use cPanel Terminal)
3. Run:
```bash
mysql -u [username] -p [database_name] < create_arpl_evaluation_criteria_table.sql
```

## SQL TO RUN

```sql
CREATE TABLE IF NOT EXISTS `arpl_evaluation_criteria` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `learner_id` int(11) NOT NULL,
  `assessor_id` int(11) NOT NULL COMMENT 'facilitator_id from facilitator table',
  `class_id` varchar(250) NOT NULL COMMENT 'classID from learnerdetails/classes',
  `project_id` int(11) NOT NULL COMMENT 'project_id from sites table',
  `site_id` int(11) NOT NULL COMMENT 'siteID from classes/sites',
  `criteria_json` text NOT NULL COMMENT 'JSON string of the 6 criteria checkbox states',
  `is_recommended` tinyint(1) DEFAULT 0 COMMENT 'Final EISA recommendation',
  `assessor_confirmation` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_arpl_criteria_learner` (`learner_id`),
  KEY `idx_project` (`project_id`),
  KEY `idx_assessor` (`assessor_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```

## VERIFY FIX WORKED

After running the SQL, re-run the diagnostic:
```
https://rlms.rlms.co.za/mobile/check_bricklayer_tables.php
```

Should show:
```
✅ ALL REQUIRED TABLES EXIST!
```

## TEST IN APP

After creating the table:

1. Open app
2. Menu → **Assessor Review (D,E,F)** or **View Complete Toolkit**
3. Select: Anele Cele
4. Try to save:
   - ✅ Appendix B → Should work
   - ✅ Appendix D → Should work
   - ✅ Appendix E → Should work
   - ✅ Appendix F → Should work
   - ✅ **Criteria/Recommendation** → Should NOW work (was failing before)

## WHAT THIS TABLE STORES

The `arpl_evaluation_criteria` table stores:

- **6 evaluation criteria checkboxes** (as JSON)
- **Final EISA recommendation** (is_recommended: yes/no)
- **Assessor confirmation**
- Links to learner, assessor, class, project, site

**Example criteria_json**:
```json
{
  "criteria_1": true,
  "criteria_2": true,
  "criteria_3": false,
  "criteria_4": true,
  "criteria_5": true,
  "criteria_6": true
}
```

## WHY WAS THIS TABLE MISSING?

Possible reasons:
1. SQL script wasn't run when database was created
2. Table was accidentally dropped
3. Different database setup between LOCAL and ONLINE

The important thing: **It's easy to create it now!**

---

## SUMMARY

**Problem**: Can't save final evaluation criteria for Bricklaying  
**Root Cause**: `arpl_evaluation_criteria` table doesn't exist  
**Solution**: Run the CREATE TABLE SQL  
**Time to Fix**: 2 minutes  
**Impact**: Unlocks complete ARPL workflow for ALL trades

---

**After creating this table, ALL save endpoints will work for Bricklaying!**

