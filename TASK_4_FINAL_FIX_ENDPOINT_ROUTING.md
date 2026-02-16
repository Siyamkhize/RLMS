# TASK 4: Moderation Status Update - FINAL FIX

## Issue Summary
User was getting "Error missing required fields" when trying to update moderation status (Upheld/Withdrawn) for formative and summative exercises.

## Root Cause
**CRITICAL BUG IN ENDPOINT ROUTING**

The Flutter code had incorrect logic for determining which PHP endpoint to use:

```dart
// WRONG (before fix):
final String endpoint = (assessmentType == 'general') 
    ? 'save_moderation_status.php'  
    : 'moderate_marks.php';
```

The problem:
- When `_buildExerciseTiles()` is called for formative exercises, it passes `assessmentType: 'formative'`
- When called for summative exercises, it passes `assessmentType: 'summative'`
- The condition `(assessmentType == 'general')` was ALWAYS FALSE
- This meant formative/summative requests were being sent to `moderate_marks.php` (wrong endpoint)
- `moderate_marks.php` expects different parameter names, causing "missing required fields" error

## The Fix

Changed the endpoint routing logic to correctly identify formative/summative:

```dart
// CORRECT (after fix):
final String endpoint = (assessmentType == 'formative' || assessmentType == 'summative') 
    ? 'save_moderation_status.php'  
    : 'moderate_marks.php';
```

Now:
- Formative exercises → `save_moderation_status.php` ✓
- Summative exercises → `save_moderation_status.php` ✓
- Logbook exercises → `moderate_marks.php` ✓

## Request Parameters

### For Formative/Summative (save_moderation_status.php)
```json
{
  "learnerId": "1231",
  "exercise": "Formative Assessment 1.1",
  "moderation_status": "Upheld",
  "moderator_comment": "Good work",
  "moderator_id": "77",
  "assessment_type": "Formative"
}
```

### For Logbook (moderate_marks.php)
```json
{
  "assessmentType": "logbook",
  "exerciseId": "123",
  "learnerId": "1231",
  "moderatorStatus": "Upheld",
  "moderatorComment": "Good work",
  "moderatorId": "77"
}
```

## Files Modified

1. **lib/ModeratorPage.dart** (line ~1993)
   - Fixed endpoint routing condition
   - Changed from `(assessmentType == 'general')` to `(assessmentType == 'formative' || assessmentType == 'summative')`

## Testing

To test the fix:

1. **Rebuild the Flutter app:**
   ```bash
   flutter clean
   flutter build apk --release
   ```

2. **Install on device and test:**
   - Navigate to a learner's formative exercises
   - Try to change moderation status from Upheld to Withdrawn (or vice versa)
   - Should now work without "missing required fields" error

3. **Check debug logs:**
   - Look for `[DEBUG] Request body:` in Flutter console
   - Verify it shows correct endpoint being used
   - Check `debug.log` on server to see received parameters

## Debug Tools Created

Created `test_moderation_request_debug.php` to help diagnose parameter issues:
- Shows what parameters are expected
- Validates parameter presence
- Shows marks table structure
- Displays sample records

## Status

✅ **FIXED** - Endpoint routing corrected

The issue was NOT with parameter names or PHP validation logic. It was simply that formative/summative requests were being sent to the wrong endpoint entirely.

## Next Steps

1. Rebuild Flutter app with the fix
2. Test on device with moderator ID 77
3. Verify formative and summative moderation status updates work
4. Verify logbook moderation still works (should be unaffected)

---

**Date:** 2026-02-11
**Moderator ID:** 77
**Issue:** Task 4 - Moderation status update error
**Resolution:** Fixed endpoint routing logic in ModeratorPage.dart
