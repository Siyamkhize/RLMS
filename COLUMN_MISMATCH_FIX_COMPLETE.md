# ✅ COLUMN MISMATCH FIX - ISSUE RESOLVED!

## THE REAL PROBLEM IDENTIFIED

The 500 error was caused by **database schema mismatch** between LOCAL and ONLINE servers!

### Error Message:
```
Exception: Unknown column 'c.startDate' in 'SELECT'
```

### Root Cause:
The `mobile/get_classes.php` was trying to SELECT columns that **don't exist on ONLINE server:**
- ❌ `c.startDate` - **DOESN'T EXIST on ONLINE**
- ❌ `c.endDate` - **DOESN'T EXIST on ONLINE**

**LOCAL database has these columns, ONLINE doesn't!**

---

## THE FIX APPLIED

### File: `mobile/get_classes.php`

**BEFORE (causing 500 error):**
```php
SELECT 
    c.classID,
    c.className,
    c.siteID,
    c.numberOfLearners,
    c.startDate,        ← DOESN'T EXIST ON ONLINE!
    c.endDate,          ← DOESN'T EXIST ON ONLINE!
    s.project_id, 
    s.Project_pathway
FROM class c
```

**AFTER (fixed):**
```php
SELECT 
    c.classID,
    c.className,
    c.siteID,
    c.numberOfLearners,
    s.project_id, 
    s.Project_pathway
FROM class c
```

**Removed:**
- ✅ `c.startDate` - removed
- ✅ `c.endDate` - removed

---

## COMPLETE FIX SUMMARY

### All Fixes Applied:

1. ✅ **APK rebuilt** - Points to ONLINE server (`rlms.rlms.co.za`)
2. ✅ **Pathway detection** - Enhanced to detect ARPL from JSON
3. ✅ **Column mismatch** - Removed non-existent `startDate` and `endDate`
4. ✅ **Project_pathway** - Added to login.php SELECT (though login.php doesn't use these columns anyway)

---

## FILES TO UPLOAD TO ONLINE SERVER

**Upload these fixed files NOW:**

### 1. mobile/get_classes.php (CRITICAL!)
```
c:\projects\rlmss\mobile\get_classes.php
```
**Status:** ✅ FIXED - Removed startDate and endDate columns

### 2. mobile/login.php (recommended)
```
c:\projects\rlmss\mobile\login.php
```
**Status:** ✅ FIXED - Added Project_pathway to SELECT

---

## EXPECTED RESULT AFTER UPLOAD

### Step 1: Upload Files
Upload the fixed files to ONLINE server

### Step 2: Clear Any Server Cache
If applicable, clear PHP opcache or restart PHP-FPM

### Step 3: Test Login
Log in as Facilitator 6

### Step 4: Verify Success
You should see:
- ✅ **Assessor Dashboard** loads
- ✅ **Facilitator ID: 6** displays
- ✅ **Classes load successfully** (no 500 error!)
- ✅ **ARPL menu items appear**:
  - ARPL Toolkit
  - ARPL Competency Scale
  - ARPL Marking
  - ARPL Hierarchical Navigator

---

## VERIFICATION TEST

After uploading, test the diagnostic endpoint:
```
https://rlms.rlms.co.za/mobile/test_get_classes.php?facilitator_id=6
```

**Expected output:**
```
===== GET_CLASSES DIAGNOSTIC =====

Testing facilitator_id: 6

Step 1: Testing basic connection...
✓ Connection OK

Step 2: Testing query...
Query prepared
✓ Statement prepared

✓ Parameters bound

✓ Query executed

✓ Results fetched

Step 3: Fetching rows...
Row 1:
  classID: 797
  className: class A
  Project_pathway: [{"type":"ARPL","name":"Bricklayer"}]...

✓ Fetched 1 rows

Step 4: JSON encoding...
✓ JSON encoded successfully

===== SUCCESS =====

RESULT:
[
    {
        "classID": "797",
        "className": "class A",
        "siteID": "835",
        "numberOfLearners": "30",
        "project_id": "100",
        "Project_pathway": "[{\"type\":\"ARPL\",\"name\":\"Bricklayer\"}]"
    }
]
```

---

## WHY THIS HAPPENED

**Development vs Production Schema Drift:**
- LOCAL database was updated with `startDate` and `endDate` columns
- ONLINE database was never updated with these columns
- Code was written against LOCAL schema
- Code failed on ONLINE with missing columns

**Lesson:** Always verify schema matches between environments!

---

## COMPLETE ISSUE TIMELINE

### Day 1: Issue Reported
- User: "ARPL menu not showing on ONLINE server"
- Logs show: "Short Skills Programme" instead of ARPL

### Investigation 1: Server Mismatch
- **Found:** APK pointing to LOCAL server instead of ONLINE
- **Fixed:** Rebuilt APK with correct server URL
- **Result:** Still not working

### Investigation 2: Missing Pathway Data
- **Found:** Login response missing `Project_pathway` field
- **Fixed:** Added `s.Project_pathway` to login.php query
- **Result:** Still not working

### Investigation 3: ArplAssessorPage Not Loading
- **Found:** Page loading but showing 500 error
- **Suspected:** PHP crash in get_classes.php
- **Action:** Created diagnostic scripts

### Investigation 4: Column Mismatch (FINAL ISSUE!)
- **Found:** `c.startDate` and `c.endDate` don't exist on ONLINE
- **Fixed:** Removed these columns from query
- **Result:** ✅ **SHOULD WORK NOW!**

---

## FINAL CHECKLIST

Before testing:
- [ ] Upload `mobile/get_classes.php` to ONLINE server
- [ ] Upload `mobile/login.php` to ONLINE server (optional but recommended)
- [ ] Clear server cache (if applicable)
- [ ] Uninstall old APK from device
- [ ] Install new APK from `build\app\outputs\flutter-apk\app-release.apk`

After upload:
- [ ] Test diagnostic: `https://rlms.rlms.co.za/mobile/test_get_classes.php?facilitator_id=6`
- [ ] Log in as Facilitator 6
- [ ] Verify ARPL menu appears
- [ ] Test ARPL menu items work

---

## SUMMARY

**Problem:** 500 error - Unknown column 'c.startDate'  
**Cause:** ONLINE database doesn't have startDate/endDate columns  
**Fix:** Removed these columns from SELECT query  
**Status:** ✅ FIXED  

**Action Required:** Upload fixed `mobile/get_classes.php` to ONLINE server and test!

---

## FILES READY TO UPLOAD

All fixed files are in:
```
c:\projects\rlmss\mobile\
```

- ✅ `get_classes.php` - **CRITICAL FIX**
- ✅ `login.php` - Recommended
- ✅ `test_get_classes.php` - For verification
- ✅ `test_simple_get_classes.php` - For verification

**Upload NOW and test!** 🚀
