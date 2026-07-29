# OFO Number Fix Complete ✅

## Issue
After ARPL menu started working, user clicks "View Complete Toolkit" but the OFO Number field was empty/not set, showing "Not Set" even though the API was returning the correct OFO code (641201).

## Root Causes

### Issue 1: ARPLAppendixHPage Not Receiving OFO
The `ARPLAppendixHPage` widget had an `ofoNumber` parameter, but:
1. The parameter was not being passed when the page was instantiated (line 152)
2. The `_ofoNumber` state variable in `_ARPLAppendixHPageState` was not initialized from `widget.ofoNumber`
3. The main `_ArplAssessorPageState` class did not have `_ofoNumber` declared and populated from the API response

### Issue 2: ViewCompleteToolkitPage Not Assigning OFO ⚠️ **CRITICAL BUG**
In `ViewCompleteToolkitPage`, the dropdown's `onChanged` handler was:
- Fetching OFO from API: ✅ Working
- Logging "Set _selectedOfoNumber=$ofo": ✅ Working  
- **Actually assigning `_selectedOfoNumber = ofo`:** ❌ **MISSING!**

The print statement claimed to set the value, but the actual assignment was never executed, so `_selectedOfoNumber` remained `null` and displayed "Not Set".

## Fixes Applied

### Fix 1: Added `_ofoNumber` to Main State Class
**File:** `lib/ArplAssessorPage.dart` (line 37)
```dart
class _ArplAssessorPageState extends State<ArplAssessorPage> {
  late Future<List<dynamic>> _classes;
  int _selectedIndex = 0;
  String? _pathwayType; // Store 'ARPL' or other pathway types
  String? _ofoNumber; // Store OFO code for ARPL assessor
```

### Fix 2: Extract OFO Code from API Response
**File:** `lib/ArplAssessorPage.dart` (in `fetchClasses` method)
```dart
// Try to parse OFO code from Project_pathway JSON
try {
  String rawPathway = data[0]['Project_pathway']?.toString() ?? '';
  if (rawPathway.isNotEmpty && rawPathway.startsWith('[')) {
    // Parse as JSON array
    List<dynamic> pathwayList = jsonDecode(rawPathway);
    if (pathwayList.isNotEmpty && pathwayList[0]['ofo_code'] != null) {
      _ofoNumber = pathwayList[0]['ofo_code'].toString();
      print('[ArplAssessorPage] Extracted OFO Code: $_ofoNumber');
    }
  }
} catch (e) {
  print('[ArplAssessorPage] Could not parse OFO code: $e');
}
```

**Expected API format:**
```json
{
  "Project_pathway": "[{\"type\":\"ARPL\",\"name\":\"Bricklayer\",\"ofo_code\":\"641201\"}]"
}
```

### Fix 3: Pass OFO Number to ARPLAppendixHPage
**File:** `lib/ArplAssessorPage.dart` (line 152)
```dart
case 21:
  return ARPLAppendixHPage(
      facilitatorId: widget.facilitator_id, ofoNumber: _ofoNumber);
```

### Fix 4: Initialize State Variable in Child Widget
**File:** `lib/ArplAssessorPage.dart` (line 11964, in `_ARPLAppendixHPageState.initState`)
```dart
@override
void initState() {
  super.initState();
  _ofoNumber = widget.ofoNumber;  // ← Initialize from widget parameter
  _fetchLearners();
}
```

### Fix 5: Actually Assign OFO in ViewCompleteToolkitPage ⭐ **KEY FIX**
**File:** `lib/ArplAssessorPage.dart` (line 12925, in dropdown `onChanged` handler)
```dart
_fetchOfoForClass(classId).then((ofo) {
  setState(() {
    _selectedLearnerId = value;
    _selectedClassId = classId;
    _selectedOfoNumber = ofo; // ← FIX: Actually assign the OFO value!
    print('[TOOLKIT_DEBUG] Set _selectedOfoNumber=$ofo (actual from class)');
  });
});
```

**Before (BROKEN):**
```dart
print('[TOOLKIT_DEBUG] Set _selectedOfoNumber=$ofo (actual from class)');
// ← Missing assignment!
```

**After (FIXED):**
```dart
_selectedOfoNumber = ofo; // ← Now actually assigns the value
print('[TOOLKIT_DEBUG] Set _selectedOfoNumber=$ofo (actual from class)');
```

