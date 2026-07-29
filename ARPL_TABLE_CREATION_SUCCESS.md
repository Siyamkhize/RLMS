# ARPL POE Unified Table Creation - SUCCESS ✓

**Date**: July 7, 2026
**Status**: COMPLETE AND VERIFIED

## Summary

The ARPL POE unified table has been **successfully created** with all proper foreign key constraints and indexes. The table now supports both theory and practical papers in a single table with optional rating support for practical papers only.

---

## What Was Fixed

### Previous Issues
1. **Foreign Key Error (errno 150)**: "Foreign key constraint is incorrectly formed"
   - **Root Cause**: Column type mismatch or referenced column not being a primary key
   - **Solution**: Verified that `facilitator(facilitator_id)` is INT(11) PRIMARY KEY and `learnerdetails(LearnerID)` is INT(11) PRIMARY KEY

2. **Table References**
   - Corrected references to use:
     - `learnerdetails` table (not `learners`)
     - `facilitator(facilitator_id)` as primary key (lowercase with underscore)

### Resolution Steps Taken
1. Created test script to check database schema
2. Verified facilitator table has `facilitator_id` (INT PRIMARY KEY)
3. Verified learnerdetails table has `LearnerID` (INT PRIMARY KEY)
4. Successfully created `arpl_poe` table with foreign key constraints

---

## Final Table Structure

### arpl_poe Table

| Column | Type | Constraints |
|--------|------|-------------|
| id | INT | PRIMARY KEY, AUTO_INCREMENT |
| learnerID | INT | NOT NULL, FOREIGN KEY → learnerdetails(LearnerID) ON DELETE CASCADE |
| ofo_number | VARCHAR(50) | NOT NULL |
| paper_title | VARCHAR(255) | NOT NULL |
| paper_number | INT | NOT NULL |
| section_type | ENUM('theory','practical') | NOT NULL |
| question_count | INT | DEFAULT 0 |
| combined_pdf_path | VARCHAR(500) | |
| file_name | VARCHAR(500) | |
| upload_status | ENUM('pending','uploaded','synced') | DEFAULT 'pending' |
| rating | DECIMAL(5,2) | DEFAULT NULL (practicals only) |
| rating_status | ENUM('pending_rating','rated','reviewed') | DEFAULT 'pending_rating' |
| assessor_id | INT | FOREIGN KEY → facilitator(facilitator_id) ON DELETE SET NULL |
| assessor_comments | TEXT | |
| rated_at | TIMESTAMP | NULL |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |
| updated_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP ON UPDATE |

### Unique Constraint
```sql
UNIQUE KEY unique_arpl_upload (learnerID, ofo_number, paper_number, section_type)
```
Ensures no duplicate uploads for the same learner, OFO number, paper number, and section type combination.

### Foreign Keys
1. **learnerID → learnerdetails(LearnerID)**
   - Cascade delete: When a learner is deleted, all their ARPL records are deleted
   - Ensures referential integrity

2. **assessor_id → facilitator(facilitator_id)**
   - Set NULL on delete: When a facilitator is deleted, assessor_id becomes NULL
   - Allows marking to be removed without data loss

### Indexes Created
```sql
idx_arpl_poe_learner              (learnerID)
idx_arpl_poe_ofo                  (ofo_number)
idx_arpl_poe_section              (section_type)
idx_arpl_poe_upload_status        (upload_status)
idx_arpl_poe_rating_status        (rating_status)
idx_arpl_poe_assessor             (assessor_id)
idx_arpl_poe_learner_section      (learnerID, section_type)
```

---

## Database Verification

### Table Creation Test Results

```
=== STEP 1: Check Facilitator Table Structure ===
✓ Found PRIMARY KEY: facilitator_id (int(11))
✓ Found column: facilitator_id (int(11))

=== STEP 2: Check Learnerdetails Table Structure ===
✓ Found PRIMARY KEY: LearnerID (int(11))

=== STEP 3: Prepare for Table Creation ===
✓ Dropped existing arpl_poe table (if it existed)

=== STEP 4: Create ARPL POE Table ===
✓ Table created successfully

=== STEP 5: Create Indexes ===
✓ Index created (all 7 indexes)

=== STEP 6: Verify Table Structure ===
✓ Table verified with 17 columns

=== STEP 7: Check Foreign Keys ===
✓ Found foreign keys:
  - arpl_poe_ibfk_1: learnerID -> learnerdetails(LearnerID)
  - arpl_poe_ibfk_2: assessor_id -> facilitator(facilitator_id)
```

### Database Statistics
- **Learners**: 21,329 total records
- **Facilitators**: 187 total records
- **ARPL POE Records**: 0 (ready for uploads)

---

## Related Endpoints

### 1. Upload Combined PDF - `mobile/arpl_save_metadata.php`
Handles theory and practical paper uploads with unified table support:

**Request Parameters**:
- `learnerID`: Student ID (foreign key reference)
- `ofo_number`: Occupational field number
- `paper_title`: Paper name
- `paper_number`: Paper sequence number
- `section_type`: 'theory' or 'practical'
- `question_count`: Number of questions
- `files`: PDF file(s) to upload

