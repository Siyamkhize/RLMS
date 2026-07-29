# ARPL COMPARISON SCRIPT - READY TO DEPLOY

## Current Status
The diagnostic comparison scripts have been created and are ready to use.

## What's Needed Now

### Step 1: Deploy PHP Script to Online Server ✓ READY
- File: `c:\projects\rlmss\mobile\compare_local_vs_online.php` (already created)
- Deploy to: `https://rlms.rlmss.co.za/mobile/compare_local_vs_online.php`
- Action: Upload this file to the online server

### Step 2: Run Comparison Script
- File: `c:\projects\rlmss\compare_servers.ps1` (fixed and ready)
- Command: `cd c:\projects\rlmss && .\compare_servers.ps1`
- What it does: Compares LOCAL (192.168.0.57:8080) with ONLINE (rlms.rlmss.co.za) servers

### Step 3: Interpret Results
The script will show which checks MATCH or are DIFFERENT:
- ✓ Facilitator Found
- ✓ Role Detected as ARPL (arpl_assessor)
- ✓ Project_pathway Column Present
- ✓ Pathway Detects as ARPL
- ✓ No Critical Issues

## Current Code Status

All fixes have been applied:
- ✅ `mobile/login.php` - Role detection with case-insensitive comparison
- ✅ `mobile/get_classes.php` - Returns Project_pathway column
- ✅ `get_classes.php` (root) - Has proper $sql declaration
- ✅ `lib/AssessorPage.dart` - ARPL pathway detection logic
- ✅ APK built and ready (45.8 MB, July 14)

## Comparison Script Details

### What It Checks
1. **Connection Info** - Host, PHP version, MySQL version
2. **Facilitator Data** - Role value from database
3. **Role Detection** - 6 different detection tests
4. **Get Classes Query** - Verifies Project_pathway column returned
5. **Pathway Detection** - JSON validation and ARPL detection
6. **Table Structure** - Verifies all tables exist

### Expected Output Examples

#### Everything Matches
```
[OK] All checks match between LOCAL and ONLINE servers!

If ARPL menu still doesn't appear online, the issue might be:
  1. Old APK version on device (rebuild and reinstall)
  2. App cache (clear with: adb shell pm clear com.example.rlmss)
```

#### Role Mismatch
```
[CRITICAL ISSUES]
ONLINE: Issues found:
  - ROLE_NOT_DETECTED_AS_ARPL: Role in database might be different format
```

#### Missing Column
```
[CRITICAL ISSUES]
ONLINE: Issues found:
  - PROJECT_PATHWAY_COLUMN_MISSING: Update get_classes.php query
```

## Files Ready to Deploy

| File | Status | Location |
|------|--------|----------|
| compare_local_vs_online.php | ✅ Created | `mobile/` |
| compare_servers.ps1 | ✅ Fixed | Project root |
| RUN_THIS_FIRST.md | ✅ Created | Project root |
| HOW_TO_USE_COMPARISON_SCRIPT.md | ✅ Created | Project root |

## Next Actions

1. **DEPLOY**: Upload `mobile/compare_local_vs_online.php` to online server at `/mobile/` path
2. **RUN**: Execute `.\compare_servers.ps1` locally
3. **ANALYZE**: Review output to identify exact differences
4. **FIX**: Apply necessary changes to online server based on findings
5. **VERIFY**: Re-run comparison script to confirm all issues resolved

## Key Insights

- **Works Locally** ✓ All checks pass on 192.168.0.57:8080
- **Doesn't Work Online** ✗ Something is different on rlms.rlmss.co.za
- **Data-Driven Approach** → Find exact difference, then fix it
- **No Guessing** → Script will tell us exactly what's wrong

## How to Know It's Fixed

When you run the comparison script:
```
CHECK             | Local | Online
Facilitator Found | YES   | YES
Role Detected     | YES   | YES
Pathway Column    | YES   | YES
Pathway ARPL      | YES   | YES
No Issues         | YES   | YES
```

All should show YES/YES to indicate complete match.

---

**Status**: Ready to execute  
**Time to resolution**: ~10-15 minutes once deployed  
**Risk**: Zero (read-only diagnostic script)

