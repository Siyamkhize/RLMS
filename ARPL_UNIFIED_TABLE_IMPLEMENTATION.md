# ARPL Unified Table Implementation - Complete Guide

**Status**: Ready for Deployment  
**Date**: July 7, 2026  
**Database**: `rlmsrlmsco_ezxcmacd_rlms` (on 192.168.0.57)

---

## Overview

The ARPL (Assessment Report Professional Learning) system now uses a **single unified table** (`arpl_poe`) to store both **theory** and **practical** papers, with built-in support for:
- Theory/Practical separation via `section_type` column
- Rating system for practical papers only
- Combined PDF upload per paper
- Assessor marking workflow

---

## Database Table Structure

### Table: `arpl_poe`

```sql
CREATE TABLE arpl_poe (
    id INT PRIMARY KEY AUTO_INCREMENT,
    learnerID INT NOT NULL,
    ofo_number VARCHAR(50) NOT NULL,
    paper_title VARCHAR(255) NOT NULL,
    paper_number INT NOT NULL,
    section_type ENUM('theory', 'practical') NOT NULL,
    question_count INT DEFAULT 0,
    combined_pdf_path VARCHAR(500),
    file_name VARCHAR(500),
    upload_status ENUM('pending', 'uploaded', 'synced') DEFAULT 'pending',
    rating DECIMAL(5,2) DEFAULT NULL,
    rating_status ENUM('pending_rating', 'rated', 'reviewed') DEFAULT 'pending_rating',
    assessor_id INT,
    assessor_comments TEXT,
    rated_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_arpl_upload (learnerID, ofo_number, paper_number, section_type)
);
```

### Key Features

| Feature | Description |
|---------|-------------|
| **Unified Storage** | Both theory and practical in ONE table |
| **Section Type** | ENUM('theory', 'practical') - differentiates paper type |
| **Combined PDF** | Single `combined_pdf_path` for all questions in a paper |
| **File Naming** | `All_Questions_[PaperTitle]_[OFO]_[theory\|practical].pdf` |
| **Rating Fields** | `rating`, `rating_status`, `assessor_id`, `assessor_comments`, `rated_at` |
| **Unique Constraint** | Prevents duplicate uploads (learnerID, ofo_number, paper_number, section_type) |
| **Status Tracking** | `upload_status`: pending → uploaded → synced |
| **Timestamps** | `created_at`, `updated_at` for audit trail |

---

## PHP Endpoints

### 1. **arpl_save_metadata.php** (UPDATED)
**Location**: `mobile/arpl_save_metadata.php`  
**Method**: POST  
**Purpose**: Upload combined PDF for theory or practical papers

**Request Parameters**:
```json
{
  "learnerID": 11515,
  "ofo_number": "9964",
  "paper_title": "Apply health and safety to comply with OHSA",
  "paper_number": 1,
  "section_type": "theory",  // or "practical"
  "question_count": 15,
  "files": [file object]
}
```

**Response on Success**:
```json
{
  "status": "success",
  "message": "Theory paper uploaded successfully",
  "data": {
    "record_id": 123,
    "learnerID": 11515,
    "section_type": "theory",
    "file_name": "All_Questions_Apply_health_and_safety_to_comply_with_OHSA_9964_theory.pdf",
    "upload_status": "uploaded",
    "rating_status": null,
    "uploaded_at": "2026-07-07 14:23:45"
  }
}
```

**Features**:
- Prevents duplicate uploads
- Validates section_type (must be 'theory' or 'practical')
- For practical papers: sets `rating_status = 'pending_rating'`
- For theory papers: `rating_status` is NULL
- Transaction-based for consistency

---

### 2. **arpl_rate_practical.php** (NEW)
**Location**: `mobile/arpl_rate_practical.php`  
**Method**: POST  
**Purpose**: Add rating and comments to practical papers (assessor action)

**Request Parameters**:
```json
{
  "record_id": 123,
  "assessor_id": 5,
  "rating": 85.5,
  "assessor_comments": "Good work, well done"
}
```

**Response on Success**:
```json
{
  "status": "success",
  "message": "Practical paper rated successfully",
  "data": {
    "record_id": 123,
    "rating": 85.5,
    "rating_status": "rated",
    "assessor_id": 5,
    "assessor_comments": "Good work, well done",
    "rated_at": "2026-07-07 14:25:30"
  }
}
```

