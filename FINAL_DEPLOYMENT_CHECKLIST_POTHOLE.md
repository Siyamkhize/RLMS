# Final Deployment Checklist - Pothole Checklist System

## Current Status
❌ **HTTP 500 Error** - The `view_pothole_checklists.php` file is not on the server or has an error.

## Files to Upload to Server

### 1. Main Endpoint (REQUIRED)
**File:** `view_pothole_checklists.php` (from workspace root)
**Upload to:** `rlms.rlms.co.za/mobile/view_pothole_checklists.php`
**Purpose:** Retrieves both scanned and system-generated checklists

### 2. Marking Endpoints (REQUIRED)
**Files:**
- `php/save_pothole_checklist_marks.php`
- `php/get_pothole_checklist_marks.php`

**Upload to:**
- `rlms.rlms.co.za/mobile/save_pothole_checklist_marks.php`
- `rlms.rlms.co.za/mobile/get_pothole_checklist_marks.php`

**Purpose:** Save and retrieve marks for checklists

### 3. Database Tables (REQUIRED)
Run these SQL scripts on your server database:

**File:** `create_pothole_checklist_scanned_table.sql`
```sql
CREATE TABLE IF NOT EXISTS pothole_checklist_scanned_documents (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    assessor_id VARCHAR(50) NOT NULL,
    document_path TEXT NOT NULL,
    assessment_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_learner_assessor_date (learner_id, assessor_id, assessment_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**File:** `create_pothole_checklist_marks_table.sql`
```sql
CREATE TABLE IF NOT EXISTS pothole_checklist_marks (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    assessor_id VARCHAR(50) NOT NULL,
    assessment_date DATE NOT NULL,
    marks INT(11) NOT NULL,
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_marking (learner_id, assessor_id, assessment_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## Deployment Steps

### Step 1: Upload PHP Files
1. Connect to your server via FTP/SFTP or cPanel
2. Navigate to `/mobile/` directory
3. Upload these files:
   - `view_pothole_checklists.php` (from workspace root)
   - `save_pothole_checklist_marks.php` (from php/ folder)
   - `get_pothole_checklist_marks.php` (from php/ folder)

### Step 2: Create Database Tables
1. Log into phpMyAdmin or MySQL console
2. Select your database
3. Run the SQL scripts above to create the tables

### Step 3: Verify File Permissions
Ensure uploaded files have correct permissions:
```bash
chmod 644 view_pothole_checklists.php
chmod 644 save_pothole_checklist_marks.php
chmod 644 get_pothole_checklist_marks.php
```

### Step 4: Test Endpoints

**Test 1: View Checklist Endpoint**
```
https://rlms.rlms.co.za/mobile/view_pothole_checklists.php?learner_id=70
```

Expected response (if data exists):
```json
{
  "status": "success",
  "data": {
    "type": "scanned",
    "learner_id": "70",
    "document_path": "../uploads/pothole_checklists/...",
    ...
  }
}
```

Or if no data:
```json
{
  "status": "error",
  "message": "No checklist found for the specified parameters"
}
```

**Test 2: Get Marks Endpoint**
```
https://rlms.rlms.co.za/mobile/get_pothole_checklist_marks.php?learner_id=70&assessor_id=6&assessment_date=2025-11-06
```

### Step 5: Test in Flutter App
1. Restart the Flutter app
2. Navigate to learner 70's POE tab
3. Should see checklist section
4. Tap to view and mark

## Troubleshooting

### If you get HTTP 500:
1. Check PHP error logs on server
2. Verify `config.php` exists in `/mobile/` directory
3. Check database credentials in `config.php`
4. Ensure all required PHP extensions are installed

### If you get HTTP 404:
1. Verify file was uploaded to correct location
2. Check file name is exactly `view_pothole_checklists.php`
3. Ensure file is in `/mobile/` not `/mobile/php/`

### If you get "No checklist found":
1. Check database has data in tables
2. Verify learner_id matches database records
3. Run SQL query to check:
```sql
SELECT * FROM pothole_checklist_scanned_documents WHERE learner_id = '70';
SELECT * FROM pothole_checklists WHERE learner_id = '70';
```

## Quick Test SQL

To verify tables exist and have data:
```sql
-- Check if tables exist
SHOW TABLES LIKE 'pothole%';

-- Check scanned documents
SELECT COUNT(*) as scanned_count FROM pothole_checklist_scanned_documents;

-- Check system checklists
SELECT COUNT(*) as system_count FROM pothole_checklists;

-- Check marks
SELECT COUNT(*) as marks_count FROM pothole_checklist_marks;
```

## File Checklist

Before deploying, verify you have:
- [ ] `view_pothole_checklists.php` (root level, not in php/ folder)
- [ ] `save_pothole_checklist_marks.php`
- [ ] `get_pothole_checklist_marks.php`
- [ ] SQL scripts ready to run
- [ ] Server access (FTP/SFTP/cPanel)
- [ ] Database access (phpMyAdmin/MySQL)

## After Deployment

Once files are uploaded and tables created:
1. Test endpoints in browser (see Test 1 & 2 above)
2. Restart Flutter app
3. Test with learner who has checklist data
4. Verify both viewing and marking work

## Support Files Location

All files are in your workspace:
- **Root level:** `view_pothole_checklists.php`
- **php/ folder:** `save_pothole_checklist_marks.php`, `get_pothole_checklist_marks.php`
- **SQL scripts:** `create_pothole_checklist_scanned_table.sql`, `create_pothole_checklist_marks_table.sql`

## Status
⏳ **AWAITING DEPLOYMENT**

Upload the files to your server and create the database tables. Once deployed, the system will work correctly.
