# Pothole Checklist Scanning Feature - Implementation Guide

## Overview
This feature allows users to either:
1. **Fill a checklist** using the system form
2. **Scan a physical checklist** document that was completed outside the system

Both methods support **offline functionality** with automatic sync when online.

---

## Database Structure

### Local SQLite Table: `pothole_checklist_scanned_documents`
```sql
CREATE TABLE pothole_checklist_scanned_documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    learner_id TEXT NOT NULL,
    assessor_id TEXT NOT NULL,
    document_path TEXT NOT NULL,
    assessment_date TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    synced INTEGER DEFAULT 0
);
```

### Server MySQL Table: `pothole_checklist_scanned_documents`
```sql
CREATE TABLE pothole_checklist_scanned_documents (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    assessor_id VARCHAR(50) NOT NULL,
    document_path TEXT NOT NULL,
    assessment_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_learner_assessor_date (learner_id, assessor_id, assessment_date)
);
```

---

## Features

### 1. Open Checklist Button
When clicked, the system:
1. **Checks local database** for scanned documents
2. **Checks server** for system-generated checklists
3. **Shows appropriate dialog**:
   - If checklist exists → Option to view it
   - If no checklist → Options to scan or fill form

### 2. Scan Document
- Uses `flutter_doc_scanner` package
- Saves scanned PDF/image to local storage
- Stores reference in local database
- Automatically syncs to server when online
- Works completely offline

### 3. Fill Form
- Traditional form-based checklist entry
- Saves to server via API
- Existing functionality enhanced

### 4. View Checklist
- **Scanned documents**: Opens PDF/image viewer
- **System checklists**: Loads data into form for viewing

---

## Offline Functionality

### How It Works
1. **Scanning Offline**:
   - Document is scanned and saved locally
   - Record stored in SQLite with `synced = 0`
   - User can continue working

2. **Automatic Sync**:
   - When device comes online
   - Background service detects unsynced records
   - Uploads documents to server
   - Marks as `synced = 1`

3. **Viewing Offline**:
   - Scanned documents are stored locally
   - Can be viewed anytime without internet
   - System checklists require initial download

---

## API Endpoints

### 1. Upload Scanned Document
**Endpoint**: `upload_scanned_pothole_checklist.php`
**Method**: POST (multipart/form-data)
**Parameters**:
- `learner_id` (string)
- `assessor_id` (string)
- `assessment_date` (date: YYYY-MM-DD)
- `document` (file: PDF/JPG/PNG)

**Response**:
```json
{
  "status": "success",
  "message": "Scanned document uploaded successfully",
  "file_path": "/uploads/pothole_checklists/pothole_checklist_123_1234567890.pdf"
}
```

### 2. Check Checklist Status
**Endpoint**: `check_pothole_checklist_status.php`
**Method**: GET
**Parameters**:
- `learner_id` (string)
- `assessor_id` (string)
- `assessment_date` (date: YYYY-MM-DD)

**Response**:
```json
{
  "status": "success",
  "exists": true,
  "type": "scanned",  // or "system" or "none"
  "data": {
    "id": 1,
    "document_path": "/uploads/...",
    "created_at": "2025-11-04 10:30:00"
  }
}
```

### 3. Save System Checklist (Existing)
**Endpoint**: `save_pothole_checklist.php`
**Method**: POST (JSON)
**Parameters**: (existing structure)

### 4. Get System Checklist (Existing)
**Endpoint**: `get_pothole_checklist.php`
**Method**: GET
**Parameters**: (existing structure)

---

## Installation Steps

### 1. Database Setup
Run the SQL file on your server:
```bash
mysql -u root -p rlms < create_pothole_checklist_scanned_table.sql
```

### 2. Upload PHP Files
Copy these files to your server:
- `php/upload_scanned_pothole_checklist.php`
- `php/check_pothole_checklist_status.php`

### 3. Create Upload Directory
```bash
mkdir -p uploads/pothole_checklists
chmod 777 uploads/pothole_checklists
```

### 4. Flutter App
The app is already updated with:
- Database migration (version 5)
- New UI with "Open Checklist" button
- Scanning functionality
- Offline support

---

## User Flow

### Scenario 1: Creating New Checklist
1. User clicks **"Open Checklist"**
2. System checks: No existing checklist found
3. Dialog shows two options:
   - **"Scan Document"** → Opens camera scanner
   - **"Fill Form"** → User fills form on screen
