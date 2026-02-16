# Scan All Offline - Diagnostic Guide

## Issue
When scanning all formative/summative questions offline, they're not showing as completed in the UI.

## Enhanced Logging Added

I've added detailed logging to help diagnose the issue. When you scan all questions offline, you should see:

### Expected Console Output:

```
[OFFLINE_SCAN] No internet connection, saving all 5 formative questions locally
[OFFLINE_SCAN] Processing question 0/5: Q1
[POE_OFFLINE] Document saved to: /path/to/file
[POE_OFFLINE] Saved locally: learnerID=123, exercise=Q1, type=Formative
[OFFLINE_SCAN] Question Q1 marked as: true
[OFFLINE_SCAN] Processing question 1/5: Q2
[POE_OFFLINE] Document saved to: /path/to/file
[POE_OFFLINE] Saved locally: learnerID=123, exercise=Q2, type=Formative
[OFFLINE_SCAN] Question Q2 marked as: true
...
[OFFLINE_SCAN] All 5 questions saved, forcing UI update...
[OFFLINE_SCAN] UI refresh complete
```

## What to Check

### 1. Are Questions Being Marked?
Look for lines like:
```
[OFFLINE_SCAN] Question Q1 marked as: true
```

**If you see `true`:** ✅ State is being updated correctly
**If you see `false` or `null`:** ❌ State update is failing

### 2. Is _saveLocally Being Called?
Look for:
```
[POE_OFFLINE] Saved locally: learnerID=123, exercise=Q1, type=Formative
```

**If you see this:** ✅ _saveLocally is working
**If you don't see this:** ❌ _saveLocally is not being called

### 3. Is UI Refresh Happening?
Look for:
```
[OFFLINE_SCAN] All X questions saved, forcing UI update...
[OFFLINE_SCAN] UI refresh complete
```

**If you see both:** ✅ UI refresh is being triggered
**If missing:** ❌ Code is not reaching the refresh

## Possible Issues and Solutions

### Issue 1: Questions Marked but UI Not Updating

**Symptoms:**
- Console shows: `Question Q1 marked as: true`
- But UI still shows questions as incomplete

**Cause:** UI not rebuilding after state change

**Solution:** Already implemented - `_refreshUploadStatus()` is called

**Check:** Look for `[OFFLINE_SCAN] UI refresh complete` in console

### Issue 2: Questions Not Being Marked

**Symptoms:**
- Console shows: `Question Q1 marked as: false` or `null`

**Cause:** `_saveLocally()` not updating state correctly

**Check the _saveLocally method:**
```dart
setState(() {
  final uploadKey = '$assessmentType-$exercise-${widget.learnerID}';
  uploadedExercises[uploadKey] = true;
});
```

**Verify:** This setState is being executed

### Issue 3: Wrong Upload Key Format

**Symptoms:**
- Questions marked but with wrong key
- UI checks different key than what's being set

**Check:**
- Save uses: `'Formative-$exercise-${widget.learnerID}'`
- UI checks: `'Formative-$exercise-${widget.learnerID}'`
- Must match exactly!

**Verify in console:**
```
[OFFLINE_SCAN] Question Q1 marked as: true
```
Then check UI is looking for same key.

### Issue 4: Dialog Closing Before State Updates

**Symptoms:**
- Questions marked in console
- But UI shows old state

**Cause:** Navigator.pop() called before state propagates

**Solution:** Moved `_refreshUploadStatus()` before showing snackbar

### Issue 5: Database Save Failing

**Symptoms:**
- No `[POE_OFFLINE] Saved locally` messages
- Or error messages in console

**Check for errors:**
```
[POE_OFFLINE] Error copying file: ...
Error saving POE upload: ...
```

**Solution:** Check file permissions, disk space, database access

## Testing Steps

### Step 1: Enable Console Logging
Make sure you can see console output (logcat on Android, console on iOS)

### Step 2: Go Offline
Turn off WiFi and mobile data

### Step 3: Scan All Formative
1. Click "Scan All Formative Answers"
2. Scan document
3. **Watch console output carefully**
4. Copy all `[OFFLINE_SCAN]` and `[POE_OFFLINE]` messages

### Step 4: Check UI
After scan completes:
- Do questions show green checkmarks? ✅
- Or still show as incomplete? ❌

### Step 5: Share Console Output
If questions still not showing as completed, share the console output showing:
- All `[OFFLINE_SCAN]` messages
- All `[POE_OFFLINE]` messages
- Any error messages

## What Should Happen

### Correct Flow:
1. User clicks "Scan All Formative"
2. Scans document
3. For each question:
   - `_saveLocally()` called
   - Document saved to file
   - Record saved to database
   - `uploadedExercises[key] = true` set
   - Console shows: `Question X marked as: true`
4. After all questions:
   - `_refreshUploadStatus()` called
   - UI rebuilds
   - Questions show as completed ✅

### If Not Working:
The console output will show exactly where the flow breaks.

## Quick Verification

Run this in your mind while watching console:

```
✅ [OFFLINE_SCAN] No internet connection, saving all X questions
✅ [OFFLINE_SCAN] Processing question 0/X: Q1
✅ [POE_OFFLINE] Document saved to: ...
✅ [POE_OFFLINE] Saved locally: ...
✅ [OFFLINE_SCAN] Question Q1 marked as: true  <-- KEY CHECK
✅ [OFFLINE_SCAN] All X questions saved, forcing UI update...
✅ [OFFLINE_SCAN] UI refresh complete
```

If all ✅ appear but UI still not updating, there's a different issue.

## Additional Debug Info

### Check uploadedExercises State
Add temporary logging in the UI build method:
```dart
print('Building UI, uploadedExercises has ${uploadedExercises.length} entries');
```

### Check Key Format
Add logging to verify key format matches:
```dart
final uploadKey = 'Formative-$exercise-${widget.learnerID}';
print('Checking key: $uploadKey, value: ${uploadedExercises[uploadKey]}');
```

## Next Steps

1. **Run the app**
2. **Go offline**
3. **Scan all questions**
4. **Watch console output**
5. **Share the `[OFFLINE_SCAN]` messages** if still not working

The enhanced logging will tell us exactly what's happening!
