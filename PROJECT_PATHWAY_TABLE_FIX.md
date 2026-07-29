# Project_pathway Column Source Fix

**Date:** July 22, 2026  
**Status:** ✅ FIXED & APK INSTALLED

---

## Issue

The query in `LearningMaterialFormPage.dart` was getting `Project_pathway` from the wrong table, causing it to always be `null`.

### Root Cause

**Wrong Query:**
```sql
SELECT 
  c.classID,
  c.className,
  s.siteID,
  s.project_id,
  s.Project_pathway,  -- ❌ Getting from sites table (wrong!)
  s.qualification_id as site_qual_id
FROM class c
LEFT JOIN sites s ON c.siteID = s.siteID
LEFT JOIN project pr ON s.project_id = pr.project_id
WHERE c.classID = ?
```

**Log Evidence:**
```
[QUALIFICATION] Project query result: [
  {
    classID: 428, 
    className: Class A, 
    siteID: 745, 
    project_id: 87, 
    Project_pathway: null,  -- ❌ NULL because sites table doesn't have this column
    site_qual_id: 24173
  }
]
```

---

## Solution

Changed query to get `Project_pathway` from the `project` table instead:

**Fixed Query:**
```sql
SELECT 
  c.classID,
  c.className,
  s.siteID,
  s.project_id,
  pr.Project_pathway,  -- ✅ Getting from project table (correct!)
  s.qualification_id as site_qual_id
FROM class c
LEFT JOIN sites s ON c.siteID = s.siteID
LEFT JOIN project pr ON s.project_id = pr.project_id
WHERE c.classID = ?
```

---

## Database Schema

**project table:**
- `project_id` (INT, primary key)
- `Project_pathway` (JSON/TEXT) - Contains qualification and unit standards data

**sites table:**
- `siteID` (INT, primary key)
- `project_id` (INT, foreign key → project.project_id)
- `qualification_id` (INT) - Fallback qualification reference
- **Does NOT have `Project_pathway` column**

**class table:**
- `classID` (INT, primary key)
- `siteID` (INT, foreign key → sites.siteID)
- `className` (VARCHAR)

---

## How It Works Now

### Step 1: Query Project Data
```sql
SELECT pr.Project_pathway FROM ...
```
Returns the JSON from `project` table instead of `sites` table

### Step 2: Parse JSON
If `Project_pathway` is not null, extract unit standards from JSON:
```json
[
  {
    "qual_types": [
      {
        "qualification": {
          "name": "Qualification Name",
          "unitStandards": [
            {"id": "123", "name": "Unit Standard 1"},
            {"id": "456", "name": "Unit Standard 2"}
          ]
        }
      }
    ]
  }
]
```

### Step 3: Fallback (if JSON is null)
Query `unitstandard` table using `qualification_id`:
```sql
SELECT unitstandard_id, unit_standard_name 
FROM unitstandard 
WHERE qualification_id = 24173
```

---

## Files Changed

**Frontend:**
- `lib/LearningMaterialFormPage.dart` (line 424) - Changed `s.Project_pathway` to `pr.Project_pathway`

---

## Testing

After installing the new APK:

1. **Check logs for Project_pathway:**
   ```bash
   adb logcat | findstr QUALIFICATION
   ```

2. **Expected output (if project has data):**
   ```
   [QUALIFICATION] Project query result: [{..., Project_pathway: {...}, ...}]
   [QUALIFICATION] Successfully parsed Project_pathway JSON
   [QUALIFICATION] Using unit standards from Project_pathway, count: X
   ```

3. **Expected output (if project has no data):**
   ```
   [QUALIFICATION] pathwayJson is null or empty
   [QUALIFICATION] Falling back to unitstandard table...
   [QUALIFICATION] Found X unit standards in table
   ```

---

## Impact

### Before Fix:
- `Project_pathway` was always `null` (wrong table)
- Always fell back to `unitstandard` table
- JSON data in `project` table was never used

### After Fix:
- `Project_pathway` correctly reads from `project` table
- JSON is parsed when available
- Fallback to `unitstandard` table only when JSON is truly missing

---

## Related Fixes This Session

1. ✅ Scanner detection crash - Already fixed with `if (mounted)` checks
2. ✅ Learner clocking query - Fixed date comparison using `strftime()`
3. ✅ Project_pathway source - Fixed table reference from `sites` to `project`

---

## APK Details

**Build:** `flutter build apk --release`  
**Install:** `adb install -r app-release.apk`  
**Size:** 45.9MB  
**Status:** ✅ Installed successfully

---

## Summary

✅ Changed `s.Project_pathway` → `pr.Project_pathway`  
✅ Now reads from correct table (`project` instead of `sites`)  
✅ APK rebuilt and installed  
✅ Ready for testing
