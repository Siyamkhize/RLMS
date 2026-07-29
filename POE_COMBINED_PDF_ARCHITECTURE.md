# POE Combined PDF Architecture - Technical Summary

## Architecture Changes

### Before (Question-by-Question)
```
Flutter                          Server                    Database
┌─────────────┐                ┌──────────────┐          ┌─────────┐
│ Question 1  │─ PDF ──────→  │ save_*.php   │ ────────→│  POE    │
│ Question 2  │─ PDF ──────→  │  (multiple   │ ────────→│ Q1 row  │
│ Question 3  │─ PDF ──────→  │   calls)     │ ────────→│ Q2 row  │
│ Question 4  │─ PDF ──────→  │              │ ────────→│ Q3 row  │
└─────────────┘                └──────────────┘          │ Q4 row  │
                                                         └─────────┘
Problem: Multiple requests, multiple files, multiple DB records
```

### After (Combined)
```
Flutter                          Server                    Database
┌─────────────┐                ┌──────────────┐          ┌─────────┐
│ Q1, Q2, Q3  │──────────────→ │ Combine PDFs │ ────────→│  POE    │
│ Q4, Q5...   │   1 PDF file   │              │          │ All Q's │
└─────────────┘   (combined)    │ Save once    │          │  1 row  │
                                │              │          └─────────┘
                                └──────────────┘

Solution: Single request, single file, single DB record
```

## Data Flow

### Request Flow
```
┌──────────────────────────────────────────────────────┐
│ Flutter App                                          │
│ ┌─────────────────────────────────────────────────┐ │
│ │ 1. Collect all questions                        │ │
│ │    - Q1: Hazard ID                              │ │
│ │    - Q2: Risk Assessment                        │ │
│ │    - Q3: Controls                               │ │
│ │    - Q4: Reporting                              │ │
│ └─────────────────────────────────────────────────┘ │
│                     ↓                                │
│ ┌─────────────────────────────────────────────────┐ │
│ │ 2. Combine all Q PDFs → Single PDF              │ │
│ │    File: combined_questions.pdf                 │ │
│ └─────────────────────────────────────────────────┘ │
│                     ↓                                │
│ ┌─────────────────────────────────────────────────┐ │
│ │ 3. Send POST Request with:                      │ │
│ │    - learnerID: "11559"                         │ │
│ │    - ofo_number: "9964"                         │ │
│ │    - paper_title: "Health & Safety"             │ │
│ │    - exercises: ["Q1", "Q2", "Q3", "Q4"]        │ │
│ │    - file: combined_questions.pdf               │ │
│ └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
                       ↓ HTTP POST
┌──────────────────────────────────────────────────────┐
│ Server (arpl_save_metadata.php)                      │
│ ┌─────────────────────────────────────────────────┐ │
│ │ 1. Validate Inputs                              │ │
│ │    - Check learnerID                            │ │
│ │    - Check OFO number                           │ │
│ │    - Check paper title                          │ │
│ └─────────────────────────────────────────────────┘ │
│                     ↓                                │
│ ┌─────────────────────────────────────────────────┐ │
│ │ 2. Check for Duplicates                         │ │
│ │    SELECT FROM poe                              │ │
│ │    WHERE learnerID = '11559'                    │ │
│ │    AND exercise LIKE 'All%Questions%'           │ │
│ │    AND type = 'ARPL'                            │ │
│ └─────────────────────────────────────────────────┘ │
│                     ↓                                │
│ ┌─────────────────────────────────────────────────┐ │
│ │ 3. Save Combined PDF                            │ │
│ │    Filename: All_Questions_9964_Health_Safety  │ │
│ │    Path: ARPL_POE/All_Questions_9964_...pdf    │ │
│ └─────────────────────────────────────────────────┘ │
│                     ↓                                │
│ ┌─────────────────────────────────────────────────┐ │
│ │ 4. Insert ONE Database Record                   │ │
│ │    exercise: "All ARPL Questions - 4 Questions" │ │
│ │    filePath: "ARPL_POE/All_Questions_..."       │ │
│ └─────────────────────────────────────────────────┘ │
│                     ↓                                │
│ ┌─────────────────────────────────────────────────┐ │
│ │ 5. Return Success Response                      │ │
│ │    - status: "success"                          │ │
│ │    - file: path/to/file.pdf                     │ │
│ │    - questions_count: 4                         │ │
│ └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
                       ↓ JSON Response
┌──────────────────────────────────────────────────────┐
│ Database                                             │
│ POE Table                                            │
│ ┌────────────────────────────────────────────────┐  │
│ │ learnerID │ exercise               │ filePath   │  │
│ │───────────┼───────────────────────┼────────────│  │
│ │ 11559     │ All ARPL Questions... │ ARPL_POE/..│  │
│ │           │ 4 Questions           │            │  │
│ └────────────────────────────────────────────────┘  │
│                                                      │
│ File System                                          │
│ ┌────────────────────────────────────────────────┐  │
│ │ ARPL_POE/                                      │  │
│ │ ├── All_Questions_9964_Health_Safety.pdf       │  │
│ └────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

## Database Schema Impact

### Before
```
poe Table:
┌──────────┬──────────────────┬─────────┬──────────┐
│learnerID │ exercise         │ type    │filePath  │
├──────────┼──────────────────┼─────────┼──────────┤
│11559     │ Question 1       │ ARPL    │file1.pdf │
│11559     │ Question 2       │ ARPL    │file2.pdf │
│11559     │ Question 3       │ ARPL    │file3.pdf │
│11559     │ Question 4       │ ARPL    │file4.pdf │
└──────────┴──────────────────┴─────────┴──────────┘

