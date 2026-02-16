# POE Document System - Quick Reference

## 🎯 Can I Scan 195 Pages Without Timeout?

**YES!** The system uses **chunked upload** to handle large files.

### How It Works:
- Files < 50MB: Direct upload (fast)
- Files > 50MB: Split into 5MB chunks (prevents timeout)
- Maximum: 200MB (approximately 195 pages)

## 📦 What Was Created

| File | Purpose |
|------|---------|
| `create_poe_documents_table.sql` | Database table |
| `upload_poe_document.php` | Upload handler (chunked) |
| `get_poe_documents.php` | Retrieve documents |
| `delete_poe_document.php` | Delete documents |
| `test_poe_document_upload.php` | Testing tool |
| `lib/poe_document_scanner.dart` | Flutter scanner |
| `lib/sdp_learners_page.dart` | Updated (uses new scanner) |

## ⚡ Quick Setup

### 1. Database
```bash
mysql -u root -p your_database < create_poe_documents_table.sql
```

### 2. Upload Directory
```bash
mkdir -p uploads/poe_documents
chmod 777 uploads/poe_documents
```

### 3. PHP Settings (php.ini)
```ini
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 300
```

### 4. Flutter Dependencies (pubspec.yaml)
**Already installed!** No changes needed. Your project already has:
- flutter_doc_scanner: ^0.0.8
- pdf: ^3.6.0
- image: ^4.0.18
- path_provider: ^2.1.5

### 5. Install & Build
```bash
flutter pub get
flutter build apk --release
```

**Note:** No new dependencies needed - you already have everything!

## 🧪 Testing

### Test Page
```
http://your-server/test_poe_document_upload.php
```

### Test Scenarios
1. ✅ Scan 10 pages (small test)
2. ✅ Scan 50 pages (medium test)
3. ✅ Scan 100+ pages (large test)

## 📊 Upload Times (Estimated)

| Pages | Size | Method | Time |
|-------|------|--------|------|
| 10 | ~3 MB | Direct | 5s |
| 50 | ~15 MB | Direct | 15s |
| 100 | ~30 MB | Direct | 30s |
| 150 | ~50 MB | Chunked | 60s |
| 195 | ~70 MB | Chunked | 90s |

## 🔧 Common Issues

### Upload Fails
```bash
# Check PHP settings
php -i | grep upload_max_filesize
php -i | grep post_max_size

# Restart web server
sudo service apache2 restart
```

### Permission Error
```bash
chmod 777 uploads/poe_documents
```

### Table Missing
```bash
mysql -u root -p your_database < create_poe_documents_table.sql
```

## 📱 User Flow

1. Open SDP Learners page
2. Click "Scan" button on learner row
3. Scanner opens (can scan up to 195 pages)
4. Scan pages one by one
5. App converts to PDF
6. Click "Upload Document"
7. Progress bar shows upload status
8. Success message appears
9. Document saved to database

## 🎨 UI Features

- ✅ Learner info card
- ✅ Page counter
- ✅ Upload progress bar
- ✅ Status messages
- ✅ Error handling
- ✅ Success confirmation

## 📋 API Endpoints

### Upload
```
POST /upload_poe_document.php
Fields: learner_id, learner_name, poe_document (file)
Optional: class_id, site_name, page_count
```

### Get Documents
```
GET /get_poe_documents.php?learner_id=12345
Optional: class_id, document_type, status
```

### Delete
```
POST /delete_poe_document.php
Fields: document_id, permanent (true/false)
```

## 💾 Database Schema

```sql
poe_documents
├── id (PK)
├── learner_id
├── learner_name
├── document_type (POE, SDP, Other)
├── file_name
├── file_path
├── file_size (bytes)
├── page_count
├── mime_type
├── uploaded_by
├── upload_date
├── class_id
├── site_name
├── status (active, archived, deleted)
└── notes
```

## 🚀 Deployment Checklist

- [ ] Create database table
- [ ] Create upload directory
- [ ] Configure PHP settings
- [ ] Upload PHP files to server
- [ ] Add Flutter dependencies
- [ ] Update pubspec.yaml
- [ ] Run flutter pub get
- [ ] Test with test_poe_document_upload.php
- [ ] Build APK
- [ ] Test scanning in app
- [ ] Test upload with 10 pages
- [ ] Test upload with 100+ pages

## 📞 Support

See full documentation: `POE_DOCUMENT_UPLOAD_GUIDE.md`
Complete implementation: `POE_DOCUMENT_SYSTEM_COMPLETE.md`
