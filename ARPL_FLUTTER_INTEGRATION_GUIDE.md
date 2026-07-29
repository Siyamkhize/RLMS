# ARPL Flutter Integration Guide - Combined PDF Upload

## Overview
Flutter sends a **single combined PDF file** to the server, which saves it with filename format:
```
All_Questions_[OFO_Number]_[Paper_Title].pdf
```

## Server Endpoint
**URL**: `mobile/arpl_save_metadata.php`

## Required POST Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `learnerID` | string | Learner ID | "11559" |
| `ofo_number` | string | OFO qualification number | "9964" |
| `paper_title` | string | Title of the paper/question set | "Apply health and safety to comply with OHSA" |
| `type` | string | Document type | "Formative" or "Summative" or "ARPL" |
| `exercises` | JSON array | List of question descriptions/labels | `["Q1: Intro", "Q2: Main", ...]` |
| `files` | file | Single combined PDF | (multipart form data) |

## Optional POST Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `trade_name` | string | Trade name for context |
| `section_type` | string | "theory" or "practical" |
| `question_number` | string | Question number (for reference) |

## Flutter Implementation Example

```dart
Future<void> _submitCombinedARPLPDF() async {
  try {
    // 1. Combine all PDFs into one
    final combinedPdfPath = await _combinePDFsIntoOne();
    
    // 2. Get learner and paper info
    final learnerID = widget.learner['learnerID'];
    final ofoNumber = "9964";
    final paperTitle = "Apply health and safety to comply with OHSA";
    
    // 3. Build exercise list (from questions answered)
    List<String> exercises = [
      "Question 1: Identify hazards",
      "Question 2: Risk assessment",
      "Question 3: Control measures",
      "Question 4: Incident reporting"
    ];
    
    // 4. Prepare multipart request
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(AppConfig.buildUrl('arpl_save_metadata.php'))
    );
    
    // Add form fields
    request.fields['learnerID'] = learnerID;
    request.fields['ofo_number'] = ofoNumber;
    request.fields['paper_title'] = paperTitle;
    request.fields['type'] = 'Formative';
    request.fields['exercises'] = jsonEncode(exercises);
    
    // Add single combined PDF file
    request.files.add(
      await http.MultipartFile.fromPath(
        'files', // Field name
        combinedPdfPath,
        contentType: MediaType('application', 'pdf'),
      ),
    );
    
    // 5. Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    // 6. Handle response
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success']) {
        print('✅ Combined PDF uploaded successfully!');
        print('File: ${data['file']}');
        print('Questions: ${data['questions_count']}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

## Server Response

### Success Response
```json
{
  "status": "success",
  "success": true,
  "message": "Combined PDF uploaded successfully for 4 questions",
  "exercise": "All ARPL Questions - 4 Questions",
  "file": "ARPL_POE/All_Questions_9964_Apply_health_and_safety_to_comply_with_OHSA.pdf",
  "questions_count": 4,
  "upload_details": {
    "total_questions": 4,
    "file_name": "All_Questions_9964_Apply_health_and_safety_to_comply_with_OHSA.pdf",
    "file_size": 2097152
  }
}
```

### Error Responses

#### Duplicate Upload
```json
{
  "status": "error",
  "success": false,
  "message": "All ARPL Questions for this paper have already been uploaded"
}
```

#### File Upload Error
```json
{
  "status": "error",
  "success": false,
  "message": "File processing errors: File exceeds 15MB limit (25.50MB)"
}
```

#### Missing Fields
```json
{
  "status": "error",
  "success": false,
  "message": "Missing required fields: learnerID, paper_title, and either exercise_text or exercises array"
}
```

## File Size Limits
- **Maximum**: 15MB per file
- This is the entire combined PDF, not per question

## Naming Convention

### File Stored As
```
All_Questions_[SANITIZED_OFO]_[SANITIZED_PAPER].pdf
```

### Sanitization Rules
1. Whitespace → underscore `_`
2. Special characters removed
3. Only alphanumeric, dots, underscores, hyphens allowed

### Examples
| Input | Output |
|-------|--------|
| OFO: "9964", Paper: "Apply health & safety" | `All_Questions_9964_Apply_health_safety.pdf` |
| OFO: "1234", Paper: "NQF Level 4 - Theory" | `All_Questions_1234_NQF_Level_4_Theory.pdf` |

## Database Storage

### Single Record Format
```
learnerID:    "11559"
exercise:     "All ARPL Questions - 4 Questions"
type:         "Formative"
filePath:     "ARPL_POE/All_Questions_9964_Apply_health_and_safety_to_comply_with_OHSA.pdf"
logbook_text: ""
```

### Querying Database
```sql
-- Get all ARPL uploads for a learner
SELECT * FROM poe 
WHERE learnerID = '11559' 
AND type = 'ARPL' 
AND exercise LIKE 'All%';

-- Get specific paper
SELECT * FROM poe 
WHERE learnerID = '11559' 
AND exercise = 'All ARPL Questions - 4 Questions';
```

## Key Points

✅ **One Combined PDF** - Flutter sends single PDF file
✅ **One Database Record** - Server stores one entry
✅ **Clear Naming** - Format: `All_Questions_[OFO]_[Title].pdf`
✅ **Duplicate Prevention** - Rejects duplicate uploads
✅ **File Validation** - Checks size (15MB max) and type (PDF only)
✅ **Transaction Safety** - Database changes rolled back on error

## Workflow Summary

1. **Flutter Side**
   - Combine multiple question PDFs into one
   - Collect all question labels
   - Get learner ID and OFO number
   - Send POST request with:
     - Single combined PDF file
     - Learner ID
     - OFO number
     - Paper title
     - Question list

2. **Server Side**
   - Validate all inputs
   - Check for duplicate uploads
   - Save PDF with filename: `All_Questions_[OFO]_[Title].pdf`
   - Insert ONE database record
   - Return success with file details

3. **Result**
   - ✅ One PDF file in `ARPL_POE/` directory
   - ✅ One database record in `poe` table
   - ✅ All questions covered by single entry
   - ✅ No redundant data

---

**Integration Status**: ✅ Ready
**Last Updated**: July 6, 2026
