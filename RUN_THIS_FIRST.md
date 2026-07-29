# RUN THIS FIRST - Find Out What's Actually Different

## The Problem
You said: "It works on local dev but not on online"

We need to find out **EXACTLY what's different** between the two servers.

---

## Solution: Run the Comparison Script

### Step 1: Upload Script to Online Server

```bash
# Upload this file to online server:
c:\projects\rlmss\mobile\compare_local_vs_online.php
→ https://rlms.rlmss.co.za/mobile/compare_local_vs_online.php
```

### Step 2: Run Comparison

```bash
# Open PowerShell and run:
cd c:\projects\rlmss
.\compare_servers.ps1
```

**That's it!** The script will tell you exactly what's different.

---

## What You'll See

### Scenario 1: Everything Matches
```
✓ All checks match between LOCAL and ONLINE servers!

If ARPL menu still doesn't appear online, the issue might be:
  1. Old APK version on device
  2. App cache
  3. Different online server configuration
```

**Action:** Rebuild and reinstall APK

---

### Scenario 2: Role Not Detected

```
[role_detection]
LOCAL:  { "detected_role": "arpl_assessor" }
ONLINE: { "detected_role": "assessor" }
✗ DIFFERENT

[CRITICAL ISSUES]
ONLINE: 
  - ROLE_NOT_DETECTED_AS_ARPL
```

**Action:** 
1. Check online database role value
2. Update `mobile/login.php` with flexible role detection
3. Upload to online server
4. Run script again to verify

---

### Scenario 3: Project_pathway Column Missing

```
[get_classes_check]
LOCAL:  { "Project_pathway": true }
ONLINE: { "Project_pathway": false }
✗ DIFFERENT

[CRITICAL ISSUES]
ONLINE: 
  - PROJECT_PATHWAY_COLUMN_MISSING
```

**Action:**
1. Check online `mobile/get_classes.php`
2. Update query to include `s.Project_pathway`
3. Upload to online server
4. Run script again to verify

---

### Scenario 4: Pathway Data Missing

```
[pathway_detection]
LOCAL:  { "will_detect_as_arpl": true }
ONLINE: { "will_detect_as_arpl": false }
✗ DIFFERENT

[CRITICAL ISSUES]
ONLINE: 
  - PATHWAY_NOT_DETECTING_ARPL
  - Solution: Check sites.Project_pathway data in database
```

**Action:**
1. Check database directly
2. Verify sites table has Project_pathway JSON with ARPL data
3. If empty, contact support or use SQL to populate

---

## The Comparison Script Checks

```
1. Connection Info       → Is it connecting to right database?
2. Facilitator Data      → Does facilitator 6 exist?
3. Role Detection        → Is role detected as "arpl_assessor"?
4. Classes Query         → Does query return all needed columns?
5. Pathway Data          → Is Project_pathway present and valid?
6. Pathway Detection     → Does app recognize as ARPL?
```

---

## Three Possible Outcomes

### ✓ Everything Matches
- Compare local and online identical
- Issue is APK cache or version
- Solution: Rebuild APK

### ✗ Role Mismatch  
- Online role format different
- Solution: Update role detection in login.php

### ✗ Missing Data Column
- Online query not returning Project_pathway
- Solution: Update get_classes.php query

---

## Quick Commands

```bash
# 1. Deploy comparison script to online
#    (upload c:\projects\rlmss\mobile\compare_local_vs_online.php)

# 2. Run comparison
cd c:\projects\rlmss
.\compare_servers.ps1

# 3. Read output
#    - Shows what matches
#    - Shows what's different
#    - Shows how to fix it

# 4. Make fixes to online server
#    (based on comparison output)

# 5. Run comparison again
.\compare_servers.ps1
#    All checks should now show ✓ MATCH
```

---

## What If I Don't See Differences?

If the comparison shows everything matches but ARPL menu still doesn't appear:

1. **Clear APK cache:**
   ```bash
   adb shell pm clear com.example.rlmss
   ```

2. **Reinstall APK:**
   ```bash
   adb uninstall com.example.rlmss
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

3. **Check app logs:**
   ```bash
   adb logcat | grep "LOGIN\|AssessorPage\|Detected"
   ```

4. **If still nothing, check:**
   - Is app pointing to online server? (check config)
   - Is network working? (try accessing web interface)
   - Is there a firewall blocking?

---

## Files Created

- ✅ `mobile/compare_local_vs_online.php` - Comparison script
- ✅ `compare_servers.ps1` - PowerShell runner
- ✅ `HOW_TO_USE_COMPARISON_SCRIPT.md` - Full documentation

---

## Summary

**This is the fastest way to find the real problem:**

1. Upload `compare_local_vs_online.php` to online server
2. Run `.\compare_servers.ps1` locally
3. Read the output
4. Fix what's different
5. Run again to verify

**That's it!**

---

**Status:** Ready to run  
**Time:** ~5 minutes to get answer  
**Risk:** Zero (read-only script)
