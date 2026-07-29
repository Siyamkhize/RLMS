# ✅ APK Installed - Sick Note Feature Ready

**Device**: RZ8X306F7TZ  
**APK**: app-release.apk (45.9MB)  
**Installation**: Success  
**Date**: Context Transfer Session

---

## What's New in This Build

### ✅ Sick Note Upload Feature
- **Access**: From learner list or clock-in page, tap "Upload Sick Note" button
- **UI**: Old simple layout (matches user screenshot)
- **Validation**: Happens INSIDE calendar picker (dates grayed out automatically)

### Key Features:
1. **Eligibility Check**: First-time learners see "not eligible" message
2. **Calendar Picker with Validation**:
   - Only shows last 5 WORKING days (excludes weekends + SA holidays)
   - Dates where learner clocked in are **grayed out** (not selectable)
   - Only missing attendance days are selectable
3. **Document Scanner**: Purple camera FAB button → camera-based PDF scanner
4. **Server Submission**: Uploads to server with status='PENDING'

---

## Testing Steps

### 1. Test First-Time Learner
- Navigate to learner with NO clocking history
- Tap "Upload Sick Note"
- **Expected**: "You are a first time learner, you are not able to upload a sick note."

### 2. Test Calendar Picker Validation ⭐ MAIN TEST
- Navigate to learner with clocking history
- Tap "Upload Sick Note"
- Tap **Date From calendar icon** 📅
- **Expected**:
  - ✅ Calendar shows only last 5 working days
  - ✅ Dates where learner clocked in are **grayed out**
  - ✅ Try to tap a grayed-out date → cannot select
  - ✅ Only valid dates (missing attendance) are selectable

### 3. Test Document Scanner
- Fill in Practice Name and Medical Practitioner
- Select valid dates
- Tap **purple camera button** (bottom right)
- **Expected**: Camera scanner opens → scan document → PDF created

### 4. Test Submission
- Complete all fields
- Tap "Submit"
- **Expected**: Success dialog → "Sick note submitted successfully and is pending approval"

---

## ⚠️ IMPORTANT: Backend PHP Files

**These PHP files still need to be uploaded to the server:**

1. **`mobile/get_sick_note_eligible_dates.php`**
   - Fixed column names: `LearnerID`, `clock_date`, `status = 'Approved'`
   - Returns list of valid/non-selectable dates

2. **`mobile/submit_sick_note.php`**
   - Fixed column names to match database schema
   - Handles file upload and database insertion

**Upload Location**: `https://rlms.rlms.co.za/mobile/`

---

## Testing Without Backend Upload

If you test BEFORE uploading PHP files, you'll see:
- ❌ "Server error" when opening sick note page (eligibility check fails)
- ❌ "Connection error" messages

**Solution**: Upload the 2 PHP files to server first!

---

## Verification Checklist

After uploading PHP files:

- [ ] First-time learner sees "not eligible" message
- [ ] Calendar picker shows only valid dates
- [ ] Clocked-in dates are grayed out in calendar
- [ ] Cannot select grayed-out dates
- [ ] Document scanner works (camera → PDF)
- [ ] Submission creates database record
- [ ] PDF uploaded to `uploads/sick_notes/` folder

---

## Files Modified This Session

### Frontend (Already in APK)
✅ `lib/sick_note_page.dart` - Complete rewrite with calendar validation

### Backend (Need Server Upload)
⏳ `mobile/get_sick_note_eligible_dates.php` - Column names fixed  
⏳ `mobile/submit_sick_note.php` - Column names fixed

### Config (Already in APK)
✅ `lib/config.dart` - Endpoints configured

---

## Quick Test Command

```sql
-- After testing, verify database record
SELECT * FROM sick_note 
WHERE learner_id = [TEST_LEARNER_ID]
ORDER BY upload_date DESC;
```

---

**Status**: APK installed ✅ | Backend pending upload ⏳