Result: 4 rows for 1 question set
```

### After
```
poe Table:
┌──────────┬────────────────────────────────────┬─────────┬──────────┐
│learnerID │ exercise                           │ type    │filePath  │
├──────────┼────────────────────────────────────┼─────────┼──────────┤
│11559     │ All ARPL Questions - 4 Questions   │ ARPL    │combo.pdf │
└──────────┴────────────────────────────────────┴─────────┴──────────┘

Result: 1 row for 1 question set
```

## File Storage Impact

### Before
```
ARPL_POE/
├── 1234567_Q1_health_safety.pdf      (Question 1)
├── 1234567_Q2_health_safety.pdf      (Question 2)
├── 1234567_Q3_health_safety.pdf      (Question 3)
└── 1234567_Q4_health_safety.pdf      (Question 4)

Total: 4 PDF files per question set
Disk space: 4x per learner
```

### After
```
ARPL_POE/
├── All_Questions_9964_Health_Safety.pdf  (All questions combined)

Total: 1 PDF file per question set
Disk space: 1x per learner
```

## Key Components

### 1. Combined Exercise Label
```php
$combinedExerciseLabel = 'All ' . $type . ' Questions - ' . 
                        (count($exerciseList) > 1 ? 
                         count($exerciseList) . ' Questions' : 
                         '1 Question');

// Examples:
// "All ARPL Questions - 4 Questions"
// "All Formative Questions - 1 Question"
// "All Summative Questions - 9 Questions"
```

### 2. Filename Format
```php
$fileName = 'All_Questions_' . $sanitizedOFO . '_' . $sanitizedPaper . '.' . $extension;

// Example:
// Input: OFO="9964", Paper="Apply health & safety to comply with OHSA"
// Output: All_Questions_9964_Apply_health_and_safety_to_comply_with_OHSA.pdf
```

### 3. Duplicate Prevention
```php
$combinedPattern = 'All ' . $type . ' Questions%';
// LIKE query prevents uploading same question set twice for same learner
// Pattern matches any "All [TYPE] Questions..." entry
```

### 4. Single Database Insert
```php
// Only ONE INSERT, regardless of question count
$stmt->bind_param('sssss', $learnerID, $combinedExerciseLabel, 
                           $type, $filePath, $emptyText);

if (!$stmt->execute()) {
    throw new Exception('Failed to insert combined upload: ' . $stmt->error);
}
```

## Performance Implications

### Network
- **Before**: Multiple HTTP requests = higher latency
- **After**: Single HTTP request = lower latency ✅

### Database
- **Before**: Multiple INSERT operations
- **After**: Single INSERT operation ✅

### Storage
- **Before**: Multiple PDF files
- **After**: Single combined PDF ✅

### Retrieval
- **Before**: Multiple rows per question set
- **After**: One row per question set ✅

## Error Handling

### Validation Errors
```
→ Missing fields → 400 error (validation fails before file upload)
→ Invalid OFO number → ignored (optional for backward compatibility)
→ Invalid paper title → 400 error
```

### File Errors
```
→ File not uploaded → 400 error
→ File size > 15MB → rejected
→ File type not PDF → rejected
→ Duplicate upload → 400 error (checked before save)
```

### Database Errors
```
→ Connection failed → 500 error
→ Insert failed → rolled back + cleanup
→ Transaction failed → full rollback
```

## Transaction Safety
```php
$conn->begin_transaction();

try {
    // Save file
    // Insert database record
    $conn->commit();
} catch (Exception $e) {
    $conn->rollback();          // ← Rollback if any error
    cleanupFiles($uploadedFiles); // ← Clean up uploaded files
    sendResponse('error', ...);
}
```

## Compatibility

### ✅ Backward Compatible
- Old API calls still work
- Single file upload supported
- Database schema unchanged

### ✅ Frontend Ready
- Flutter can send combined PDF
- No changes to existing Flutter logic
- Works with pdf_combiner or similar

### ✅ Integration Ready
- Works with existing POE system
- Follows same pattern as regular POE
- Compatible with get_poe.php

---

**Architecture**: Combined PDF Upload
**Status**: ✅ Implemented & Tested
**Version**: 1.0
**Date**: July 6, 2026
