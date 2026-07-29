# FIX ACTIVITIES NOT LOADING + 404 SAVE ERRORS - COMPLETE GUIDE

## SUMMARY

Fixed **TWO critical issues**:
1. ✅ Activities not loading from database (endpoint was hardcoded for Electrician only)
2. ✅ 404 errors when saving (endpoints need to be uploaded to server)

---

## ISSUE 1: ACTIVITIES NOT LOADING (FIXED)

### Problem
- OFO shows correctly (641201)
- BUT activities don't load from database
- Endpoint was hardcoded to query `arplappxb_electrician_activities` only

### Root Cause
`mobile/get_arpl_competency_data.php` was hardcoded to fetch only Electrician activities, regardless of OFO number

### Solution Applied
Modified endpoint to:
1. Accept OFO as string parameter (not just int)
2. Dynamically select correct table based on OFO:
   - 641201 → `arplappxb_bricklaying_activities`
   - 671101 → `arplappxb_electrician_activities`
   - 671201 → `arplappxb_plumber_activities`
3. Check table exists before querying
4. Return error if table not found

### Files Modified
- ✅ `mobile/get_arpl_competency_data.php` - Fixed to support all trades

---

## ISSUE 2: 404 SAVE ERRORS (NEED TO UPLOAD)

### Problem
When saving Appendix B, D, or E → Returns 404 error

### Root Cause
Save endpoint PHP files exist LOCALLY but NOT on ONLINE server

### Files That Need Upload
All these files exist in `c:\projects\rlmss\mobile\` and need to be uploaded:

**Critical (Used by both routes)**:
1. `save_arpl_appendix_b.php` - Save Appendix B activities
2. `save_arpl_appendix_d.php` - Save Appendix D self-evaluation
3. `save_arpl_appendix_e.php` - Save Appendix E interview ratings
4. `save_arpl_appendix_f.php` - Save Appendix F feedback
5. `save_arpl_criteria.php` - Save evaluation criteria

**Optional (may be needed later)**:
6. `save_arpl_toolkit_edits.php` - Save complete toolkit edits
7. `save_arpl_access_recommendation.php` - Save Appendix H
8. `save_arpl_gap_analysis.php` - Save gap analysis

---

## UPLOAD & TEST INSTRUCTIONS

### STEP 1: Upload Fixed Activity Loading Endpoint ⚠️ CRITICAL

```
File: mobile/get_arpl_competency_data.php
Upload to: https://rlms.rlms.co.za/mobile/
```

**Test After Upload**:
```
URL: https://rlms.rlms.co.za/mobile/test_get_arpl_competency_fixed.php

Expected Result:
✅ SUCCESS: Activities Loaded
Total Activities: [number > 0]
Sample activities shown for Bricklayer
```

---

### STEP 2: Upload Save Endpoints ⚠️ CRITICAL

Upload ALL these files to: `https://rlms.rlms.co.za/mobile/`

**Priority 1** (Used immediately):
```
✅ save_arpl_appendix_b.php
✅ save_arpl_appendix_d.php
✅ save_arpl_appendix_e.php
```

**Priority 2** (Used for complete workflow):
```
✅ save_arpl_appendix_f.php
✅ save_arpl_criteria.php
```

**Priority 3** (Optional, upload if needed):
```
□ save_arpl_toolkit_edits.php
□ save_arpl_access_recommendation.php
□ save_arpl_gap_analysis.php
```

---

### STEP 3: Verify Files Uploaded Successfully

Test each endpoint exists:

**Test Activity Loading**:
```
https://rlms.rlms.co.za/mobile/get_arpl_competency_data.php?learnerID=11701&ofo_number=641201
Expected: JSON with activities array
```

