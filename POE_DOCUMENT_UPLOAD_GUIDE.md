# POE Document Upload System - Complete Guide

## Overview
System for uploading large multi-page POE documents (up to 195 pages) without timeout issues.

## Features
- ✅ Direct upload for files < 50MB
- ✅ Chunked upload for files > 50MB (prevents timeout)
- ✅ Supports PDF and images
- ✅ Maximum file size: 200MB
- ✅ Tracks page count, file size, upload date
- ✅ Links to learner, class, and site

## Setup Instructions

### 1. Create Database Table
```bash
mysql -u root -p your_database < create_poe_documents_table.sql
```

### 2. Create Upload Directory
The PHP script will auto-create, but you can manually create:
```bash
mkdir -p uploads/poe_documents
chmod 777 uploads/poe_documents
```

### 3. Configure PHP Settings
Edit `php.ini` for large file uploads:
```ini
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 300
memory_limit = 256M
```

## API Endpoints

### Upload POE Document
**Endpoint:** `upload_poe_document.php`
**Method:** POST (multipart/form-data)

**Required Fields:**
- `learner_id` - Learner ID number
- `learner_name` - Full name of learner
- `poe_document` - File upload field

**Optional Fields:**
- `document_type` - Default: "POE"
- `page_count` - Number of pages
- `class_id` - Associated class
- `site_name` - Site location
- `uploaded_by` - Username
- `notes` - Additional notes

**Response:**
```json
{
  "success": true,
  "message": "POE document uploaded successfully",
  "document_id": 123,
  "file_name": "POE_12345_1234567890_abc123.pdf",
  "file_size": 52428800,
  "page_count": 195
}
```

### Get POE Documents
**Endpoint:** `get_poe_documents.php`
**Method:** GET

**Parameters:**
- `learner_id` - Filter by learner
- `class_id` - Filter by class
- `document_type` - Filter by type
- `status` - Default: "active"

**Response:**
```json
{
  "success": true,
  "count": 5,
  "documents": [...]
}
```

### Delete POE Document
**Endpoint:** `delete_poe_document.php`
**Method:** POST

**Parameters:**
- `document_id` - ID of document to delete

## Flutter Integration

### For Direct Upload (< 50MB)
```dart
// After scanning with flutter_doc_scanner
final scannedDoc = await DocumentScannerFlutter.launchForPdf();

if (scannedDoc != null) {
  final file = File(scannedDoc);
  final fileSize = await file.length();
  
  // Upload
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/upload_poe_document.php'),
  );
  
  request.fields['learner_id'] = learnerId;
  request.fields['learner_name'] = learnerName;
  request.fields['page_count'] = pageCount.toString();
  request.fields['document_type'] = 'POE';
  
  request.files.add(
    await http.MultipartFile.fromPath('poe_document', file.path)
  );
  
  final response = await request.send();
}
```

### For Chunked Upload (> 50MB)
```dart
// Split file into chunks
const chunkSize = 5 * 1024 * 1024; // 5MB chunks
final fileBytes = await file.readAsBytes();
final totalChunks = (fileBytes.length / chunkSize).ceil();
final fileId = DateTime.now().millisecondsSinceEpoch.toString();

for (int i = 0; i < totalChunks; i++) {
  final start = i * chunkSize;
  final end = min(start + chunkSize, fileBytes.length);
  final chunk = fileBytes.sublist(start, end);
  
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/upload_poe_document.php'),
  );
  
  request.fields['chunk_index'] = i.toString();
  request.fields['total_chunks'] = totalChunks.toString();
  request.fields['file_id'] = fileId;
  request.fields['learner_id'] = learnerId;
  request.fields['learner_name'] = learnerName;
  request.fields['file_extension'] = 'pdf';
  
  if (i == totalChunks - 1) {
    // Last chunk includes metadata
    request.fields['page_count'] = pageCount.toString();
    request.fields['document_type'] = 'POE';
  }
  
  request.files.add(
    http.MultipartFile.fromBytes('chunk', chunk)
  );
  
  await request.send();
}
```

## Testing

1. Run test page:
```
http://your-server/test_poe_document_upload.php
```

2. Test with small file first (< 10MB)
3. Test with large file (> 50MB) using chunked upload

## Troubleshooting

### Upload fails with "File too large"
- Check PHP settings: `upload_max_filesize` and `post_max_size`
- Restart web server after changing php.ini

### Timeout during upload
- Use chunked upload for files > 50MB
- Increase `max_execution_time` in php.ini

### Permission denied
```bash
chmod 777 uploads/poe_documents
```

### Database connection error
- Check connection.php credentials
- Verify table exists: `SHOW TABLES LIKE 'poe_documents'`

## File Size Recommendations

- **1-50 pages:** ~5-15MB (direct upload)
- **51-100 pages:** ~15-30MB (direct upload)
- **101-195 pages:** ~30-60MB (use chunked upload)

## Security Notes

- Files are stored with unique names to prevent overwriting
- MIME type validation prevents malicious uploads
- Only PDF and image files are accepted
- Upload directory should be outside web root in production
