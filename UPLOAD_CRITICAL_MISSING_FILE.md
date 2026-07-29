# 🚨 CRITICAL: Missing File Causing "OFO Number: Not Set"

## PROBLEM IDENTIFIED

**ViewCompleteToolkitPage** shows "OFO Number: Not Set" because:
- The dropdown calls `_fetchOfoForClass()` method
- This method requests: `https://rlms.rlms.co.za/mobile/get_class_trade_info.php`
- **THIS FILE IS MISSING FROM THE ONLINE SERVER** ❌

## ROOT CAUSE

The file `mobile/get_class_trade_info.php` exists **LOCALLY** but was **NEVER UPLOADED** to the online server.

## SOLUTION

Upload this ONE critical file to fix the "Not Set" issue.

---

## FILE TO UPLOAD IMMEDIATELY

```
File: mobile/get_class_trade_info.php
Location: c:\projects\rlmss\mobile\get_class_trade_info.php
Upload to: https://rlms.rlms.co.za/mobile/
```

### What This File Does

1. Accepts `classID` parameter (e.g., 797)
2. Queries database for class trade information
3. Returns OFO number with fallback chain:
   - First tries `arpl_trades` table via `trade_id` JOIN
   - Falls back to `Project_pathway` JSON column
   - Falls back to default Electrician (671101)

### Response Format

```json
{
  "status": "success",
  "classID": 797,
  "className": "Bricklayer ARPL",
  "trade_id": 4,
  "trade_name": "Bricklayer",
  "ofo_number": "641201",
  "siteName": "Site Name"
}
```

---

## HOW TO UPLOAD

### Method 1: cPanel File Manager (Recommended)

1. Login to cPanel at `rlms.rlms.co.za/cpanel`
2. Click **File Manager**
3. Navigate to: `public_html/mobile/`
4. Click **Upload** button
5. Select file: `get_class_trade_info.php` from `c:\projects\rlmss\mobile\`
6. Wait for upload complete
7. Verify file appears in directory

### Method 2: FTP Client

1. Connect to: `rlms.rlms.co.za`
2. Navigate to: `/public_html/mobile/`
3. Upload: `get_class_trade_info.php`
4. Verify upload successful

---

## VERIFY UPLOAD WORKED

### Test 1: Direct Browser Test

Open in browser:
```
https://rlms.rlms.co.za/mobile/get_class_trade_info.php?classID=797
```

**Expected Response** (SUCCESS):
```json
{
  "status": "success",
  "classID": 797,
  "trade_name": "Bricklayer",
  "ofo_number": "641201"
}
```

**If you see 404** (FAILURE):
```
404 Not Found
```
→ File didn't upload correctly, try again

---

### Test 2: Test in App

After uploading the file:

1. Open the app
2. Menu → **View Complete Toolkit**
3. Select learner: **Anele Cele**
4. Check the "OFO Number" field

**BEFORE upload**:
```
OFO Number: Not Set  ❌
```

**AFTER upload**:
```
OFO Number: 641201  ✅
```

---

## WHY THIS WAS MISSED

The file was created to support:
- ViewCompleteToolkitPage OFO fetching
- Dynamic OFO resolution from `Project_pathway` JSON

But it was **NOT included in the upload checklists** created earlier. This is the missing piece!

---

## COMPLETE UPLOAD CHECKLIST (ALL MISSING FILES)

After discovering this issue, here's the COMPLETE list of files to upload:

### 🔥 CRITICAL #1 - Fix "OFO Number: Not Set"
```
✅ mobile/get_class_trade_info.php  ← YOU ARE HERE
```

### 🔥 CRITICAL #2 - Fix "Activities Not Loaded"
```
✅ mobile/get_arpl_competency_data.php
```

### 🔥 CRITICAL #3 - Fix 404 Save Errors
```
✅ mobile/save_arpl_appendix_b.php
✅ mobile/save_arpl_appendix_d.php
✅ mobile/save_arpl_appendix_e.php
✅ mobile/save_arpl_appendix_f.php
✅ mobile/save_arpl_criteria.php
```

---

## TEST SEQUENCE AFTER ALL UPLOADS

### Route 1: Assessor Review (D,E,F)

1. Menu → **Assessor Review (D,E,F)**
2. Select: Anele Cele
3. **CHECK**: OFO shows "641201" ✅ (already working)
4. Go to Appendix B tab
5. **CHECK**: Activities load from database ✅ (works after upload #2)
6. Rate some activities
7. Click **Save**
8. **CHECK**: Shows "Saved successfully" (NOT 404) ✅ (works after upload #3)

### Route 2: View Complete Toolkit

1. Menu → **View Complete Toolkit**
2. Select: Anele Cele
3. **CHECK**: OFO Number shows "641201" (NOT "Not Set") ✅ (works after upload #1)
4. Click **Open Complete Toolkit**
5. **CHECK**: Activities load ✅
6. Make edits
7. Click **Save**
8. **CHECK**: Shows "Saved successfully" (NOT 404) ✅ (works after upload #3)

---

## TECHNICAL DETAILS

### Why ViewCompleteToolkitPage Needs This File

**Location in code**: `lib/ArplAssessorPage.dart` (lines ~12646-12696)

**Flow**:
1. User selects learner from dropdown
2. Dropdown's `onChanged` triggers
3. Code extracts `classID` from selected learner
4. Calls `_fetchOfoForClass(classId)`
5. This method makes HTTP POST to: `mobile/get_class_trade_info.php`
6. Endpoint returns OFO number
7. Code sets `_selectedOfoNumber = ofo`
8. UI displays OFO number

**When file is missing**:
- HTTP request returns 404
- Method catches exception, returns `null`
- `_selectedOfoNumber` remains `null`
- UI displays "Not Set"

### Why Assessor Review Works Differently

**Assessor Review** route doesn't use `get_class_trade_info.php`:
- It uses `_fetchTraceabilityData()` method instead
- This method calls `mobile/get_arpl_data.php`
- That endpoint returns OFO directly with learner data
- So it never needed the missing file

**ViewCompleteToolkit** was designed differently:
- Only has learner dropdown (no class/OFO selection)
- Must infer OFO from classID
- Requires dedicated endpoint to fetch OFO by classID
- That's why `get_class_trade_info.php` was created

---

## SUMMARY

**Problem**: "OFO Number: Not Set" in View Complete Toolkit
**Root Cause**: Missing `mobile/get_class_trade_info.php` on server
**Solution**: Upload 1 file
**Time to Fix**: 2 minutes
**No Rebuild Needed**: Server-side only fix

---

## AFTER YOU UPLOAD

Reply with:
- ✅ "Uploaded get_class_trade_info.php - OFO now shows correctly!"

OR if there's an issue:
- ❌ "Uploaded but still shows 'Not Set'" + error message/screenshot

---

**Date**: 2026-07-15  
**Priority**: 🚨 CRITICAL - Blocks View Complete Toolkit route  
**Status**: File identified, ready to upload