## Data Flow
1. Login → `mobile/login.php` returns `Project_pathway` JSON
2. `mobile/get_classes.php` returns classes with `Project_pathway` field
3. `fetchClasses()` in `ArplAssessorPage` parses JSON and extracts `ofo_code`
4. `_ofoNumber` is stored in `_ArplAssessorPageState`
5. When "View Complete Toolkit" is tapped, `ViewCompleteToolkitPage` opens
6. User selects learner from dropdown → triggers `onChanged`
7. `_fetchOfoForClass()` calls API to get OFO for the class
8. **NEW:** OFO is **actually assigned** to `_selectedOfoNumber` (was missing before!)
9. UI displays OFO value (was showing "Not Set" before fix)
10. "Open Complete Toolkit" button uses `_selectedOfoNumber` to navigate

## Expected Behavior
When facilitator (ID: 6, role: `arpl_Assessor`) logs in and navigates to "View Complete Toolkit":
1. Select a candidate from dropdown (e.g., "Anele Cele")
2. API fetches OFO for class 797
3. OFO Number field should display: **641201** (for Bricklayer trade)
4. "Open Complete Toolkit" button navigates to toolkit with correct OFO
5. Toolkit pages correctly identify trade-specific content based on OFO code

## Logs Showing The Bug
```
[TOOLKIT_DEBUG] API Response Body: {"status":"success","classID":797,"className":"class A","trade_id":4,"trade_name":"Bricklayer","ofo_number":"641201","siteName":"Pinetown ARPL"}
[TOOLKIT_DEBUG] API returned OFO: 641201 for trade: Bricklayer
[TOOLKIT_DEBUG] Set _selectedLearnerId=9201151070088
[TOOLKIT_DEBUG] Set _selectedClassId=797
[TOOLKIT_DEBUG] Set _selectedOfoNumber=641201 (actual from class)  ← LIED! Was only printing, not assigning
```

The log said "Set _selectedOfoNumber=641201" but this was **only a print statement**, the actual assignment `_selectedOfoNumber = ofo;` was missing!

## Testing
**Test Credentials:**
- Facilitator ID: 6
- Role: `arpl_Assessor`
- ClassID: 797
- Expected Trade: Bricklayer
- Expected OFO Code: 641201

**Test Steps:**
1. Install the new APK: `build/app/outputs/flutter-apk/app-release.apk`
2. Login with facilitator ID 6
3. ARPL menu should appear (already verified working)
4. Click "View Complete Toolkit"
5. Select a candidate from dropdown (e.g., "Anele Cele")
6. **Verify OFO Number now displays:** **641201** (was "Not Set" before)
7. Click "Open Complete Toolkit"
8. Verify toolkit shows Bricklayer-specific content

## Files Modified
- `lib/ArplAssessorPage.dart` (5 changes across 3 different classes)
  - **Main `_ArplAssessorPageState` class:**
    - Added `_ofoNumber` declaration
    - Added OFO extraction logic in `fetchClasses()`
    - Updated `ARPLAppendixHPage` instantiation to pass `ofoNumber`
  - **`_ARPLAppendixHPageState` class:**
    - Added initialization in `initState()` to get `_ofoNumber` from widget
  - **`_ViewCompleteToolkitPageState` class:**
    - ⭐ **Added missing assignment:** `_selectedOfoNumber = ofo;` in dropdown's `onChanged` handler

## APK Location
```
build/app/outputs/flutter-apk/app-release.apk
```

## Build Info
- Build Date: 2026-07-15
- Build Command: `flutter build apk --release`
- APK Size: 45.9MB
- Build Status: ✅ Success
- Builds: 2 (first build fixed ARPLAppendixHPage, second build fixed ViewCompleteToolkitPage)

## Root Cause Analysis
**Why This Bug Existed:**
1. Developer added debug print statement: `print('[TOOLKIT_DEBUG] Set _selectedOfoNumber=$ofo ...')`
2. Print statement was descriptive and looked like an action: "Set _selectedOfoNumber"
3. Actual assignment `_selectedOfoNumber = ofo;` was forgotten
4. Logs showed "Set _selectedOfoNumber=641201" making it **appear** that the assignment happened
5. Bug was hidden because:
   - API was working correctly (returning 641201)
   - Logs showed the correct value
   - Only the actual state variable assignment was missing

**Lesson:** Print statements that describe actions should come **after** the action, not instead of it.

## Next Steps
1. Install new APK on device
2. Test "View Complete Toolkit" feature
3. Verify OFO Number displays correctly (641201 for Bricklayer)
4. Verify "Open Complete Toolkit" navigation works
5. Verify toolkit content is trade-specific
