# Sick Note Frontend Implementation Complete

## Status: ✅ READY FOR TESTING

All backend and frontend components have been implemented with comprehensive validation.

---

## Files Created/Modified

### Backend PHP Files
1. ✅ **`mobile/get_sick_note_eligible_dates.php`** - Returns eligible dates for sick note upload
2. ✅ **`mobile/submit_sick_note.php`** - Handles sick note submission with validation
3. ✅ **`check_sick_note_schema.php`** - Schema discovery tool

### Frontend Flutter Files
4. ✅ **`lib/sick_note_page.dart`** - Complete UI with date picker and validation
5. ✅ **`lib/config.dart`** - Updated with endpoint URLs

### Documentation
6. ✅ **`SICK_NOTE_DATE_PICKER_IMPLEMENTATION.md`** - Complete technical documentation
7. ✅ **`SICK_NOTE_FRONTEND_IMPLEMENTATION_COMPLETE.md`** - This file

---

## Frontend Validation Features

### 1. Eligibility Check (On Page Load)
```dart
- Calls mobile/get_sick_note_eligible_dates.php
- Checks if learner has clocking history
- Blocks access if first-time learner
- Shows clear error message
```

**First-Time Learner Block:**
- Icon: Red block icon
- Message: "You are a first time learner, you are not able to upload a sick note."
- Action: "Go Back" button

---

### 2. Date Selection Validation
```dart
- Only shows last 5 working days (from server)
- Grays out dates where learner already clocked in
- Grays out dates with approved manual clocking
- Grays out dates with existing sick notes
- Visual feedback: Green selection with white text
- Client-side validation: Must select a date
```

**No Available Dates:**
- Icon: Orange calendar icon
- Message: "No Available Dates"
- Explanation: "You have already clocked in or submitted sick notes for all recent working days."

---

### 3. Form Field Validation

#### Practice Name (Optional)
- Text field with hospital icon
- Placeholder: "e.g., City Medical Centre"
- No validation required

#### Practitioner Name (Required)
- Text field with medical services icon
- Marked with asterisk (*)
- Placeholder: "e.g., Dr. Smith"
- Client validation: Cannot be empty
- Error shown in SnackBar

#### Document Upload (Required)
- Card with upload icon
- Changes to green checkmark when file selected
- Shows selected filename
- Accepted formats: PDF, JPG, JPEG, PNG
- Max file size: 10MB
- Client validation: 
  - File must be selected
  - File size check before upload
- Error shown in SnackBar

---

### 4. Submission Validation

**Client-Side Checks:**
1. ✅ Date selected
2. ✅ Practitioner name filled
3. ✅ Document attached
4. ✅ File size ≤ 10MB

**Server-Side Re-Validation:**
1. ✅ Learner eligibility check
2. ✅ Date within last 5 working days
3. ✅ No attendance record for selected date
4. ✅ Document successfully uploaded
5. ✅ Database insert successful

---

## UI/UX Features

### Loading States
- ✅ Initial loading: Circular progress + "Checking eligibility..."
- ✅ Submission loading: Button shows spinner, disabled
- ✅ Smooth transitions between states

### Visual Feedback
- ✅ Color-coded cards (green for learner info, blue for instructions)
- ✅ Selected date: Green background with white text
- ✅ Unselected dates: White with green border
- ✅ Document picker: Green checkmark when file selected
- ✅ Success dialog: Green check icon
- ✅ Error snackbars: Red background

### User Guidance
- ✅ Instructions card: "You can only upload sick notes for days you did not clock in within the last 5 working days."
- ✅ Field labels: Clear, descriptive
- ✅ Placeholders: Examples provided
- ✅ File format hint: "PDF, JPG, JPEG, PNG (Max 10MB)"

---

## Success Flow

1. **Page Load**
   - Shows loading spinner
   - Calls `get_sick_note_eligible_dates.php`
   - Displays eligible dates

2. **User Fills Form**
   - Selects date (visual feedback)
   - Enters practitioner name
   - Optionally enters practice name
   - Uploads document (green checkmark)

3. **User Clicks Submit**
   - Client validation runs
   - Button shows spinner
   - Form disabled during submission
   - Calls `submit_sick_note.php`

4. **Success**
   - Dialog appears with green check icon
   - Message: "Sick note submitted successfully and is pending approval."
   - User clicks OK → Dialog closes → Page closes
   - Returns to previous screen

---

## Error Handling

### Not Eligible Error
```
Screen: Center-aligned error view
Icon: Red block
Message: "You are a first time learner..."
Action: "Go Back" button
```

### No Available Dates Error
```
Screen: Center-aligned info view
Icon: Orange calendar
Message: "No Available Dates"
Action: "Go Back" button
```

### Form Validation Errors
```
Location: SnackBar (bottom)
Color: Orange
Duration: Default
Examples:
- "Please select a date"
- "Please enter practitioner name"
- "Please attach sick note document"
- "File size must be less than 10MB"
```

### Submission Errors
```
Location: SnackBar (bottom)
Color: Red
Duration: 4 seconds
Examples:
- "Selected date is not within the last 5 working days..."
- "You already clocked in on this date..."
- "A sick note already exists for this date."
- "Server error: 500"
```

### Connection Errors
```
Location: SnackBar
Color: Red
Example: "Connection error: SocketException..."
```

---

## Navigation

### Opening Sick Note Page
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SickNotePage(
      learnerID: learnerID,
      learnerName: learnerName,
    ),
  ),
);
```

### Closing Page
- After successful submission: Closes automatically
- "Go Back" button: Closes page
- AppBar back button: Closes page

---

## Dependencies Required

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  file_picker: ^6.0.0
  intl: ^0.18.0
```

Run:
```bash
flutter pub get
```

