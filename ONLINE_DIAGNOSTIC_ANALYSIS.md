# ONLINE DIAGNOSTIC ANALYSIS - ARPL ASSESSOR MENU FIX

**Date**: July 14, 2026  
**Status**: Ready to Execute  
**Priority**: CRITICAL

---

## OBJECTIVE

Identify why the ARPL assessor menu doesn't appear for facilitator 6 on the ONLINE server, when:
1. Code logic is correct (verified on LOCAL)
2. Database contains facilitator 6 data (confirmed exists)
3. Facilitator 6 should be assigned to an ARPL class

---

## THE MYSTERY

We know from the conversation:
- **LOCAL database**: Facilitator 118 assigned to ClassID 797 (ARPL) ✅ WORKS
- **ONLINE database**: Facilitator 6 supposedly assigned to ClassID 797 (ARPL) ❌ DOESN'T WORK

Both databases have the same ClassID 797, but different facilitator IDs.

**The Question**: If facilitator 6 on ONLINE is also assigned to ClassID 797, why doesn't the ARPL menu appear?

---

## POSSIBLE ROOT CAUSES

### Cause A: Role Detection Failure
```
LOCAL:  Facilitator 118, role = "arpl_Assessor"     → Role detection SUCCESS ✓
ONLINE: Facilitator 6, role = "???"                 → Role detection FAIL ✗
```

**Diagnosis**: Check facilitator 6's role field in ONLINE database

**Fix**: Update role to match format containing both "arpl" and "assessor"

---

### Cause B: Class Assignment Mismatch
```
LOCAL:  Facilitator 118 → classID = "797"                      ✓
ONLINE: Facilitator 6   → classID = "???"  (not 797?)          ✗
```

**Diagnosis**: Check facilitator 6's classID field in ONLINE database

**Note**: User said it's 797, but maybe it's actually different

**Fix**: Reassign facilitator 6 to ClassID 797 or check actual assignment

---

### Cause C: Missing ARPL Pathway Data
```
LOCAL:  ClassID 797 site → Project_pathway = "ARPL Electrician" ✓
ONLINE: ClassID 797 site → Project_pathway = ""                ✗
```

**Diagnosis**: Check sites.Project_pathway for the site linked to ClassID 797

**Fix**: Populate Project_pathway with ARPL trade name

---

### Cause D: get_classes.php Not Including Project_pathway
```
Query might not include:  s.Project_pathway  column
```

**Diagnosis**: Check mobile/get_classes.php response includes Project_pathway

**Fix**: Ensure SELECT includes s.Project_pathway from sites table

---

## DIAGNOSTIC SCRIPT APPROACH

Created: `run_online_diagnostic.php`

This script will:

1. ✅ Verify facilitator 6 exists
2. ✅ Read facilitator 6's role from database
3. ✅ Apply EXACT login.php role detection logic
4. ✅ Get all classes assigned to facilitator 6
5. ✅ Check each class's site for Project_pathway data
6. ✅ Apply EXACT AssessorPage.dart ARPL detection logic
7. ✅ Compare with LOCAL working state
8. ✅ Identify root cause
9. ✅ Recommend fix

---

## HOW TO RUN THE DIAGNOSTIC

### Step 1: Upload Script to ONLINE Server
```
File: c:\projects\rlmss\run_online_diagnostic.php
Destination: https://rlms.rlmss.co.za/run_online_diagnostic.php
Method: FTP or file manager
```

### Step 2: Execute on ONLINE Server
```
URL: https://rlms.rlmss.co.za/run_online_diagnostic.php
Method: Open in browser or curl
Expected: JSON response with detailed diagnostic data
```

### Step 3: Save Output
```
Copy full JSON response to analyze
```

### Step 4: Compare with LOCAL Output
```
Run same diagnostic on LOCAL server:
http://192.168.0.57:8080/assessorReport2/run_online_diagnostic.php
```

### Step 5: Analyze Differences
```
Look for differences in:
- facilitator role
- classID assignments
- Project_pathway values
- ARPL detection results
```

---

## EXPECTED DIAGNOSTIC OUTPUT FORMAT

```json
{
  "timestamp": "2026-07-14 16:05:00",
  "server": "rlms.rlmss.co.za",
  "environment": "ONLINE",
  
  "step_1_facilitator_exists": {
    "found": true,
    "facilitator_id": 6,
    "name": "John Doe",
    "role_raw": "arpl_Assessor",
    "classID_raw": "797,800,812",
    "classIDs_array": ["797", "800", "812"],
    "number_of_classes": 3
  },
  
  "step_2_role_detection": {
    "role_from_db": "arpl_Assessor",
    "login_php_logic_result": "arpl_assessor",    ← CRITICAL
    "will_show_arpl_menu": true,                   ← CRITICAL
    "tests": {
      "contains_both_arpl_and_assessor": true,
      "exact_match_assessor": false,
      "exact_match_moderator": false
    }
  },
  
  "step_3_classes": {
    "count": 3,
    "classes": [
      {
        "classID": 797,
        "className": "ARPL Electrician",
        "siteID": 828,
        "siteName": "NDENGEZI",
        "Project_pathway": "ARPL Electrician",      ← CRITICAL
        "project_id": "arpl_electrician"
      },
      ...
    ]
  },
  
  "step_4_pathway_detection": [
    {
      "classID": 797,
      "className": "ARPL Electrician",
      "pathway_raw": "ARPL Electrician",
      "will_detect_as_arpl": true                   ← CRITICAL
    },
    ...
  ],
  
  "step_6_diagnosis": {
    "issues": [],
    "summary": "NO ISSUES - SHOULD WORK"
  },
  
  "final_verdict": {
    "will_arpl_menu_appear": true,
    "root_cause": "Unknown - data looks correct",
    "next_action": "Clear app cache and reinstall APK - database appears correct"
  }
}
```

