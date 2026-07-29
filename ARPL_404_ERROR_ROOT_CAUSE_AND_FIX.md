# ARPL 404 ERROR - ROOT CAUSE IDENTIFIED AND FIXED

**Date:** July 15, 2026  
**Issue:** Getting "Error saving: Exception: Failed to save Appendix B/D/E: 404" on all appendix saves for Bricklaying

---

## 🔴 ROOT CAUSE

The **View Complete Toolkit** route in `lib/ArplToolkitViewerPage.dart` was calling a **NON-EXISTENT endpoint**:

```dart
// Line 292 in ArplToolkitViewerPage.dart
final response1 = await http.post(
  Uri.parse('${AppConfig.baseUrl}/mobile/save_arpl_toolkit_edits.php'),  // ← FILE DID NOT EXIST!
  ...
);
```

This endpoint **`save_arpl_toolkit_edits.php`** was missing from the server, causing **404 errors**.

### Why This Happened

There are **TWO different routes** that save ARPL data:

1. **Assessor Review (D,E,F)** route → Uses individual endpoints:
   - `save_arpl_appendix_b.php` ✅ EXISTS
   - `save_arpl_appendix_d.php` ✅ EXISTS
   - `save_arpl_appendix_e.php` ✅ EXISTS

2. **View Complete Toolkit** route → Uses **COMBINED endpoint**:
   - `save_arpl_toolkit_edits.php` ❌ **DID NOT EXIST** (causing 404!)

---

## ✅ SOLUTION IMPLEMENTED

Created the missing endpoint: **`mobile/save_arpl_toolkit_edits.php`**

This endpoint:
- Accepts a combined payload with Appendix B, D, and E data
- Saves all three appendices in a single request
- Handles all trades (Bricklayer, Electrician, Plumber) dynamically based on OFO number
- Returns detailed response with save counts for each appendix

### Endpoint Features

**Request Format:**
```json
{
  "learnerID": 11701,
  "classID": 797,
  "ofoNumber": "641201",
  "appendixB": [
    {"activity_id": 1, "rating": 4, "comments": "Good work"}
  ],
  "appendixD": {
    "1": "yes",
    "2": "no"
  },
  "appendixE": [
    {"activity_id": 1, "rating": 3, "comments": "Needs improvement"}
  ]
}
```

**Response Format:**
```json
{
  "status": "success",
  "message": "All appendices saved successfully",
  "details": {
    "appendixB": {"saved": 2, "errors": []},
    "appendixD": {"status": "updated"},
    "appendixE": {"saved": 3, "errors": []}
  }
}
```

---

## 📋 FILES TO UPLOAD TO SERVER

**CRITICAL - MUST UPLOAD:**
```
mobile/save_arpl_toolkit_edits.php  ← NEW FILE (Fixes the 404!)
```

**Verify these also exist:**
```
mobile/save_arpl_appendix_b.php
mobile/save_arpl_appendix_d.php
mobile/save_arpl_appendix_e.php
mobile/save_arpl_appendix_f.php
mobile/save_arpl_criteria.php
mobile/get_class_trade_info.php
```

---

## 🧪 TESTING

### Test Endpoint Accessibility

Visit: `https://rlms.rlms.co.za/mobile/test_all_arpl_endpoints.php`

This diagnostic page will:
1. ✅ Check if all ARPL endpoint files exist and are readable
2. ✅ Verify database tables exist
3. ✅ Show expected URLs the app is calling
4. ✅ Highlight any missing files or tables

### Test Save Functionality

**Route:** Menu → **View Complete Toolkit** → Select Learner (Anele Cele)

**Steps:**
1. Open Complete Toolkit for learner
2. Edit any rating in Appendix B, D, or E
3. Tap "Save All Changes" button
4. **Expected Result:** Success message "All appendices saved successfully"
5. **Previous Result:** "Error saving: Exception: Failed to save Appendix B/D/E: 404" ❌

---