---

## Testing Checklist

### Eligibility Testing
- [ ] First-time learner (no clocking history) → Blocked
- [ ] Learner with learner_clocking record → Allowed
- [ ] Learner with approved manual_clocking → Allowed

### Date Selection Testing
- [ ] Today is working day → Today shown
- [ ] Last 5 working days shown correctly
- [ ] Dates with clocking not shown
- [ ] Dates with approved manual clocking not shown
- [ ] Dates with existing sick notes not shown
- [ ] Public holiday excluded correctly
- [ ] Weekend excluded correctly

### Form Validation Testing
- [ ] Submit without date → Error shown
- [ ] Submit without practitioner name → Error shown
- [ ] Submit without document → Error shown
- [ ] Submit with 15MB file → Error shown
- [ ] Submit with valid data → Success

### File Upload Testing
- [ ] PDF file → Accepted
- [ ] JPG file → Accepted
- [ ] PNG file → Accepted
- [ ] DOC file → Should be rejected by file picker
- [ ] 11MB PDF → Client rejects
- [ ] Filename displayed correctly

### Server Validation Testing
- [ ] Submit old date (>5 days) → Server rejects
- [ ] Submit date with attendance → Server rejects
- [ ] Submit duplicate sick note → Server rejects
- [ ] Valid submission → Success + status=PENDING

### UI/UX Testing
- [ ] Loading spinner shows during eligibility check
- [ ] Loading spinner shows during submission
- [ ] Date selection visual feedback works
- [ ] Document upload visual feedback works
- [ ] Success dialog appears and closes correctly
- [ ] Error messages clear and helpful
- [ ] Navigation works correctly

---

## Database Verification

After successful submission, check database:

```sql
SELECT * FROM sick_note 
WHERE learner_id = ? 
ORDER BY upload_date DESC 
LIMIT 1;
```

Expected result:
```
note_id: (auto-increment)
learner_id: (submitted ID)
document_path: uploads/sick_notes/sick_note_12345_20260722_143052.pdf
practice_name: (submitted or NULL)
practitioner_name: (submitted)
date_from: (selected date)
date_to: (selected date)
upload_date: (current timestamp)
status: PENDING
rejection_reason: NULL
```

---

## Production Deployment Steps

### 1. Upload Backend Files
```bash
# Upload to server
scp mobile/get_sick_note_eligible_dates.php user@server:/path/to/mobile/
scp mobile/submit_sick_note.php user@server:/path/to/mobile/
```

### 2. Create Upload Directory
```bash
# On server
mkdir -p /path/to/uploads/sick_notes
chmod 755 /path/to/uploads/sick_notes
```

### 3. Test Backend Endpoints
```bash
# Test eligibility endpoint
curl -X POST https://rlms.rlms.co.za/mobile/get_sick_note_eligible_dates.php \
  -d "learner_id=12345"

# Should return JSON with dates or error
```

### 4. Update Flutter Config
- Confirm `lib/config.dart` has correct endpoint URLs
- Confirm `AppConfig.baseUrl` points to production

### 5. Build APK
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### 6. Test on Device
- Install APK on test device
- Test with real learner IDs
- Verify dates load correctly
- Submit test sick note
- Verify in database

### 7. Monitor Logs
```bash
# Check PHP error logs
tail -f /var/log/apache2/error.log

# Check uploaded files
ls -lah /path/to/uploads/sick_notes/
```

---

## Future Enhancements

### Phase 2 Features
1. **View Sick Note History**
   - List of submitted sick notes
   - Status badges (Pending, Approved, Declined)
   - View uploaded document

2. **Date Range Support**
   - Select multiple consecutive days
   - Single sick note for date range

3. **Offline Support**
   - Save draft locally
   - Submit when online

4. **Push Notifications**
   - Notify when status changes
   - Reminder if pending >24 hours

5. **Document Preview**
   - View document before upload
   - Edit/replace before submission

---

## Error Codes Reference (for debugging)

| Code | Meaning | Solution |
|------|---------|----------|
| `INVALID_LEARNER_ID` | Learner ID missing/invalid | Check learner ID parameter |
| `NOT_ELIGIBLE` | No clocking history | Learner must clock in first |
| `INVALID_DATE_RANGE` | Date outside 5-day window | Select valid date |
| `ALREADY_CLOCKED_IN` | Attendance exists | Cannot upload for attended days |
| `APPROVED_MANUAL_EXISTS` | Manual clocking approved | Cannot upload for manually approved days |
| `SICK_NOTE_EXISTS` | Duplicate sick note | Already submitted for this date |
| `DOCUMENT_REQUIRED` | No file uploaded | Attach document |
| `INVALID_FILE_TYPE` | Wrong file format | Use PDF/JPG/PNG only |
| `UPLOAD_FAILED` | File upload error | Check file size/permissions |
| `DATABASE_ERROR` | Database insert failed | Check database/logs |

---

## Support Information

### For Developers
- Backend code: `mobile/get_sick_note_eligible_dates.php`, `mobile/submit_sick_note.php`
- Frontend code: `lib/sick_note_page.dart`
- Config: `lib/config.dart`
- Documentation: `SICK_NOTE_DATE_PICKER_IMPLEMENTATION.md`

### For Testers
- Test learner IDs: Get from production database
- Valid dates: Last 5 working days without attendance
- File formats: PDF (recommended), JPG, PNG
- Max file size: 10MB

### For End Users
- Access: From learner dashboard
- Requirements: Must have clocked in at least once
- Valid dates: Last 5 working days you missed
- Status: Shows as "Pending" until approved

---

**Implementation Date**: July 22, 2026  
**Status**: ✅ Complete and Ready for Testing  
**Next Step**: Deploy backend files → Build APK → Test on device
