# Diagnose: Scanned Document Not Displaying

## Current Situation
- ✅ Endpoint is working (HTTP 200)
- ✅ No PHP errors
- ❌ Scanned document not showing for learner 70
- ✅ System-generated checklist works for learner 75

## Possible Causes

### 1. No Data in Database
The most likely cause - the scanned document was never uploaded to the database.

### 2. Wrong Learner ID
The document exists but for a different learner ID.

### 3. Data Format Issue
The document path or other fields have incorrect format.

## Diagnostic Steps

### Step 1: Check Database
Run the SQL queries in `check_scanned_documents.sql`:

```sql
-- Quick check
SELECT * FROM pothole_checklist_scanned_documents;
```

**Expected Results:**

**If table is empty:**
```
Empty set (0 rows)
```
→ **Solution:** You need to upload/scan a document first

**If table has data:**
```
| id | learner_id | assessor_id | document_path | assessment_date | created_at |
|----|------------|-------------|---------------|-----------------|------------|
| 1  | 1231       | 6           | ../uploads... | 2025-11-06      | 2025-11-06 |
```
→ **Check:** Does learner_id match the one you're testing?

### Step 2: Verify Document Upload Process

The scanned document should be uploaded through one of these methods:

**Method 1: Via App (Learner uploads)**
1. Learner opens pothole checklist page
2. Scans document using camera
3. Document is saved locally
4. Synced to server
5. Record created in `pothole_checklist_scanned_documents`

**Method 2: Via PHP Upload Endpoint**
```
POST /upload_scanned_pothole_checklist.php
```

**Check if this endpoint exists and is working.**

### Step 3: Test with Known Data

If you know the document exists at:
```
../uploads/pothole_checklists/pothole_checklist_1231_1762330576.pdf
```

Manually insert a test record:

```sql
INSERT INTO pothole_checklist_scanned_documents 
(learner_id, assessor_id, document_path, assessment_date)
VALUES 
('70', '6', '../uploads/pothole_checklists/pothole_checklist_1231_1762330576.pdf', '2025-11-06');
```

Then test again in the app.

### Step 4: Check Upload Endpoint

Verify the upload endpoint exists:
```
php/upload_scanned_pothole_checklist.php
```

Test it:
```bash
curl -X POST https://rlms.rlms.co.za/mobile/upload_scanned_pothole_checklist.php \
  -F "learner_id=70" \
  -F "assessor_id=6" \
  -F "document=@/path/to/test.pdf"
```

### Step 5: Check File Permissions

Verify the uploads directory exists and is writable:
```bash
ls -la /path/to/uploads/pothole_checklists/
```

Should show:
```
drwxrwxrwx  uploads/pothole_checklists/
-rw-r--r--  pothole_checklist_1231_1762330576.pdf
```

## Common Issues and Solutions

### Issue 1: Table Doesn't Exist
**Symptom:** SQL error "Table doesn't exist"

**Solution:** Run the table creation script:
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

### Issue 2: Table is Empty
**Symptom:** Query returns 0 rows

**Solution:** Upload a document through the app or manually insert test data.

### Issue 3: Wrong Learner ID Format
**Symptom:** Data exists but not found

**Check:**
```sql
-- What format is in database?
SELECT DISTINCT learner_id FROM pothole_checklist_scanned_documents;

-- Result might be: '1231' instead of '70'
```

**Solution:** Use the correct learner_id when testing.

### Issue 4: Document Not Uploaded Yet
**Symptom:** No records in database

**Solution:** 
1. Open the app as a learner
2. Navigate to pothole checklist page
3. Scan/upload a document
4. Verify it syncs to server
5. Check database again

## Quick Test Script

Create a test record to verify the system works:

```sql
-- Insert test data
INSERT INTO pothole_checklist_scanned_documents 
(learner_id, assessor_id, document_path, assessment_date)
VALUES 
('70', '6', '../uploads/pothole_checklists/test_document.pdf', CURDATE());

-- Verify it was inserted
SELECT * FROM pothole_checklist_scanned_documents WHERE learner_id = '70';

-- Test the endpoint
-- Open in browser: https://rlms.rlms.co.za/mobile/view_pothole_checklists.php?learner_id=70
```

Expected response:
```json
{
  "status": "success",
  "data": {
    "type": "scanned",
    "learner_id": "70",
    "document_path": "../uploads/pothole_checklists/test_document.pdf",
    ...
  }
}
```

## Verification Checklist

Run through this checklist:

- [ ] Table `pothole_checklist_scanned_documents` exists
- [ ] Table has correct structure (id, learner_id, assessor_id, document_path, assessment_date, created_at)
- [ ] Table has at least one record
- [ ] Record exists for the learner you're testing
- [ ] `document_path` field is not empty
- [ ] File actually exists at the path specified
- [ ] Endpoint returns HTTP 200
- [ ] Endpoint returns valid JSON
- [ ] Response has `type: 'scanned'`

## Next Steps

1. **Run the SQL queries** in `check_scanned_documents.sql`
2. **Share the results** - How many records? What learner_ids?
3. **If empty** - We need to upload a document first
4. **If has data** - We need to test with the correct learner_id

## Summary

The code is working correctly. The issue is likely:
- ✅ **Most likely:** No data in database yet
- ⚠️ **Possible:** Testing with wrong learner_id
- ⚠️ **Possible:** Document upload process not working

Run the diagnostic SQL queries to identify which one it is!
