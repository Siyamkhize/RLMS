# CRITICAL: ARPL Upload Fix Required

**Issue**: Data is being uploaded but NOT appearing on frontend  
**Root Cause**: Flutter app is NOT sending required parameters to `arpl_save_metadata.php`

---

## What's Missing in Flutter Upload

### Current Upload (BROKEN) ❌
```dart
var request = http.MultipartRequest('POST', url)
  ..fields['learnerID'] = widget.learnerId.toString()
  ..fields['type'] = 'ARPL'
  ..fields['exercises'] = json.encode(questions...)
  ..fields['paper_title'] = selectedPaper!;
  // Missing: ofo_number, paper_number, section_type, question_count
```

### Required Upload (FIXED) ✅
```dart
var request = http.MultipartRequest('POST', url)
  ..fields['learnerID'] = widget.learnerId.toString()
  ..fields['ofo_number'] = selectedTrade!  // OFO/Trade name
  ..fields['paper_title'] = selectedPaper!
  ..fields['paper_number'] = '1'  // Default to 1 or extract from data
  ..fields['section_type'] = selectedSection == 'theory_papers' ? 'theory' : 'practical'
  ..fields['question_count'] = questions.length.toString();
```

---

## Data Available in Flutter App

| Parameter | Source | Value |
|-----------|--------|-------|
| learnerID | widget.learnerId | ✓ Already sent |
| ofo_number | selectedTrade | ✓ Available - NEED TO ADD |
| paper_title | selectedPaper | ✓ Already sent |
| paper_number | ? | ❓ Need to extract or default to 1 |
| section_type | selectedSection | ✓ Available - NEED TO ADD (convert theory_papers→theory) |
| question_count | questions.length | ✓ Available - NEED TO ADD |

---

## Fix Location

**File**: `lib/ArplHierarchicalNavigatorPage.dart`  
**Line**: ~1484-1489  

**Current Code**:
```dart
var request = http.MultipartRequest('POST', url)
  ..fields['learnerID'] = widget.learnerId.toString()
  ..fields['type'] = 'ARPL'
  ..fields['exercises'] = json.encode(questions
      .map((item) => item['exercise']?.toString() ?? 'N/A')
      .toList())
  ..fields['paper_title'] = selectedPaper!;
```

**Fixed Code**:
```dart
var request = http.MultipartRequest('POST', url)
  ..fields['learnerID'] = widget.learnerId.toString()
  ..fields['ofo_number'] = selectedTrade!
  ..fields['paper_title'] = selectedPaper!
  ..fields['paper_number'] = '1'  // Paper 1 by default
  ..fields['section_type'] = selectedSection == 'theory_papers' ? 'theory' : 'practical'
  ..fields['question_count'] = questions.length.toString()
  ..fields['type'] = 'ARPL'
  ..fields['exercises'] = json.encode(questions
      .map((item) => item['exercise']?.toString() ?? 'N/A')
      .toList());
```

---

## Why This Fixes The Issue

1. **ofo_number** = Makes record identifiable by trade/OFO
2. **paper_number** = Allows multiple papers per trade (1, 2, 3...)
3. **section_type** = Tells system if it's theory or practical
4. **question_count** = Tracks how many questions in the upload

Without these, the database INSERT fails the NOT NULL constraint or creates invalid records.

---

## Next Steps

1. ✅ Update Flutter code with the 4 missing fields
2. ✅ Rebuild APK: `flutter clean` → `flutter pub get` → `flutter build apk --release`
3. ✅ Install to device and test upload
4. ✅ Verify data appears on frontend query endpoint
5. ✅ Verify no errors in PHP error log

---

## What Will Happen After Fix

### Before (Currently)
```
App → arpl_save_metadata.php → Database
(Missing ofo_number, section_type, question_count)
           ↓
Incomplete record or INSERT fails
           ↓
Data not showing on frontend
```

### After Fix
```
App → arpl_save_metadata.php → Database (arpl_poe)
(All required fields present)
           ↓
Record inserted successfully with all data
           ↓
Query endpoint returns complete data
           ↓
Frontend displays theory/practical papers correctly
```

---

## Verification Steps

### Test Upload
1. Go to ARPL screen
2. Select theory paper
3. Capture/upload PDF
4. Check database with query:
   ```sql
   SELECT * FROM arpl_poe 
   WHERE learnerID = [your_id] 
   ORDER BY created_at DESC LIMIT 1;
   ```
5. Verify all fields populated:
   - ofo_number ✓
   - paper_title ✓
   - paper_number ✓
   - section_type ✓
   - question_count ✓

---

**This is a critical fix that MUST be applied before data will show on the frontend.**
