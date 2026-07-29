# Trade-Specific ARPL Forms - OFO Fix Device Test
**Date:** July 9, 2026  
**Build:** APK Rebuilt with OFO API Integration Fix

---

## ISSUE FIXED
**Problem:** Dart code was hardcoding `_selectedOfoNumber = '671101'` instead of fetching the correct OFO from the database based on the class's assigned trade.

**Result:** The Bricklaying class (ID 783, trade_id 4, OFO 671103) was incorrectly routing to the Electrician form instead of the Bricklayer form.

**Solution Implemented:** 
1. Added new method `_fetchOfoForClass()` that calls the API to fetch the correct OFO
2. Modified dropdown handler to use API call instead of hardcoded value
3. The API `get_arpl_toolkit_data.php` already had correct logic - it queries `class.trade_id → arpl_trades.ofo_number`

---

## CODE CHANGES

### File: `lib/ArplAssessorPage.dart`

**Change 1: Added new helper method**
```dart
Future<String?> _fetchOfoForClass(String classId) async {
  try {
    print('[TOOLKIT_DEBUG] Fetching OFO for classID: $classId');
    
    final response = await http.get(
      Uri.parse(
        'https://rlms.rlms.co.za/mobile/get_arpl_toolkit_data.php?classID=$classId',
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && data['ofo_number'] != null) {
        final ofo = data['ofo_number'].toString();
        print('[TOOLKIT_DEBUG] API returned OFO: $ofo');
        return ofo;
      } else {
        print('[TOOLKIT_DEBUG] API returned no OFO, using default 671101');
        return '671101';
      }
    } else {
      print('[TOOLKIT_DEBUG] API error: ${response.statusCode}, using default 671101');
      return '671101';
    }
  } catch (e) {
    print('[TOOLKIT_DEBUG] Exception fetching OFO: $e, using default 671101');
    return '671101';
  }
}
```

**Change 2: Updated dropdown handler**
- **OLD:** `_selectedOfoNumber = '671101';` (hardcoded)
- **NEW:** Calls `_fetchOfoForClass()` to get OFO from API based on classID

```dart
onChanged: (value) {
  // ... existing code ...
  if (learner.isNotEmpty) {
    final classId = learner['classID']?.toString() ?? '';
    
    // Fetch OFO from API based on classID
    _fetchOfoForClass(classId).then((ofo) {
      setState(() {
        _selectedLearnerId = value;
        _selectedClassId = classId;
        _selectedOfoNumber = ofo ?? '671101';  // Now gets correct OFO from API!
        print('[TOOLKIT_DEBUG] Set _selectedOfoNumber=$_selectedOfoNumber');
      });
    });
  }
}
```

---

## TEST PROCEDURE

### Step 1: Open ARPL Toolkit Viewer
1. Open the app and navigate to **ARPL Assessment → View Complete Toolkit**
2. Wait for learner list to load

### Step 2: Select Bricklaying Class Learner
1. Click the **Candidate dropdown**
2. Select a learner from the **Bricklaying class** (e.g., Masoko Rosinah Segola)
   - This learner's class ID is 783
   - This class is assigned to Bricklayer trade (trade_id 4)
   - Expected OFO: **671103**

### Step 3: Verify Correct Routing
1. Click **Open Toolkit** button
2. **Check logs in Android Studio:**
   ```
   [TOOLKIT_DEBUG] Dropdown onChanged: value=...
   [TOOLKIT_DEBUG] Found learner in dropdown: true
   [TOOLKIT_DEBUG] Learner classID: 783
   [TOOLKIT_DEBUG] Fetching OFO for classID: 783
   [TOOLKIT_DEBUG] API returned OFO: 671103  ← MUST BE 671103 (not 671101)
   [TOOLKIT_DEBUG] Set _selectedOfoNumber=671103
   ```

3. **Verify page opened:**
   - Should open **ArplToolkitBricklayerPage** (Bricklayer form)
   - Should NOT open **ArplToolkitViewerPage** (Electrician form)
   - Page title or content should indicate Bricklayer toolkit

### Step 4: Test with Other Classes
1. Go back and select a learner from **"lowest" class** (ID 782)
   - This class is assigned to Electrician trade (trade_id 1)
   - Expected OFO: **671101**
2. Verify logs show:
   ```
   [TOOLKIT_DEBUG] Fetching OFO for classID: 782
   [TOOLKIT_DEBUG] API returned OFO: 671101  ← MUST BE 671101
   [TOOLKIT_DEBUG] Set _selectedOfoNumber=671101
   ```
3. Should open **ArplToolkitViewerPage** (Electrician form)

### Step 5: Test with Plumbing Class (if available)
1. If there's a learner in a Plumbing class:
   - Expected OFO: **671102**
2. Verify logs show correct OFO
3. Should open **ArplToolkitPlumberPage** (Plumber form)

---

## EXPECTED RESULTS

| Class Name | Class ID | Trade ID | Expected OFO | Expected Page |
|-----------|----------|----------|-------------|----------------|
| Bricklaying | 783 | 4 | 671103 | ArplToolkitBricklayerPage |
| "lowest" | 782 | 1 | 671101 | ArplToolkitViewerPage |
| Plumbing | TBD | 3 | 671102 | ArplToolkitPlumberPage |

---

## VERIFICATION CHECKLIST

- [ ] App installed successfully (v45.9 MB)
- [ ] Bricklaying learner routes to Bricklayer form (OFO 671103)
- [ ] Electrician learner routes to Electrician form (OFO 671101)
- [ ] Plumbing learner routes to Plumber form (OFO 671102) - if available
- [ ] Logs show correct OFO being fetched from API
- [ ] No crashes or errors when selecting learners
- [ ] Navigation is smooth and immediate

---

## BUILD SUMMARY

- **Dart Changes:** 1 file modified (`ArplAssessorPage.dart`)
- **Build Status:** ✅ SUCCESS (45.9 MB APK)
- **Installation Status:** ✅ SUCCESS
- **Build Time:** ~13.5 seconds

---

## NOTES

- The API endpoint `get_arpl_toolkit_data.php` was already correct
- It properly queries: `class.trade_id → arpl_trades.ofo_number`
- The fix was purely on the Dart frontend side
- All trade-specific forms were already created and working
- This fix just ensures the correct form opens based on the learner's class trade

