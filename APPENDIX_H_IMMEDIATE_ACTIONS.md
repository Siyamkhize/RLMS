# APPENDIX H GAP CLOSURE - IMMEDIATE ACTIONS REQUIRED

**Date:** January 2025  
**Status:** ⚠️ 2 Missing Tables + Missing Unit Standards Data

---

## 📊 VERIFICATION RESULTS SUMMARY

Based on `check_existing_gap_closure_tables.php` output:

### ✅ Bricklayer - COMPLETE
- ✓ `arplbricklayer_access_recommendation` exists (0 records)
- ✓ `arplbricklayer_gap_unit_standards` exists (0 records)
- ✓ **35 unit standards** available in database

### ⚠️ Electrician - PARTIAL  
- ✓ `arplelectrician_access_recommendation` exists (8 records)
- ✗ `arplelectrician_gap_unit_standards` **MISSING**
- ✗ **0 unit standards** in database (qualification_id 671101)

### ⚠️ Plumber - PARTIAL
- ✓ `arplplumber_access_recommendation` exists (0 records)
- ✗ `arplplumber_gap_unit_standards` **MISSING**
- ✗ **0 unit standards** in database (qualification_id 642601)

---

## 🚨 CRITICAL ISSUES

1. **Missing Tables:** Need to create 2 gap_unit_standards tables
2. **Missing Data:** Electrician and Plumber have NO unit standards in the database
3. **Note:** Plumber Alt (qualification_id 671201) is not used - removed from scripts

---

## ⚡ IMMEDIATE ACTIONS

### STEP 1: Create Missing Tables

Run these 2 SQL scripts via phpMyAdmin:

#### A. Create Electrician Gap Unit Standards Table

**File:** `create_electrician_gap_closure_tables.sql`

