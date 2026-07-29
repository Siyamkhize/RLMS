# ARPL ASSESSOR MENU FIX - PATHWAY DETECTION LOGIC CORRECTED

**Date:** Context Transfer Session
**Status:** ✅ COMPLETE - Ready for deployment and testing

---

## PROBLEM SUMMARY

**User-Reported Issue:**
- ARPL assessor menu works on LOCAL dev server
- ARPL assessor menu does NOT work on ONLINE production server
- Facilitator with `arpl_Assessor` role sees regular assessor menu instead of ARPL menu

**Root Cause Identified:**
The bug was NOT a database or schema issue. The real problem was **inconsistent pathway detection logic** between two similar pages:

1. **ArplAssessorPage.dart** - Had NARROW detection: Only checked `if (pathway.contains('ARPL'))`
2. **AssessorPage.dart** - Had LENIENT detection: Checked for 'ARPL', 'ELECTRICIAN', 'BRICKLAYING', 'BRICKLAYER', 'PLUMBING', 'PLUMBER', 'ELECTRICITY'

**The Bug Flow:**
```
User logs in with role = 'arpl_Assessor' ✅ (CORRECT)
  ↓
Backend detects 'arpl_Assessor' and returns it ✅ (CORRECT)
  ↓
Flutter navigates to ArplAssessorPage ✅ (CORRECT)
  ↓
ArplAssessorPage calls fetchClasses()
  ↓
Checks: if (pathway.contains('ARPL'))  ❌ (TOO STRICT!)
  ↓
If pathway = "Electrician" (not "ARPL"), check FAILS
  ↓
Falls through to default assessor menu ❌ (WRONG!)
```

---

## FIXES APPLIED

### 1. ✅ ArplAssessorPage.dart - Pathway Detection Logic Fixed

**File:** `lib/ArplAssessorPage.dart` (lines 62-85)

**Changed From (Narrow Logic):**
```dart
String pathway = (data[0]['Project_pathway'] ?? data[0]['learning_pathway'])
    ?.toString().toUpperCase() ?? '';

if (pathway.contains('ARPL')) {
  _pathwayType = 'ARPL';
} else {
  _pathwayType = pathway;
}
```

**Changed To (Lenient Logic - Ported from AssessorPage.dart):**
```dart
String pathway = (data[0]['Project_pathway'] ?? data[0]['learning_pathway'])
    ?.toString().toUpperCase() ?? '';

// Check for ARPL detection in multiple formats:
// 1. Full JSON format: [{"type":"ARPL",...}]
// 2. Trade names (these are ARPL trades): ELECTRICIAN, BRICKLAYING, BRICKLAYER, PLUMBING, PLUMBER, ELECTRICITY
bool isARPL = pathway.contains('ARPL') ||
    pathway.contains('ELECTRICIAN') ||
    pathway.contains('BRICKLAYING') ||
    pathway.contains('BRICKLAYER') ||
    pathway.contains('PLUMBING') ||
    pathway.contains('PLUMBER') ||
    pathway.contains('ELECTRICITY');

if (isARPL) {
  _pathwayType = 'ARPL';
} else {
  _pathwayType = pathway;
}
```

**Result:** Now recognizes ARPL pathways whether they contain literal "ARPL" OR trade names like "Electrician", "Plumbing", etc.

---

### 2. ✅ mobile/get_classes.php - Schema Mismatch Fixed (From Earlier Query)

