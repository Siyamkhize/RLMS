# Sick Note Scanner Integration Complete

## Status: ✅ READY FOR TESTING

Successfully integrated the existing document scanning workflow into the sick note upload feature.

---

## Changes Made

### 1. Replaced File Picker with Document Scanner

**BEFORE** (File Picker):
- Used `file_picker` package
- Allowed PDF, JPG, JPEG, PNG files
- Manual file selection from device storage

**AFTER** (Document Scanner):
- Uses `flutter_doc_scanner` package (already in project)
- Camera-based document scanning
- Automatic PDF conversion
- Multi-page support (max 80 pages)
- Edge detection and image enhancement

---

## Updated Files

### Frontend (Flutter)
1. ✅ **`lib/sick_note_page.dart`**
   - Replaced `FilePicker` with `FlutterDocScanner`
   - Added `CameraResourceManager` for camera access control
   - Added `_scanDocument()` method (same as POE scanning)
   - Updated UI to show "Scan Document" instead of "Upload Document"
   - Added scanning progress indicator
   - Camera permission handling
   - Proper cleanup in dispose

### Backend (PHP)
2. ✅ **`mobile/submit_sick_note.php`**
   - Updated file validation to accept PDF only
   - Updated error message: "Only PDF files are allowed (scanned documents)"

### Dependencies
3. ✅ **`pubspec.yaml`**
   - Removed `file_picker` dependency (not needed)
   - Already has `flutter_doc_scanner`, `permission_handler`, `intl`, `http`

---

## How It Works

### User Workflow
1. **Navigate to Sick Note Page**
   - Page checks eligibility (learner must have clocking history)
   - Loads available dates (last 5 working days without attendance)

2. **Select Date**
   - User taps on available date card
   - Selected date shows green background

3. **Fill Form**
   - Practice Name (optional)
   - Practitioner Name (required)

4. **Scan Document**
   - User taps "Tap to Scan Document" card
   - Camera permission requested if not granted
   - Document scanner opens (same as POE scanning)
   - User scans sick note pages (max 80 pages)
   - Scanner converts to PDF automatically
   - Success message: "PDF document scanned successfully!"

5. **Submit**
   - Client-side validation runs
   - PDF uploaded to server
   - Server validates date, eligibility, file
   - Success dialog appears
   - Page closes automatically

---

## Technical Details

### Camera Resource Management
```dart
final CameraResourceManager _cameraManager = CameraResourceManager();
```
- Prevents camera conflicts with other features
- Requests camera access before scanning
- Releases camera access after scanning
- Marks ML Kit scanner as active/inactive

### Scanning Implementation
```dart
Future<void> _scanDocument() async {
  // Check camera permissions
  // Request camera access
  // Mark ML Kit scanner active
  // Launch FlutterDocScanner
  // Resolve PDF file from scanner result
  // Validate PDF is readable
  // Store scanned PDF
  // Release camera and cleanup
}
```

### File Validation
**Client-Side**:
- Date selected ✓
- Practitioner name filled ✓
- Document scanned ✓
- File size ≤ 10MB ✓

**Server-Side**:
- PDF extension only ✓
- Eligibility check ✓
- Date in last 5 working days ✓
- No existing attendance ✓
- File uploaded successfully ✓

---

## Scanner Features

### Visual Feedback
- **Before Scanning**: Blue scanner icon + "Tap to Scan Document"
- **During Scanning**: Circular progress + "Scanner opening..."
- **After Scanning**: Green check icon + filename + file size

### Scanner Information Card
```
📄 Uses camera to scan document
✅ Converts to PDF automatically
⚠️ Maximum 80 pages per scan
```

### Error Handling
- Camera permission denied → Error snackbar
- Camera busy → Error snackbar with user info
- Scanner returns invalid data → Error snackbar
- File unreadable → Error snackbar
- All errors show retry-able message

---

## Integration with Existing Workflow

The sick note scanner uses the **exact same scanning logic** as:
- ✅ POE Document Scanner (`lib/poe_document_scanner.dart`)
- ✅ Camera Scan Page (`lib/CameraScanPage.dart`)
- ✅ Pothole Checklist (`lib/potholeChecklistpage.dart`)

This ensures:
- Consistent user experience
- Proven scanning stability
- Shared camera resource management
- Same 80-page limit
- Same error handling patterns

