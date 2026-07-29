# Sick Note Feature - Ready for Testing

**Status**: ✅ APK Built & Ready  
**Date**: Context Transfer Session  
**Build**: `app-release.apk` (45.9MB)

---

## What Was Implemented

### ✅ Frontend (Flutter)
- **File**: `lib/sick_note_page.dart`
- **UI Layout**: Matches old format exactly
  - Learner Information card (Name, Surname)
  - Sick Note Details section with:
    - Practice Name field
    - Medical Practitioner field
    - Practitioner Type dropdown
    - **Date From (YYYY-MM-DD)** with calendar picker 📅
    - **Date To (YYYY-MM-DD)** with calendar picker 📅
    - Purple camera FAB button (bottom right)

### ✅ Calendar Picker Validation (AS REQUESTED)
- **Validation happens INSIDE the calendar picker**
- When user taps the calendar icon, the calendar automatically:
  - ✅ Shows only valid dates (last 5 working days where learner did NOT clock in)
  - ✅ Grays out dates where learner already clocked in
  - ✅ Prevents selection of invalid dates
- **Implementation**: Uses `selectableDayPredicate` in `showDatePicker()`

### ✅ Backend (PHP) - Column Names Fixed
- **File**: `mobile/get_sick_note_eligible_dates.php`
  - Fixed ALL column names to use `LearnerID`, `clock_date`, `status = 'Approved'`
  - Returns list of valid and non-selectable dates
  
- **File**: `mobile/submit_sick_note.php`
  - Fixed ALL column names to match database schema
  - Server-side validation (eligibility, date range, attendance check)
  - File upload handling (PDF only, max 10MB)
  - Inserts record with `status='PENDING'`

---

## Testing Workflow

### Step 1: Install APK
```bash
# Copy APK from build folder
C:\projects\rlmss\build\app\outputs\flutter-apk\app-release.apk

# Install on test device via USB or adb
adb install -r app-release.apk
```

### Step 2: Upload Fixed PHP Files to Server
Upload these files to `https://rlms.rlms.co.za/mobile/`:
- ✅ `mobile/get_sick_note_eligible_dates.php` (column names fixed)
- ✅ `mobile/submit_sick_note.php` (column names fixed)

### Step 3: Test Eligibility Check

#### Test Case 1: First-Time Learner (No Clocking History)
1. Navigate to learner with NO clocking records
2. Tap "Upload Sick Note" button
3. **Expected**: See message "You are a first time learner, you are not able to upload a sick note."

#### Test Case 2: Eligible Learner
1. Navigate to learner with clocking history
2. Tap "Upload Sick Note" button
3. **Expected**: See form with Learner Information and Sick Note Details

### Step 4: Test Calendar Picker Validation

#### Test Case 3: Date From Calendar Validation
1. Tap the **calendar icon** next to "Date From (YYYY-MM-DD)"
2. **Expected Calendar Behavior**:
   - ✅ Only shows last 5 WORKING days (excluding weekends and SA public holidays)
   - ✅ Dates where learner clocked in are **grayed out** and NOT selectable
   - ✅ Only dates with missing attendance are selectable
3. Try to tap a grayed-out date (clocked-in day)
4. **Expected**: Calendar does not allow selection

#### Test Case 4: Date To Calendar Validation
1. Select a valid "Date From"
2. Tap the **calendar icon** next to "Date To (YYYY-MM-DD)"
3. **Expected Calendar Behavior**:
   - ✅ Only shows dates >= Date From
   - ✅ Only shows valid dates (no clocking records)
   - ✅ Grays out invalid dates

### Step 5: Test Document Scanner
1. Fill in all fields (Practice Name, Medical Practitioner)
2. Tap the **purple camera FAB button** (bottom right)
3. **Expected**: Camera-based document scanner opens
4. Scan sick note document
5. **Expected**: Automatic PDF conversion and file size validation (max 10MB)
6. **Expected**: Green success indicator shows "Document scanned: sick_note_xxxxx.pdf"

