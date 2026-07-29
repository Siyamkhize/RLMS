# ARPL ASSESSOR FIX - DIAGNOSTIC DEPLOYMENT GUIDE

## Current Situation
- ✅ ARPL menu works on **LOCAL dev server** (192.168.0.57:8080)
- ❌ ARPL menu doesn't work on **ONLINE server** (rlms.rlmss.co.za)
- ✅ All code fixes have been applied
- ✅ APK has been rebuilt (45.8 MB, July 14)
- ✅ Diagnostic comparison scripts are ready

**Problem**: We don't know exactly what's different between the two servers

**Solution**: Deploy and run the diagnostic comparison script

---

## Step-by-Step Deployment Guide

### STEP 1: Deploy Diagnostic Script to Online Server

**What**: Upload the comparison PHP script to the online server  
**File**: `c:\projects\rlmss\mobile\compare_local_vs_online.php`  
**Destination**: `https://rlms.rlmss.co.za/mobile/compare_local_vs_online.php`

**How to Deploy**:
1. Open an FTP client or file manager
2. Connect to: rlms.rlmss.co.za
3. Navigate to: `/mobile/` directory
4. Upload: `compare_local_vs_online.php`
5. Verify: Visit `https://rlms.rlmss.co.za/mobile/compare_local_vs_online.php` in browser

**Expected Output** (JSON format):
```json
{
  "environment": "ONLINE",
  "server_info": {...},
  "facilitator_check": {
    "found": true,
    "facilitator_id": 6,
    "role_in_database": "arpl_Assessor"
  },
  "role_detection": {
    "detected_role": "arpl_assessor"
  },
  ...
}
```

---

### STEP 2: Run Comparison Script Locally

**What**: Compare LOCAL vs ONLINE using PowerShell  
**File**: `c:\projects\rlmss\compare_servers.ps1`  
**Command**:
```bash
cd c:\projects\rlmss
.\compare_servers.ps1
```

**What It Does**:
- Calls the comparison PHP script on BOTH servers
- Fetches diagnostic data from each
- Compares side-by-side
- Highlights differences

**Time**: ~30 seconds to 1 minute

---

## How to Interpret the Results

### Scenario 1: Everything Matches ✓

**Output**:
```
[OK] All checks match between LOCAL and ONLINE servers!

If ARPL menu still doesn't appear online, the issue might be:
  1. Old APK version on device (rebuild and reinstall)
  2. App cache (clear with: adb shell pm clear com.example.rlmss)
```

**Action**:
1. Clear APK cache on device: `adb shell pm clear com.example.rlmss`
2. Reinstall APK: `adb install -r build/app/outputs/flutter-apk/app-release.apk`
3. Test login

---

### Scenario 2: Role Not Detected ✗

**Output**:
```
[role_detection]
LOCAL:  { "detected_role": "arpl_assessor" }
ONLINE: { "detected_role": "assessor" }  [DIFFERENT]

[CRITICAL ISSUES]
ONLINE: 
  - ROLE_NOT_DETECTED_AS_ARPL
```

**Cause**: Online database has different role format  
**Action**:
1. Check online database: `SELECT role FROM facilitator WHERE facilitator_id = 6;`
2. If role is exactly "assessor" (not "arpl_assessor"), update database:
   ```sql
   UPDATE facilitator SET role = 'arpl_Assessor' WHERE facilitator_id = 6;
   ```
3. Verify: Run comparison script again

---

### Scenario 3: Project_pathway Column Missing ✗

**Output**:
```
[get_classes_check]
LOCAL:  { "Project_pathway": true }
ONLINE: { "Project_pathway": false }  [DIFFERENT]

[CRITICAL ISSUES]
ONLINE: 
  - PROJECT_PATHWAY_COLUMN_MISSING
```

**Cause**: Online server's get_classes.php doesn't return Project_pathway  
**Action**:
1. Update `/mobile/get_classes.php` on online server
2. Ensure the query includes `s.Project_pathway`:
   ```php
   SELECT 
       c.classID,
       c.className,
       ...
       s.project_id, 
       s.Project_pathway    ← Make sure this line exists
   FROM class c
   JOIN sites s ON s.siteID = c.siteID
   ```
3. Save and deploy
4. Run comparison script again

---

### Scenario 4: Pathway Data Missing ✗

**Output**:
```
[pathway_detection]
LOCAL:  { "will_detect_as_arpl": true }
ONLINE: { "will_detect_as_arpl": false }  [DIFFERENT]

[CRITICAL ISSUES]
ONLINE: 
  - PATHWAY_NOT_DETECTING_ARPL
```

