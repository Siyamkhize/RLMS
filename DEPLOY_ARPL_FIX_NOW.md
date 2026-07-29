# ARPL ASSESSOR MENU FIX - DEPLOYMENT GUIDE

**Status:** ✅ ALL FIXES APPLIED - Ready for APK rebuild and testing

---

## WHAT WAS FIXED

### 1. ArplAssessorPage.dart - Pathway Detection Logic ✅
**Problem:** Only recognized literal "ARPL" substring, failed on trade names like "Electrician"
**Fix:** Now checks for ARPL OR any trade name (Electrician, Plumbing, Bricklaying, etc.)
**Location:** `lib/ArplAssessorPage.dart` lines 62-85

### 2. mobile/get_classes.php - Schema Mismatch ✅
**Problem:** Selected non-existent columns: instructorID, contact_hours
**Fix:** Removed those columns from SELECT query
**Status:** Already fixed in previous session

### 3. mobile/compare_local_vs_online.php - Diagnostic Script ✅
**Problem:** Checked for non-existent columns in diagnostic output
**Fix:** Removed checks for instructorID and contact_hours
**Location:** Lines 169-179

---

## QUICK DEPLOYMENT (3 STEPS)

### Step 1: Rebuild APK (5 minutes)

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

**APK Output:** `build/app/outputs/flutter-apk/app-release.apk`

---

### Step 2: Deploy Fixed PHP File (1 minute)

**Only if you haven't already:**
```bash
# Upload the fixed diagnostic script
scp mobile/compare_local_vs_online.php user@rlms.rlmsco.com:/home/rlmsrlmsco/public_html/mobile/
```

**Note:** `mobile/get_classes.php` should already be deployed from earlier fix.

---

### Step 3: Test on Device (5 minutes)

1. **Uninstall old APK** from test device
2. **Install fresh APK:** `adb install build/app/outputs/flutter-apk/app-release.apk`
3. **Log in as facilitator 6** (role: arpl_Assessor)
4. **Verify:**
   - ✅ ARPL assessor menu appears (not regular assessor menu)
   - ✅ Menu shows ARPL-specific options
   - ✅ Works correctly with trade pathways

---

## TEST CREDENTIALS

**Facilitator ID:** 6
**Role:** arpl_Assessor
**Class ID:** 797
**Expected:** Should see ARPL assessor menu with trade-specific options

---

## WHAT TO LOOK FOR IN LOGS

**Success indicators:**
```
[ArplAssessorPage] Detected Pathway: ARPL (from data: ELECTRICIAN, isARPL: true)
```

**Failure indicators:**
```
[ArplAssessorPage] Detected Pathway: ELECTRICIAN (from data: ELECTRICIAN, isARPL: false)
```

---

## IF TEST FAILS

1. **Check database:** What's the actual pathway value in ClassID 797?
   ```sql
   SELECT c.classID, c.className, s.Project_pathway 
   FROM class c 
   JOIN sites s ON s.siteID = c.siteID 
   WHERE c.classID = 797;
   ```

2. **Check logs:** Look for `[ArplAssessorPage] Detected Pathway:` message

3. **Verify role:** Ensure facilitator 6 has `arpl_Assessor` in the database
   ```sql
   SELECT facilitator_id, role FROM facilitator WHERE facilitator_id = 6;
   ```

---

## SUCCESS = DONE! 🎉

Once the test passes, you're done! The ARPL assessor menu will work correctly for all facilitators with the `arpl_Assessor` role, regardless of whether their pathway contains "ARPL" or a trade name.