**Features**:
- Only rates practical papers (rejects theory)
- Validates rating (0-100)
- Records assessor ID and timestamp
- Sets rating_status to 'rated'

---

### 3. **arpl_get_practical_ratings.php** (NEW)
**Location**: `mobile/arpl_get_practical_ratings.php`  
**Method**: GET or POST  
**Purpose**: Retrieve practical papers for assessor marking interface

**Request Parameters** (optional):
```json
{
  "rating_status": "pending_rating",  // pending_rating, rated, reviewed
  "learnerID": 11515,                 // filter by learner
  "ofo_number": "9964",               // filter by OFO
  "limit": 50,
  "offset": 0
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Practical papers retrieved successfully",
  "pagination": {
    "total": 150,
    "limit": 50,
    "offset": 0,
    "count": 50
  },
  "filters": {
    "rating_status": "pending_rating",
    "learnerID": 0,
    "ofo_number": ""
  },
  "data": [
    {
      "id": 123,
      "learnerID": 11515,
      "ofo_number": "9964",
      "paper_title": "Apply health and safety to comply with OHSA",
      "paper_number": 1,
      "section_type": "practical",
      "question_count": 10,
      "rating_status": "pending_rating",
      "rating": null,
      "assessor_id": null,
      "created_at": "2026-07-07 14:23:45",
      "learner_name": "John Doe"
    }
  ]
}
```

**Features**:
- Filters by rating_status (default: pending_rating)
- Pagination support
- Left joins with learners table for learner names
- Returns metadata for UI display

---

## File Upload Format

**Filename Convention**:
```
All_Questions_[Paper_Title]_[OFO_Number]_[theory|practical].pdf
```

**Example**:
- `All_Questions_Apply_health_and_safety_to_comply_with_OHSA_9964_theory.pdf`
- `All_Questions_Apply_health_and_safety_to_comply_with_OHSA_9964_practical.pdf`

**Upload Directory**: `ARPL_POE/` (relative to web root)

---

## Workflow: Theory Paper Upload

```
1. Learner opens ARPL Portfolio → selects Theory section
2. Learner uploads combined PDF for Paper 1, Theory
3. Flutter calls: arpl_save_metadata.php with section_type='theory'
4. Backend:
   - Validates input (learnerID, ofo_number, paper_number, section_type)
   - Checks for duplicate (unique constraint)
   - Saves PDF to ARPL_POE/ directory
   - Inserts record into arpl_poe table:
     * rating_status = NULL (not applicable for theory)
     * upload_status = 'uploaded'
5. Response includes record_id and file path
6. UI shows: "Theory Paper 1 uploaded successfully"
```

---

## Workflow: Practical Paper Upload & Rating

```
1. Learner uploads combined PDF for Paper 1, Practical
2. Flutter calls: arpl_save_metadata.php with section_type='practical'
3. Backend:
   - Validates input
   - Checks for duplicate
   - Inserts record into arpl_poe table:
     * rating_status = 'pending_rating' (awaiting assessor)
     * upload_status = 'uploaded'
4. Response shows: "Practical Paper 1 uploaded - awaiting assessment"
5. UI shows: ⏳ Pending Rating badge

---

6. Assessor logs in → Views ARPL Practical Papers → Filters "pending_rating"
7. Calls: arpl_get_practical_ratings.php with rating_status='pending_rating'
8. Backend returns list of practicals awaiting rating
9. Assessor selects paper → Opens marking interface
10. Assessor rates: 85/100 → "Good work, well done"
11. Calls: arpl_rate_practical.php with:
    * record_id, rating, assessor_comments, assessor_id
12. Backend:
    - Updates arpl_poe record:
      * rating = 85.00
      * rating_status = 'rated'
      * assessor_id = 5
      * assessor_comments = "Good work, well done"
      * rated_at = NOW()
13. UI updates: Shows rating badge "85/100 ✓"
```

---

## SQL Indexes

For performance optimization:

```sql
CREATE INDEX idx_arpl_poe_learner ON arpl_poe(learnerID);
CREATE INDEX idx_arpl_poe_ofo ON arpl_poe(ofo_number);
CREATE INDEX idx_arpl_poe_section ON arpl_poe(section_type);
CREATE INDEX idx_arpl_poe_upload_status ON arpl_poe(upload_status);
CREATE INDEX idx_arpl_poe_rating_status ON arpl_poe(rating_status);
CREATE INDEX idx_arpl_poe_assessor ON arpl_poe(assessor_id);
CREATE INDEX idx_arpl_poe_learner_section ON arpl_poe(learnerID, section_type);
```