**Response**:
```json
{
  "status": "success",
  "message": "Theory paper uploaded successfully",
  "data": {
    "record_id": 123,
    "learnerID": 11515,
    "ofo_number": "9964",
    "section_type": "theory",
    "file_name": "All_Questions_Apply_health_and_safety_to_comply_with_OHSA_9964_theory.pdf",
    "rating_status": null
  }
}
```

### 2. Rate Practical Paper - `mobile/arpl_rate_practical.php`
Updates rating for practical papers only:

**Request Parameters**:
- `record_id`: ARPL POE record ID
- `rating`: Score out of 100
- `assessor_id`: Facilitator ID conducting assessment
- `assessor_comments`: Feedback comments

**Database Update**:
```sql
UPDATE arpl_poe 
SET rating = 85.5, 
    rating_status = 'rated', 
    assessor_id = 1, 
    assessor_comments = 'Good work', 
    rated_at = NOW()
WHERE id = 123 AND section_type = 'practical'
```

### 3. Get Practical Ratings - `mobile/arpl_get_practical_ratings.php`
Retrieves practicals pending rating for assessor marking:

**Query**:
```sql
SELECT * FROM arpl_poe 
WHERE section_type = 'practical' 
  AND rating_status = 'pending_rating' 
ORDER BY learnerID, paper_number
```

---

## Usage Examples

### Example 1: Insert Theory Paper
```sql
INSERT INTO arpl_poe (
    learnerID, ofo_number, paper_title, paper_number, section_type, 
    question_count, combined_pdf_path, file_name, upload_status, rating_status
) VALUES (
    70, '9964', 'Apply health and safety to comply with OHSA', 1, 'theory', 
    15, 'ARPL_POE/file.pdf', 'All_Questions_Apply_health_and_safety_9964_theory.pdf', 'uploaded', NULL
);
```

### Example 2: Insert Practical Paper
```sql
INSERT INTO arpl_poe (
    learnerID, ofo_number, paper_title, paper_number, section_type, 
    question_count, combined_pdf_path, file_name, upload_status, rating_status
) VALUES (
    70, '9964', 'Apply health and safety to comply with OHSA', 1, 'practical', 
    10, 'ARPL_POE/file.pdf', 'All_Questions_Apply_health_and_safety_9964_practical.pdf', 'uploaded', 'pending_rating'
);
```

### Example 3: Get All Papers for a Learner
```sql
SELECT * FROM arpl_poe 
WHERE learnerID = 70 AND ofo_number = '9964' 
ORDER BY paper_number, section_type;
```

### Example 4: Get Statistics by Section
```sql
SELECT 
  section_type,
  COUNT(*) as total_papers,
  SUM(CASE WHEN upload_status = 'uploaded' THEN 1 ELSE 0 END) as uploaded,
  AVG(CASE WHEN rating IS NOT NULL THEN rating ELSE NULL END) as avg_rating
FROM arpl_poe 
WHERE learnerID = 70 AND ofo_number = '9964'
GROUP BY section_type;
```

### Example 5: Rate a Practical Paper
```sql
UPDATE arpl_poe 
SET rating = 85.5, 
    rating_status = 'rated', 
    assessor_id = 6, 
    assessor_comments = 'Excellent performance', 
    rated_at = NOW()
WHERE id = 1 AND section_type = 'practical';
```

---

## Next Steps for Flutter Integration

1. **Update ARPL Upload Screen**
   - Add `section_type` selector (theory/practical)
   - Send parameter to `arpl_save_metadata.php`

2. **Add Assessor Rating UI**
   - List practicals pending rating
   - Show learner name, paper title, upload date
   - Rating input (0-100)
   - Comments textarea
   - Submit to `arpl_rate_practical.php`

3. **Display Marking Status**
   - Show theory papers as "Uploaded" (no rating)
   - Show practical papers with status:
     - "Pending Rating" (waiting for assessor)
     - "Rated: XX/100" (completed)
     - "Reviewed" (final approval)

4. **Query Examples for Flutter**
   - Get papers: `SELECT * FROM arpl_poe WHERE learnerID = ? ORDER BY paper_number, section_type`
   - Get unrated practicals: `SELECT * FROM arpl_poe WHERE section_type = 'practical' AND rating_status = 'pending_rating'`
   - Get learner stats: Count theory vs practical, average rating, upload status

---

## Testing Files

- `test_arpl_table_creation.php` - Table creation verification ✓
- `test_arpl_upload_flow.php` - Full workflow testing
- `diagnose_database_schema.php` - Database schema inspection
- `setup_arpl_poe_table.php` - Production table setup script
- `mobile/arpl_save_metadata.php` - Upload endpoint (COMPLETE)
- `mobile/arpl_rate_practical.php` - Rating endpoint (COMPLETE)
- `mobile/arpl_get_practical_ratings.php` - Query endpoint (COMPLETE)

---

## Status Summary

| Item | Status |
|------|--------|
| Table Creation | ✓ COMPLETE |
| Foreign Key: learnerID | ✓ VERIFIED |
| Foreign Key: assessor_id | ✓ VERIFIED |
| Indexes | ✓ ALL 7 CREATED |
| Unique Constraint | ✓ ACTIVE |
| Upload Endpoint | ✓ READY |
| Rating Endpoint | ✓ READY |
| Query Endpoint | ✓ READY |

---

**All systems are GO for Flutter integration!**
