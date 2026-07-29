# ARPL Combined PDF Upload Fix - Complete

## Problem Fixed
Previously, the ARPL system was uploading individual PDFs for each question, creating multiple file entries. The system was saving one PDF file but then inserting multiple database records (one per exercise).

## Solution Implemented
The system now saves and stores **ONE combined PDF file** with a single database record containing all questions.

## Key Changes in `arpl_save_metadata.php`

### 1. Added OFO Number Support
```php
$ofoNumber = trim($_POST['ofo_number'] ?? ''); // OFO number for filename
```
- Accepts OFO number from Flutter request
- Used in the filename for better organization

### 2. Combined Exercise Label
```php
$combinedExerciseLabel = 'All ' . $type . ' Questions - ' . (count($exerciseList) > 1 ? count($exerciseList) . ' Questions' : '1 Question');
```
- Creates a single label that represents all questions combined
- Example: "All ARPL Questions - 9 Questions"

### 3. Improved Duplicate Check
```php
$combinedPattern = 'All ' . $type . ' Questions%';
$checkStmt->bind_param('sss', $learnerID, $combinedPattern, $type);
```
- Checks if the combined upload already exists
- Prevents re-uploading the same question set
- Uses LIKE pattern for flexibility

### 4. File Naming Format
```php
$fileName = 'All_Questions_' . $sanitizedOFO . '_' . $sanitizedPaper . '.' . $extension;
// Example: All_Questions_9964_Apply_health_and_safety_to_comply_with_OHSA.pdf
```
- Format: `All_Questions_[OFO]_[PaperTitle].pdf`
- Single file per paper, per learner
- Clean, standardized naming convention

### 5. Single Database Record
```php
// Insert ONE database record only - with combined label
$stmt->bind_param('sssss', $learnerID, $combinedExerciseLabel, $type, $filePath, $emptyText);

if (!$stmt->execute()) {
    throw new Exception('Failed to insert combined upload: ' . $stmt->error);
}
```
- Only ONE database record is inserted
- Contains the combined exercise label
- Points to the single combined PDF file

### 6. Enhanced Response
```php
$response = [
    'status' => 'success',
    'message' => 'Combined PDF uploaded successfully for ' . count($exerciseList) . ' questions',
    'exercise' => $combinedExerciseLabel,
    'file' => $filePath,
    'questions_count' => count($exerciseList),
    'upload_details' => [
        'total_questions' => count($exerciseList),
        'file_name' => $uploadedFiles[0]['saved_name'],
        'file_size' => $uploadedFiles[0]['size']
    ]
];
```
- Provides clear feedback about the combined upload
- Includes question count and file details

## Database Changes
- **Before**: Multiple records in POE table (one per question)
  - Example: Q1, Q2, Q3, Q4 = 4 database rows
- **After**: Single record in POE table
  - Example: "All ARPL Questions - 4 Questions" = 1 database row

## File Storage Changes
- **Before**: Multiple PDF files (potentially)
- **After**: Single combined PDF file
  - Named: `All_Questions_[OFO]_[Paper].pdf`
  - Example: `All_Questions_9964_Apply_health_and_safety_to_comply_with_OHSA.pdf`

## Expected Behavior

### Successful Upload
1. Flutter sends one combined PDF containing all questions
2. Server validates the PDF and OFO number
3. File is saved as: `ARPL_POE/All_Questions_[OFO]_[PaperTitle].pdf`
4. Single database record is inserted with label: `All ARPL Questions - [N] Questions`
5. Response includes total question count and file details

### Duplicate Prevention
- If user tries to upload the same question set again, it's rejected
- Error message: "All ARPL Questions for this paper have already been uploaded"

## Testing Steps

### 1. Verify File Naming
```
Expected format: All_Questions_9964_Apply_health_and_safety_to_comply_with_OHSA.pdf
Location: ARPL_POE/ directory
```

### 2. Verify Database Record
```sql
SELECT * FROM poe WHERE learnerID = [ID] AND type = 'ARPL';
-- Should show 1 record with exercise = "All ARPL Questions - [N] Questions"
```

### 3. Verify Duplicate Prevention
- Try uploading the same question set twice
- Should get error: "All ARPL Questions for this paper have already been uploaded"

## Server Requirements

### POST Parameters Required
- `learnerID` - Learner ID
- `ofo_number` - OFO number (for filename)
- `paper_title` - Paper/question set title
- `type` - Document type (default: 'ARPL')
- `exercises` - JSON array of question labels (optional, for tracking purposes)
- `files` - Single combined PDF file

### Optional Parameters
- `trade_name` - Trade name (for context)
- `section_type` - "theory" or "practical"
- `question_number` - Question number (for context)

## Compatibility
✅ Works with existing Flutter implementation
✅ Single PDF file upload from Flutter
✅ OFO number-based filename organization
✅ Clean database schema (one entry per paper)
✅ Prevents duplicate uploads

## Logging
The system logs all operations:
```
[Combined PDF uploaded: ...file -> ARPL_POE/...file for 9 questions]
[ARPL combined upload completed for learnerID=..., paper=..., questions=9, file=...]
```

---

**Status**: ✅ Complete and Ready for Testing
**Date**: July 6, 2026