---

## Testing Checklist

### Permissions
- [ ] Camera permission prompt appears on first use
- [ ] Scanner works after granting permission
- [ ] Error shown if permission denied
- [ ] Permission remembered for subsequent scans

### Scanning
- [ ] Scanner opens successfully
- [ ] Single page scan works
- [ ] Multi-page scan works (2-5 pages)
- [ ] Large scan works (20+ pages)
- [ ] PDF generated correctly
- [ ] File size displayed correctly

### Camera Management
- [ ] Camera released after scanning
- [ ] No conflicts with other camera features
- [ ] Scanning works after app resume
- [ ] Cleanup works when page closed mid-scan

### Form Validation
- [ ] Cannot submit without date
- [ ] Cannot submit without practitioner name
- [ ] Cannot submit without scanned document
- [ ] 10MB limit enforced (if possible to test)

### Server Integration
- [ ] PDF uploaded successfully
- [ ] File saved to `uploads/sick_notes/` folder
- [ ] Database record created
- [ ] Status set to PENDING
- [ ] Success dialog appears
- [ ] Page closes after OK

---

## File Locations

### Frontend Files
```
lib/
├── sick_note_page.dart          (Main sick note UI with scanner)
├── config.dart                   (API endpoint URLs)
├── services/
│   └── camera_resource_manager.dart  (Camera access control)
└── utils/
    └── scanner_pdf_resolver.dart      (PDF file resolution helper)
```

### Backend Files
```
mobile/
├── get_sick_note_eligible_dates.php  (Eligibility check + dates)
└── submit_sick_note.php              (PDF upload + validation)
```

### Uploaded Files
```
uploads/
└── sick_notes/
    └── sick_note_{learnerID}_{timestamp}.pdf
```

---

## API Endpoints

### Get Eligible Dates
**URL**: `https://rlms.rlms.co.za/mobile/get_sick_note_eligible_dates.php`
**Method**: POST
**Parameters**: `learner_id`

### Submit Sick Note
**URL**: `https://rlms.rlms.co.za/mobile/submit_sick_note.php`
**Method**: POST (multipart/form-data)
**Parameters**: 
- `learner_id`
- `date_from`
- `date_to`
- `practice_name` (optional)
- `practitioner_name` (required)
- `document` (PDF file)

---

## Next Steps

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Build APK
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### 3. Test on Device
- Install APK
- Navigate to Sick Note page
- Test full workflow with camera
- Verify PDF uploads to server
- Check database records

### 4. Production Deployment
- Backend files already on server
- Upload directory exists with permissions
- Test with real learner IDs
- Monitor server logs for errors

---

## Differences from Original Implementation

| Feature | Original (File Picker) | New (Document Scanner) |
|---------|----------------------|----------------------|
| Input Method | File selection | Camera scanning |
| File Types | PDF/JPG/JPEG/PNG | PDF only |
| Source | Device storage | Camera capture |
| Multi-page | Manual merge | Automatic |
| Edge Detection | No | Yes |
| Image Enhancement | No | Yes |
| User Experience | File browser | Camera UI |
| Consistency | Different from POE | Same as POE |

---

## Benefits of Scanner Integration

1. **Consistency**: Same workflow as POE and other scanning features
2. **Quality**: Automatic edge detection and image enhancement
3. **Simplicity**: No need to merge multiple files
4. **Mobile-First**: Camera is more natural on mobile devices
5. **Proven**: Uses existing, tested scanning infrastructure
6. **Resource Safe**: Shares camera management with other features

---

## User Instructions

### For Learners:
1. Open sick note page from your dashboard
2. Select the date you were sick
3. Fill in doctor/clinic details
4. Tap "Tap to Scan Document"
5. Allow camera permission if prompted
6. Scan your sick note (multiple pages OK)
7. Tap checkmark when done scanning
8. Verify the document was scanned
9. Tap "Submit Sick Note"
10. Wait for success message

### Tips:
- Ensure good lighting when scanning
- Hold phone steady over document
- Scanner automatically detects edges
- You can scan up to 80 pages at once
- File will be converted to PDF automatically

---

**Implementation Date**: July 22, 2026  
**Status**: ✅ Complete - Ready for Testing  
**Next**: Build APK and test on device

