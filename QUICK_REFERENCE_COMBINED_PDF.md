# ARPL Combined PDF System - Quick Reference Card

## 🎯 TL;DR - The Change

**BEFORE**: 4 questions = 4 files + 4 database records + 4 API calls
**AFTER**: 4 questions = 1 file + 1 database record + 1 API call

---

## 📝 Filename Format

```
All_Questions_[OFO]_[PaperTitle].pdf
```

**Example:**
```
All_Questions_9964_Apply_health_and_safety_to_comply_with_OHSA.pdf
```

---

## 🔧 Server Endpoint

**URL**: `/mobile/arpl_save_metadata.php`

**Method**: `POST` (multipart/form-data)

**Required Fields:**
| Field | Type | Example |
|-------|------|---------|
| learnerID | string | "11559" |
| ofo_number | string | "9964" |
| paper_title | string | "Apply health and safety..." |
| type | string | "Formative" |
| exercises | JSON array | `["Q1", "Q2", "Q3", "Q4"]` |
| files | file | combined.pdf |

---

## 📤 Request Example (cURL)

```bash
curl -X POST http://server/mobile/arpl_save_metadata.php \
  -F "learnerID=11559" \
  -F "ofo_number=9964" \
  -F "paper_title=Apply health and safety to comply with OHSA" \
  -F "type=Formative" \
  -F 'exercises=["Q1: Hazards", "Q2: Risk", "Q3: Controls", "Q4: Incident"]' \
  -F "files=@combined.pdf"
```

---

## ✅ Success Response

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

---

## ❌ Error Responses

**Duplicate Upload:**
```json
{
  "status": "error",
  "success": false,
  "message": "All ARPL Questions for this paper have already been uploaded"
}
```

**File Too Large:**
```json
{
  "status": "error",
  "success": false,
  "message": "File processing errors: File exceeds 15MB limit (25.50MB)"
}
```

**Missing Fields:**
```json
{
  "status": "error",
  "success": false,
  "message": "Missing required fields: learnerID, paper_title, and either exercise_text or exercises array"
}
```

---

## 🗄️ Database Query

```sql
-- Get uploaded ARPL for learner
SELECT * FROM poe 
WHERE learnerID = '11559' 
AND exercise LIKE 'All%Questions%'
AND type = 'ARPL';

-- Result:
-- 1 row with exercise = "All ARPL Questions - 4 Questions"
```

---

## 📂 File Storage Location

```
ARPL_POE/
└── All_Questions_9964_Apply_health_and_safety_to_comply_with_OHSA.pdf
```

---

## 🚀 Flutter Implementation

```dart
// 1. Combine PDFs
final combined = await combinePDFs([q1, q2, q3, q4]);

// 2. Build request
var request = http.MultipartRequest('POST', url);
request.fields['learnerID'] = '11559';
request.fields['ofo_number'] = '9964';
request.fields['paper_title'] = 'Apply health and safety...';
request.fields['type'] = 'Formative';
request.fields['exercises'] = jsonEncode(['Q1', 'Q2', 'Q3', 'Q4']);
request.files.add(await http.MultipartFile.fromPath('files', combined));

// 3. Send
final response = await request.send();
final data = json.decode(await response.stream.bytesToString());

if (data['success']) {
  print('✅ Uploaded ${data['questions_count']} questions');
  print('File: ${data['file']}');
}
```

---

## 📊 Performance Impact

| Metric | Impact |
|--------|--------|
| API Calls | ⬇️ -75% (4 → 1) |
| Database Rows | ⬇️ -75% (4 → 1) |
| Files Stored | ⬇️ -75% (4 → 1) |
| Network Requests | ⬇️ -75% (4 → 1) |
| Disk Space | ⬇️ -75% |

---

## 🔍 Testing

### Test Upload
```bash
curl -X POST http://localhost/mobile/arpl_save_metadata.php \
  -F "learnerID=test123" \
  -F "ofo_number=9964" \
  -F "paper_title=Test Paper" \
  -F "type=ARPL" \
  -F 'exercises=["Q1", "Q2"]' \
  -F "files=@test.pdf"
```

### Verify File
```bash
ls -la ARPL_POE/All_Questions_9964_Test_Paper.pdf
```

### Verify Database
```sql
SELECT * FROM poe WHERE exercise LIKE 'All ARPL Questions%';
```

---

## ⚠️ Important Notes

✅ **Single File Per Paper Per Learner**
- Only one combined PDF saved
- Can't re-upload same questions

✅ **File Size Limit**
- Maximum: 15MB per file
- This is the entire combined PDF

✅ **Naming Convention**
- OFO number sanitized (special chars removed)
- Paper title sanitized (special chars removed)
- Whitespace converted to underscores

✅ **Backward Compatible**
- Existing uploads not affected
- Old API calls still work

---

## 📋 Checklist

Before uploading, ensure:
- [ ] PDF file is combined (single file)
- [ ] OFO number is correct
- [ ] Paper title is provided
- [ ] File size < 15MB
- [ ] File is PDF format
- [ ] Learner ID is valid
- [ ] Questions list is in JSON array format

---

## 🆘 Troubleshooting

**"File exceeds 15MB limit"**
→ Combine PDFs more efficiently or split into multiple papers

**"Already uploaded"**
→ This question set was already submitted, cannot re-upload

**"Missing required fields"**
→ Check: learnerID, ofo_number, paper_title, exercises, files

**"Invalid file type"**
→ Only PDF files allowed (not image, text, etc.)

**File not saving**
→ Check: ARPL_POE directory exists and is writable (chmod 777)

---

## 📞 Support

| Issue | Solution |
|-------|----------|
| Upload failing | Check server logs in `/logs/php_error_log` |
| File not found | Verify path: `ARPL_POE/All_Questions_...` |
| Database error | Check poe table exists and has correct schema |
| Duplicate rejection | Verify learnerID and ofo_number are same |

---

**Last Updated**: July 6, 2026  
**Version**: 1.0  
**Status**: ✅ Ready