```sql
-- Only creates the missing gap_unit_standards table
-- Access recommendation table already exists
CREATE TABLE IF NOT EXISTS arplelectrician_gap_unit_standards (
    id INT(10) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    learner_id INT(11) NOT NULL,
    recommendation_id INT(10) UNSIGNED,
    unit_standard_id VARCHAR(50) NOT NULL,
    unit_standard_name TEXT,
    qualification_id INT(11) NOT NULL DEFAULT 671101,
    ofo_code VARCHAR(20) DEFAULT '671101',
    assigned_date DATE,
    status VARCHAR(50) DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_learner_id (learner_id),
    INDEX idx_recommendation_id (recommendation_id),
    INDEX idx_qualification_id (qualification_id),
    FOREIGN KEY (recommendation_id) REFERENCES arplelectrician_access_recommendation(RecommendationID) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

#### B. Create Plumber Gap Unit Standards Table

**File:** `create_plumber_gap_closure_tables.sql`

```sql
-- Only creates the missing gap_unit_standards table
-- Access recommendation table already exists
CREATE TABLE IF NOT EXISTS arplplumber_gap_unit_standards (
    id INT(10) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    learner_id INT(11) NOT NULL,
    recommendation_id INT(10) UNSIGNED,
    unit_standard_id VARCHAR(50) NOT NULL,
    unit_standard_name TEXT,
    qualification_id INT(11) NOT NULL DEFAULT 642601,
    ofo_code VARCHAR(20) DEFAULT '642601',
    assigned_date DATE,
    status VARCHAR(50) DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_learner_id (learner_id),
    INDEX idx_recommendation_id (recommendation_id),
    INDEX idx_qualification_id (qualification_id),
    FOREIGN KEY (recommendation_id) REFERENCES arplplumber_access_recommendation(RecommendationID) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**How to Run:**
1. Open phpMyAdmin → Select your database
2. Go to SQL tab
3. Copy and paste the SQL above
4. Click "Go"
5. Verify success message

---

### STEP 2: Upload PHP Backend Files

Upload these 4 NEW files to `https://rlms.rlms.co.za/mobile/`:

#### Electrician Endpoints (NEW):
- `mobile/get_electrician_gap_unit_standards.php`
- `mobile/save_electrician_gap_closure.php`

#### Plumber Endpoints (NEW):
- `mobile/get_plumber_gap_unit_standards.php`
- `mobile/save_plumber_gap_closure.php`

**Note:** Bricklayer endpoints already exist and are working.

---

### STEP 3: ADD UNIT STANDARDS DATA ⚠️

**CRITICAL:** Electrician and Plumber have NO unit standards in the database!

You need to populate the `unitstandard` table with unit standards for:
- **Electrician** (qualification_id = 671101)
- **Plumber** (qualification_id = 642601)

**Without unit standards data, the gap closure feature will show "No unit standards available" even though the functionality works.**

#### Check Current Data:

```sql
-- Check Bricklayer (should show 35)
SELECT COUNT(*) FROM unitstandard WHERE qualification_id = 65409;

-- Check Electrician (currently 0 - NEEDS DATA)
SELECT COUNT(*) FROM unitstandard WHERE qualification_id = 671101;

-- Check Plumber (currently 0 - NEEDS DATA)
SELECT COUNT(*) FROM unitstandard WHERE qualification_id = 642601;
```

#### Where to Get Unit Standards:

You need the official SAQA unit standards for each qualification:
- **Bricklaying (65409):** Already has 35 unit standards ✓
- **Electrician (671101):** Need to add from SAQA database
- **Plumber (642601):** Need to add from SAQA database

**Options:**
1. Import from SAQA official database
2. Manually add unit standards via SQL INSERT
3. Copy structure from Bricklayer and adapt

**Example Insert:**
```sql
INSERT INTO unitstandard (unit_standard_id, unit_standard_name, credits, qualification_id)
VALUES 
('12345', 'Install electrical wiring systems', 8, 671101),
('12346', 'Test and commission electrical installations', 10, 671101);
```

---

### STEP 4: Verify Installation

After completing Steps 1-3, run the verification script again:

```
https://rlms.rlms.co.za/check_existing_gap_closure_tables.php
```

Expected results after fix:
- ✓ All 6 tables exist (2 per trade)
- ✓ Bricklayer: 35 unit standards
- ✓ Electrician: X unit standards (after you add them)
- ✓ Plumber: X unit standards (after you add them)

---

## 🔧 FLUTTER APP CHANGES (NOT DONE YET)

The Flutter app currently only has gap closure working for **Bricklayer**.

You still need to implement gap closure UI for Electrician and Plumber:

**Option A:** Update `ArplToolkitViewerPage.dart` to handle all trades dynamically
**Option B:** Create separate pages like `ArplToolkitElectricianPage.dart` and `ArplToolkitPlumberPage.dart`

**Recommended:** Option A (dynamic approach based on OFO code)

See `APPENDIX_H_GAP_CLOSURE_COMPLETE.md` for Flutter implementation details.

---

## 📝 TESTING CHECKLIST

After completing all steps:

### Backend Testing:

1. ☐ Run `check_existing_gap_closure_tables.php`
2. ☐ Verify all 6 tables exist
3. ☐ Verify unit standards data exists for all 3 trades
4. ☐ Test `get_electrician_gap_unit_standards.php` endpoint
5. ☐ Test `save_electrician_gap_closure.php` endpoint
6. ☐ Test `get_plumber_gap_unit_standards.php` endpoint
7. ☐ Test `save_plumber_gap_closure.php` endpoint

### Flutter Testing (after implementation):

1. ☐ Open Appendix H for Bricklayer learner
2. ☐ Select "Recommended for Gap Closure"
3. ☐ Verify unit standards list appears
4. ☐ Select unit standards and save
5. ☐ Repeat for Electrician learner
6. ☐ Repeat for Plumber learner

---

## 📞 CURRENT STATUS

**Backend:** ✅ PHP files ready, need to:
- Create 2 missing tables (5 minutes)
- Upload 4 PHP files (5 minutes)
- Add unit standards data for Electrician and Plumber (TIME VARIES)

**Frontend:** ⏳ Flutter changes not started yet

**Blocker:** Missing unit standards data for Electrician and Plumber qualifications

---

## ❓ QUESTIONS TO ANSWER

1. **Do you have unit standards data for Electrician (671101) and Plumber (642601)?**
   - If yes: Provide SQL file or CSV to import
   - If no: Need to source from SAQA or other official database

2. **Plumber qualification ID:**
   - Confirmed using **642601** only (not 671201)
   - Is this correct?

3. **Flutter implementation approach:**
   - Prefer Option A (dynamic) or Option B (separate pages)?

---

**Next Steps:** Run Steps 1-2 now, then address unit standards data issue.
