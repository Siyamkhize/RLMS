# ARPL APK Installation Quick Guide

## 📦 APK Ready for Testing
**File:** `app-release.apk`  
**Location:** `c:\projects\rlmss\build\app\outputs\flutter-apk\`  
**Size:** 45.55 MB  
**Date Built:** July 7, 2026

---

## 🚀 Installation Steps

### Method 1: Direct File Transfer
1. Locate: `c:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk`
2. Copy file to Android device via:
   - USB cable
   - WhatsApp/Email
   - Google Drive
   - Bluetooth

### Method 2: From Device File Manager
1. Open Android File Manager
2. Navigate to APK location
3. Tap `app-release.apk`
4. If prompted: Enable "Install from Unknown Sources" in Settings
5. Tap "Install"

### Method 3: Command Line (Device Connected)
```bash
cd c:\projects\rlmss
flutter install --release
```

---

## ✅ Test Checklist (Learner 16389)

### Basic Test
- [ ] Open app and login
- [ ] Navigate to Learner: Lungisani Cele (ID: 16389)

### Paper List Test
- [ ] Go to ARPL module
- [ ] Navigate: Pathway → Trade → Theory section
- [ ] **Expected:** See "Basic Electrical Safety" with ✅ checkmark
- [ ] **Expected:** Only 1 paper shows as uploaded (not all 5)

### Questions Display Test
- [ ] Click into "Basic Electrical Safety" paper
- [ ] **Expected:** All 21 questions visible
- [ ] **Expected:** Each question has:
  - ✅ Green checkmark icon
  - ✅ Green card background  
  - ✅ "✅ Uploaded" badge next to question number
  - ✅ "Completed" status text

### Status Messages Test
- [ ] At top of questions list:
  - **Expected:** "Total Questions: 21"
  - **Expected:** "Remaining: 0"
  - **Expected:** "Status: Complete" (in green)

- [ ] At bottom of screen:
  - **Expected:** "✅ All questions completed!"
  - **Expected:** Scan button is greyed out (disabled)

### Data Persistence Test
- [ ] Navigate away from learner 16389
- [ ] Navigate back to learner 16389
- [ ] Go into ARPL again
- [ ] **Expected:** Paper still shows as uploaded
- [ ] **Expected:** All questions still show completed status

---

## 🔍 What's Been Fixed

### Issue 1: Status Disappeared When Returning to Learner ✅
**Now Fixed:** Calls new `get_arpl_upload_status.php` endpoint that queries `arpl_poe` table

### Issue 2: All Papers Showed as Uploaded ✅
**Now Fixed:** Uses paper-title-based keys for unique identification

### Issue 3: Questions Didn't Show as Completed ✅
**Now Fixed:** Visual checkmarks and badges added when paper is uploaded

---

## 📱 Visual Changes You'll See

### Before
- Questions showed: "Upload 21 questions"
- Button was green and active
- No visual indication of completion

### After  
- Questions show with green checkmarks (✅)
- Each question has "Uploaded" badge
- Bottom shows: "✅ All questions completed!"
- Scan button is greyed out
- Paper info shows "Remaining: 0" and "Status: Complete"

---

## 🐛 If Something's Wrong

### Questions Still Show as Pending
- Check internet connection
- Try logging out and back in
- Restart the app
- Check if learner actually has uploaded papers

### Status Doesn't Persist
- Verify `get_arpl_upload_status.php` is on server
- Check database connection to `arpl_poe` table
- Try clearing app cache

### Visual Indicators Not Showing
- Ensure APK is fully installed (not cached)
- Try uninstalling and reinstalling APK
- Check Flutter version compatibility

---

## 📞 Testing Notes

- Test data already in system for learner 16389
- Paper uploaded: Basic Electrical Safety (Theory), 21 questions
- Uploaded at: 2026-07-07 09:18:52
- All questions should show as complete

---

## 📋 System Requirements

- Android 5.0+ (API 21)
- 100+ MB free storage
- Internet connection recommended (for server sync)
- Works offline too (uses local database)

---

## ✨ Key Features in This Build

✅ Paper upload status persists  
✅ Only uploaded papers show checkmarks  
✅ Questions display with visual completion indicators  
✅ Clear "All questions completed!" message  
✅ Scan button disabled when complete  
✅ Paper info shows accurate remaining count  

---

## 🎯 Success Criteria

After installing, if you can:
1. ✅ See learner 16389's paper with checkmark
2. ✅ Click into paper and see all 21 questions with green checkmarks
3. ✅ Navigate away and back - status persists
4. ✅ See "All questions completed!" message
5. ✅ See greyed-out scan button

**Then the fix is working correctly!** 🎉

