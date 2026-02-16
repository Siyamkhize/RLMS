# Fixed: Scanned PDF Document Viewer

## Problem
The scanned document viewer was trying to open a server path directly as a local file, which doesn't work.

**Document path from database:**
```
../uploads/pothole_checklists/pothole_checklist_1231_1762330576.pdf
```

**What was happening:**
```dart
OpenFile.open("../uploads/pothole_checklists/...pdf")  // ❌ Fails - not a local file
```

## Solution
The app now:
1. Converts the relative server path to a full URL
2. Downloads the PDF from the server
3. Saves it to temporary local storage
4. Opens the local file

## Implementation

### Path Conversion Logic
```dart
// Input: ../uploads/pothole_checklists/pothole_checklist_1231_1762330576.pdf
// Output: https://rlms.rlms.co.za/uploads/pothole_checklists/pothole_checklist_1231_1762330576.pdf

if (documentUrl.startsWith('../')) {
  documentUrl = documentUrl.replaceFirst('../', '');
  documentUrl = 'https://rlms.rlms.co.za/$documentUrl';
}
```

### Download and Open Flow
```dart
1. Convert path to URL
2. Download PDF: http.get(url)
3. Save to temp: getTemporaryDirectory()
4. Write file: file.writeAsBytes(response.bodyBytes)
5. Open local file: OpenFile.open(localPath)
```

## Path Examples

### Example 1: Relative path with ../
```
Input:  ../uploads/pothole_checklists/pothole_checklist_1231_1762330576.pdf
URL:    https://rlms.rlms.co.za/uploads/pothole_checklists/pothole_checklist_1231_1762330576.pdf
Local:  /data/user/0/com.example.rlmss/cache/pothole_checklist_1231_1762330576.pdf
```

### Example 2: Relative path without ../
```
Input:  uploads/pothole_checklists/document.pdf
URL:    https://rlms.rlms.co.za/mobile/uploads/pothole_checklists/document.pdf
Local:  /data/user/0/com.example.rlmss/cache/document.pdf
```

### Example 3: Already full URL
```
Input:  https://rlms.rlms.co.za/uploads/document.pdf
URL:    https://rlms.rlms.co.za/uploads/document.pdf (unchanged)
Local:  /data/user/0/com.example.rlmss/cache/document.pdf
```

## User Experience

### Before Fix:
1. Tap "Open PDF Document" button
2. Error: "File not found" or "Cannot open file"
3. PDF doesn't open

### After Fix:
1. Tap "Open PDF Document" button
2. App downloads PDF from server (shows briefly)
3. PDF opens in device's default PDF viewer
4. User can view, scroll, zoom the document
5. User returns to app to enter marks

## Debug Output

The app now logs:
```
DEBUG: Opening document from URL: https://rlms.rlms.co.za/uploads/pothole_checklists/...
DEBUG: PDF downloaded to: /data/user/0/com.example.rlmss/cache/pothole_checklist_1231_1762330576.pdf
DEBUG: OpenFile result: done
```

## Error Handling

The app handles these scenarios:
- ✅ Network errors (can't download)
- ✅ Invalid URLs
- ✅ Server returns 404
- ✅ No PDF viewer installed
- ✅ Permission issues

All errors show user-friendly messages.

## Testing

### Test Scenario 1: Open Scanned Document
1. Navigate to learner with scanned checklist
2. Tap "View Pothole Checklist"
3. Should see "Scanned Document" page
4. Tap "Open PDF Document"
5. PDF should download and open
6. View the document
7. Return to app
8. Enter marks and save

### Test Scenario 2: Offline Mode
If offline:
- Shows error: "Error opening document: Failed to download PDF"
- User can still enter marks based on memory/notes

## File Locations

### Server:
```
https://rlms.rlms.co.za/uploads/pothole_checklists/
  ├── pothole_checklist_1231_1762330576.pdf
  ├── pothole_checklist_1232_1762330577.pdf
  └── ...
```

### Database:
```sql
pothole_checklist_scanned_documents
- document_path: ../uploads/pothole_checklists/pothole_checklist_1231_1762330576.pdf
```

### Local Cache (temporary):
```
/data/user/0/com.example.rlmss/cache/
  └── pothole_checklist_1231_1762330576.pdf (downloaded)
```

## Benefits

✅ Works with relative server paths
✅ Works with absolute URLs
✅ Downloads PDF automatically
✅ Opens in device's PDF viewer
✅ Handles errors gracefully
✅ Debug logging for troubleshooting
✅ No manual file management needed

## Status
✅ **FIXED AND READY TO TEST**

The scanned document viewer now correctly downloads and opens PDFs from the server. Test it with a learner who has a scanned checklist!