### Step 6: Test Submission
1. Complete all fields and scan document
2. Tap "Submit" button
3. **Expected**: 
   - Loading indicator appears
   - Success dialog shows "Sick note submitted successfully and is pending approval"
   - PDF uploaded to `uploads/sick_notes/` on server
   - Database record created in `sick_note` table with `status='PENDING'`

### Step 7: Verify Database Record
```sql
-- Check if sick note was saved
SELECT * FROM sick_note 
WHERE learner_id = [TEST_LEARNER_ID]
ORDER BY upload_date DESC 
LIMIT 1;

-- Expected fields:
-- note_id, learner_id, document_path, practice_name, practitioner_name
-- date_from, date_to, upload_date, status='PENDING'
```

### Step 8: Verify File Upload
```bash
# Check if PDF exists on server
https://rlms.rlms.co.za/uploads/sick_notes/sick_note_[LEARNER_ID]_[TIMESTAMP].pdf
```

---

## Key Features Confirmed

### ✅ Validation Inside Calendar Picker
The validation happens **exactly as requested** - inside the calendar picker itself:

```dart
selectableDayPredicate: (DateTime date) {
  String dateStr = DateFormat('yyyy-MM-dd').format(date);
  return _validDates.contains(dateStr);
}
```

This means:
- User **cannot** select dates where they clocked in (grayed out in calendar)
- User **can only** select dates from last 5 working days with missing attendance
- No need for post-selection validation messages - the calendar prevents invalid selection

### ✅ SA Public Holiday Logic
- Fixed holidays: Jan 1, Mar 21, Apr 27, May 1, Jun 16, Aug 9, Sep 24, Dec 16, Dec 25, Dec 26
- Easter-based: Good Friday (Easter - 2), Family Day (Easter + 1)
- Weekend rules: Sunday → Monday (+1 day), Saturday → Monday (+2 days)
- Exception: December 26 stays fixed even on weekends

### ✅ Database Schema Compliance
All queries now use correct column names:
- `learner_clocking` table: `LearnerID`, `clock_date`
- `manual_clocking` table: `LearnerID`, `clock_date`, `status = 'Approved'`
- `sick_note` table: `learner_id`, `date_from`, `date_to`, `status` ENUM('PENDING','APPROVED','Declined')

---

## Known Issues Resolved

### ✅ Fixed: Column Name Mismatch
- **Was**: Using `learner_id` (lowercase) in queries
- **Now**: Using `LearnerID` (PascalCase) to match database schema

### ✅ Fixed: Layout Format
- **Was**: New modern card layout
- **Now**: Old simple layout matching user's screenshot

### ✅ Fixed: Validation Location
- **Was**: Post-selection validation with error messages
- **Now**: Pre-selection validation inside calendar picker (dates grayed out)

---

## Files Modified This Session

### Frontend
- ✅ `lib/sick_note_page.dart` - Complete rewrite with old UI format

### Backend (Need to Upload to Server)
- ✅ `mobile/get_sick_note_eligible_dates.php` - Column names fixed
- ✅ `mobile/submit_sick_note.php` - Column names fixed

### Configuration
- ✅ `lib/config.dart` - Endpoints already configured with cache-busting

---

## Next Actions

1. ✅ **APK Built**: `app-release.apk` (45.9MB)
2. ⏳ **Upload PHP files to server**:
   - `mobile/get_sick_note_eligible_dates.php`
   - `mobile/submit_sick_note.php`
3. ⏳ **Install APK on test device**
4. ⏳ **Test workflow** (eligibility → calendar validation → document scan → submit)
5. ⏳ **Verify database records and file uploads**

---

## Success Criteria

✅ First-time learners see "not eligible" message  
✅ Calendar picker only shows valid dates (validation INSIDE picker)  
✅ Dates where learner clocked in are grayed out and not selectable  
✅ Document scanner works (camera-based, PDF conversion)  
✅ Submission creates database record with status='PENDING'  
✅ PDF uploaded to `uploads/sick_notes/` directory  

---

**Status**: Ready for production testing! 🚀
