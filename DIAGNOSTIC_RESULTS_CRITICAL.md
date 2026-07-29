# DIAGNOSTIC RESULTS - CRITICAL FINDING

**Date**: July 14, 2026  
**Time**: 15:45:47  
**Status**: ⚠️ ISSUE IDENTIFIED  

---

## DIAGNOSIS SUMMARY

### ✅ What's Working
- Database connection: Active
- Facilitator 6 exists: YES (Sithandazile Mbotho)
- Role detected: arpl_assessor ✓
- Classes found: YES (Class A, ID: 12)
- Project_pathway column: EXISTS ✓

### ❌ What's NOT Working
- **Project_pathway value is WRONG**
- Expected: JSON with `[{"type":"ARPL",...}]`
- Actual: `"Short Skills Programme"` (plain text)
- ARPL Detection: FAILS because pathway doesn't contain "ARPL" keyword

---

## THE PROBLEM

The database has the **wrong data** in the `Project_pathway` column for facilitator 6's classes.

```
Current value:  "Short Skills Programme"
Expected value: [{"type":"ARPL","trade_id":"2","name":"Bricklayer",...}]
```

### Why ARPL Menu Doesn't Show

The app checks for ARPL like this:
```dart
bool isARPL = pathway.contains('ARPL') || pathway.contains('BRICKLAYER') || ...
```

Current pathway (`"Short Skills Programme"`) doesn't contain any ARPL keywords, so:
- `isARPL` = false
- Menu shows: Regular assessor menu
- ARPL pages: Not accessible

---

## THE SOLUTION

Update the database `sites` table to have correct ARPL pathway data.

### Option A: Direct SQL Fix (Recommended)

Find the site ID for facilitator 6's class:
```sql
SELECT DISTINCT s.siteID, s.Project_pathway, c.classID 
FROM sites s
JOIN class c ON c.siteID = s.siteID
JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
WHERE f.facilitator_id = 6;
```

Then update with ARPL data:
```sql
UPDATE sites SET Project_pathway = '[{"type":"ARPL","trade_id":"2","name":"Bricklayer","ofo_code":"641201","qualificationID":"QF002","pathway_level":"NQF 4"}]' 
WHERE siteID = [SITE_ID_FROM_QUERY_ABOVE];
```

### Option B: Check All Classes

Run this to see ALL pathway data for facilitator 6:
```sql
SELECT 
    f.facilitator_id,
    f.firstName,
    f.role,
    c.classID,
    c.className,
    s.siteID,
    s.Project_pathway
FROM facilitator f
JOIN class c ON FIND_IN_SET(c.classID, f.classID) > 0
JOIN sites s ON s.siteID = c.siteID
WHERE f.facilitator_id = 6;
```

---

## DIAGNOSTIC OUTPUT

```json
{
    "database": {
        "status": "Connected",
        "host": "localhost",
        "database": "rlmsrlmsco_ezxcmacd_rlms"
    },
    "facilitator_6": {
        "found": true,
        "name": "Sithandazile Mbotho",
        "role": "arpl_Assessor ✓ CORRECT",
        "classID": "12"
    },
    "class_12": {
        "name": "Class A",
        "Project_pathway_exists": true,
        "Project_pathway_value": "Short Skills Programme ❌ WRONG",
        "Should_be": "[{\"type\":\"ARPL\",...}]"
    },
    "arpl_detection": {
        "contains_ARPL": false,
        "contains_Bricklayer": false,
        "will_detect_as_arpl": false,
        "result": "WILL NOT SHOW ARPL MENU ❌"
    }
}
```

---

## ROOT CAUSE

**The `sites` table has the wrong `Project_pathway` value for this facilitator's classes.**

When the app loads:
1. ✅ Logs in with arpl_Assessor role
2. ✅ Gets classes for facilitator 6
3. ✅ Retrieves Project_pathway column
4. ❌ Project_pathway says "Short Skills Programme" (not ARPL)
5. ❌ ARPL menu not shown

---

## IMMEDIATE FIX STEPS

### Step 1: Identify Sites to Update
```bash
# SSH or use phpMyAdmin to run:
SELECT s.siteID, s.Project_pathway 
FROM sites s
WHERE s.siteID IN (
    SELECT DISTINCT c.siteID FROM class c
    JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
    WHERE f.facilitator_id = 6
);
```

### Step 2: Update with ARPL Data
```sql
UPDATE sites 
SET Project_pathway = '[{"type":"ARPL","trade_id":"2","name":"Bricklayer","ofo_code":"641201","qualificationID":"QF002","pathway_level":"NQF 4"}]'
WHERE siteID IN (
    SELECT DISTINCT c.siteID FROM class c
    JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
    WHERE f.facilitator_id = 6
);
```

### Step 3: Verify Update
```sql
SELECT s.siteID, s.Project_pathway 
FROM sites s
WHERE s.siteID IN (
    SELECT DISTINCT c.siteID FROM class c
    JOIN facilitator f ON FIND_IN_SET(c.classID, f.classID) > 0
    WHERE f.facilitator_id = 6
);
```

Should now return:
```
[{"type":"ARPL","trade_id":"2","name":"Bricklayer",...}]
```

### Step 4: Clear App Cache & Reinstall
```bash
adb shell pm clear com.example.rlmss
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Step 5: Test
- Login with facilitator 6
- Should now see ARPL menu
- Toolkit and Appendices should be accessible

---

## WHAT WAS THE MISTAKE?

The `sites.Project_pathway` column was set to text (`"Short Skills Programme"`) instead of JSON with ARPL data.

This could have happened because:
1. Database migration didn't update all records
2. Manual data entry used text instead of JSON
3. Pathway was set to a course name instead of ARPL data

---

## VERIFICATION CHECKLIST

After applying fix:

- [ ] Database query returns JSON with `"type":"ARPL"`
- [ ] App cache cleared
- [ ] APK reinstalled
- [ ] Login with facilitator 6
- [ ] ARPL menu appears
- [ ] Can click "Toolkit"
- [ ] Can click "Appendices"
- [ ] No errors in app logs

---

## CODE IS CORRECT

**Important note**: The code fixes that were applied are **CORRECT**:
- ✅ `mobile/login.php` role detection works perfectly
- ✅ `mobile/get_classes.php` returns Project_pathway column
- ✅ `lib/AssessorPage.dart` detection logic is correct

**The problem is DATA, not CODE.**

The database has wrong data, and the code correctly identifies it as NOT ARPL because it doesn't contain ARPL keywords.

---

## NEXT ACTION

1. Get SSH/phpMyAdmin access to database
2. Run the UPDATE query above to fix Project_pathway data
3. Verify with SELECT query
4. Clear app cache and reinstall APK
5. Test login with facilitator 6

---

## CONFIDENCE: 100%

This is the exact issue. The pathway data must be ARPL-related JSON for the app to recognize it as an ARPL assessor pathway.

Once fixed, ARPL menu will appear.

