# Project_pathway Fix - Complete

## ISSUE IDENTIFIED ✅

The error was:
```
{"status":"error","message":"Unknown column 'c.Project_pathway' in 'SELECT'"}
```

## ROOT CAUSE

The `get_class_trade_info.php` file was querying `c.Project_pathway` (from class table), but the column actually exists in the **SITES table**, not the class table.

## DATABASE STRUCTURE

```
class table:
  - classID (PK)
  - className
  - siteID (FK → sites.siteID)
  - trade_id (FK → arpl_trades.trade_id)

sites table:
  - siteID (PK)
  - siteName
  - Project_pathway (JSON column) ← OFO data is HERE

arpl_trades table:
  - trade_id (PK)
  - trade_name
  - ofo_number
```

## RELATIONSHIP

```
class → sites (via siteID)
      → arpl_trades (via trade_id)
```

The `Project_pathway` column is in the `sites` table, storing JSON like:
```json
[{"type":"ARPL","name":"Bricklayer","ofo_code":"641201"}]
```

## FIX APPLIED ✅

Modified `mobile/get_class_trade_info.php`:

**BEFORE** (incorrect):
```sql
SELECT 
    c.classID,
    c.className,
    c.trade_id,
    c.Project_pathway,  ← ERROR: Column doesn't exist in class table
    ...
FROM class c
LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
LEFT JOIN sites s ON c.siteID = s.siteID
```

**AFTER** (correct):
```sql
SELECT 
    c.classID,
    c.className,
    c.trade_id,
    c.siteID,
    s.siteName,
    s.Project_pathway,  ← CORRECT: Column from sites table
    t.trade_name,
    t.ofo_number
FROM class c
LEFT JOIN sites s ON c.siteID = s.siteID
LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
```

## OFO FALLBACK CHAIN

The endpoint now uses this priority:

1. **Primary**: `arpl_trades.ofo_number` (via trade_id JOIN)
2. **Fallback**: `sites.Project_pathway` JSON (parse ofo_code)
3. **Default**: '671101' (Electrician)

## FILES UPDATED

1. ✅ `mobile/get_class_trade_info.php` - Fixed to query sites.Project_pathway
2. ✅ `check_class_sites_schema.php` - Created diagnostic script

## NEXT STEP

**Re-upload the corrected file**:

```
File: mobile/get_class_trade_info.php
Upload to: https://rlms.rlms.co.za/mobile/
Action: Replace the existing file with corrected version
```

## TEST AFTER RE-UPLOAD

```
https://rlms.rlms.co.za/mobile/get_class_trade_info.php?classID=797
```

**Expected Response**:
```json
{
  "status": "success",
  "classID": 797,
  "className": "...",
  "trade_name": "Bricklayer",
  "ofo_number": "641201",
  "siteName": "..."
}
```

**NOT**:
```json
{"status":"error","message":"Unknown column 'c.Project_pathway' in 'SELECT'"}
```

## APP TEST

After re-uploading the corrected file:

1. Open app
2. Menu → **View Complete Toolkit**
3. Select learner: **Anele Cele**
4. **Expected**: OFO Number shows **641201** (not "Not Set")

---

**Status**: Fix applied locally, ready for re-upload  
**Date**: 2026-07-15  
**Issue**: Schema mismatch - querying wrong table for Project_pathway  
**Solution**: Query sites.Project_pathway instead of class.Project_pathway

