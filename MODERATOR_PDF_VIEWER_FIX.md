# Moderator Page - PDF Viewer Fix for Scanned Pothole Checklist

## Issue
When moderators tried to view a scanned pothole checklist, only a dialog with document information was shown instead of opening the actual PDF document.

## Root Cause
The `_viewPotholeChecklist` method was constructing the PDF URL incorrectly. It was simply appending the document path to the base URL without handling relative paths (like `../uploads/...`) properly.

## Solution Implemented

### 1. Fixed URL Construction
Updated the `_viewPotholeChecklist` method to properly handle different path formats:

```dart
// Convert relative server path to full URL
String fullUrl = documentPath;

// If path starts with ../, convert to full URL
if (documentPath.startsWith('../')) {
  // Remove ../ and construct full URL
  documentPath = documentPath.replaceFirst('../', '');
  // Use base domain without /mobile path for documents in root uploads folder
  final baseDomain = AppConfig.baseUrl.replaceAll('/mobile', '');
  fullUrl = '$baseDomain/$documentPath';
} else if (!documentPath.startsWith('http')) {
  // If it's a relative path without ../, add base URL
  fullUrl = '${AppConfig.baseUrl}/$documentPath';
}
```

### 2. PDF Viewer Already Exists
The `PotholeChecklistPDFViewer` widget was already implemented in the ModeratorPage with:
- PDF download functionality
- Local file caching
- PDF rendering using `flutter_pdfview` package
- Page navigation
- External app opening option
- Error handling and retry mechanism

## How It Works Now

### User Flow
1. Moderator navigates to learner's POE Details tab
2. Expands "Pothole Checklist" section
3. Sees "Scanned Document" option
4. Taps on it
5. **NEW:** PDF viewer page opens showing the actual document
6. Can view all pages, zoom, and navigate through the PDF
7. Can open in external PDF app if needed

### Technical Flow
1. `_viewPotholeChecklist` is called with scanned document data
2. Document path is converted to full URL (handling `../` paths)
3. Navigates to `PotholeChecklistPDFViewer` page
4. PDF is downloaded from server
5. Saved to local temporary storage
6. Rendered using `PDFView` widget
7. User can interact with the PDF

## URL Path Handling

### Example Paths
```
Input: ../uploads/pothole_checklists/pothole_checklist_1231_1762330576.pdf
Base URL: https://rlms.rlms.co.za/mobile
Result: https://rlms.rlms.co.za/uploads/pothole_checklists/pothole_checklist_1231_1762330576.pdf

Input: uploads/pothole_checklists/document.pdf
Base URL: https://rlms.rlms.co.za/mobile
Result: https://rlms.rlms.co.za/mobile/uploads/pothole_checklists/document.pdf

Input: https://rlms.rlms.co.za/uploads/document.pdf
Result: https://rlms.rlms.co.za/uploads/document.pdf (unchanged)
```

## Features of PDF Viewer

### Display Features
✅ Full-screen PDF viewing
✅ Page navigation (swipe up/down)
✅ Zoom in/out
✅ Page counter (current page / total pages)
✅ Document information card

### Functionality
✅ Download PDF from server
✅ Cache locally for offline viewing
✅ Open in external PDF app
✅ Retry on download failure
✅ Loading indicator
✅ Error messages with retry option

### Document Info Displayed
- Learner ID
- Assessment Date
- Total pages
- Current page number
- Document type (Scanned Document)

## Error Handling

### Download Errors
- Shows error message with details
- Provides "Retry" button
- Logs error to console for debugging

### Network Issues
- Handles timeout gracefully
- Shows user-friendly error message
- Allows retry without leaving page

### File Access Issues
- Handles permission errors
- Provides fallback to external app

## Testing Recommendations

1. **Test with different path formats:**
   - Paths starting with `../`
   - Paths starting with `uploads/`
   - Full URLs

2. **Test network conditions:**
   - Good connection
   - Slow connection
   - No connection (should show error)

3. **Test PDF features:**
   - Page navigation
   - Zoom functionality
   - External app opening

4. **Test error scenarios:**
   - Invalid PDF URL
   - Corrupted PDF file
   - Server unavailable

## Dependencies Required

The PDF viewer uses these packages (should already be in `pubspec.yaml`):
```yaml
dependencies:
  flutter_pdfview: ^1.3.2
  http: ^1.1.0
  path_provider: ^2.1.1
  url_launcher: ^6.2.1
```

## Comparison with AssessorPage

| Feature | AssessorPage | ModeratorPage |
|---------|-------------|---------------|
| View PDF | ✅ | ✅ |
| Download PDF | ✅ | ✅ |
| Page Navigation | ✅ | ✅ |
| External App | ✅ | ✅ |
| Submit Marks | ✅ | ❌ (View only) |
| Add Comments | ✅ | ❌ (View only) |

Moderators can view the PDF but cannot submit marks or comments (as intended for the moderator role).

## Debug Logging

All debug messages are prefixed with:
- `DEBUG:` for view-related logs
- `DEBUG PDF:` for PDF download/rendering logs

Example logs:
```
DEBUG: _viewPotholeChecklist called with type=scanned
DEBUG: Opening scanned PDF
DEBUG: Full PDF URL: https://rlms.rlms.co.za/uploads/pothole_checklists/document.pdf
DEBUG PDF: Downloading from https://rlms.rlms.co.za/uploads/pothole_checklists/document.pdf
DEBUG PDF: Downloaded to /data/user/0/com.example.app/app_flutter/temp_pothole_checklist.pdf
```

## Status
✅ **Fix Complete and Ready for Testing**

The PDF viewer now properly opens and displays scanned pothole checklist documents for moderators.

## Next Steps (Optional Enhancements)

1. Add PDF annotation capability (view-only mode)
2. Implement PDF search functionality
3. Add bookmark support for multi-page documents
4. Enable PDF sharing via email/messaging
5. Add print functionality