## 🔍 WHY THE CONFUSION

We were focused on the **individual save endpoints** (which all exist and work fine), but the error was coming from the **View Complete Toolkit route** which uses a **different combined endpoint** that was missing.

### Two Different Code Paths:

| Route | File | Endpoints Used |
|-------|------|----------------|
| **Assessor Review (D,E,F)** | `ArplAssessorPage.dart` | `save_arpl_appendix_b.php`<br>`save_arpl_appendix_d.php`<br>`save_arpl_appendix_e.php` |
| **View Complete Toolkit** | `ArplToolkitViewerPage.dart` | `save_arpl_toolkit_edits.php` ← **MISSING!** |

---

## 📊 ENDPOINT MAPPING

### All ARPL Endpoints

| Endpoint | Purpose | Status |
|----------|---------|--------|
| `save_arpl_appendix_b.php` | Save Appendix B ratings individually | ✅ EXISTS |
| `save_arpl_appendix_d.php` | Save Appendix D responses individually | ✅ EXISTS |
| `save_arpl_appendix_e.php` | Save Appendix E ratings individually | ✅ EXISTS |
| `save_arpl_appendix_f.php` | Save Appendix F assessment | ✅ EXISTS |
| `save_arpl_criteria.php` | Save evaluation criteria | ✅ EXISTS |
| **`save_arpl_toolkit_edits.php`** | **Save B+D+E combined (Toolkit view)** | ✅ **CREATED** |
| `save_arpl_appendix_f_assessment.php` | Save Appendix F assessment (alt) | ✅ EXISTS |
| `get_arpl_competency_data.php` | Get activities for B/E | ✅ EXISTS |
| `get_class_trade_info.php` | Get OFO from classID | ✅ EXISTS |

---

## ✅ NEXT STEPS

1. **Upload the new file:**
   ```bash
   Upload: mobile/save_arpl_toolkit_edits.php
   To: /home/rlmsrlmsco/public_html/mobile/
   ```

2. **Verify upload:**
   - Visit: `https://rlms.rlms.co.za/mobile/test_all_arpl_endpoints.php`
   - Should show **ALL ENDPOINTS ARE ACCESSIBLE** ✅

3. **Test the fix:**
   - Open View Complete Toolkit
   - Select Anele Cele (Bricklayer, Class 797)
   - Edit any rating
   - Save → Should now work! ✅

4. **Verify database tables:**
   - `arpl_evaluation_criteria` was created (from previous fix)
   - All Bricklayer tables exist (verified in previous queries)

---

## 🎯 EXPECTED RESULT

After uploading `save_arpl_toolkit_edits.php`:

- ✅ **View Complete Toolkit** → Save button works
- ✅ **Assessor Review (D,E,F)** → Save buttons work (already working)
- ✅ All appendix saves work for all trades (Bricklayer, Electrician, Plumber)
- ❌ No more 404 errors

---

## 🔧 TECHNICAL DETAILS

### Why We Need Both Individual and Combined Endpoints

1. **Individual endpoints** (`save_arpl_appendix_b.php`, etc.)
   - Used by Assessor Review route
   - Saves one appendix at a time
   - Simpler payload structure

2. **Combined endpoint** (`save_arpl_toolkit_edits.php`)
   - Used by View Complete Toolkit route
   - Saves B+D+E in single request
   - More efficient for full toolkit edits

Both approaches are valid and serve different UI workflows.

---

## 📝 SUMMARY

**Problem:** 404 error when saving from View Complete Toolkit  
**Root Cause:** Missing `save_arpl_toolkit_edits.php` endpoint  
**Solution:** Created the missing endpoint with full B+D+E save logic  
**Status:** Ready to upload and test  
**Impact:** Fixes ALL save operations in View Complete Toolkit route  

---

**File Created:** `mobile/save_arpl_toolkit_edits.php`  
**Diagnostic Tool:** `mobile/test_all_arpl_endpoints.php`  
**Ready for deployment!** ✅
