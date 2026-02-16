# Moderator View Answer Feature Implementation

## Overview
Added the ability for moderators to view learner-submitted POE documents (answers) before making moderation decisions to uphold or withdraw marks.

## Changes Made

### 1. Added "View Learner Answer" Button
**Location:** `lib/ModeratorPage.dart` - `_buildExerciseTiles` method

Added a button that appears for each exercise that has an uploaded document:

```dart
// View Answer button
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

### 2. Created PDF Viewer Screen
**Location:** `lib/ModeratorPage.dart` - `ModeratorPdfViewerScreen` class

Features:
- Downloads PDF from server URL
- Displays PDF with page navigation
- Shows document info (total pages, current page)
- Option to open in external app
- Error handling with retry functionality
- Loading indicator during download

```dart
class ModeratorPdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  // ... implementation
}
```

## User Experience

### Moderator Workflow
1. Navigate to a learner's marks
2. Expand an exercise to see details
3. Click "View Learner Answer" button (appears if document exists)
4. PDF viewer opens showing the learner's submitted work
5. Review the answer
6. Return to moderation page
7. Make decision to Uphold or Withdraw marks

### Button Visibility
- Button only appears if `exercise['fileUrl']` exists and is not empty
- Button is full-width for easy tapping
- Blue color with PDF icon for clear identification

## Technical Details

### Dependencies
Uses existing dependencies:
- `flutter_pdfview` - For PDF rendering
- `path_provider` - For temporary file storage
- `http` - For downloading PDFs
- `url_launcher` - For opening in external apps

### Data Requirements
The exercise data from `get_poe.php` must include:
- `fileUrl` - Full URL to the uploaded PDF document
- `filePath` - Server path to the document (optional, for reference)

### Error Handling
- Network errors during download
- PDF rendering errors
- Missing file URLs
- Retry functionality for failed downloads

## Benefits

1. **Informed Decisions**: Moderators can now see what the learner actually submitted
2. **Consistency**: Same viewing experience as assessors have
3. **Transparency**: Full visibility into the assessment process
4. **Quality Assurance**: Moderators can verify marks against actual work

## Testing Checklist

- [ ] Button appears when fileUrl exists
- [ ] Button hidden when no fileUrl
- [ ] PDF downloads successfully
- [ ] PDF displays correctly
- [ ] Page navigation works
- [ ] External app opening works
- [ ] Error handling displays properly
- [ ] Retry functionality works
- [ ] Back navigation returns to moderation page
- [ ] Works for all assessment types (Formative, Summative, Logbook)

## Next Steps

If needed, can add:
- Zoom controls for PDF viewer
- Search functionality within PDF
- Annotation capabilities
- Side-by-side view of rubric and answer
- Download PDF to device option
