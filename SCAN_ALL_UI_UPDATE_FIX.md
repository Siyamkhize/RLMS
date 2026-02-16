# Scan All UI Update Fix

## Issue
When using "Scan All Formative" or "Scan All Summative" while offline, the questions were being saved locally but not showing as completed in the UI.

## Root Cause
The `_saveLocally()` method was updating the `uploadedExercises` state for each individual question, but the UI wasn't being rebuilt after all questions were saved in the batch operation.

## Solution
Added explicit `setState(() {})` call after all questions are saved locally to force a UI rebuild.

## Changes Made

### 1. Formative Scan All (Offline)
**Before:**
```dart
} else {
  // Save locally for all formative questions
  for (var item in formativeQuestions) {
    await _saveLocally(document, 'Formative', exercise, null);
  }
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

**After:**
```dart
} else {
  // Save locally for all formative questions
  for (var item in formativeQuestions) {
    await _saveLocally(document, 'Formative', exercise, null);
  }
  
  // Force UI update after all saves
  setState(() {});
  
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

### 2. Summative Scan All (Offline)
Same fix applied to summative questions.

## How It Works Now

### Offline Scan All Flow:
1. User clicks "Scan All Formative/Summative"
2. Scans document with camera
3. For each question in the unit standard:
   - `_saveLocally()` is called
   - Document saved to local storage
   - Record saved to database with `synced=0`
   - `uploadedExercises[key] = true` is set
4. **NEW:** `setState(() {})` forces UI rebuild
5. All questions now show as completed ✅
6. Orange sync banner shows pending uploads

### Why setState Was Needed:
- `_saveLocally()` calls `setState()` for each individual save
- But Flutter batches setState calls for performance
- When saving multiple questions rapidly, the UI might not update until the next frame
- Explicit `setState(() {})` after the loop ensures immediate UI update

## Testing

### Test Scenario 1: Offline Formative Scan All
1. Go offline
2. Click "Scan All Formative Answers"
3. Scan document
4. **Expected:** All formative questions immediately show green checkmarks ✅

### Test Scenario 2: Offline Summative Scan All
1. Go offline
2. Complete all formative questions first
3. Click "Scan All Summative Answers"
4. Scan document
5. **Expected:** All summative questions immediately show green checkmarks ✅

### Test Scenario 3: Online Scan All
1. Stay online
2. Click "Scan All Formative/Summative"
3. Scan document
4. **Expected:** Questions upload to server and show as completed ✅

## Benefits

✅ **Immediate UI feedback** - Questions show as completed right away
✅ **Better UX** - User sees progress instantly
✅ **Consistent behavior** - Works same way online and offline
✅ **No data loss** - All questions still saved correctly
✅ **Proper sync** - Documents still sync when back online

## Related Code

### _saveLocally Method
Already includes `setState()` for individual saves:
```dart
setState(() {
  final uploadKey = '$assessmentType-$exercise-${widget.learnerID}';
  uploadedExercises[uploadKey] = true;
});
```

### Why Additional setState Was Needed
When called in a loop, Flutter may batch the setState calls. The additional `setState(() {})` after the loop ensures the UI updates immediately after all saves complete.

## Console Output

You should now see:
```
No internet connection, saving all 5 formative questions locally
Saved locally: formative question 1/5: Q1
[POE_OFFLINE] Saved locally: learnerID=123, exercise=Q1, type=Formative
Saved locally: formative question 2/5: Q2
[POE_OFFLINE] Saved locally: learnerID=123, exercise=Q2, type=Formative
...
Saved locally: formative question 5/5: Q5
[POE_OFFLINE] Saved locally: learnerID=123, exercise=Q5, type=Formative
```

Then UI updates to show all questions as completed.

## Summary

**Fixed:** UI now updates immediately after scanning all questions offline.

**How:** Added `setState(() {})` after batch save operations.

**Result:** All questions in the unit standard show as completed right after scanning. ✅
