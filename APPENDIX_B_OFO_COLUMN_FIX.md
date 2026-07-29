# ✅ APPENDIX B - OFO Column Missing Fix

**Date:** July 15, 2026  
**Issue:** `#1072 - Key column 'ofo_number' doesn't exist in table`  
**Root Cause:** ONLINE server table structure different from LOCAL  
**Status:** DIAGNOSTIC READY

---

## 🔍 Issue Analysis

### Error Message
```
#1072 - Key column 'ofo_number' doesn't exist in table
```

**Attempted SQL:**
```sql
ALTER TABLE arplappxb_activity_ratings
ADD UNIQUE KEY unique_learner_activity_assessor 
(learnerID, ofo_number, activity_id, assessor_id);
```

**Problem:** Column `ofo_number` does NOT exist in ONLINE server's table

---

## 📋 Diagnostic Steps

### Step 1: Run Diagnostic Script

Upload and run:
```
https://rlms.rlms.co.za/mobile/diagnose_appendix_b_table.php
```

**This will show:**
1. ✅ Actual table structure
2. ✅ Existing columns
3. ✅ Current indexes
4. ✅ Recommended UNIQUE KEY for YOUR table
5. ✅ Whether ofo_number exists
6. ✅ Duplicate records check

---

## 🔧 Solution Options

### Option A: Add ofo_number Column (RECOMMENDED)

This makes the table match the code and allows trade-specific tracking.

**SQL:**
```sql
-- Add ofo_number column
ALTER TABLE arplappxb_activity_ratings
ADD COLUMN ofo_number VARCHAR(20) AFTER learnerID;

-- Add UNIQUE KEY with ofo_number
ALTER TABLE arplappxb_activity_ratings
ADD UNIQUE KEY unique_learner_activity_assessor 
(learnerID, ofo_number, activity_id, assessor_id);
```

**Advantages:**
- ✅ Code works as-is (no PHP changes)
- ✅ Supports multiple trades per learner
- ✅ Better data integrity
- ✅ Trade-agnostic ratings

### Option B: Modify Code to Remove ofo_number

Keep table as-is, change PHP code.

**SQL (Simpler UNIQUE KEY):**
```sql
ALTER TABLE arplappxb_activity_ratings
ADD UNIQUE KEY unique_learner_activity_assessor 
(learnerID, activity_id, assessor_id);
```

**PHP Change:**
Replace `save_arpl_appendix_b.php` with `save_arpl_appendix_b_no_ofo.php`

**Advantages:**
- ✅ No table changes needed
- ✅ Works with existing data

**Disadvantages:**
- ❌ Can't track different trades separately
- ❌ Assumes one learner = one trade only

---

## 📊 Comparison Matrix

| Aspect | Option A (Add Column) | Option B (No OFO) |
|--------|----------------------|-------------------|
| Table Changes | Add column + index | Index only |
| PHP Changes | None | Replace file |
| Multi-trade Support | ✅ Yes | ❌ No |
| Data Integrity | ✅ Better | ⚠️ Limited |
| Complexity | ⚠️ Higher | ✅ Lower |
| **Recommendation** | **✅ BEST** | ⚠️ Fallback |

---

## 🚀 Deployment Steps

### OPTION A (Recommended)

**1. Upload diagnostic script:**
```
c:\projects\rlmss\mobile\diagnose_appendix_b_table.php
→
/home/rlmsrlmsco/public_html/mobile/diagnose_appendix_b_table.php
```

**2. Run diagnostic:**
```
https://rlms.rlms.co.za/mobile/diagnose_appendix_b_table.php
```

**3. Add ofo_number column:**
```sql
ALTER TABLE arplappxb_activity_ratings
ADD COLUMN ofo_number VARCHAR(20) AFTER learnerID;
```

**4. Add UNIQUE KEY:**
```sql
ALTER TABLE arplappxb_activity_ratings
ADD UNIQUE KEY unique_learner_activity_assessor 
(learnerID, ofo_number, activity_id, assessor_id);
```

**5. Re-upload optimized save_arpl_appendix_b.php** (already done)

**6. Test:**
```
https://rlms.rlms.co.za/mobile/test_appendix_b_save.php
```

### OPTION B (Fallback)

**1. Run diagnostic** (same as above)

**2. Add simpler UNIQUE KEY:**
```sql
ALTER TABLE arplappxb_activity_ratings
ADD UNIQUE KEY unique_learner_activity_assessor 
(learnerID, activity_id, assessor_id);
```

**3. Replace PHP file:**
```
Rename: save_arpl_appendix_b.php → save_arpl_appendix_b_WITH_OFO.php.bak
Replace with: save_arpl_appendix_b_no_ofo.php → save_arpl_appendix_b.php
```

