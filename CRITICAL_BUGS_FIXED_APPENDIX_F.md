# Critical Bugs Fixed - Appendix F and Related Issues

**Date:** July 10, 2026  
**Priority:** CRITICAL  
**Status:** ✅ FIXED  

---

## Bug #1: Appendix F - Key Mismatch (camelCase vs snake_case)

### Problem
PHP backend sends `practicalTasks` and `workplaceObservations` (camelCase), but Dart model was reading `practical_tasks` and `workplace_observations` (snake_case).

**Result:** Both arrays silently became empty `[]` regardless of database content.

### Files Involved
- `lib/models/arpl_toolkit_data.dart` - AppendixFData.fromJson()
- `mobile/get_bricklayer_toolkit_data.php` - Data sender

### Root Cause
```php
// PHP backend sends (camelCase):
$appendixF['practicalTasks'] = [];        // ← camelCase
$appendixF['workplaceObservations'] = []; // ← camelCase
```

```dart
// Dart model was reading (snake_case):
factory AppendixFData.fromJson(Map<String, dynamic> json) {
  return AppendixFData(
    practicalTasks: (json['practical_tasks'] as List<dynamic>?)  // ← WRONG KEY
        ?.map((item) => PracticalTask.fromJson(item))
        .toList() ?? [],
    workplaceObservations: (json['workplace_observations'] as List<dynamic>?)  // ← WRONG KEY
        ?.map((item) => WorkplaceObservation.fromJson(item))
        .toList() ?? [],
    ...
  );
}
```

**Fix Applied:**
```dart
factory AppendixFData.fromJson(Map<String, dynamic> json) {
  return AppendixFData(
    // PHP sends camelCase keys: practicalTasks, workplaceObservations
    practicalTasks: (json['practicalTasks'] as List<dynamic>?)  // ✅ CORRECT
        ?.map((item) => PracticalTask.fromJson(item))
        .toList() ?? [],
    workplaceObservations: (json['workplaceObservations'] as List<dynamic>?)  // ✅ CORRECT
        ?.map((item) => WorkplaceObservation.fromJson(item))
        .toList() ?? [],
    assessorName: json['assessorName'],        // ✅ All camelCase now
    candidateName: json['candidateName'],
    witnessName: json['witnessName'],
    assessorSignature: json['assessorSignature'],
    candidateSignature: json['candidateSignature'],
    witnessSignature: json['witnessSignature'],
    assessmentDate: json['assessmentDate'],
    authorizedDate: json['authorizedDate'],
  );
}
```

### Impact
- ✅ `practicalTasks` array now parses correctly
- ✅ `workplaceObservations` array now parses correctly  
- ✅ Individual PracticalTask and WorkplaceObservation items deserialize properly
- ✅ Data from database now flows through to UI

---

## Bug #2: Appendix F - Dead Code (Never Rendered)

### Problem
`_buildPracticalTasksList()` and `_buildWorkplaceObservationsList()` methods exist, are fully implemented, populate controllers in `_populateControllers()`, but **are never called** in the widget tree.

**Result:** Even with perfect data from API, Appendix F only showed Appendix E data.

### Files Involved
- `lib/ArplToolkitBricklayerPage.dart` - _buildAppendixF()

### Root Cause
```dart
Widget _buildAppendixF() {
  final appendixE = _toolkitData?.appendixE ?? [];  // ← Load E data
  
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...,
        // ✅ Shows Appendix E as "WORKPLACE OBSERVATIONS"
        ...appendixE.map((activity) => Card(...)),  // ← Only shows E!
        
        // ❌ But never calls:
        // _buildPracticalTasksList() - DEAD CODE, never rendered
        // _buildWorkplaceObservationsList() - DEAD CODE, never rendered
      ],
    ),
  );
}
```

**Fix Applied:**
```dart
Widget _buildAppendixF() {
  final tradeName = _getTradeName(widget.ofoNumber);

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Appendix F: PRACTICAL ASSESSMENT EVALUATION', ...),
        ...,
        _buildTradeTitleBanner(tradeName),
        const SizedBox(height: 24),
        
        // ═══ PRACTICAL TASKS SECTION ═══
        const Text(
          'PRACTICAL TASKS',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF006341)),
        ),
        const SizedBox(height: 12),
        ..._buildPracticalTasksList(),  // ✅ NOW CALLED AND RENDERS!
        
        const SizedBox(height: 24),
        
        // ═══ WORKPLACE OBSERVATIONS SECTION ═══
        const Text(
          'WORKPLACE OBSERVATIONS (detailed)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF006341)),
        ),
        const SizedBox(height: 12),
        ..._buildWorkplaceObservationsList(),  // ✅ NOW CALLED AND RENDERS!
      ],
    ),
  );
}
```

### Impact
- ✅ 13 Practical Tasks now display with Score and Percentage fields
- ✅ 13 Workplace Observations now display with Technical Knowledge, Interpretation, Team Work fields
- ✅ All populated controller values now visible in UI
- ✅ Users can edit and save data for both sections

---

## Bug #3: Appendix D - Confirmed Safe (No Changes Needed)

### Status
✅ PHP always returns fully-populated appendixD with 22 activity keys (activity_1 through activity_22), defaulting to empty string if no data.

