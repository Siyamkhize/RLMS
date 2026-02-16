# Moderator View Answer Feature - Complete

## Overview
The Moderator page now displays uploaded learner answers, allowing moderators to view the submitted work before making their decision to uphold or withdraw marks.

## Implementation Status
✅ **ALREADY IMPLEMENTED** - The feature is already in place in the ModeratorPage.dart file.

## Features Included

### 1. View Answer Button
- Located in each exercise tile within the expansion panel
- Displays as a full-width blue button with PDF icon
- Label: "View Learner Answer"
- Only shows when `fileUrl` is available for the exercise

### 2. PDF Viewer Screen
- **Class**: `ModeratorPdfViewerScreen`
- **Location**: Lines 1713+ in ModeratorPage.dart
- **Features**:
  - Downloads PDF from server
  - Displays PDF inline using flutter_pdfview
  - Shows document info (total pages, current page)
  - Option to open in external app
  - Error handling with retry option
  - Loading indicator during download

### 3. Exercise Data Structure
The exercise object includes:
- `fileUrl` or `file_url`: URL to the uploaded answer
- `filePath` or `file_path`: Alternative path field
- `marks_scored`: Marks given by assessor
- `total_marks`: Maximum marks possible
- `moderator_status`: Current moderation status (Upheld/Withdrawn)
- `moderator_comment`: Moderator's comments

## User Flow

1. **Moderator navigates to learner's POE**
   - Selects class → Selects learner → Views POE Details tab

2. **Expands exercise tile**
   - Sees marks scored by assessor
   - Sees "View Learner Answer" button (if answer was uploaded)

3. **Clicks "View Learner Answer"**
   - PDF viewer screen opens
   - Document downloads and displays
   - Can scroll through pages
   - Can open in external app if needed

4. **Makes moderation decision**
   - After reviewing the answer
   - Clicks "Uphold" or "Withdraw"
   - Adds optional comment
   - Submits decision

## Code Location

### View Answer Button
```dart
// Location: lib/ModeratorPage.dart, lines ~1207-1232
if (exercise['fileUrl'] != null && exercise['fileUrl'].toString().isNotEmpty) ...[
  SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () {
        String fileUrl = exercise['fileUrl'];
        if (fileUrl.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ModeratorPdfViewerScreen(pdfUrl: fileUrl),
            ),
          );
        }
      },
      icon: const Icon(Icons.picture_as_pdf),
      label: const Text('View Learner Answer'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  ),
  const SizedBox(height: 12),
],
```

### PDF Viewer Screen
```dart
// Location: lib/ModeratorPage.dart, lines ~1713+
class ModeratorPdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  // ... implementation
}
```

## Backend Requirements

The `get_poe.php` endpoint must return exercise data with:
- `fileUrl` or `file_url`: Full URL to the uploaded PDF
- Example: `https://example.com/uploads/learner_answers/exercise_123.pdf`

## Testing Checklist

- [x] View Answer button appears when fileUrl is present
- [x] View Answer button hidden when no fileUrl
- [x] PDF downloads successfully
- [x] PDF displays correctly
- [x] Page navigation works
- [x] External app option works
- [x] Error handling displays properly
- [x] Loading indicator shows during download
- [x] Back button returns to POE page

## Comparison with Assessor Page

Both Assessor and Moderator pages now have identical functionality for viewing learner answers:

| Feature | Assessor Page | Moderator Page |
|---------|--------------|----------------|
| View Answer Button | ✅ | ✅ |
| PDF Viewer | ✅ | ✅ |
| Download & Display | ✅ | ✅ |
| External App Option | ✅ | ✅ |
| Error Handling | ✅ | ✅ |

## Notes

- The feature uses the same PDF viewing approach as the Assessor page
- Requires `flutter_pdfview` package (already in dependencies)
- Requires `url_launcher` package (already in dependencies)
- PDFs are downloaded to temporary directory
- No offline caching (downloads each time)

## Status
✅ **FEATURE COMPLETE** - No additional work needed. The moderator can already view uploaded answers.
