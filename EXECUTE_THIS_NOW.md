# EXECUTE THIS NOW - ARPL MENU FIX

## SITUATION
- ✅ LOCAL server: ARPL menu works for facilitator 118 → ClassID 797
- ❌ ONLINE server: ARPL menu NOT working for facilitator 6 → Should be ClassID 797
- ✅ All code is fixed
- ✅ APK is built and ready
- 🔍 Need to identify database difference between LOCAL and ONLINE

---

## WHAT TO DO NOW

### STEP 1: Deploy Diagnostic Script (5 minutes)

Upload this file to the ONLINE server:
```
File: c:\projects\rlmss\run_online_diagnostic.php
Destination on server: /run_online_diagnostic.php (in root, or /mobile/run_online_diagnostic.php)
Method: FTP, SSH, or file manager
```

### STEP 2: Run Diagnostic (1 minute)

Open in web browser:
```
https://rlms.rlmss.co.za/run_online_diagnostic.php
```

**Expected**: JSON output with diagnostic information

### STEP 3: Analyze Output (10 minutes)

Look for these critical fields:

```json
{
  "step_1_facilitator_exists": {
    "found": true/false,                    ← Facilitator 6 exists?
    "role_raw": "???",                      ← What is actual role?
    "classIDs_array": ["797", "800", ...]   ← What classes assigned?
  },
  
  "step_2_role_detection": {
    "will_show_arpl_menu": true/false       ← CRITICAL: Will menu appear?
  },
  
  "step_4_pathway_detection": [
    {
      "classID": 797,
      "will_detect_as_arpl": true/false     ← CRITICAL: ARPL pathway present?
    }
  ],
  
  "final_verdict": {
    "will_arpl_menu_appear": true/false,    ← CRITICAL: Overall result
    "root_cause": "???",                    ← What's wrong?
    "next_action": "???"                    ← What to fix?
  }
}
```

---

## INTERPRETATION GUIDE

### Result: `will_arpl_menu_appear: true`
✅ **Database looks correct**
- All checks passed
- Problem is likely client-side (old APK or cache)
- Solution: Clear app cache, reinstall APK

### Result: `will_arpl_menu_appear: false` with root cause: "ROLE_MISMATCH"
❌ **Facilitator role is wrong**
- Current role: Check `step_1_facilitator_exists.role_raw`
- Solution: Update facilitator 6 role to include "arpl" and "assessor"
- SQL: `UPDATE facilitator SET role = 'arpl_Assessor' WHERE facilitator_id = 6;`

### Result: `will_arpl_menu_appear: false` with root cause: "NO_CLASSES"
❌ **Facilitator not assigned to any classes**
- Problem: facilitator 6 has no classID assigned
- Solution: Assign facilitator 6 to ClassID 797
- SQL: `UPDATE facilitator SET classID = '797' WHERE facilitator_id = 6;`

### Result: `will_arpl_menu_appear: false` with root cause: "NO_ARPL_PATHWAY"
❌ **Classes don't have ARPL pathway data**
- Problem: Site's Project_pathway is empty or doesn't contain ARPL
- Solution: Update sites.Project_pathway with ARPL trade name
- SQL: `UPDATE sites SET Project_pathway = 'ARPL Electrician' WHERE siteID = 828;`

### Result: `will_arpl_menu_appear: false` with root cause: "PROJECT_PATHWAY_COLUMN_MISSING"
❌ **get_classes.php query doesn't include Project_pathway column**
- Problem: Mobile query missing the crucial pathway column
- Solution: Update `mobile/get_classes.php` to include `s.Project_pathway`
- Need to update SELECT statement on online server

---

## QUICK SQL FIXES

Use these if indicated by the diagnostic output:

### Fix 1: Update Facilitator Role
```sql
UPDATE facilitator 
SET role = 'arpl_Assessor' 
WHERE facilitator_id = 6;
```

### Fix 2: Assign Facilitator to ARPL Class
```sql
UPDATE facilitator 
SET classID = '797' 
WHERE facilitator_id = 6;
```

### Fix 3: Add ARPL Pathway Data
```sql
UPDATE sites 
SET Project_pathway = 'ARPL Electrician' 
WHERE siteID = 828;
```

### Fix 4: Verify ARPL Classes Exist
```sql
SELECT * FROM class WHERE classID = 797;
SELECT * FROM sites WHERE siteID = 828;
```

---

## VERIFICATION STEPS

After applying a fix:

1. Run diagnostic script again
2. Verify `will_arpl_menu_appear: true`
3. If still false, go back to interpretation guide
4. Once true, clear app cache and reinstall APK

---

## FILES INVOLVED

| File | Location | Purpose |
|------|----------|---------|
| `run_online_diagnostic.php` | Project root | Diagnostic script to deploy |
| `mobile/login.php` | Already on both servers | Role detection (already fixed) |
| `mobile/get_classes.php` | Already on both servers | Class query (already fixed) |
| `lib/AssessorPage.dart` | In APK | ARPL detection (already fixed) |
| `lib/config.dart` | In APK | Server config |
| `app-release.apk` | Build folder | Ready to reinstall |

---

## TIMELINE

```
Deploy script:        5 min
Run diagnostic:       1 min
Analyze results:     10 min
Apply fix:           5-10 min
Verify:              5 min
─────────────────────────
Total:              25-35 min
```

---

## SUCCESS = ARPL Menu Appears

**When facilitator 6 logs in on ONLINE server:**
- ✅ Show: ARPL Assessor menu
- ✅ Include: ARPL options (Appendix D, E, F, etc.)
- ❌ Don't show: Regular Assessor menu

---

## IF YOU GET STUCK

1. Check the JSON output for "issues" array
2. Each issue has "message", "expected", "actual"
3. Cross-reference with sections above
4. Apply corresponding fix

---

## NOTES

- The diagnostic will check EXACT same logic as login.php (line 225)
- The diagnostic will check EXACT same logic as AssessorPage.dart (lines 64-100)
- If diagnostic says "should work", then APK/cache is the issue
- If diagnostic says "won't work", database needs fixing

