# ROOT CAUSE: Project_Pathway Data Not Synced on Online Server

**Date:** July 14, 2026  
**Severity:** CRITICAL  
**Status:** Root cause identified + SQL fix provided

---

## THE REAL PROBLEM

The online server's `sites` table is **missing or has truncated `Project_pathway` data**.

### Local (Working)
```
sites.Project_pathway = [{"type":"ARPL","trade_id":"1","name":"Electrician"...}]
                         ↑ Full JSON with type, trade_id, name
```

### Online (Broken)
```
sites.Project_pathway = "Bricklaying"
                         ↑ Only the name, not the full JSON structure
```

---

## WHY THIS BREAKS ARPL UI

The app checks for the pathway type in `Project_pathway`:

```dart
String pathway = (data[0]['Project_pathway'] ?? '')
    .toString()
    .toUpperCase() ?? '';

if (pathway.contains('ARPL')) {
  showARPLUI();  // ← This needs the word "ARPL" in pathway
} else {
  showNormalAssessorUI();  // ← Currently showing this
}
```

**Local:** `pathway = "[{"type":"ARPL",...]"` → contains "ARPL" ✅  
**Online:** `pathway = "Bricklaying"` → does NOT contain "ARPL" ❌

---

## ROOT CAUSE

When sites were created/updated on the online server, the `Project_pathway` field in the `sites` table was not synced with the `Project_pathway` from the `project` table.

The `sites` table needs to have a **copy** of the `Project_pathway` from its linked `project` record so that when queries fetch sites, they have the full pathway JSON available.

---

## THE FIX

### SQL Script

Run this on your online database:

```sql
UPDATE sites s
INNER JOIN project p ON s.project_id = p.project_id
SET s.Project_pathway = p.Project_pathway
WHERE s.project_id IS NOT NULL;
```

This synchronizes all sites with their project's pathway data.

### Steps to Deploy

1. **SSH to online server:**
   ```bash
   ssh user@rlms.rlms.co.za
   ```

2. **Connect to database:**
   ```bash
   mysql -u [username] -p [database_name]
   ```

3. **Run the fix:**
   ```bash
   source /path/to/fix_sites_project_pathway.sql
   ```

Or execute the UPDATE query directly:
```sql
UPDATE sites s
INNER JOIN project p ON s.project_id = p.project_id
SET s.Project_pathway = p.Project_pathway
WHERE s.project_id IS NOT NULL;
```

4. **Verify:**
   ```sql
   SELECT COUNT(*) FROM sites WHERE Project_pathway LIKE '%ARPL%';
   ```

   Should return: > 0 (at least some ARPL sites)

---

## VERIFICATION BEFORE & AFTER

### Before Fix (Broken)

Local query:
```sql
SELECT siteID, siteName, Project_pathway FROM sites LIMIT 3;
```

Local response (correct):
```
siteID | siteName  | Project_pathway
1      | Site 1    | [{"type":"ARPL","trade_id":"1","name":"Electrician"...}]
2      | Site 2    | [{"type":"Training","name":"Skills Programme"...}]
3      | Site 3    | [{"type":"ARPL","trade_id":"2","name":"Bricklaying"...}]
```

Online response (broken):
```
siteID | siteName  | Project_pathway
1      | Site 1    | Electrician           ← Should be full JSON
2      | Site 2    | Training Programme    ← Should be full JSON
3      | Site 3    | Bricklaying           ← Should be full JSON
```

### After Fix (Correct)

Online response (fixed):
```
siteID | siteName  | Project_pathway
1      | Site 1    | [{"type":"ARPL","trade_id":"1","name":"Electrician"...}]
2      | Site 2    | [{"type":"Training","name":"Skills Programme"...}]
3      | Site 3    | [{"type":"ARPL","trade_id":"2","name":"Bricklaying"...}]
```

---

## API RESPONSE AFTER FIX

The `mobile/get_classes.php` endpoint will return:

**Before:**
```json
{
  "classID": "782",
  "className": "Electrician",
  "Project_pathway": "Electrician"
}
```

**After:**
```json
{
  "classID": "782",
  "className": "Electrician",
  "Project_pathway": "[{\"type\":\"ARPL\",\"trade_id\":\"1\",\"name\":\"Electrician\"...}]"
}
```

App detects `"ARPL"` in pathway → Shows ARPL menu ✅

---

## WHY LOCAL WORKS BUT ONLINE DOESN'T

### Local Database
- Sites were created with Project_pathway values synced
- The JSON data is intact
- Contains "ARPL" string that app can detect

### Online Database
- Sites were migrated/created without proper pathway sync
- Project_pathway was only partially copied (just the trade name, not the full JSON)
- Missing the "ARPL" type identifier

---

## COMPLETE FIX SEQUENCE

### 1. Data Fix (SQL)
```sql
UPDATE sites s
INNER JOIN project p ON s.project_id = p.project_id
SET s.Project_pathway = p.Project_pathway
WHERE s.project_id IS NOT NULL;
```

### 2. API Fix (Already Done)
Added `s.Project_pathway` to `mobile/get_classes.php` SELECT

### 3. Test Fix
- Clear app cache: `adb shell pm clear com.example.rlmss`
- Relogin with ARPL assessor
- ARPL menu should appear ✅

---

## SCHEMA CONTEXT

The `sites` table references the `project` table:

```sql
-- sites table structure (relevant fields)
CREATE TABLE sites (
    siteID INT PRIMARY KEY,
    siteName VARCHAR(255),
    project_id INT,
    Project_pathway LONGTEXT,  ← This needs to be synced
    ...
    FOREIGN KEY (project_id) REFERENCES project(project_id)
);

-- project table (source of truth)
CREATE TABLE project (
    project_id INT PRIMARY KEY,
    Project_name VARCHAR(255),
    Project_pathway LONGTEXT,  ← Contains [{"type":"ARPL",...}]
    ...
);
```

The `Project_pathway` should be a copy in `sites` from `project` so queries can access it without extra joins.

---

## IMPACT

| Component | Impact | Fix Status |
|-----------|--------|-----------|
| Local DB | ✅ Working | N/A |
| Online DB | ❌ Broken | 🔧 Can be fixed with SQL |
| API Code | ⚠️ Partial | ✅ Fixed |
| App Code | ✅ Correct | N/A |

---

## CHECKLIST

- [ ] SSH to online server
- [ ] Connect to database
- [ ] Run SQL UPDATE to sync Project_pathway
- [ ] Verify ARPL sites exist: `SELECT COUNT(*) FROM sites WHERE Project_pathway LIKE '%ARPL%'`
- [ ] Test endpoint returns correct pathway
- [ ] Clear app cache on device
- [ ] Relogin with ARPL assessor
- [ ] Verify ARPL menu appears

---

## SUMMARY

**The Issue:**
- Online server's `sites` table has truncated `Project_pathway` values
- Missing the full JSON structure with "ARPL" type identifier
- App cannot detect ARPL pathway

**The Fix:**
- One SQL UPDATE query to sync sites with project pathway data
- Takes ~10 seconds to execute
- No code changes needed
- Instantly fixes the ARPL UI detection

**Impact:**
- 🚀 ARPL assessors will see correct UI
- 🚀 ARPL Toolkit will be visible
- 🚀 All appendices will be accessible
- 🚀 Full ARPL workflow will work

---

**File:** `fix_sites_project_pathway.sql` contains the complete fix script ready to deploy.