**Cause**: Online database doesn't have ARPL pathway data in sites.Project_pathway  
**Action**:
1. Check database: 
   ```sql
   SELECT siteID, Project_pathway FROM sites 
   WHERE siteID IN (
       SELECT DISTINCT siteID FROM class 
       WHERE classID IN (
           SELECT classID FROM facilitator WHERE facilitator_id = 6
       )
   );
   ```
2. Should return something like:
   ```
   [{"type":"ARPL","trade_id":"2","name":"Bricklayer",...}]
   ```
3. If empty, need to populate Project_pathway data
4. Run comparison script again

---

## What the Comparison Script Checks

| Check | Purpose | What It's Looking For |
|-------|---------|----------------------|
| Connection Info | Server connectivity | Host, PHP version, MySQL, database |
| Facilitator Check | User exists | Facilitator 6 in database |
| Role Detection | Role parsing | 6 different detection methods |
| Classes Query | Column presence | Project_pathway column returned |
| Pathway Detection | ARPL recognition | ARPL keyword in JSON data |
| Table Structure | Schema validation | All required tables exist |

---

## Troubleshooting

### Script Won't Run
```bash
# Error: PowerShell execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Then try again:
.\compare_servers.ps1
```

### Can't Connect to Local Server
```bash
# Verify local server is running and accessible:
curl http://192.168.0.57:8080/assessorReport2/mobile/compare_local_vs_online.php

# If 404 error, check:
# 1. Is local dev server running?
# 2. Is 192.168.0.57 the correct IP?
# 3. Is port 8080 correct?
```

### Can't Connect to Online Server
```bash
# Verify online server is accessible:
curl https://rlms.rlmss.co.za/mobile/compare_local_vs_online.php

# If connection timeout, check:
# 1. Is the file uploaded to /mobile/?
# 2. Is internet connection working?
# 3. Is the domain correct?
```

---

## After You Find the Issue

Once the comparison script identifies what's different:

1. **Record the exact difference** (copy the JSON output)
2. **Fix it** (see scenarios above)
3. **Re-run the script** to verify the fix
4. **Check all items match** before proceeding
5. **Rebuild/reinstall APK** if all else matches

---

## Quick Reference Commands

```bash
# Deploy the script (manual FTP upload)
# Upload: c:\projects\rlmss\mobile\compare_local_vs_online.php
# To: https://rlms.rlmss.co.za/mobile/

# Run comparison
cd c:\projects\rlmss
.\compare_servers.ps1

# Clear app cache
adb shell pm clear com.example.rlmss

# Reinstall APK
adb uninstall com.example.rlmss
adb install build/app/outputs/flutter-apk/app-release.apk

# Check logs
adb logcat | grep "AssessorPage\|LOGIN\|Detected"
```

---

## Expected Timeline

| Activity | Time |
|----------|------|
| Deploy script | 2 minutes |
| Run comparison | 1 minute |
| Analyze results | 2 minutes |
| Apply fix (if needed) | 5-10 minutes |
| Re-run comparison | 1 minute |
| Verify APK (if all matches) | 3 minutes |

**Total**: ~15-30 minutes to complete fix

---

## Success Criteria

When complete, you should see:

1. **Comparison Script Output**:
   ```
   CHECK                 | Local | Online
   ──────────────────────┼───────┼────────
   Facilitator Found     | YES   | YES
   Role Detected as ARPL | YES   | YES
   Project_pathway       | YES   | YES
   Pathway Detects ARPL  | YES   | YES
   No Critical Issues    | YES   | YES
   ```

2. **App Behavior**:
   - ARPL assessor logs in → Sees ARPL menu
   - Has "Toolkit" and "Appendices" options
   - Can access ARPL-specific pages

---

## Files Involved

| File | Purpose | Status |
|------|---------|--------|
| mobile/compare_local_vs_online.php | Diagnostic script | ✅ Ready to deploy |
| compare_servers.ps1 | PowerShell runner | ✅ Ready to run |
| mobile/login.php | Role detection | ✅ Already fixed |
| mobile/get_classes.php | Pathway query | ✅ Already fixed |
| lib/AssessorPage.dart | UI logic | ✅ Already fixed |

---

## Next Steps

1. **NOW**: Deploy `compare_local_vs_online.php` to online server
2. **NEXT**: Run `.\compare_servers.ps1` locally
3. **THEN**: Analyze output and apply fixes as needed
4. **FINALLY**: Rebuild APK if all checks match

Do not guess or patch randomly. Let the diagnostic script tell you exactly what's wrong.

