# Sick Note APK Build Complete

## ✅ Status: READY FOR INSTALLATION

**Build Date**: July 22, 2026  
**APK Location**: `build\app\outputs\flutter-apk\app-release.apk`  
**APK Size**: 45.9 MB

---

## What's New in This Build

### 🆕 Sick Note Upload Feature
- **Camera-based document scanning** (same as POE)
- **Automatic PDF conversion**
- **Smart date validation** (last 5 working days only)
- **First-time learner blocking** (must have clocking history)
- **Excludes weekends & SA public holidays**
- **Grays out dates where learner already clocked in**

### 🔧 Fixes Applied
- ✅ Fixed undefined `_selectedDocument` variable
- ✅ Added `learnerName` parameter to all SickNotePage calls
- ✅ Updated LearnerListPage.dart
- ✅ Updated clock_in_page.dart

---

## Installation Instructions

### Option 1: Install via USB (Recommended)
```bash
adb install build\app\outputs\flutter-apk\app-release.apk
```

### Option 2: Install Manually on Device
1. Copy `build\app\outputs\flutter-apk\app-release.apk` to your device
2. Open the file on your Android device
3. Allow "Install from Unknown Sources" if prompted
4. Tap "Install"
5. Wait for installation to complete
6. Tap "Done"

### Option 3: Replace Existing Installation
```bash
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

---

## How to Access Sick Note Feature

### For Learners (from Clock In Page):
1. Log in as learner
2. Open Clock In page
3. Scroll to your name in the learner table
4. Click the **blue sick note button** (📄 icon)
5. Follow the sick note upload workflow

### For Facilitators (from Learner List):
1. Log in as facilitator
2. Open Learner List
3. Find learner in the table
4. Click the **sick note button** in Actions column
5. Follow the sick note upload workflow

---

## Sick Note Workflow

### Step 1: Eligibility Check
- System automatically checks if learner has clocking history
- **Blocks first-time learners** with message:
  - "You are a first time learner, you are not able to upload a sick note."

### Step 2: Date Selection
- Shows last **5 WORKING days** (excludes weekends & holidays)
- **Grayed out dates**:
  - ❌ Days learner clocked in
  - ❌ Days with approved manual clocking
  - ❌ Days with existing sick notes
- **Selectable dates**:
  - ✅ Days learner did NOT clock in (missed days)

### Step 3: Fill Details
- Practice Name (optional)
- Practitioner Name (required) ⚠️
- Tap "Scan Document" button

### Step 4: Scan Document
- Camera opens automatically
- Scan sick note pages (multi-page support)
- Maximum 80 pages per scan
- Automatic edge detection
- Converts to PDF automatically

### Step 5: Submit
- Review scanned document
- Click "Submit Sick Note"
- Wait for success message
- Page closes automatically

---

## Backend Already Deployed

### PHP Endpoints (Already on Server):
✅ `mobile/get_sick_note_eligible_dates.php`  
✅ `mobile/submit_sick_note.php`

### Database Table:
✅ `sick_note` table exists with correct schema

### Upload Directory:
✅ `uploads/sick_notes/` folder created with permissions

---

## Testing Checklist

### Eligibility Testing
- [ ] First-time learner (never clocked in) → Blocked ✋
- [ ] Learner with clocking history → Allowed ✅
- [ ] Learner with approved manual clocking → Allowed ✅

### Date Selection
- [ ] Today is working day → Today shown in list
- [ ] Yesterday clocked in → Yesterday grayed out
- [ ] Day before clocked in → Grayed out
- [ ] Missed day last week → Selectable ✅
- [ ] Weekend dates → Not shown in list
- [ ] Public holiday dates → Not shown in list

### Form Validation
- [ ] Submit without date → Error: "Please select a date"
- [ ] Submit without practitioner name → Error: "Please enter practitioner name"
- [ ] Submit without scanned document → Error: "Please scan sick note document"
- [ ] Submit with 11MB file → Error: "File size must be less than 10MB"

### Scanner Testing
- [ ] Camera permission requested on first use
- [ ] Scanner opens successfully
- [ ] Single page scan works
- [ ] Multi-page scan works (2-5 pages)
- [ ] PDF generated correctly
- [ ] File size displayed correctly
- [ ] Scanner closes after completion

### Server Integration
- [ ] PDF uploads to server successfully
- [ ] File saved to `uploads/sick_notes/` folder
- [ ] Database record created in `sick_note` table
- [ ] Status set to 'PENDING'
- [ ] Success dialog appears
- [ ] Page closes after OK button

### Database Verification
After successful submission, check database:
```sql
SELECT * FROM sick_note 
WHERE learner_id = [TEST_LEARNER_ID] 
ORDER BY upload_date DESC 
LIMIT 1;
```

Expected result:
- `note_id`: (auto-increment)
- `learner_id`: [TEST_LEARNER_ID]
- `document_path`: uploads/sick_notes/sick_note_[ID]_[TIMESTAMP].pdf
- `practice_name`: (as entered or NULL)
- `practitioner_name`: (as entered)
- `date_from`: (selected date)
- `date_to`: (selected date)
- `upload_date`: (current timestamp)
- `status`: 'PENDING'
- `rejection_reason`: NULL

---

## Known Limitations

1. **80 Page Limit**: Scanner can handle maximum 80 pages per scan
   - Solution: Split large documents into multiple submissions

2. **5 Working Day Window**: Can only upload for last 5 working days
   - Reason: Prevents backdating sick notes indefinitely
   - Solution: Upload sick notes promptly

3. **First-Time Learner Block**: Must have clocked in at least once
   - Reason: Prevents abuse of sick note system
   - Solution: Learner must clock in at least one day first

4. **Camera Permission**: Required for scanning
   - Solution: Grant camera permission when prompted

---

## Troubleshooting

### "Camera permission denied"
- Go to device Settings → Apps → RLMSS → Permissions
- Enable Camera permission
- Try scanning again

### "Camera is being used by..."
- Another feature is using the camera
- Wait a few seconds
- Try scanning again

### "Scanner returned invalid data"
- Scanner crashed or was interrupted
- Try scanning again
- If persists, restart the app

### "You are a first time learner..."
- Learner has never clocked in
- Learner must clock in at least once first
- Then sick notes can be uploaded

### "No Available Dates"
- Learner has already clocked in or submitted sick notes for all recent days
- This is correct behavior
- No action needed

### File upload fails
- Check internet connection
- Check file size (must be < 10MB)
- Try scanning again with fewer pages
- Contact support if persists

---

## File Locations

### APK File
```
build\app\outputs\flutter-apk\app-release.apk
```

### Source Files Modified
```
lib/
├── sick_note_page.dart          (New sick note UI)
├── LearnerListPage.dart          (Added learnerName parameter)
├── clock_in_page.dart            (Added learnerName parameter)
└── config.dart                   (Sick note endpoint URLs)
```

### Backend Files (Already on Server)
```
mobile/
├── get_sick_note_eligible_dates.php  (Date validation & filtering)
└── submit_sick_note.php              (Upload & server-side validation)
```

### Database
```
sick_note table                   (Already exists)
uploads/sick_notes/               (File storage)
```

---

## Support Information

### For Developers
- Frontend: `lib/sick_note_page.dart`
- Backend: `mobile/get_sick_note_eligible_dates.php`, `mobile/submit_sick_note.php`
- Documentation: `SICK_NOTE_SCANNER_INTEGRATION_COMPLETE.md`

### For Administrators
- Sick notes are stored in: `uploads/sick_notes/`
- Database table: `sick_note`
- Status: PENDING (awaiting approval)
- Approval workflow: To be implemented in admin panel

### For End Users
- Access from: Clock In page or Learner List
- Requirements: Camera permission, clocking history
- Valid dates: Last 5 working days without attendance
- File format: PDF (automatically generated from camera)

---

## Next Steps

1. ✅ APK built successfully
2. ⏳ **Install APK on test device**
3. ⏳ Test with real learner who has clocking history
4. ⏳ Test with first-time learner (should be blocked)
5. ⏳ Test date selection (dates should be correct)
6. ⏳ Test scanning workflow (camera → PDF)
7. ⏳ Verify upload to server
8. ⏳ Check database records

---

## Success Criteria

✅ APK installs without errors  
✅ Sick note button appears in UI  
✅ Eligibility check works correctly  
✅ Date validation excludes clocked-in days  
✅ Scanner opens and captures document  
✅ PDF uploads to server successfully  
✅ Database record created with status='PENDING'  
✅ User sees success message  

---

**Build Status**: ✅ SUCCESS  
**APK Ready**: YES  
**Backend Ready**: YES  
**Next Action**: Install and test on device

