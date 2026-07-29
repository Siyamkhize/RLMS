# ACTION PLAN: Fix ARPL Assessor Menu Not Showing Online

**Problem**: ARPL menu works on LOCAL dev server but not on ONLINE server  
**Solution**: Deploy diagnostic script and identify exact difference  
**Time Required**: 30-45 minutes  

---

## IMMEDIATE ACTION REQUIRED

### Action 1: Deploy Diagnostic Script (5 minutes)

**File to upload**:  
```
c:\projects\rlmss\mobile\compare_local_vs_online.php
```

**Upload destination**:  
```
https://rlms.rlmss.co.za/mobile/compare_local_vs_online.php
```

**How to upload**:
1. Open FTP client or web file manager
2. Connect to: `rlms.rlmss.co.za`
3. Navigate to: `/mobile/` directory
4. Upload: `compare_local_vs_online.php`
5. Verify: Open browser and visit the URL above

**What you should see** (JSON output in browser):
```json
{
  "environment": "ONLINE",
  "facilitator_check": { "found": true },
  "role_detection": { "detected_role": "..." },
  ...
}
```

---

### Action 2: Run Comparison Script (2 minutes)

**Open PowerShell** and run:
```powershell
cd c:\projects\rlmss
.\compare_servers.ps1
```

**What to expect**:
- Fetches data from LOCAL server
- Fetches data from ONLINE server
- Shows detailed comparison
- Lists any differences found

---

### Action 3: Analyze Output (5 minutes)

**Look for this section**:
```
DIFFERENCES FOUND:
```

**If you see**:

#### ✓ "All checks match between LOCAL and ONLINE servers!"
```
NEXT STEPS:
1. Clear app cache:
   adb shell pm clear com.example.rlmss

2. Reinstall APK:
   adb install -r build/app/outputs/flutter-apk/app-release.apk

3. Login and test ARPL menu
```

#### ✗ "Role Not Detected As ARPL"
```
ISSUE: Online database has wrong role format
FIX:
1. SSH into online server or use phpMyAdmin
2. Run: SELECT role FROM facilitator WHERE facilitator_id = 6;
3. If role is "assessor" (not "arpl_assessor"):
   UPDATE facilitator SET role = 'arpl_Assessor' WHERE facilitator_id = 6;
4. Save changes
5. Re-run: .\compare_servers.ps1
```

#### ✗ "Project_pathway Column Missing"
```
ISSUE: Online get_classes.php not returning Project_pathway
FIX:
1. Upload mobile/get_classes.php to online /mobile/ directory
2. Ensure it has this query:
   SELECT 
       c.classID, c.className, c.siteID, ...
       s.project_id, 
       s.Project_pathway
   FROM class c
   JOIN sites s ON s.siteID = c.siteID
3. Save and deploy
4. Re-run: .\compare_servers.ps1
```

#### ✗ "Pathway Not Detecting ARPL"
```
ISSUE: Online database missing ARPL pathway data
FIX:
1. Check database:
   SELECT Project_pathway FROM sites 
   WHERE Project_pathway LIKE '%ARPL%' LIMIT 1;
2. If empty, need to populate Project_pathway with ARPL data
3. Contact support or populate manually with SQL
4. Re-run: .\compare_servers.ps1
```

---

### Action 4: Apply Fixes

**Once you identify the issue**, fix it based on the scenario above.

**After each fix**:
```powershell
# Re-run comparison to verify
.\compare_servers.ps1
```

**Keep doing this until you see**:
```
[OK] All checks match between LOCAL and ONLINE servers!
```

---

### Action 5: If All Matches - Rebuild APK

```bash
# Clear app cache on device
adb shell pm clear com.example.rlmss

# Uninstall old APK (optional)
adb uninstall com.example.rlmss

# Install new APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Test: Login with facilitator 6 (Sithandazile Mbotho)
# Should now see ARPL menu with "Toolkit" and "Appendices"
```

---

## QUICK REFERENCE COMMANDS

### Deployment
```bash
# Deploy diagnostic script to online server
# File: c:\projects\rlmss\mobile\compare_local_vs_online.php
# To: https://rlms.rlmss.co.za/mobile/
```