**4. Test:**
```
https://rlms.rlms.co.za/mobile/test_appendix_b_save.php
```

---

## 🗄️ Expected Table Structure

### After Option A (Recommended)

```sql
CREATE TABLE arplappxb_activity_ratings (
  activity_rating_id INT PRIMARY KEY AUTO_INCREMENT,
  learnerID INT NOT NULL,
  ofo_number VARCHAR(20),  -- ✅ ADDED
  activity_id INT NOT NULL,
  activity_name VARCHAR(255),
  competency_scale_id INT,  -- Rating 1-5
  assessor_id INT,
  comments TEXT,
  rating_date DATETIME,
  UNIQUE KEY unique_learner_activity_assessor (learnerID, ofo_number, activity_id, assessor_id)
);
```

### After Option B (Fallback)

```sql
CREATE TABLE arplappxb_activity_ratings (
  activity_rating_id INT PRIMARY KEY AUTO_INCREMENT,
  learnerID INT NOT NULL,
  -- NO ofo_number column
  activity_id INT NOT NULL,
  activity_name VARCHAR(255),
  competency_scale_id INT,
  assessor_id INT,
  comments TEXT,
  rating_date DATETIME,
  UNIQUE KEY unique_learner_activity_assessor (learnerID, activity_id, assessor_id)
);
```

---

## ✅ Verification Checklist

### After Implementation:

- [ ] **Diagnostic run successful**
  - Shows actual table structure
  - Recommends correct UNIQUE KEY

- [ ] **Column added (Option A) OR code replaced (Option B)**

- [ ] **UNIQUE KEY added successfully**
  - No "column doesn't exist" error
  - Shows in SHOW INDEX output

- [ ] **Test script passes**
  - URL: `https://rlms.rlms.co.za/mobile/test_appendix_b_save.php`
  - HTTP 200, success response
  - No timeout

- [ ] **App test successful**
  - Login as ARPL Assessor
  - Save Appendix B
  - Green success message

- [ ] **Data persists**
  - Check database
  - Records saved correctly

---

## 🐛 Troubleshooting

### Issue: Diagnostic shows ofo_number doesn't exist

**Solution:** Use Option A (add column) OR Option B (no OFO code)

### Issue: "Duplicate entry" error when adding UNIQUE KEY

**Cause:** Existing duplicate records

**Solution:**
```sql
-- Find duplicates
SELECT learnerID, activity_id, COUNT(*) as cnt
FROM arplappxb_activity_ratings
GROUP BY learnerID, activity_id
HAVING cnt > 1;

-- Delete duplicates (keep most recent)
DELETE t1 FROM arplappxb_activity_ratings t1
INNER JOIN arplappxb_activity_ratings t2
WHERE t1.activity_rating_id < t2.activity_rating_id
AND t1.learnerID = t2.learnerID
AND t1.activity_id = t2.activity_id;
```

### Issue: Still getting timeout

**Check:**
1. Correct file uploaded?
2. UNIQUE KEY added?
3. PHP opcache cleared?

---

## 📝 Files Created

### Diagnostic
- ✅ `mobile/diagnose_appendix_b_table.php` - Table structure diagnostic

### PHP Endpoints
- ✅ `mobile/save_arpl_appendix_b.php` - WITH ofo_number (original optimized)
- ✅ `mobile/save_arpl_appendix_b_no_ofo.php` - WITHOUT ofo_number (fallback)

### SQL Scripts
- ✅ `add_appendix_b_unique_key.sql` - Original (with ofo_number)

### Documentation
- ✅ `APPENDIX_B_OFO_COLUMN_FIX.md` - This file
- ✅ `APPENDIX_B_TIMEOUT_FIXED.md` - Optimization details
- ✅ `APPENDIX_B_404_FIX.md` - Upload instructions

---

## 🎯 Success Criteria

After fix:

- ✅ UNIQUE KEY added without errors
- ✅ No timeout when saving
- ✅ Test script returns HTTP 200
- ✅ App saves successfully in <5 seconds
- ✅ Data persists correctly
- ✅ Works for all trades (if Option A)

---

## 🚨 IMMEDIATE NEXT STEP

**RIGHT NOW - Run Diagnostic:**

1. Upload diagnostic script to server
2. Visit: `https://rlms.rlms.co.za/mobile/diagnose_appendix_b_table.php`
3. Check output to see:
   - Does ofo_number column exist?
   - What UNIQUE KEY is recommended?
4. Follow recommended option (A or B)

---

**Generated:** July 15, 2026 10:15:00  
**Status:** Diagnostic ready, awaiting table structure check  
**Priority:** HIGH - Blocking deployment
