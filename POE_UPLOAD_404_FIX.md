# POE Upload 404 Error - Fixed

## Problem
Getting 404 error when uploading POE documents.

## Cause
The `upload_poe_document.php` file needs to be uploaded to the correct server location.

## Solution

### 1. Upload PHP File to Server
Upload `upload_poe_document.php` to:
```
https://rlms.rlms.co.za/mobile/upload_poe_document.php
```

**Server path:** `/mobile/upload_poe_document.php`

### 2. Also Upload These Files
- `get_poe_documents.php` → `/mobile/get_poe_documents.php`
- `delete_poe_document.php` → `/mobile/delete_poe_document.php`

### 3. Create Database Table
Run on your server database:
```bash
mysql -u your_user -p your_database < create_poe_documents_table.sql
```

### 4. Create Upload Directory
On your server, create:
```bash
mkdir -p /path/to/web/root/mobile/uploads/poe_documents
chmod 777 /path/to/web/root/mobile/uploads/poe_documents
```

### 5. Test the Upload
Open in browser:
```
https://rlms.rlms.co.za/mobile/test_poe_document_upload.php
```

This will verify:
- ✓ PHP file exists
- ✓ Database table exists
- ✓ Upload directory exists and is writable
- ✓ PHP settings are correct

### 6. Rebuild Flutter App
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

### 7. Test in App
1. Install APK on device
2. Open SDP Learners page
3. Click "Scan" on any learner
4. Scan a document
5. Click "Upload Document"
6. Should upload successfully!

## Current Configuration

**App URL:** `https://rlms.rlms.co.za/mobile/upload_poe_document.php`

The app now uses `AppConfig.baseUrl` which automatically builds the correct URL based on your config.dart settings.

## Troubleshooting

### Still Getting 404?
1. Check file exists on server:
```bash
ls -la /path/to/web/root/mobile/upload_poe_document.php
```

2. Check file permissions:
```bash
chmod 644 /path/to/web/root/mobile/upload_poe_document.php
```

3. Test directly in browser:
```
https://rlms.rlms.co.za/mobile/upload_poe_document.php
```
Should show: "Method not allowed" or similar (not 404)

### Getting 500 Error?
Check PHP error log:
```bash
tail -f /var/log/apache2/error.log
# or
tail -f /var/log/nginx/error.log
```

### Upload Directory Error?
```bash
mkdir -p uploads/poe_documents
chmod 777 uploads/poe_documents
chown www-data:www-data uploads/poe_documents
```

## Files to Upload

```
Server: rlms.rlms.co.za
Directory: /mobile/

Files:
├── upload_poe_document.php       ← Main upload handler
├── get_poe_documents.php         ← Retrieve documents
├── delete_poe_document.php       ← Delete documents
├── test_poe_document_upload.php  ← Testing tool
└── uploads/
    └── poe_documents/            ← Upload directory (777)
```

## Database Setup

```sql
-- Run this on your server database
CREATE TABLE IF NOT EXISTS poe_documents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    learner_name VARCHAR(255) NOT NULL,
    document_type VARCHAR(50) DEFAULT 'POE',
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size BIGINT NOT NULL,
    page_count INT DEFAULT 0,
    mime_type VARCHAR(100) DEFAULT 'application/pdf',
    uploaded_by VARCHAR(100),
    upload_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    class_id VARCHAR(50),
    site_name VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_learner_id (learner_id),
    INDEX idx_class_id (class_id),
    INDEX idx_upload_date (upload_date),
    INDEX idx_status (status)
);
```

## Summary

✅ **Fixed:** App now uses correct URL from AppConfig
✅ **Next:** Upload PHP files to server
✅ **Then:** Create database table
✅ **Finally:** Test upload in app

The 404 error will be resolved once you upload the PHP file to the correct server location!