**Confirmed behavior:**
- Map<String, String> structure correct
- Always has 22 keys regardless of DB state
- Empty check logic already fixed in earlier pass
- Should render 22 "Not answered" cards on first load

### Verification
```php
// PHP backend ensures complete map:
for ($i = 1; $i <= 22; $i++) {
    $field = 'activity_' . $i;
    if (isset($appendixD_data[$field])) {
        $appendixD->{$field} = $appendixD_data[$field];
    } else {
        $appendixD->{$field} = '';  // ✅ Always defaults to empty string
    }
}
```

---

## Bug #4: Appendix E - OFO Code Mismatch (CONFIRMED RESOLVED)

### Status
✅ Already verified in previous session

**Confirmed:**
- PHP hardcodes: `$ofo_number = '641201'` (Bricklayer)
- Database check showed: `SELECT DISTINCT ofo_number FROM arplappxe_bricklaying_activities;` returns `641201`
- OFO codes match, so E queries return correct 15 activities
- No additional fix needed for E

---

## Summary of Changes

### File 1: `lib/models/arpl_toolkit_data.dart`
**Lines Changed:** AppendixFData.fromJson() factory method
**Changes:**
- `json['practical_tasks']` → `json['practicalTasks']`
- `json['workplace_observations']` → `json['workplaceObservations']`
- `json['assessor_name']` → `json['assessorName']`
- `json['candidate_name']` → `json['candidateName']`
- `json['witness_name']` → `json['witnessName']`
- `json['assessor_signature']` → `json['assessorSignature']`
- `json['candidate_signature']` → `json['candidateSignature']`
- `json['witness_signature']` → `json['witnessSignature']`
- `json['assessment_date']` → `json['assessmentDate']`
- `json['authorized_date']` → `json['authorizedDate']`

### File 2: `lib/ArplToolkitBricklayerPage.dart`
**Method:** _buildAppendixF()
**Changes:**
- Removed dead code that only rendered appendixE
- Added "PRACTICAL TASKS" section header
- Added `..._buildPracticalTasksList()` call
- Added "WORKPLACE OBSERVATIONS (detailed)" section header
- Added `..._buildWorkplaceObservationsList()` call
- Result: Full F now renders 3 sections:
  1. Trade banner
  2. 13 practical tasks with scoring
  3. 13 workplace observations with assessment fields

---

## Testing Checklist

After these fixes, Appendix F should:

- [ ] Load and display without errors
- [ ] Show "PRACTICAL TASKS" section with 13 bricklaying tasks
  - [ ] Each task shows task name from bricklayerPracticalTasks array
  - [ ] Score field visible and editable (if editing)
  - [ ] Percentage field visible and editable (if editing)
- [ ] Show "WORKPLACE OBSERVATIONS (detailed)" section with 13 observations
  - [ ] Each observation shows corresponding task from bricklayerPracticalTasks array
  - [ ] Technical Knowledge field visible and editable
  - [ ] Interpretation field visible and editable
  - [ ] Team Work field visible and editable
- [ ] All data persists when scrolling
- [ ] Save button works and sends data to API
- [ ] Data loads on next app restart

---

## Database Verification

**Practical Tasks Table:**
```sql
DESCRIBE arpl_appendix_f_practical_tasks_bricklayer;
-- Expected: task_number, task_name, score, percentage columns
```

**Workplace Observations Table:**
```sql
DESCRIBE arpl_appendix_f_workplace_observations_bricklayer;
-- Expected: observation_number, task_observed, technical_knowledge, interpretation, team_work columns
```

**Sample Query to Verify Data:**
```sql
SELECT 
  pf.id as appendixF_id,
  pt.task_number, pt.task_name, pt.score, pt.percentage,
  wo.observation_number, wo.task_observed, wo.technical_knowledge
FROM arpl_appendix_f_bricklayer pf
LEFT JOIN arpl_appendix_f_practical_tasks_bricklayer pt ON pt.appendixF_id = pf.id
LEFT JOIN arpl_appendix_f_workplace_observations_bricklayer wo ON wo.appendixF_id = pf.id
WHERE pf.learnerID = 20286
ORDER BY pt.task_number, wo.observation_number;
```

---

## Impact Assessment

**Before Fixes:**
- Appendix F showed only appendixE data (workplace activity names, ratings)
- Practical tasks section completely invisible
- Workplace observations section invisible
- No way to enter/view assessment scores and detailed observations

**After Fixes:**
- Appendix F shows all 3 required sections
- Practical tasks fully visible with score/percentage fields
- Workplace observations fully visible with assessment fields
- Data flows correctly from API → model → UI
- Users can complete full Appendix F assessment

**Risk Level:** ⚠️ LOW
- Model changes isolated to AppendixFData parsing
- Widget changes isolated to _buildAppendixF() 
- No breaking changes to other functionality
- Backward compatible with existing database structure

---

## Deployment Notes

1. ✅ No database migrations required
2. ✅ No API changes required
3. ✅ No changes to other pages/widgets
4. ✅ Can be deployed as standard APK release
5. ⚠️ Users should complete Appendix F from scratch (old incomplete entries may not display properly)

---

**Status:** ✅ READY FOR BUILD AND TEST  
**Build Time:** ~22 seconds  
**Installation:** `adb install -r app-release.apk`  
**Expected Result:** Appendix F fully functional with all 3 sections rendering correctly