**Issue:** Query was selecting non-existent columns on ONLINE database:
- `c.instructorID` (column doesn't exist)
- `c.contact_hours` (column doesn't exist)

**Fix:** Removed those columns from the SELECT statement.

**Status:** Already deployed and tested.

---

### 3. ✅ mobile/compare_local_vs_online.php - Schema Check Fixed

**Issue:** Diagnostic script was checking for non-existent columns:
- Lines 175, 178: Checking `isset($firstClass['instructorID'])` and `isset($firstClass['contact_hours'])`

**Fix Applied:** Removed the checks for those two non-existent columns from the `all_columns_present` array.

**Before:**
```php
'all_columns_present' => [
    'classID' => isset($firstClass['classID']),
    'className' => isset($firstClass['className']),
    'siteID' => isset($firstClass['siteID']),
    'numberOfLearners' => isset($firstClass['numberOfLearners']),
    'project_id' => isset($firstClass['project_id']),
    'Project_pathway' => isset($firstClass['Project_pathway']),
    'instructorID' => isset($firstClass['instructorID']),  // ❌ Non-existent column
    'startDate' => isset($firstClass['startDate']),
    'endDate' => isset($firstClass['endDate']),
    'contact_hours' => isset($firstClass['contact_hours']),  // ❌ Non-existent column
],
```

**After:**
```php
'all_columns_present' => [
    'classID' => isset($firstClass['classID']),
    'className' => isset($firstClass['className']),
    'siteID' => isset($firstClass['siteID']),
    'numberOfLearners' => isset($firstClass['numberOfLearners']),
    'project_id' => isset($firstClass['project_id']),
    'Project_pathway' => isset($firstClass['Project_pathway']),
    'startDate' => isset($firstClass['startDate']),
    'endDate' => isset($firstClass['endDate']),
],
```

---

## DEPLOYMENT STEPS

### Step 1: Rebuild APK with Fixed ArplAssessorPage Logic

```bash
# Clean build
flutter clean
flutter pub get

# Build release APK
flutter build apk --release
```

**Output APK Location:** `build/app/outputs/flutter-apk/app-release.apk`

---

### Step 2: Deploy Fixed PHP Files to ONLINE Server

**Files to Deploy:**
1. ✅ `mobile/get_classes.php` (schema fix - already deployed)
2. ✅ `mobile/compare_local_vs_online.php` (diagnostic script fix - just applied)

**Deployment Command:**
```bash
# Upload the fixed compare script
scp mobile/compare_local_vs_online.php user@rlms.rlmsco.com:/home/rlmsrlmsco/public_html/mobile/
```

---

### Step 3: Test on ONLINE Server

**Test Scenario:**
1. **Uninstall old APK** from test device
2. **Install fresh APK** with the pathway detection fix
3. **Clear app cache** (if needed)
4. **Log in as facilitator 6** (with `arpl_Assessor` role)
5. **Verify:**
   - ✅ ARPL assessor menu appears (NOT regular assessor menu)
   - ✅ Menu shows ARPL-specific options
   - ✅ Works with both "ARPL" and trade-specific pathway data (e.g., "Electrician", "Plumbing")

**Test Data:**
- **Facilitator ID:** 6
- **Role:** arpl_Assessor
- **Class ID:** 797
- **Expected Pathway:** Should contain either "ARPL" or a trade name like "Electrician"

---

## VERIFICATION CHECKLIST

- [x] ArplAssessorPage.dart pathway detection logic updated to match AssessorPage.dart
- [x] Schema mismatch in mobile/get_classes.php fixed (instructorID, contact_hours removed)
- [x] Schema check in mobile/compare_local_vs_online.php fixed
- [ ] APK rebuilt with fixed ArplAssessorPage logic
- [ ] Fixed APK deployed to test device
- [ ] Tested login as facilitator 6 with arpl_Assessor role
- [ ] Verified ARPL menu appears correctly
- [ ] Tested with different pathway types (ARPL, Electrician, Plumbing, etc.)

---

## TECHNICAL NOTES

### Why This Fix Works

**Before:** ArplAssessorPage only recognized pathways containing the literal substring "ARPL"
- ❌ "Electrician" → Not recognized as ARPL
- ❌ "Plumbing" → Not recognized as ARPL
- ✅ "ARPL" → Recognized as ARPL

**After:** ArplAssessorPage recognizes pathways containing ARPL keyword OR any ARPL trade name
- ✅ "Electrician" → Recognized as ARPL
- ✅ "Plumbing" → Recognized as ARPL
- ✅ "ARPL" → Recognized as ARPL
- ✅ "Bricklaying" → Recognized as ARPL
- ✅ "Electricity" → Recognized as ARPL

### Why Backend Role Detection Was NOT the Issue

The backend (`mobile/login.php`) correctly detects and returns `role = 'arpl_assessor'`:
- ✅ Line 215-230: Proper role detection logic
- ✅ Navigation to ArplAssessorPage works correctly
- ✅ The bug was INSIDE ArplAssessorPage's own pathway detection, not in the navigation logic

---

## FILES MODIFIED

1. **lib/ArplAssessorPage.dart** (lines 62-85)
   - Added lenient pathway detection (checks for ARPL keywords + trade names)

2. **mobile/get_classes.php** (already fixed in previous query)
   - Removed non-existent columns: instructorID, contact_hours

3. **mobile/compare_local_vs_online.php** (lines 169-179)
   - Removed checks for non-existent columns in diagnostic output

---

## NEXT ACTIONS

1. **Build APK:**
   ```bash
   flutter build apk --release
   ```

2. **Deploy to device and test:**
   - Uninstall old APK
   - Install new APK from `build/app/outputs/flutter-apk/app-release.apk`
   - Log in as facilitator 6
   - Verify ARPL menu appears

3. **If test passes:** Deploy to production and notify users

4. **If test fails:** Review logs and check:
   - What pathway value is in the database for ClassID 797?
   - Is the pathway detection logging working? (Check for `[ArplAssessorPage] Detected Pathway:` in logs)

---

## SUCCESS CRITERIA

✅ **Fix is successful when:**
1. Facilitator with `arpl_Assessor` role sees ARPL assessor menu on ONLINE server
2. Menu works with both "ARPL" and trade name pathways (Electrician, Plumbing, etc.)
3. No more falling through to default assessor menu
4. No PHP errors related to schema mismatches

---

**Status:** Ready for APK rebuild and deployment testing
