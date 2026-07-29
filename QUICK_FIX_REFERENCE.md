# Quick Fix Reference - July 22, 2026

## What Was Fixed

### Learning Material Form Page - Learners Not Showing

**Problem:** "No learner clocked in" message even when learners clocked in today

**Fix:** Changed SQLite date comparison from `DATE('now')` to `strftime('%Y-%m-%d', column)`

**Result:** More reliable date matching in SQLite local database

---

## Testing Right Now

Open the app and test:

### Test 1: Learning Material Form
1. Have a learner clock in
2. Go to Learning Material Form page for that class
3. **Expected:** Learner should appear in the list

### Test 2: Check Logs
Connect phone and run:
```bash
adb logcat | findstr MATERIALS
```

Look for:
```
[MATERIALS] Today date: 2026-07-22
[MATERIALS] Query returned X rows
[MATERIALS] ✅ Found X learners
```

If still shows 0 rows:
```
[MATERIALS] Total clocking records for today: X
[MATERIALS]   - Learner ID (Name), classID=Y
```
Check if the classID matches your expected class

---

## What's NOT Fixed (Needs Server Upload)

### Sick Note PHP Files

These are ready but NOT uploaded to server yet:

1. `mobile/get_sick_note_eligible_dates.php`
2. `mobile/submit_sick_note.php`

**To upload:**
- Use FTP/cPanel to upload files to `mobile/` directory on server
- After upload, test sick note feature in app

---

## If Learners Still Don't Show

Possible causes (check debug logs):

1. **Date format mismatch:**
   - Log shows date but query returns 0 rows
   - Check how `clock_date` is stored in database

2. **ClassID mismatch:**
   - Log shows learners exist but for different classID
   - Verify correct classID is being passed to page

3. **Clock_in_time NULL:**
   - Query filters for `clock_in_time IS NOT NULL`
   - Check if learners actually completed clock-in

---

## Quick Commands

**Rebuild and install:**
```bash
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

**View logs:**
```bash
adb logcat | findstr MATERIALS
adb logcat | findstr SICK_NOTE
adb logcat | findstr SCANNER
```

**Clear app data (if needed):**
```bash
adb shell pm clear com.example.rlmss
```

---

## Status Summary

✅ APK built (45.9MB)  
✅ APK installed on device  
✅ Query date function fixed  
✅ Scanner crash already fixed  
⏳ Needs device testing  
⏳ Sick note PHP needs server upload  

---

## Files Changed

**Frontend:**
- `lib/LearningMaterialFormPage.dart` - Query fixed

**Backend (Ready, Not Uploaded):**
- `mobile/get_sick_note_eligible_dates.php`
- `mobile/submit_sick_note.php`

---

## Contact Points

**If learners still don't show:**
- Share the `[MATERIALS]` debug logs
- Include the classID being used
- Confirm learner clocked in today

**If sick note doesn't work:**
- First upload PHP files to server
- Then test and share any error messages
