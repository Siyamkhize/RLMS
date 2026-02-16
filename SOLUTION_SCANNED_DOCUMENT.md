# Solution: Scanned Document Not Displaying

## Problem Identified
✅ **File exists on server:** `/public_html/rlms.rlms.co.za/uploads/pothole_checklists/pothole_checklist_70_1762423169.pdf`
❌ **Database record missing:** No entry in `pothole_checklist_scanned_documents` table

## Why This Happens
The file was uploaded to the server, but the database record wasn't created. This can happen if:
1. Upload process was interrupted
2. Database insert failed silently
3. File was manually uploaded without creating database record

## Solution

### Step 1: Insert Database Record
Run this SQL query:

```sql
INSERT INTO pothole_checklist_scanned_documents 
(learner_id, assessor_id, document_path, assessment_date, created_at)
VALUES 
('70', '6', '../uploads/pothole_checklists/pothole_checklist_70_1762423169.pdf', CURDATE(), NOW());
```

### Step 2: Verify Record Created
```sql
SELECT * FROM pothole_checklist_scanned_documents WHERE learner_id = '70';
```

Should return:
```
| id | learner_id | assessor_id | document_path                                                  | assessment_date | created_at          |
|----|------------|-------------|----------------------------------------------------------------|-----------------|---------------------|
| 1  | 70         | 6           | ../uploads/pothole_checklists/pothole_checklist_70_1762423169.pdf | 2025-11-06      | 2025-11-06 15:30:00 |
```

### Step 3: Test in App
1. Restart Flutter app (or just navigate away and back)
2. Open learner 70's POE tab
3. Should now see "View Pothole Checklist" button
4. Tap to open scanned document viewer
5. Tap "Open PDF Document" to view the PDF

## Path Explanation

**Server file path:**
```
/public_html/rlms.rlms.co.za/uploads/pothole_checklists/pothole_checklist_70_1762423169.pdf
```

**Database path (relative):**
```
../uploads/pothole_checklists/pothole_checklist_70_1762423169.pdf
```

**Why relative path?**
- PHP scripts run from `/public_html/rlms.rlms.co.za/mobile/`
- `../` means "go up one directory" to `/public_html/rlms.rlms.co.za/`
- Then access `uploads/pothole_checklists/...`

**Full URL (for downloading):**
```
https://rlms.rlms.co.za/uploads/pothole_checklists/pothole_checklist_70_1762423169.pdf
```

## Testing the Fix

### Test 1: Endpoint
```
https://rlms.rlms.co.za/mobile/view_pothole_checklists.php?learner_id=70
```

Expected response:
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "type": "scanned",
    "learner_id": "70",
    "assessor_id": "6",
    "assessment_date": "2025-11-06",
    "document_path": "../uploads/pothole_checklists/pothole_checklist_70_1762423169.pdf",
    "created_at": "2025-11-06 15:30:00"
  }
}
```

### Test 2: File Access
```
https://rlms.rlms.co.za/uploads/pothole_checklists/pothole_checklist_70_1762423169.pdf
```

Should download/display the PDF file.

### Test 3: Flutter App
1. Open app
2. Navigate to learner 70's POE tab
3. See "Scanned Document" button
4. Tap to view
5. Tap "Open PDF Document"
6. PDF should download and open
7. Enter marks and save

## Preventing This Issue

To prevent files without database records in the future:

### Option 1: Fix Upload Endpoint
Ensure `upload_scanned_pothole_checklist.php` creates database record atomically:

```php
// Upload file
move_uploaded_file($tmpFile, $targetPath);

// Create database record (in same transaction)
$stmt = $conn->prepare("INSERT INTO pothole_checklist_scanned_documents ...");
$stmt->execute();

// If either fails, rollback both
```

### Option 2: Add Verification Script
Create a script to find orphaned files:

```php
// Find files without database records
$files = glob('../uploads/pothole_checklists/*.pdf');
foreach ($files as $file) {
    // Check if database record exists
    // If not, create it or alert admin
}
```

## Summary

**The Fix:**
1. ✅ File exists on server
2. ❌ Database record missing
3. 🔧 **Solution:** Insert database record manually
4. ✅ System will work after record is created

**Run the SQL insert query and the scanned document will appear in the app!**
