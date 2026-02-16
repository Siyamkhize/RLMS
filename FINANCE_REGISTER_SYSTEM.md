# Finance Register Scanning System

## Overview
Complete implementation of a finance role that allows scanning and managing learner attendance registers.

## Features
- Finance users can view all classes
- View learners per class with register count
- Scan multiple registers per learner
- Month/Year selection (Year fixed to 2024)
- Document scanning using flutter_doc_scanner
- Upload and store scanned registers
- View history of scanned registers

## Files Created

### Flutter (Dart) Files
1. **lib/finance_dashboard.dart** - Main dashboard showing all classes
2. **lib/finance_learner_list.dart** - List of learners in a class
3. **lib/finance_register_scanner.dart** - Register scanning and management

### PHP Backend Files
1. **get_finance_classes.php** - Fetch all classes with learner counts
2. **get_finance_learners.php** - Fetch learners in a class with register counts
3. **get_learner_registers.php** - Fetch all registers for a learner
4. **upload_learner_register.php** - Upload scanned register

### Database
1. **create_learner_registers_table.sql** - Database schema

## Database Schema

```sql
CREATE TABLE learner_registers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    class_id VARCHAR(50) NOT NULL,
    finance_id VARCHAR(50),
    register_month INT NOT NULL,
    register_year INT NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_learner_month_year (learner_id, register_month, register_year)
);
```

## Setup Instructions

### 1. Database Setup
Run the SQL file to create the table:
```bash
mysql -u username -p database_name < create_learner_registers_table.sql
```

Or execute in phpMyAdmin/MySQL Workbench.

### 2. Create Finance User
Add a finance user to your users table:
```sql
INSERT INTO users (email, password, role, name, surname) 
VALUES ('finance@example.com', MD5('password123'), 'finance', 'Finance', 'User');
```

### 3. Upload PHP Files
Upload these files to your server at `rlms.rlms.co.za/mobile/`:
- get_finance_classes.php
- get_finance_learners.php
- get_learner_registers.php
- upload_learner_register.php

### 4. Create Upload Directory
Create the uploads directory on your server:
```bash
mkdir -p uploads/registers
chmod 777 uploads/registers
```

Or use PHP:
```php
<?php
$dir = 'uploads/registers';
if (!file_exists($dir)) {
    mkdir($dir, 0777, true);
}
?>
```

### 5. Rebuild Flutter App
```bash
flutter clean
flutter pub get
flutter build apk
```

## User Flow

### Finance Login
1. Finance user logs in with credentials
2. System checks role = 'finance'
3. Redirects to Finance Dashboard

### View Classes
1. Finance Dashboard shows all classes
2. Each class card shows:
   - Class name
   - Number of learners
   - Tap to view learners

### View Learners
1. Select a class
2. See list of all learners with:
   - Learner name
   - ID number
   - Number of registers scanned
   - "Scan" button

### Scan Register
1. Tap "Scan" button for a learner
2. Month/Year picker appears (Year = 2024)
3. Select month (January - December)
4. Tap "Continue"
5. Document scanner opens
6. Scan the register
7. Image is uploaded to server
8. Success message shown
9. Register list refreshes

### View Register History
1. After scanning, registers appear in list
2. Each register shows:
   - Month and Year
   - Upload date
   - File name
   - Check mark icon

## API Endpoints

### 1. Get Classes
```
GET /mobile/get_finance_classes.php
```

**Response:**
```json
[
  {
    "class_id": "1",
    "class_name": "Class A",
    "learner_count": "25"
  }
]
```

### 2. Get Learners
```
GET /mobile/get_finance_learners.php?classID=1
```

**Response:**
```json
[
  {
    "learner_id": "123",
    "name": "John",
    "surname": "Doe",
    "id_number": "9901015800080",
    "class_id": "1",
    "register_count": "3"
  }
]
```

### 3. Get Registers
```
GET /mobile/get_learner_registers.php?learner_id=123
```

**Response:**
```json
[
  {
    "id": "1",
    "learner_id": "123",
    "class_id": "1",
    "finance_id": "456",
    "register_month": "1",
    "register_year": "2024",
    "file_name": "register_123_2024_01_1234567890.jpg",
    "file_path": "uploads/registers/register_123_2024_01_1234567890.jpg",
    "uploaded_at": "2024-01-15 10:30:00"
  }
]
```

### 4. Upload Register
```
POST /mobile/upload_learner_register.php
```

**Parameters:**
- learner_id (string)
- class_id (string)
- finance_id (string)
- register_month (int) - 1-12
- register_year (int) - 2024
- register_file (file)

**Response:**
```json
{
  "success": true,
  "message": "Register uploaded successfully",
  "register_id": 1
}
```

## Testing

### Test Finance Login
1. Create finance user in database
2. Login with finance credentials
3. Should see Finance Dashboard

### Test Class List
```bash
curl https://rlms.rlms.co.za/mobile/get_finance_classes.php
```

### Test Learner List
```bash
curl "https://rlms.rlms.co.za/mobile/get_finance_learners.php?classID=1"
```

### Test Register Upload
```bash
curl -X POST https://rlms.rlms.co.za/mobile/upload_learner_register.php \
  -F "learner_id=123" \
  -F "class_id=1" \
  -F "finance_id=456" \
  -F "register_month=1" \
  -F "register_year=2024" \
  -F "register_file=@/path/to/image.jpg"
```

## Features Implemented

✅ Finance role authentication
✅ Class listing with learner counts
✅ Learner listing with register counts
✅ Month/Year picker (Year = 2024)
✅ Document scanning with flutter_doc_scanner
✅ Register upload with validation
✅ Duplicate prevention (one register per month/year)
✅ Register history view
✅ Automatic file naming
✅ Upload directory creation
✅ Error handling
✅ Loading states
✅ Success/error messages
✅ Pull to refresh

## Security Considerations

1. **File Upload Validation**
   - Check file type
   - Limit file size
   - Sanitize filenames

2. **Access Control**
   - Verify finance role before allowing access
   - Add finance_id to all queries

3. **SQL Injection Prevention**
   - All queries use prepared statements
   - Parameters are properly escaped

4. **File Storage**
   - Files stored outside web root (recommended)
   - Unique filenames prevent overwrites
   - Directory permissions set correctly

## Troubleshooting

### Issue: "No classes found"
**Solution:** Check if classes table has data

### Issue: "Upload failed"
**Solution:** 
- Check uploads/registers directory exists
- Check directory permissions (777)
- Check PHP upload_max_filesize setting

### Issue: "Scanner not working"
**Solution:**
- Check camera permissions
- Ensure flutter_doc_scanner is in pubspec.yaml
- Run flutter pub get

### Issue: "Finance role not working"
**Solution:**
- Check users table has role column
- Verify user role = 'finance'
- Check login.php returns role correctly

## Future Enhancements

- [ ] View/download scanned registers
- [ ] Delete registers
- [ ] Filter by month/year
- [ ] Export register list
- [ ] Add notes to registers
- [ ] Bulk upload
- [ ] Register approval workflow
- [ ] Email notifications
- [ ] Analytics dashboard
- [ ] Multi-year support

## Support

For issues or questions:
1. Check this documentation
2. Review error logs
3. Test API endpoints directly
4. Check database records

## Version History

**v1.0.0** - December 20, 2024
- Initial implementation
- Basic scanning functionality
- Month/Year selection (2024)
- Upload and storage
- Register history

