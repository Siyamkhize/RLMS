# DEPLOY FIXES NOW - ARPL MENU FIX

**Status**: ✅ ROOT CAUSE FIXED, READY TO DEPLOY

---

## WHAT WAS WRONG

Query was selecting columns that don't exist on ONLINE server:
- `c.instructorID` ❌
- `c.contact_hours` ❌

This caused queries to fail, breaking the entire ARPL detection flow.

---

## WHAT TO DEPLOY

### File 1: `mobile/get_classes.php`
- **Path**: `/mobile/get_classes.php` (on ONLINE server)
- **Change**: Removed `c.instructorID` and `c.contact_hours` from SELECT
- **Status**: Fixed, ready to upload

---

## DEPLOYMENT STEPS

### Step 1: Upload Fixed Files
```
Method: FTP or file manager
Local: c:\projects\rlmss\mobile\get_classes.php
Remote: https://rlms.rlmss.co.za/mobile/get_classes.php

Action: Upload (replace existing file)
```

### Step 2: Test Upload
```
Open browser: https://rlms.rlmss.co.za/mobile/get_classes.php?facilitator_id=6
Expected: JSON array with class data
Verify: No 404 or syntax errors
```

### Step 3: Install Fresh APK
```
1. Uninstall old app completely
2. Clear app cache
3. Install: app-release.apk from build folder
4. Launch app
```

### Step 4: Test Login
```
1. Log in with facilitator (arpl_Assessor role)
2. Expected: ARPL Assessor menu appears
3. Check: All ARPL options available
4. Done! ✅
```

---

## WHAT CHANGED IN CODE

### Before (Broken):
```php
SELECT 
    c.classID, c.className, c.siteID, c.numberOfLearners,
    c.instructorID,          ← DOESN'T EXIST
    c.startDate, c.endDate,
    c.contact_hours,         ← DOESN'T EXIST
    s.project_id, s.Project_pathway
```

### After (Fixed):
```php
SELECT 
    c.classID, c.className, c.siteID, c.numberOfLearners,
    c.startDate, c.endDate,
    s.project_id, s.Project_pathway
```

---

## WHY THIS MATTERS

The query failure meant:
1. ❌ No class data returned
2. ❌ No Project_pathway available
3. ❌ ARPL detection failed
4. ❌ Regular assessor menu shown

After fix:
1. ✅ Class data returned
2. ✅ Project_pathway available
3. ✅ ARPL detection works
4. ✅ ARPL menu shown

---

## VERIFICATION

After deployment:
```
✅ get_classes.php query works
✅ Returns JSON without errors
✅ Includes Project_pathway field
✅ App receives class data
✅ ARPL menu appears on login
```

---

## SUMMARY

| Item | Status |
|------|--------|
| Root cause identified | ✅ YES - schema mismatch |
| Files fixed | ✅ YES - get_classes.php |
| Ready to deploy | ✅ YES |
| APK ready | ✅ YES - already built |
| Test procedure | ✅ YES - 4 simple steps |

**Next action**: Upload `mobile/get_classes.php` and test