---

## WHAT EACH RESULT MEANS

### If `will_show_arpl_menu` = FALSE
```
Problem: Role detection failed
Solution: Update facilitator 6's role in database

Current role format doesn't contain both "arpl" and "assessor"
Required: Role string with both keywords (case-insensitive)
Example: "arpl_Assessor", "ARPL_Assessor", "arpl_assessor", "Assessor_ARPL"
```

### If `step_3_classes` count = 0
```
Problem: Facilitator has no classes assigned
Solution: Assign facilitator 6 to ClassID 797 or another ARPL class

Check: facilitator.classID field for facilitator_id = 6
Update: INSERT or UPDATE facilitator set classID = '797' WHERE facilitator_id = 6
```

### If `will_detect_as_arpl` = FALSE for all classes
```
Problem: Classes don't have ARPL pathway data
Solution: Update sites.Project_pathway with ARPL trade names

Check: sites.Project_pathway for the siteID linked to facilitator's classes
Update: SET Project_pathway = 'ARPL Electrician' WHERE siteID = 828
```

### If `Project_pathway` column is missing from response
```
Problem: get_classes.php not returning pathway column
Solution: Update mobile/get_classes.php query

Required change:
    SELECT c.classID, ..., s.Project_pathway  ← Add this
    FROM class c
    JOIN sites s ON c.siteID = s.siteID
```

### If ALL CRITICAL VALUES are CORRECT but menu still doesn't appear
```
Problem: Likely client-side cache or old APK version
Solution: 
1. Clear app cache on phone
2. Clear app data on phone
3. Reinstall APK (fresh install, not update)
4. Log in again
```

---

## DECISION TREE

```
Run diagnostic script on ONLINE server
        ↓
Does facilitator 6 exist?
├─ NO  → Add facilitator 6 to database
└─ YES ↓
       Does role contain "arpl" AND "assessor"?
       ├─ NO  → Update role field (Cause A)
       └─ YES ↓
              Does facilitator have any classes?
              ├─ NO  → Assign to ClassID 797 (Cause B)
              └─ YES ↓
                     Do any classes have ARPL pathway?
                     ├─ NO  → Update sites.Project_pathway (Cause C)
                     └─ YES ↓
                            Does get_classes response include Project_pathway?
                            ├─ NO  → Update get_classes.php query (Cause D)
                            └─ YES ✓ ALL CORRECT
                                   Clear app cache & reinstall APK
```

---

## FILES CREATED

| File | Purpose | Status |
|------|---------|--------|
| `run_online_diagnostic.php` | Main diagnostic script | ✅ Ready to deploy |
| `ONLINE_DIAGNOSTIC_ANALYSIS.md` | This analysis document | ✅ Created |

---

## FILES REFERENCED (Code Being Diagnosed)

| File | Lines | Purpose |
|------|-------|---------|
| `mobile/login.php` | 213-230 | Role detection logic |
| `mobile/get_classes.php` | 12-30 | Get classes query |
| `lib/AssessorPage.dart` | 64-100 | ARPL menu display logic |
| `lib/config.dart` | 1-40 | Server configuration |

---

## DEPLOYMENT PLAN

### TODAY (July 14, 2026)
1. Upload `run_online_diagnostic.php` to ONLINE server
2. Execute script to get JSON diagnostic output
3. Analyze results
4. Identify root cause

### NEXT STEPS (based on findings)
1. Apply fix to ONLINE database or code
2. Re-run diagnostic to verify fix
3. If all correct: Clear app cache, reinstall APK
4. Test ARPL menu appears for facilitator 6

---

## TIME ESTIMATE

- Upload script: 2 minutes
- Execute script: 1 minute
- Analyze results: 5 minutes
- Apply fix: 5-15 minutes (depends on issue type)
- Verify fix: 5 minutes
- Total: 20-30 minutes to resolution

---

## SUCCESS CRITERIA

**ARPL menu appears when facilitator 6 logs into ONLINE server**

```
Facilitator Login:  "facilitator_user" / "password"
Expected Result:    ARPL Assessor menu with ARPL options
Current Result:     Regular Assessor menu
Target Result:      ✅ ARPL Assessor menu
```

---

## CRITICAL NOTES

⚠️ **DO NOT GUESS OR MAKE RANDOM CHANGES**

Run the diagnostic first. It will tell us exactly what's wrong.

⚠️ **DATABASE DIFFERENCES MATTER**

Even though LOCAL and ONLINE both have facilitator 6, their data might be different:
- Different role format
- Different class assignments
- Different pathway data
- Different database version

⚠️ **CODE CHANGES ALREADY APPLIED**

All PHP and Dart code has been fixed. This diagnostic is to find the data issue, not a code issue.

---

## NEXT INSTRUCTIONS

1. Read this entire document
2. Upload `run_online_diagnostic.php` to online server's `/mobile/` directory
3. Open URL in browser: `https://rlms.rlmss.co.za/run_online_diagnostic.php`
4. Copy entire JSON response
5. Share response for analysis
6. Follow the "DECISION TREE" section to identify root cause
7. Apply appropriate fix
8. Re-run diagnostic to verify