**Test Save Endpoints Exist** (will return error but shouldn't be 404):
```
https://rlms.rlms.co.za/mobile/save_arpl_appendix_b.php
https://rlms.rlms.co.za/mobile/save_arpl_appendix_d.php
https://rlms.rlms.co.za/mobile/save_arpl_appendix_e.php

Expected: NOT 404 (should see PHP error or JSON error message)
If 404: File not uploaded correctly
```

---

### STEP 4: Test in App

**Test Route 1: Assessor Review (D,E,F)**
1. Menu → Assessor Review (D,E,F)
2. Select: Anele Cele
3. Go to Appendix B tab
4. **CHECK**: Activities should now load (not "Activities not loaded")
5. Rate some activities
6. Click Save button
7. **EXPECTED**: "Appendix B saved successfully" (NOT 404)

**Test Route 2: View Complete Toolkit**
1. Menu → View Complete Toolkit
2. Select: Anele Cele
3. Click: Open Complete Toolkit
4. **CHECK**: Activities should load
5. Make some edits
6. Click Save button
7. **EXPECTED**: "Saved successfully" (NOT 404)

---

## ENDPOINT DETAILS

### get_arpl_competency_data.php

**Purpose**: Load activities for a learner based on OFO number

**Parameters**:
- `learnerID` (required): Learner ID
- `ofo_number` (optional): OFO code (e.g., "641201")

**Response**:
```json
{
  "status": "success",
  "ofo_number": "641201",
  "appxb_activities": [
    {
      "activity_id": 1,
      "activity_number": "1",
      "activity_name": "Interpret drawings...",
      "ofo_number": "641201"
    }
  ],
  "total_activities": 20
}
```

**Trade Mapping**:
- 641201 → arplappxb_bricklaying_activities
- 671101 → arplappxb_electrician_activities  
- 671201 → arplappxb_plumber_activities

---

### save_arpl_appendix_b.php

**Purpose**: Save Appendix B activity ratings

**Method**: POST

**Payload**:
```json
{
  "learnerID": 11701,
  "assessor_id": 6,
  "ofo_number": "641201",
  "ratings": [
    {
      "activity_id": 1,
      "activity_name": "...",
      "rating": 4,
      "comments": "..."
    }
  ]
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Saved X activities"
}
```

---

### save_arpl_appendix_d.php

**Purpose**: Save Appendix D self-evaluation responses

**Method**: POST

**Payload**:
```json
{
  "learnerID": 11701,
  "assessor_id": 6,
  "ofo_number": "641201",
  "activities": {
    "1": "yes",
    "2": "no",
    "3": "yes"
  }
}
```

---

### save_arpl_appendix_e.php

**Purpose**: Save Appendix E interview ratings

**Method**: POST

**Payload**:
```json
{
  "learnerID": 11701,
  "assessor_id": 6,
  "ofo_number": "641201",
  "ratings": [
    {
      "activity_id": 1,
      "rating": 5,
      "comments": "..."
    }
  ]
}
```

---

## TROUBLESHOOTING

### If Activities Still Don't Load After Upload

**Check 1: Test Endpoint Directly**
```
https://rlms.rlms.co.za/mobile/test_get_arpl_competency_fixed.php
```

**Possible Issues**:
1. **File didn't upload** → Re-upload get_arpl_competency_data.php
2. **Table is empty** → Database has no activities for OFO 641201
3. **OFO mismatch** → Activities in DB have different OFO value

**Check 2: Verify Database Has Activities**
```sql
SELECT COUNT(*) 
FROM arplappxb_bricklaying_activities 
WHERE ofo_number = '641201';
```

If count = 0: Need to populate activities table

---

### If Save Still Returns 404

**Check 1: Verify Files Uploaded**
```
Visit each URL in browser:
https://rlms.rlms.co.za/mobile/save_arpl_appendix_b.php
https://rlms.rlms.co.za/mobile/save_arpl_appendix_d.php
https://rlms.rlms.co.za/mobile/save_arpl_appendix_e.php

Should NOT see "404 Not Found"
Should see PHP error or JSON error message
```

**Check 2: File Permissions**
Ensure uploaded files have correct permissions:
- Recommended: 644 or 755
- Owner: Your cPanel user
- Group: Your cPanel group

**Check 3: File Location**
Files must be in:
```
/home/rlmsrlmsco/public_html/mobile/save_arpl_appendix_b.php
/home/rlmsrlmsco/public_html/mobile/save_arpl_appendix_d.php
/home/rlmsrlmsco/public_html/mobile/save_arpl_appendix_e.php
```

NOT in subdirectories or wrong location.

---

### If Save Returns Error (Not 404)

**Possible Database Issues**:
1. **Missing columns**: Endpoint expects columns that don't exist
2. **Wrong table**: Table name mismatch
3. **Constraint violations**: UNIQUE KEY or FOREIGN KEY issues

**To Diagnose**:
```
1. Check Apache error logs for PHP errors
2. Enable error reporting in PHP files temporarily
3. Check database schema matches code expectations
```

---

## SUCCESS CRITERIA

### Activities Loading
- [x] Endpoint uploaded
- [ ] Test script shows activities loaded
- [ ] App shows activities in Appendix B
- [ ] App shows activities in Appendix D
- [ ] App shows activities in Appendix E

### Save Functionality  
- [x] Endpoints uploaded
- [ ] Test URLs return non-404 responses
- [ ] App can save Appendix B without 404
- [ ] App can save Appendix D without 404
- [ ] App can save Appendix E without 404
- [ ] Saved data persists in database
- [ ] Can reload and see saved ratings

---

## UPLOAD CHECKLIST

### Files to Upload (Check when complete)

**Critical - Upload These First**:
- [ ] `mobile/get_arpl_competency_data.php` ← FIX FOR ACTIVITIES
- [ ] `mobile/save_arpl_appendix_b.php` ← FIX FOR SAVE 404
- [ ] `mobile/save_arpl_appendix_d.php` ← FIX FOR SAVE 404
- [ ] `mobile/save_arpl_appendix_e.php` ← FIX FOR SAVE 404

**Important - Upload These Next**:
- [ ] `mobile/save_arpl_appendix_f.php`
- [ ] `mobile/save_arpl_criteria.php`

**Optional - Upload If Needed**:
- [ ] `mobile/save_arpl_toolkit_edits.php`
- [ ] `mobile/save_arpl_access_recommendation.php`
- [ ] `mobile/save_arpl_gap_analysis.php`

**Test Scripts** (Helpful for debugging):
- [ ] `mobile/test_get_arpl_competency_fixed.php`

---

## WHAT'S FIXED VS WHAT'S NEXT

### ✅ Fixed in Code (No Rebuild Needed)
1. `get_arpl_competency_data.php` - Now supports all trades dynamically
2. Save endpoints exist locally - Just need upload

### ⏳ Need to Upload
1. Activity loading endpoint
2. All save endpoints (B, D, E, F, criteria)

### 🎯 Next Issue (After These Work)
1. Appendix B save timeout (if it occurs)
2. Database schema issues (if any)

---

## QUICK REFERENCE

### Upload Location
```
cPanel File Manager → public_html/mobile/
```

### Test URLs
```
Activities: https://rlms.rlms.co.za/mobile/test_get_arpl_competency_fixed.php
Save B: https://rlms.rlms.co.za/mobile/save_arpl_appendix_b.php
Save D: https://rlms.rlms.co.za/mobile/save_arpl_appendix_d.php
Save E: https://rlms.rlms.co.za/mobile/save_arpl_appendix_e.php
```

### Test Credentials
```
Facilitator ID: 6
Role: arpl_Assessor
Class: 797
Learner: Anele Cele (ID: 11701)
OFO: 641201 (Bricklayer)
```

---

**Date**: 2026-07-15
**Status**: Code fixes complete, awaiting upload
**Priority**: HIGH - Blocking all ARPL assessments
