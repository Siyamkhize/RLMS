# ASSESSOR REVIEW (D,E,F) - "Activities Not Loaded OFO:null" FIX

## PROBLEM CLARIFICATION

User clarified there are **TWO SEPARATE ISSUES**:

### Issue 1: View Complete Toolkit ✅ (ALREADY WORKING)
- **Route**: Menu Bar → View Complete Toolkit → Select Candidate → Open Toolkit
- **Status**: OFO loads correctly, activities load
- **Problem**: Save returns 404 (separate issue to fix next)

### Issue 2: Assessor Review (D,E,F) ❌ (THIS FIX)
- **Route**: Menu Bar → Assessor Review (D,E,F) → Select Candidate → View Appendix B/D/E
- **Status**: Shows "Activities not loaded OFO:null"
- **Problem**: OFO never gets fetched when learner is selected

---

## ROOT CAUSE

In **ARPLAssessorReviewPage** (`_ARPLAssessorReviewPageState`):

### The Flow (BEFORE FIX)
```
User selects learner from dropdown (line 9247)
    ↓
onChanged: _selectedLearnerId = value
    ↓
_fetchTraceabilityData(value) called
    ↓
Fetches: classID, siteID, projectID
    ❌ Does NOT fetch OFO!
    ↓
_loadExistingARPLData() called
    ↓
Activities try to load but _ofoNumber is NULL
    ↓
Shows: "Activities not loaded OFO:null"
```

### The Problem
`_fetchTraceabilityData()` method fetches classID, siteID, and projectID but **never fetches OFO**.

The `_ofoNumber` variable is declared in the state but never populated when a learner is selected.

---

## SOLUTION APPLIED

### Modified Method: `_fetchTraceabilityData()`

**File**: `lib/ArplAssessorPage.dart`
**Lines**: ~9540-9580 (in `_ARPLAssessorReviewPageState`)

### Changes Made

**Added**:
1. Call `_fetchOfoFromClassData(classId)` to get OFO from class
2. Set `_ofoNumber` in setState
3. Call `_loadActivitiesFromAPI(learnerId)` to load activities

**Code Added**:
```dart
// FIX: Fetch OFO for this class
String? ofoNumber;
if (classId != null && classId.isNotEmpty) {
  print('[ARPL] Fetching OFO for classID: $classId');
  ofoNumber = await _fetchOfoFromClassData(classId);
  print('[ARPL] Fetched OFO: $ofoNumber');
}

setState(() {
  _classId = classId;
  _siteId = siteId;
  _projectId = projectId;
  _ofoNumber = ofoNumber; // Set OFO number ← NEW
});
print(
    '[ARPL] Traceability data: Class=$_classId, Site=$_siteId, Project=$_projectId, OFO=$_ofoNumber');

_loadExistingARPLData(learnerId);

// Load activities now that we have OFO ← NEW
if (ofoNumber != null && ofoNumber.isNotEmpty) {
  _loadActivitiesFromAPI(learnerId);
}
```

### The Flow (AFTER FIX)
```
User selects learner from dropdown
    ↓
onChanged: _selectedLearnerId = value
    ↓
_fetchTraceabilityData(value) called
    ↓
Fetches: classID, siteID, projectID
    ↓
✅ NEW: Calls _fetchOfoFromClassData(classId)
    ↓
✅ NEW: Sets _ofoNumber = ofoNumber (e.g., "641201")
    ↓
✅ NEW: Calls _loadActivitiesFromAPI(learnerId)
    ↓
Activities load successfully with correct OFO
    ↓
Shows: List of activities for Bricklayer
```

---

## DEPENDENCIES

### This Fix Uses Existing Method
The fix calls `_fetchOfoFromClassData()` which already exists in the same class (defined around line 10050).

**Method Signature**:
```dart
Future<String?> _fetchOfoFromClassData(String classId) async {
  // Calls: get_class_trade_info.php
  // Returns: OFO number from Project_pathway JSON (via our earlier fix)
}
```

### Server-Side Dependency
This fix requires that **`get_class_trade_info.php` has the Project_pathway fallback** (which we fixed earlier).

If that endpoint is NOT yet uploaded with the fix, this will still fail because the endpoint will return NULL.

---

## TESTING INSTRUCTIONS

### Requirements
1. App must be rebuilt with this fix
2. `get_class_trade_info.php` must be uploaded to server (with Project_pathway fallback)

### Test Steps

**Step 1: Rebuild App**
```bash
cd c:\projects\rlmss
flutter build apk --release
```

**Step 2: Install APK**
- File location: `build/app/outputs/flutter-apk/app-release.apk`
- Install on test device

