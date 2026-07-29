# Sick Note Upload Date-Picker Implementation

## Overview
Complete server-side date validation system for sick note uploads with SA public holiday support and strict eligibility rules.

---

## Database Schema

### sick_note Table
```sql
CREATE TABLE `sick_note` (
  `note_id` int(11) NOT NULL AUTO_INCREMENT,
  `learner_id` int(11) DEFAULT NULL,
  `document_path` varchar(255) DEFAULT NULL,
  `practice_name` varchar(255) DEFAULT NULL,
  `medical_practitioner` varchar(100) DEFAULT NULL,
  `practitioner_name` varchar(255) NOT NULL,
  `date_from` date DEFAULT NULL,
  `date_to` date DEFAULT NULL,
  `upload_date` datetime DEFAULT current_timestamp(),
  `status` enum('PENDING','APPROVED','Declined') NOT NULL DEFAULT 'PENDING',
  `rejection_reason` text DEFAULT NULL,
  PRIMARY KEY (`note_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### Related Tables
- **learner_clocking**: Clock-in records (columns: `learner_id`, `timestamp`)
- **manual_clocking**: Manual attendance records (columns: `learner_id`, `date`, `approval_status`)
- **learnerdetails**: Learner master table (column: `learner_id`)

---

## API Endpoints

### 1. Get Eligible Dates
**Endpoint**: `mobile/get_sick_note_eligible_dates.php`  
**Method**: POST  
**Parameters**:
- `learner_id` (int, required)

**Response**:
```json
{
  "status": "success",
  "is_eligible": true,
  "dates": [
    {
      "date": "2026-07-22",
      "formatted": "Tue, 22 Jul 2026",
      "is_selectable": true
    },
    {
      "date": "2026-07-21",
      "formatted": "Mon, 21 Jul 2026",
      "is_selectable": false,
      "reason": "clocked_in"
    }
  ],
  "candidate_dates": ["2026-07-22", "2026-07-21", "2026-07-18", "2026-07-17", "2026-07-16"],
  "message": "Eligible to upload sick note"
}
```

**Error Response (Not Eligible)**:
```json
{
  "status": "error",
  "message": "You are a first time learner, you are not able to upload a sick note.",
  "is_eligible": false,
  "reason": "no_clocking_history"
}
```

---

### 2. Submit Sick Note
**Endpoint**: `mobile/submit_sick_note.php`  
**Method**: POST (multipart/form-data)  
**Parameters**:
- `learner_id` (int, required)
- `date_from` (date Y-m-d, required)
- `date_to` (date Y-m-d, optional - defaults to date_from)
- `practice_name` (string, optional)
- `practitioner_name` (string, required)
- `document` (file, required - PDF/JPG/JPEG/PNG)

**Success Response**:
```json
{
  "status": "success",
  "message": "Sick note submitted successfully and is pending approval.",
  "note_id": 264,
  "date_from": "2026-07-22",
  "date_to": "2026-07-22",
  "document_path": "uploads/sick_notes/sick_note_12345_20260722_143052.pdf"
}
```

**Error Responses**:

**Not Eligible**:
```json
{
  "status": "error",
  "message": "You are a first time learner, you are not able to upload a sick note.",
  "error_code": "NOT_ELIGIBLE"
}
```

**Invalid Date Range**:
```json
{
  "status": "error",
  "message": "Selected date is not within the last 5 working days. Please select a valid date.",
  "error_code": "INVALID_DATE_RANGE",
  "valid_dates": ["2026-07-22", "2026-07-21", "2026-07-18", "2026-07-17", "2026-07-16"],
  "submitted_date": "2026-07-15"
}
```

**Already Clocked In**:
```json
{
  "status": "error",
  "message": "You already clocked in on this date. Sick note cannot be submitted.",
  "error_code": "ALREADY_CLOCKED_IN",
  "date": "2026-07-22"
}
```

**Approved Manual Clocking Exists**:
```json
{
  "status": "error",
  "message": "You have an approved manual clocking record on this date. Sick note cannot be submitted.",
  "error_code": "APPROVED_MANUAL_EXISTS",
  "date": "2026-07-22"
}
```

**Sick Note Already Exists**:
```json
{
  "status": "error",
  "message": "A sick note already exists for this date.",
  "error_code": "SICK_NOTE_EXISTS",
  "date": "2026-07-22"
}
```

---

## Business Logic

### STEP 1: Eligibility Gate
Before showing the sick note form, the system checks if the learner has:
- **Option A**: At least one row in `learner_clocking` table, OR
- **Option B**: At least one row in `manual_clocking` with approved status

**If neither exists**: Block upload with message:  
_"You are a first time learner, you are not able to upload a sick note."_

---

