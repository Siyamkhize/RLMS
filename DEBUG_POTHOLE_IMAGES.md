# Debug Pothole Evidence Images Not Appearing

## Problem
Images are being uploaded from the Flutter app but not appearing in the POE table on the server.

## Diagnostic Steps

### Step 1: Run the comprehensive test
```
https://rlms.rlms.co.za/mobile/test_pothole_evidence_upload.php
```

This will check:
- POE table structure
- Upload directory existence and permissions
- Existing pothole evidence entries
- Database insert capability
- PHP error logs

### Step 2: Test the upload endpoint directly
```
https://rlms.rlms.co.za/mobile/test_upload_debug.php
```

Upload a test image using Postman or similar tool to see what data is being received.

### Step 3: Check the debug POE table script
```
https://rlms.rlms.co.za/mobile/debug_poe_table.php?learnerID=<LEARNER_ID>
```

Replace `<LEARNER_ID>` with an actual learner ID to see their POE entries.

### Step 4: Check existing pothole images
```
https://rlms.rlms.co.za/mobile/get_pothole_images.php?learnerID=<LEARNER_ID>
```

## Common Issues and Fixes

### Issue 1: Upload directory doesn't exist or isn't writable
**Fix:** The script should auto-create it, but you can manually create:
```bash
mkdir -p uploads/pothole_evidence
chmod 755 uploads/pothole_evidence
```

### Issue 2: PHP field name mismatch
The Flutter app sends files as `images[]` which PHP receives as `images` in $_FILES array.

**Current fix:** The upload script now handles both `images` and `images_` field names.

### Issue 3: Database insert failing silently
**Check:** Look at PHP error log at `/home/username/public_html/logs/php_error_log`

### Issue 4: Files uploading but not saving to database
**Symptoms:** Files appear in `uploads/pothole_evidence/` but no entries in POE table.

**Fix:** Check the database insert statement in `upload_pothole_evidence.php` around line 110.

## Files Modified

1. **upload_pothole_evidence.php** - Fixed to handle both `images` and `images_` field names
2. **debug_pothole_upload.php** - New diagnostic script
3. **test_upload_debug.php** - Simple upload test
4. **test_pothole_evidence_upload.php** - Comprehensive test script

## How the Upload Works

### Flutter Side (AssessorPage.dart)
```dart
// Line ~5720
var request = http.MultipartRequest(
  'POST',
  Uri.parse('https://rlms.rlms.co.za/mobile/upload_pothole_evidence.php'),
);

request.fields['learnerID'] = learnerId;
request.fields['assessorID'] = widget.facilitatorId;
request.fields['assessmentDate'] = DateTime.now().toIso8601String().split('T').first;

// Add files with array notation
for (int i = 0; i < images.length; i++) {
  var file = await http.MultipartFile.fromPath(
    'images[]',  // <-- This becomes 'images' in PHP $_FILES
    images[i].path,
    filename: images[i].name,
  );
  request.files.add(file);
}
```

### PHP Side (upload_pothole_evidence.php)
```php
// Receives files in $_FILES['images'] array
$filesKey = isset($_FILES['images']) ? 'images' : (isset($_FILES['images_']) ? 'images_' : null);

// Process each file
for ($i = 0; $i < $fileCount; $i++) {
  // Move file to uploads/pothole_evidence/
  // Insert into POE table
  $stmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, filePath, logbook_text) VALUES (?, ?, ?, ?, ?)');
}
```

## Next Steps

1. Run `test_pothole_evidence_upload.php` to see current state
2. Try uploading images from the app
3. Run the test again to see if new entries appear
4. Check PHP error log for any errors
5. If files are in the directory but not in database, check the database insert statement

## Expected Database Entry

When an image is uploaded, it should create an entry in the `poe` table:
- **learnerID**: The learner's ID
- **exercise**: "Pothole Patching Evidence - [timestamp]"
- **type**: "LogBook"
- **filePath**: "uploads/pothole_evidence/pothole_[learnerID]_[date]_[timestamp]_[uniqueid].[ext]"
- **logbook_text**: "Pothole patching evidence uploaded by assessor [assessorID] on [date]"
