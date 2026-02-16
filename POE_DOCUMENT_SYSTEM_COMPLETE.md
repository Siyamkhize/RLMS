# POE Document Upload System - Complete Implementation

## ✅ What's Been Created

### 1. Database Table
**File:** `create_poe_documents_table.sql`
- Stores POE documents with full metadata
- Tracks learner, class, site, page count, file size
- Supports up to 195 pages per document
- Indexed for fast queries

### 2. PHP Upload Handler
**File:** `upload_poe_document.php`
- **Direct upload** for files < 50MB
- **Chunked upload** for files > 50MB (prevents timeout)
- Maximum file size: 200MB
- Validates MIME types (PDF, JPEG, PNG)
- Auto-creates upload directory
- Returns document ID and metadata

### 3. PHP Retrieval API
**File:** `get_poe_documents.php`
- Get documents by learner ID
- Filter by class, site, document type
- Returns formatted file sizes
- Includes download URLs

### 4. PHP Delete API
**File:** `delete_poe_document.php`
- Soft delete (mark as deleted)
- Permanent delete (remove file + record)

### 5. Flutter Scanner Widget
**File:** `lib/poe_document_scanner.dart`
- Multi-page scanning (up to 195 pages)
- Automatic PDF conversion
- Progress indicator during upload
- Chunked upload for large files
- Beautiful UI with status messages

### 6. Integration
**File:** `lib/sdp_learners_page.dart` (updated)
- "Scan" button now opens POE document scanner
- Passes learner context (ID, name, class, site)
- Shows success/error messages

### 7. Testing Tools
**File:** `test_poe_document_upload.php`
- Check table structure
- Verify upload directory
- Test upload form
- View existing documents

## 📋 Setup Checklist

### Step 1: Database Setup
```bash
mysql -u root -p your_database < create_poe_documents_table.sql
```

### Step 2: Create Upload Directory
```bash
mkdir -p uploads/poe_documents
chmod 777 uploads/poe_documents
```

### Step 3: Configure PHP (php.ini)
```ini
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 300
memory_limit = 256M
```

Restart web server after changes:
```bash
# Apache
sudo service apache2 restart

# Nginx
sudo service nginx restart
sudo service php-fpm restart
```

### Step 4: Add Flutter Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  cunning_document_scanner: ^1.2.2
  pdf: ^3.10.4
  image: ^4.0.17
  path_provider: ^2.1.1
```

Run:
```bash
flutter pub get
```

### Step 5: Test Upload System
1. Open: `http://your-server/test_poe_document_upload.php`
2. Verify table exists
3. Check upload directory permissions
4. Test with small PDF file first

## 🚀 How It Works

### Scanning Process
1. User clicks "Scan" button on learner row
2. Opens `PoeDocumentScanner` widget
3. User scans pages (up to 195)
4. App converts images to single PDF
5. Checks file size:
   - **< 50MB:** Direct upload
   - **> 50MB:** Chunked upload (5MB chunks)

### Chunked Upload Flow
```
1. Split PDF into 5MB chunks
2. Upload chunk 1 → Server saves to temp
3. Upload chunk 2 → Server saves to temp
4. Upload chunk 3 → Server saves to temp
   ...
N. Upload last chunk → Server merges all chunks
   → Creates final PDF
   → Saves to database
   → Returns success
```

### Why Chunked Upload?
- **Prevents timeout** on slow connections
- **Handles large files** (50-200MB)
- **Shows progress** to user
- **Recoverable** if connection drops

## 📊 File Size Estimates

| Pages | Estimated Size | Upload Method |
|-------|---------------|---------------|
| 1-50  | 5-15 MB       | Direct        |
| 51-100| 15-30 MB      | Direct        |
| 101-150| 30-50 MB     | Direct/Chunked|
| 151-195| 50-80 MB     | Chunked       |

## 🔍 Testing Scenarios

### Test 1: Small Document (10 pages)
```
Expected: Direct upload, < 5 seconds
```

### Test 2: Medium Document (50 pages)
```
Expected: Direct upload, 10-15 seconds
```

### Test 3: Large Document (100 pages)
```
Expected: Chunked upload, 30-60 seconds
Progress bar shows upload status
```

### Test 4: Maximum Document (195 pages)
```
Expected: Chunked upload, 60-120 seconds
Multiple chunks uploaded sequentially
```

## 📱 User Experience

### Before Scanning
- Shows learner info card
- Instructions: "Scan up to 195 pages"
- Blue info card with icon

### During Scanning
- "Scanning..." button with spinner
- Status: "Opening scanner..."
- Scanner opens with camera

### After Scanning
- Green card: "X pages scanned"
- Status: "Converting to PDF..."
- Status: "Ready to upload"
- Upload button appears

### During Upload
- Progress bar (0-100%)
- Status messages:
  - "Preparing upload..."
  - "Uploading..." (direct)
  - "Uploading chunk X of Y..." (chunked)

### After Upload
- Success message
- Returns to learner list
- Green snackbar confirmation

## 🔧 Troubleshooting

### "Upload failed: File too large"
- Check PHP settings: `upload_max_filesize`
- Increase to 200M or higher

### "Timeout during upload"
- Chunked upload should prevent this
- Check `max_execution_time` in php.ini
- Verify network connection

### "Permission denied"
```bash
chmod 777 uploads/poe_documents
```

### "Table doesn't exist"
```bash
mysql -u root -p your_database < create_poe_documents_table.sql
```

### "Scanner not opening"
- Check camera permissions in AndroidManifest.xml
- Verify `cunning_document_scanner` dependency

## 📂 File Structure

```
Server:
├── upload_poe_document.php       (Upload handler)
├── get_poe_documents.php         (Retrieval API)
├── delete_poe_document.php       (Delete API)
├── test_poe_document_upload.php  (Testing tool)
├── create_poe_documents_table.sql (Database schema)
└── uploads/
    └── poe_documents/            (Storage directory)
        ├── POE_12345_1234567890_abc.pdf
        └── temp/                 (Chunked upload temp)

Flutter:
└── lib/
    ├── poe_document_scanner.dart (Scanner widget)
    └── sdp_learners_page.dart    (Updated integration)
```

## 🎯 Next Steps

1. **Deploy to server:**
   - Upload PHP files
   - Create database table
   - Set up upload directory

2. **Build Flutter app:**
   ```bash
   flutter build apk --release
   ```

3. **Test with real data:**
   - Scan 10-page document
   - Scan 50-page document
   - Scan 100+ page document

4. **Monitor performance:**
   - Check upload times
   - Verify file sizes
   - Test on slow connections

## 💡 Future Enhancements

- [ ] Resume interrupted uploads
- [ ] Compress images before PDF conversion
- [ ] OCR text extraction
- [ ] Document preview before upload
- [ ] Batch upload multiple documents
- [ ] Download documents in app
- [ ] Document versioning

## ✅ Summary

You now have a complete system for scanning and uploading large POE documents (up to 195 pages) without timeout issues. The chunked upload mechanism ensures reliable uploads even on slow connections, and the Flutter UI provides clear feedback throughout the process.

**Key Features:**
- ✅ Scan up to 195 pages
- ✅ Automatic PDF conversion
- ✅ Chunked upload (no timeout)
- ✅ Progress tracking
- ✅ Learner context tracking
- ✅ Beautiful UI
- ✅ Error handling