### STEP 2: Build Candidate Date Range
Computes the **last 5 WORKING days** ending today (inclusive), excluding:
- Saturdays (day 6)
- Sundays (day 0)
- SA Public Holidays

**SA Public Holiday Rules**:
- Fixed holidays fall on Sunday → moved to Monday (+1 day)
- Fixed holidays fall on Saturday → moved to Monday (+2 days)
- **Exception**: December 26 stays fixed even on weekends
- Easter-based holidays: Good Friday (Easter - 2 days), Family Day (Easter + 1 day)

**Example**: If today is Wednesday, the system may need to check back ~10 calendar days to find 5 working days.

---

### STEP 3: Filter to "Missing Attendance" Days
For each candidate date, the date is **SELECTABLE** only if:
1. ❌ **NOT EXISTS** in `learner_clocking` for this learner_id on that date
2. ❌ **NOT EXISTS** in `manual_clocking` with approved status on that date
3. ❌ **NOT EXISTS** in `sick_note` (date falls within date_from to date_to range)

**If learner DID clock in or HAS approved manual clocking**: Date is **grayed out** (not selectable).

---

### STEP 4: Server-Side Validation on Submit
1. ✅ **Re-check eligibility gate** (learner has clocking history)
2. ✅ **Re-check date is within current 5-working-day window** (server-side recomputation)
3. ✅ **Re-check no attendance record exists** for submitted date
4. ✅ **Validate document upload** (PDF/JPG/JPEG/PNG, max size, successful upload)
5. ✅ **Insert into sick_note table** with status='PENDING'

---

## SA Public Holidays 2024-2027

### Fixed Holidays
| Date | Holiday Name |
|------|--------------|
| Jan 1 | New Year's Day |
| Mar 21 | Human Rights Day |
| Apr 27 | Freedom Day |
| May 1 | Workers' Day |
| Jun 16 | Youth Day |
| Aug 9 | National Women's Day |
| Sep 24 | Heritage Day |
| Dec 16 | Day of Reconciliation |
| Dec 25 | Christmas Day |
| Dec 26 | Day of Goodwill (stays fixed) |

### Easter-Based Holidays (Variable)
- **Good Friday**: Easter - 2 days
- **Family Day**: Easter + 1 day

### Weekend Rules
- If holiday falls on **Sunday**: Observed on **Monday**
- If holiday falls on **Saturday**: Observed on **Monday**
- **Exception**: December 26 never moves

---

## File Structure

```
mobile/
├── get_sick_note_eligible_dates.php  # Get selectable dates
├── submit_sick_note.php              # Submit sick note with validation
└── connection.php                     # Database connection

uploads/
└── sick_notes/                        # Sick note documents
    └── sick_note_{learnerID}_{timestamp}.{ext}

check_sick_note_schema.php             # Schema discovery tool
```

---

## Testing Checklist

### Eligibility Testing
- [ ] First-time learner (no clocking history) → blocked
- [ ] Learner with learner_clocking record → allowed
- [ ] Learner with approved manual_clocking → allowed
- [ ] Learner with both → allowed

### Date Range Testing
- [ ] Today is a working day → today included in selectable dates
- [ ] Today is Saturday → last Friday included
- [ ] Today is Sunday → last Friday included
- [ ] Public holiday in last 5 days → skipped correctly
- [ ] Long weekend (Fri+Mon holiday) → correct working days computed

### Attendance Overlap Testing
- [ ] Date with clocking record → grayed out
- [ ] Date with approved manual clocking → grayed out
- [ ] Date with pending manual clocking → selectable
- [ ] Date with declined manual clocking → selectable
- [ ] Date with existing sick note → grayed out
- [ ] Date with no records → selectable

### Submission Validation Testing
- [ ] Submit date outside 5-working-day window → rejected
- [ ] Submit date with existing attendance → rejected
- [ ] Submit without document → rejected
- [ ] Submit with invalid file type (exe, doc) → rejected
- [ ] Submit valid sick note → success, status=PENDING

### File Upload Testing
- [ ] PDF upload → success
- [ ] JPG/JPEG upload → success
- [ ] PNG upload → success
- [ ] File too large → rejected (configure max size)
- [ ] Corrupted file → rejected
- [ ] Duplicate filename handling → unique timestamp

---

## Flutter/Frontend Integration

### Step 1: Check Eligibility
```dart
final response = await http.post(
  Uri.parse('${AppConfig.baseUrl}/get_sick_note_eligible_dates.php'),
  body: {'learner_id': learnerId.toString()},
);

final data = jsonDecode(response.body);
if (data['is_eligible'] == false) {
  showDialog(...); // Show "first time learner" message
  return;
}
```

### Step 2: Render Date Picker
```dart
List<DateTime> selectableDates = [];
for (var dateObj in data['dates']) {
  if (dateObj['is_selectable'] == true) {
    selectableDates.add(DateTime.parse(dateObj['date']));
  }
}

// Use selectableDates in date picker with grayed-out non-selectable dates
```

