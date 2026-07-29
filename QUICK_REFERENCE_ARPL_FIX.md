# ARPL Fix - Quick Reference Card

**Date:** July 14, 2026  
**Status:** ✅ Ready to Deploy  
**Time to Deploy:** 5 minutes

---

## The Fix in One Sentence

Updated Dart code to detect ARPL from trade names (online) in addition to JSON format (local).

---

## What Changed

**File:** `lib/AssessorPage.dart` (Lines 64-91)

**From:** 1 condition → 7 conditions for ARPL detection

```dart
// Before
if (pathway.contains('ARPL')) { ... }

// After  
if (pathway.contains('ARPL') || 
    pathway.contains('ELECTRICIAN') || 
    pathway.contains('BRICKLAYING') || 
    pathway.contains('BRICKLAYER') || 
    pathway.contains('PLUMBING') || 
    pathway.contains('PLUMBER') || 
    pathway.contains('ELECTRICITY')) { ... }
```

---

## Build Status

| Item | Status |
|------|--------|
| Code | ✅ Updated |
| Build | ✅ Complete |
| APK | ✅ Ready (45.9 MB) |
| Location | `build/app/outputs/flutter-apk/app-release.apk` |
| Size | 45.9 MB |
| Date | July 14, 2026 |

---

## Installation (2 minutes)

```bash
adb uninstall com.example.rlmss
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Test (3 minutes)

1. Open app
2. Login as ARPL facilitator (class 782 or 783)
3. Verify: See ARPL menu ✅

**Expected:** Toolkit + Appendices A-I visible

---

## What It Fixes

| Before | After |
|--------|-------|
| ❌ Online: Normal menu shown | ✅ Online: ARPL menu shown |
| ✅ Local: ARPL menu shown | ✅ Local: ARPL menu shown |
| N/A | ✅ No DB changes needed |
| N/A | ✅ Backward compatible |

---

## The Data Issue (Context)

**Local Server:**
```
Project_pathway: [{"type":"ARPL","name":"Electrician"...}]
                  ↑ Contains "ARPL"
```

**Online Server:**
```
Project_pathway: "Bricklaying"
                  ↑ Only trade name, no "ARPL"
```

**Solution:** Check for trade names too

---

## ARPL Trade Names Detected

- ELECTRICIAN ✅
- ELECTRICITY ✅
- BRICKLAYING ✅
- BRICKLAYER ✅
- PLUMBING ✅
- PLUMBER ✅
- Plus: Any "ARPL" in pathway ✅

---

## If It Doesn't Work

| Issue | Fix |
|-------|-----|
| Still see normal menu | Check facilitator assigned to class 782/783 |
| APK won't install | `adb uninstall com.example.rlmss` first |
| Need to rollback | Install previous APK (reversible) |
| Want database sync | See `fix_sites_project_pathway.sql` (optional) |

---

## Documentation

| Document | Purpose |
|----------|---------|
| `ARPL_ASSESSOR_UI_FIX_COMPLETED.md` | Full overview |
| `INSTALL_ARPL_FIX_APK.md` | Installation guide |
| `ARPL_DUAL_FORMAT_DETECTION_CODE_CHANGE.md` | Technical deep-dive |
| `NEXT_STEPS_ARPL_DEPLOYMENT.md` | Deployment checklist |
| `TASK_COMPLETION_SUMMARY.md` | Complete summary |
| `QUICK_REFERENCE_ARPL_FIX.md` | This file |

---

## Config Locations

**Local Dev (Current):**
```
Server: 192.168.0.57:8080
Path: /assessorReport2/mobile
Protocol: HTTP
```

**Online (if needed):**
```
Server: rlms.rlms.co.za:443
Path: /mobile
Protocol: HTTPS
```

Edit in: `lib/config.dart` then rebuild

---

## Key Facts

- ✅ No database changes required
- ✅ Works with existing online data
- ✅ Backward compatible with local server
- ✅ Very low risk deployment
- ✅ Reversible (just install old APK)
- ✅ Takes 5 minutes to deploy
- ✅ Takes 3 minutes to test

---

## Why This Happened

Local server stores full JSON:
```json
[{"type":"ARPL","trade_id":"1","name":"Electrician"...}]
```

Online server only stores trade name:
```
"Bricklaying"
```

App only checked for "ARPL" string, so it failed online.

**Fix:** Now checks for trade names too.

---

## Success Indicators

After installation, with ARPL facilitator login:

✅ See "Toolkit" menu item  
✅ See "Appendices A-I" menu item  
✅ Can access ARPL workflow  
✅ Normal assessors still see normal menu  

---

## Rollback (< 1 minute)

If anything wrong:
```bash
adb uninstall com.example.rlmss
adb install [path/to/old_apk]
```

No data changes, fully reversible.

---

## One-Line Summary

App now detects ARPL from trade names (online) + JSON format (local) → ARPL assessors see correct UI on both servers.

---

**Ready?** → Install APK  
**Next?** → Test login  
**Done?** → Distribute to users