**Step 3: Test in App**
1. Open ARPL Assessor app
2. Login as Facilitator 6 (arpl_Assessor role)
3. From menu bar, tap: **Assessor Review (D,E,F)**
4. Select candidate: **Anele Cele** (or any learner in Class 797)
5. Wait for loading...
6. Go to **Appendix B (Activities)** tab

**Expected Results**:
- ✅ Should show: "OFO: 641201" (not "OFO: null")
- ✅ Should show: List of Bricklayer activities
- ✅ NO "Activities not loaded" message

**Step 4: Test Other Appendices**
- Go to **Appendix D** tab → Should show activities
- Go to **Appendix E** tab → Should show activities

---

## FILES MODIFIED

### Flutter App (REQUIRES REBUILD)
- ✅ `lib/ArplAssessorPage.dart` - Modified `_fetchTraceabilityData()` method

### Server Files (NO CHANGES NEEDED IF ALREADY UPLOADED)
- ⏳ `mobile/get_class_trade_info.php` - Must have Project_pathway fallback (from earlier fix)

---

## WHAT THIS FIXES

### Fixed (After Rebuild)
✅ Assessor Review (D,E,F) → Appendix B shows "Activities not loaded OFO:null"
✅ Assessor Review (D,E,F) → Appendix D shows "Activities not loaded OFO:null"
✅ Assessor Review (D,E,F) → Appendix E shows "Activities not loaded OFO:null"

### Still Need to Fix (NEXT)
⏳ Save Appendix B/D/E returns 404 error
⏳ Appendix B save timeout

---

## BUILD INSTRUCTIONS

### Quick Build
```cmd
cd c:\projects\rlmss
flutter clean
flutter pub get
flutter build apk --release
```

### Output Location
```
build/app/outputs/flutter-apk/app-release.apk
```

### APK Size
Expected: ~45-50 MB

### Installation
```
adb install build/app/outputs/flutter-apk/app-release.apk
```
Or copy APK to device and install manually.

---

## VERIFICATION CHECKLIST

### Pre-Build
- [x] Code modified in ArplAssessorPage.dart
- [x] `get_class_trade_info.php` uploaded with Project_pathway fallback
- [x] Build instructions ready

### Build Process
- [ ] `flutter clean` completed
- [ ] `flutter pub get` completed
- [ ] `flutter build apk --release` completed without errors
- [ ] APK file generated successfully

### Testing
- [ ] APK installed on device
- [ ] Login successful as Facilitator 6
- [ ] Navigate to "Assessor Review (D,E,F)"
- [ ] Select learner
- [ ] Appendix B shows OFO: 641201 (not null)
- [ ] Appendix B shows list of activities
- [ ] Appendix D shows activities
- [ ] Appendix E shows activities

---

## TROUBLESHOOTING

### If Still Shows "OFO:null" After Rebuild

**Check 1: Server Endpoint**
```
Test URL: https://rlms.rlms.co.za/mobile/test_get_class_trade_info_fixed.php

Expected: OFO Number: 641201
If NOT: Upload get_class_trade_info.php from earlier fix
```

**Check 2: App Logs**
Look for these log messages:
```
[ARPL] Fetching OFO for classID: 797
[ARPL] Fetched OFO: 641201
[ARPL] Traceability data: ... OFO=641201
```

If logs show "Fetched OFO: null" → Server endpoint issue
If logs don't appear → App not rebuilt correctly

**Check 3: APK Version**
Ensure you're testing the NEW APK, not the old one:
- Uninstall old app completely
- Install new APK
- Clear app data if needed

### If Activities Still Don't Load

**Possible Causes**:
1. Activities table is empty for OFO 641201
2. `get_arpl_competency_data.php` has issues
3. Network connectivity problem

**Debug**:
```
1. Run: diagnose_arpl_complete_flow.php
2. Check: Activities exist for OFO 641201
3. Check: get_arpl_competency_data.php returns data
```

---

## SUMMARY

### What Changed
- Modified `_fetchTraceabilityData()` in `ARPLAssessorReviewPageState`
- Added OFO fetching when learner is selected
- Added activity loading after OFO is fetched

### Impact
- **Requires**: App rebuild
- **Requires**: Server endpoint uploaded (get_class_trade_info.php)
- **Risk**: Low - only affects Assessor Review route
- **Rollback**: Install previous APK

### Next Steps
1. **IMMEDIATE**: Rebuild app with this fix
2. **THEN**: Test Assessor Review (D,E,F) route
3. **NEXT**: Fix save 404 errors (both routes)
4. **LAST**: Fix save timeout

---

**Date**: 2026-07-15
**Status**: Code fix complete, awaiting rebuild and test
**Route Affected**: Menu → Assessor Review (D,E,F)
**Route NOT Affected**: View Complete Toolkit (already working)