### Step 3: Submit Sick Note
```dart
var request = http.MultipartRequest(
  'POST',
  Uri.parse('${AppConfig.baseUrl}/submit_sick_note.php'),
);

request.fields['learner_id'] = learnerId.toString();
request.fields['date_from'] = selectedDate.toString();
request.fields['practitioner_name'] = practitionerName;
request.fields['practice_name'] = practiceName;

request.files.add(await http.MultipartFile.fromPath(
  'document',
  sickNoteFilePath,
));

final response = await request.send();
final responseData = await response.stream.bytesToString();
final result = jsonDecode(responseData);

if (result['status'] == 'success') {
  showSuccessDialog(result['message']);
} else {
  showErrorDialog(result['message']);
}
```

---

## Security Considerations

### File Upload Security
- ✅ File type whitelist (PDF, JPG, JPEG, PNG only)
- ✅ Unique filename generation (prevents overwrites)
- ✅ File size limit (configure in php.ini or code)
- ✅ Upload directory outside web root (recommended)
- ✅ Validate actual file content, not just extension

### SQL Injection Prevention
- ✅ All queries use prepared statements with bind_param
- ✅ No direct string concatenation in queries

### Authorization
- ⚠️ **TODO**: Add session/token validation to ensure learner_id matches logged-in user
- ⚠️ **TODO**: Prevent learners from submitting sick notes for other learners

---

## Admin/Manager Features (Future)

### Sick Note Approval Workflow
1. Learner submits sick note → status = 'PENDING'
2. Manager/Admin reviews document
3. Manager approves → status = 'APPROVED' (counts as attendance)
4. Manager declines → status = 'Declined', `rejection_reason` filled

### Query Approved Sick Notes
```sql
SELECT date_from, date_to, status
FROM sick_note
WHERE learner_id = ?
AND status = 'APPROVED'
AND ? BETWEEN date_from AND date_to;
```

---

## Error Codes Reference

| Error Code | Meaning | User Action |
|------------|---------|-------------|
| `INVALID_LEARNER_ID` | Learner ID is missing or invalid | Contact support |
| `MISSING_DATE` | Date not provided | Select a date |
| `NOT_ELIGIBLE` | First-time learner with no clocking history | Clock in first before uploading sick notes |
| `INVALID_DATE_RANGE` | Date outside last 5 working days | Select a date from the list |
| `ALREADY_CLOCKED_IN` | Attendance record exists for this date | Cannot upload sick note for attended days |
| `APPROVED_MANUAL_EXISTS` | Approved manual clocking exists | Cannot upload sick note for manually approved days |
| `SICK_NOTE_EXISTS` | Sick note already uploaded for this date | View existing sick note status |
| `DOCUMENT_REQUIRED` | No file uploaded | Attach sick note document |
| `INVALID_FILE_TYPE` | Wrong file format | Upload PDF, JPG, JPEG, or PNG only |
| `UPLOAD_FAILED` | File upload error | Try again or check file size |
| `DATABASE_ERROR` | Database insert failed | Contact support |
| `SERVER_ERROR` | Unexpected server error | Contact support |

---

## Config Update Required

Add to `lib/config.dart`:

```dart
// Sick Note Endpoints
static String get getSickNoteEligibleDatesUrl => '$baseUrl/get_sick_note_eligible_dates.php';
static String get submitSickNoteUrl => '$baseUrl/submit_sick_note.php';
```

---

## Deployment Steps

1. ✅ Upload `mobile/get_sick_note_eligible_dates.php` to server
2. ✅ Upload `mobile/submit_sick_note.php` to server
3. ✅ Create `uploads/sick_notes/` directory with write permissions (755)
4. ✅ Update `lib/config.dart` with endpoint URLs
5. ✅ Test eligibility check with different learner scenarios
6. ✅ Test date picker with various date scenarios
7. ✅ Test file upload with different file types
8. ✅ Test server-side validation rejects invalid submissions
9. ✅ Rebuild Flutter APK
10. ✅ Test on production with real learner data

---

## Future Enhancements

### Date Range Support
- Allow sick notes for multiple consecutive days (date_from to date_to)
- Validate all days in range are working days without attendance

### Notification System
- Email/SMS notification when sick note status changes
- Reminder if sick note pending for >24 hours

### Document Management
- View uploaded sick note document in app
- Download sick note for records
- Replace/update sick note if declined

### Reporting
- Admin dashboard: Pending sick notes count
- Monthly sick note report per learner
- Attendance summary including sick notes

---

**Implementation Date**: July 22, 2026  
**Status**: Ready for Testing  
**Next Steps**: Flutter UI implementation + endpoint integration