### Run Comparison
```powershell
cd c:\projects\rlmss
.\compare_servers.ps1
```

### Fix Database Role
```sql
UPDATE facilitator 
SET role = 'arpl_Assessor' 
WHERE facilitator_id = 6;
```

### Clear App Cache
```bash
adb shell pm clear com.example.rlmss
```

### Reinstall APK
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Check Logs
```bash
adb logcat | grep "AssessorPage\|LOGIN\|Detected\|ARPL"
```

---

## DIAGNOSTIC SCRIPT EXPLAINED

### What it checks:
1. **Connection** - Can it connect to database?
2. **Facilitator** - Does facilitator 6 exist?
3. **Role** - Is role detected as "arpl_assessor"?
4. **Query** - Does get_classes return Project_pathway?
5. **Pathway** - Is pathway JSON valid and contains ARPL?
6. **Issues** - Are there any critical problems?

### Why we run it on BOTH servers:
- LOCAL: Shows what works correctly
- ONLINE: Shows what's broken
- COMPARISON: Shows exactly what's different

---

## EXPECTED OUTCOMES

### Best Case (3 scenarios lead here)
```
CHECK                 | Local | Online
──────────────────────┼───────┼────────
Facilitator Found     | YES   | YES
Role Detected as ARPL | YES   | YES
Project_pathway       | YES   | YES
Pathway Detects ARPL  | YES   | YES
No Critical Issues    | YES   | YES
```

**Result**: Clear cache and reinstall APK

### Worst Case (still fixable)
```
One or more items shows:
Local: YES
Online: NO
```

**Result**: Apply fix from the appropriate scenario above

---

## TIMELINE

| Step | Time | Status |
|------|------|--------|
| Upload diagnostic script | 5 min | ACTION 1 |
| Run comparison | 2 min | ACTION 2 |
| Analyze results | 5 min | ACTION 3 |
| Apply fix (if needed) | 10 min | ACTION 4 |
| Re-run comparison | 2 min | ACTION 4 |
| Clear cache & reinstall | 3 min | ACTION 5 |
| Test on device | 3 min | VERIFY |
| **TOTAL** | **~30 min** | **COMPLETE** |

---

## CRITICAL NOTES

✓ **DO**: Use the diagnostic script to find the exact issue  
✓ **DO**: Re-run after each fix to verify  
✓ **DO**: Follow the exact scenario that matches your output  

✗ **DON'T**: Make random changes  
✗ **DON'T**: Guess what's wrong  
✗ **DON'T**: Assume both servers are identical  

---

## TROUBLESHOOTING

### PowerShell won't run the script
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\compare_servers.ps1
```

### Can't upload to online server
- Use FileZilla (free FTP client)
- Or use cPanel File Manager if available
- Or contact hosting provider

### Script won't connect to local server
- Verify local dev server is running
- Verify correct IP: 192.168.0.57:8080
- Test: `curl http://192.168.0.57:8080/assessorReport2/mobile/compare_local_vs_online.php`

### Online server shows "file not found"
- Verify file uploaded to `/mobile/` directory
- Check file permissions (should be readable)
- Wait a few seconds and refresh browser

---

## SUCCESS CRITERIA

You're done when:

1. ✅ Diagnostic script runs successfully on both servers
2. ✅ Comparison shows all checks match
3. ✅ APK reinstalled with cleared cache
4. ✅ Facilitator 6 logs in → ARPL menu appears
5. ✅ Can access Toolkit and Appendices pages

---

## NEXT STEPS

1. **Right now**: Upload diagnostic script to online server
2. **In 5 minutes**: Run comparison script
3. **In 10 minutes**: Analyze results and apply fixes
4. **In 20 minutes**: Verify all checks match
5. **In 30 minutes**: Clear cache and test APK
6. **In 45 minutes**: ARPL menu should appear!

---

## GET HELP

If comparison script shows unexpected output:
1. Copy the full JSON output
2. Check which check shows DIFFERENT
3. Refer to the scenario section above
4. Apply the specific fix for that scenario

---

**Status**: Ready to execute  
**Confidence**: High (diagnostic approach is proven)  
**Time to fix**: ~30-45 minutes total  

**Let's go! Deploy the diagnostic script now.** 