4. User chooses method and completes checklist
5. Data saved locally (offline) or synced (online)

### Scenario 2: Viewing Existing Checklist
1. User clicks **"Open Checklist"**
2. System finds existing checklist (scanned or system)
3. Dialog shows: "Checklist Found"
4. User clicks **"View Checklist"**
5. Document opens in viewer (scanned) or form loads (system)

### Scenario 3: Offline Operation
1. User is offline (no internet)
2. User scans document → Saved locally
3. User can view scanned document anytime
4. When online → Auto-syncs to server
5. Status changes from "unsynced" to "synced"

---

## Testing Checklist

### Test 1: Scan Document (Online)
- [ ] Click "Open Checklist"
- [ ] Select "Scan Document"
- [ ] Scan a physical checklist
- [ ] Verify document saved locally
- [ ] Verify document uploaded to server
- [ ] Check database for record

### Test 2: Scan Document (Offline)
- [ ] Turn off internet
- [ ] Click "Open Checklist"
- [ ] Select "Scan Document"
- [ ] Scan a physical checklist
- [ ] Verify document saved locally
- [ ] Turn on internet
- [ ] Verify auto-sync occurs
- [ ] Check server for uploaded file

### Test 3: Fill Form
- [ ] Click "Open Checklist"
- [ ] Select "Fill Form"
- [ ] Complete all fields
- [ ] Click "Save Checklist"
- [ ] Verify saved to server
- [ ] Re-open and verify data loads

### Test 4: View Scanned Document
- [ ] Create scanned checklist
- [ ] Click "Open Checklist"
- [ ] Verify "Checklist Found" message
- [ ] Click "View Checklist"
- [ ] Verify document opens correctly

### Test 5: View System Checklist
- [ ] Create system checklist (form)
- [ ] Click "Open Checklist"
- [ ] Verify "Checklist Found" message
- [ ] Click "View Checklist"
- [ ] Verify form loads with data

---

## Troubleshooting

### Issue: Scanner not working
**Solution**: Check camera permissions in AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

### Issue: Document not syncing
**Solution**: 
1. Check internet connection
2. Verify server URL in config.dart
3. Check PHP upload directory permissions
4. Review app logs for sync errors

### Issue: Cannot view scanned document
**Solution**:
1. Verify file exists at stored path
2. Check file permissions
3. Ensure PDF viewer app installed
4. Try re-scanning document

### Issue: Database migration fails
**Solution**:
1. Uninstall and reinstall app (dev only)
2. Or manually update database version
3. Check database_helper.dart for errors

---

## Code Structure

### Flutter Files Modified
- `lib/database_helper.dart` - Added scanned document methods
- `lib/potholeChecklistpage.dart` - Added scanning UI and logic

### PHP Files Created
- `php/upload_scanned_pothole_checklist.php` - Upload handler
- `php/check_pothole_checklist_status.php` - Status checker

### SQL Files Created
- `create_pothole_checklist_scanned_table.sql` - Table creation

---

## Future Enhancements

1. **Batch Scanning**: Scan multiple pages into one document
2. **OCR Integration**: Extract text from scanned documents
3. **Image Enhancement**: Auto-crop and enhance scanned images
4. **Cloud Storage**: Store documents in cloud (AWS S3, etc.)
5. **Signature Verification**: Verify signatures on scanned documents
6. **Audit Trail**: Track who viewed/modified checklists
7. **Export Options**: Export checklists as PDF reports

---

## Security Considerations

1. **File Upload Validation**: Only PDF/JPG/PNG allowed
2. **File Size Limits**: Implement max file size (e.g., 10MB)
3. **Access Control**: Verify user permissions before upload/view
4. **Secure Storage**: Store files outside web root if possible
5. **SQL Injection**: All queries use prepared statements
6. **XSS Protection**: Sanitize all user inputs

---

## Performance Optimization

1. **Image Compression**: Compress scanned images before upload
2. **Lazy Loading**: Load documents only when needed
3. **Caching**: Cache frequently accessed documents
4. **Background Sync**: Use WorkManager for efficient syncing
5. **Database Indexing**: Indexes on learner_id, assessment_date

---

## Support

For issues or questions:
1. Check this documentation
2. Review app logs
3. Test API endpoints with Postman
4. Check database records
5. Contact development team

---

**Last Updated**: November 4, 2025
**Version**: 1.0
**Status**: Ready for Testing