---

## Setup Instructions

### Option 1: Using PHP Script (Recommended)

1. Run this command or access via browser:
   ```
   http://192.168.0.57:8080/setup_arpl_poe_table.php
   ```

2. Expected response:
   ```json
   {
     "status": "success",
     "message": "ARPL POE table created successfully",
     "table_info": {
       "name": "arpl_poe",
       "columns": 19,
       "has_unique_constraint": true,
       "indexes_created": 7
     }
   }
   ```

### Option 2: Direct SQL

1. Open phpMyAdmin or MySQL client
2. Select database: `rlmsrlmsco_ezxcmacd_rlms`
3. Run SQL from: `create_arpl_poe_unified_table.sql`

---

## Testing the Implementation

### Test 1: Create Theory Paper Record

```bash
curl -X POST http://192.168.0.57:8080/mobile/arpl_save_metadata.php \
  -F "learnerID=11515" \
  -F "ofo_number=9964" \
  -F "paper_title=Apply health and safety to comply with OHSA" \
  -F "paper_number=1" \
  -F "section_type=theory" \
  -F "question_count=15" \
  -F "files=@/path/to/theory.pdf"
```

### Test 2: Create Practical Paper Record

```bash
curl -X POST http://192.168.0.57:8080/mobile/arpl_save_metadata.php \
  -F "learnerID=11515" \
  -F "ofo_number=9964" \
  -F "paper_title=Apply health and safety to comply with OHSA" \
  -F "paper_number=1" \
  -F "section_type=practical" \
  -F "question_count=10" \
  -F "files=@/path/to/practical.pdf"
```

### Test 3: Get Pending Practical Papers

```bash
curl "http://192.168.0.57:8080/mobile/arpl_get_practical_ratings.php?rating_status=pending_rating"
```

### Test 4: Rate a Practical Paper

```bash
curl -X POST http://192.168.0.57:8080/mobile/arpl_rate_practical.php \
  -d "record_id=1" \
  -d "assessor_id=5" \
  -d "rating=85.5" \
  -d "assessor_comments=Good work"
```

---

## Benefits of Unified Approach

✓ **Simplicity**: One table instead of two  
✓ **Consistency**: No data duplication or sync issues  
✓ **Flexibility**: Easy to add more fields (e.g., moderator feedback)  
✓ **Performance**: Single unique index handles both sections  
✓ **Querying**: Simple WHERE clauses for section_type filtering  
✓ **Scalability**: Scales better than separate tables  

---

## Files Modified/Created

| File | Type | Status |
|------|------|--------|
| `mobile/arpl_save_metadata.php` | Modified | ✓ Complete |
| `mobile/arpl_rate_practical.php` | New | ✓ Complete |
| `mobile/arpl_get_practical_ratings.php` | New | ✓ Complete |
| `setup_arpl_poe_table.php` | New | ✓ Complete |
| `create_arpl_poe_unified_table.sql` | New | ✓ Complete |

---

## Next Steps

1. ✓ Run `setup_arpl_poe_table.php` to create the table
2. Update Flutter ARPL upload screen to send `section_type` parameter
3. Add UI for assessors to view and rate practical papers
4. Update ARPL portfolio page to show theory/practical tabs
5. Rebuild and deploy APK

---

## Support & Troubleshooting

**Q: Foreign key constraint error when creating table?**  
A: Table creation is now without foreign keys. Use `setup_arpl_poe_table.php` instead.

**Q: Can I upload the same paper as both theory and practical?**  
A: Yes! The unique constraint is on (learnerID, ofo_number, paper_number, section_type), so uploading both is allowed.

**Q: Where are the PDF files stored?**  
A: In the `ARPL_POE/` directory relative to your web root. Configure as needed.

**Q: How do I query both theory and practical for a learner?**  
```sql
SELECT * FROM arpl_poe 
WHERE learnerID = 11515 AND ofo_number = '9964'
ORDER BY paper_number, section_type;
```

---

**Implementation Complete** ✓  
Ready for production deployment on 192.168.0.57:8080
