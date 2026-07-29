# Assessment Papers System Overview

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                      ASSESSOR UPLOADS PAPERS                       │
│                    (Flutter App - ARPL Role)                       │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │ Paper Scanner   │
                    │ PDF Merger      │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
    Theory Paper      Practical Paper       Metadata
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────────────────────────────────────────────────┐
│          UPLOAD ENDPOINTS (mobile/arpl_save_*.php)       │
│  - arpl_save_theory.php                                 │
│  - arpl_save_practical.php                              │
│  - arpl_save_metadata.php (generic)                     │
└───────────────────────┬────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
    File Save      DB Insert      File Index
        │               │               │
        └───────────────┼───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │  ARPL_POE/ Directory Structure│
        ├───────────────────────────────┤
        │ ARPL_THEORY/                  │
        │  ├─ Paper1_theory.pdf         │
        │  ├─ Paper2_theory.pdf         │
        │  └─ ...                       │
        │ ARPL_PRACTICAL/               │
        │  ├─ Paper1_practical.pdf      │
        │  ├─ Paper2_practical.pdf      │
        │  └─ ...                       │
        └───────────────────────────────┘
                        │
        ┌───────────────▼───────────────┐
        │      Database Storage         │
        ├───────────────────────────────┤
        │ arpl_poe Table                │
        │ ─────────────────────────────│
        │ id                     INT    │
        │ learnerID              INT    │
        │ ofo_number            VARCHAR│
        │ paper_title           VARCHAR│
        │ paper_number           INT    │
        │ section_type    'theory' OR   │
        │              'practical'      │
        │ combined_pdf_path     VARCHAR│
        │ file_name            VARCHAR│
        │ upload_status VARCHAR  ↓      │
        │ rating (practical)  DECIMAL  │
        │ rating_status       VARCHAR  │
        │ assessor_id            INT    │
        │ created_at          TIMESTAMP│
        └───────────────────────────────┘
                        │
        ┌───────────────▼───────────────┐
        │  PDF GENERATION REQUEST       │
        │  (web/arpl_pdf.php)           │
        │  ?learnerID=12107&ofo=671101  │
        └───────────────────────────────┘
                        │
        ┌───────────────▼───────────────────────┐
        │     QUERY ASSESSMENT PAPERS           │
        ├───────────────────────────────────────┤
        │                                       │
        │ SELECT * FROM arpl_poe WHERE          │
        │   learnerID = 12107 AND               │
        │   ofo_number = '671101' AND           │
        │   section_type = 'theory'             │
        │ ORDER BY paper_number                 │
        │                                       │
        │ SELECT * FROM arpl_poe WHERE          │
        │   learnerID = 12107 AND               │
        │   ofo_number = '671101' AND           │
        │   section_type = 'practical'          │
        │ ORDER BY paper_number                 │
        │                                       │
        └───────────────────────────────────────┘
                        │
        ┌───────────────▼─────────────────────┐
        │      FILE RESOLUTION & LOADING      │
        ├─────────────────────────────────────┤
        │ FOR EACH PAPER:                     │
        │  1. Get combined_pdf_path from DB   │
        │  2. Try possible file locations:    │
        │     - __DIR__ . '/' . $filePath     │
        │     - 'ARPL_POE/' . $filePath       │
        │     - 'ARPL_POE/' . basename()      │
        │     - $filePath                     │
        │  3. Check file exists & readable    │
        │  4. Check file size < 10MB          │
        │  5. Read file content               │
        │  6. Base64 encode                   │
        │  7. Embed in PDF output             │
        │                                     │
        └───────────────────────────────────────┘
                        │
        ┌───────────────▼─────────────────────┐
        │      PDF SECTIONS GENERATED         │
        ├─────────────────────────────────────┤
        │ Appendix L: Theory Papers       ✓   │
        │   └─ Table + Embedded PDFs          │
        │                                     │
        │ Appendix M: Theory Register     ✓   │
        │   └─ NOT UPLOADED placeholder       │
        │                                     │
        │ Appendix N: Practical Scripts   ✓   │
        │   └─ Table + Embedded PDFs          │
        │                                     │
        │ Appendix O: Practical Register  ✓   │
        │   └─ NOT UPLOADED placeholder       │
        │                                     │
        │ Appendix P: Workplace Exp.      ✓   │
        │   └─ Employment history table       │
        │                                     │
        └───────────────────────────────────────┘
                        │
        ┌───────────────▼────────────────────┐
        │   RETURN PDF TO USER/BROWSER       │
        │   (HTML with embedded base64 PDFs) │
        └────────────────────────────────────┘
```

---

## Data Flow - Paper Upload to Display

### Step 1: Assessor Uploads Paper via Flutter App
```
Assessor Action: Select paper PDF from device
                  │
                  ▼
            PDF Validation
                  │
                  ▼
          Merge with questions
                  │
                  ▼
        Send to web server
```

### Step 2: Server Receives Upload
```
POST: mobile/arpl_save_theory.php
OR
POST: mobile/arpl_save_practical.php

Payload:
{
  learnerID: 12107,
  ofoNumber: '671101',
  paperTitle: 'Basic Electrical Safety',
  paperNumber: 1,
  questionCount: 25,
  sectionType: 'theory'|'practical',
  combinedPdf: [binary file data]
}
```

### Step 3: File Storage
```
Server writes file to:
/assessorReport2/ARPL_POE/
    ARPL_THEORY/
        All_Questions_Basic_Electrical_Safety_theory.pdf
    
File path stored in database
```

### Step 4: Database Storage
```
INSERT INTO arpl_poe (
  learnerID: 12107,
  ofo_number: '671101',
  paper_title: 'Basic Electrical Safety',
  paper_number: 1,
  section_type: 'theory',
  question_count: 25,
  combined_pdf_path: 'ARPL_POE/ARPL_THEORY/All_Questions_...pdf',
  file_name: 'All_Questions_...theory.pdf',
  upload_status: 'uploaded',
  created_at: NOW()
)
```

### Step 5: PDF Generation
```
Request: web/arpl_pdf.php?learnerID=12107&ofo=671101

Process:
  1. Query: SELECT * FROM arpl_poe 
     WHERE learnerID=12107 
     AND ofo_number='671101' 
     AND section_type='theory'
     
  2. For each paper:
     - Find file using combined_pdf_path
     - Read file content
     - Base64 encode
     - Create embed tag in PDF
     
  3. Generate complete ARPL PDF with:
     - All 12 appendices
     - Theory papers
     - Practical scripts
     - Registers (placeholders)
     - Employment history
```

### Step 6: PDF Display
```
Browser receives:
<embed src="data:application/pdf;base64,JVBERi0xLjQK..." />

User sees:
- Embedded PDF viewer
- Paper title and metadata
- File size
- Fallback message if file unavailable
```

---

## Database Relationships

```
                    ┌──────────────────┐
                    │ learnerdetails   │
                    │──────────────────│
                    │ learnerID (PK)   │
                    │ firstName        │
                    │ lastName         │
                    │ email            │
                    └────────┬─────────┘
                             │
                             │ FK: learnerID
                             │
        ┌────────────────────▼─────────────────────┐
        │           arpl_poe                       │
        ├────────────────────────────────────────┤
        │ id (PK)                                │
        │ learnerID (FK → learnerdetails)       │
        │ ofo_number                             │
        │ paper_title                            │
        │ paper_number                           │
        │ section_type: 'theory'|'practical'    │
        │ question_count                         │
        │ combined_pdf_path                      │
        │ file_name                              │
        │ upload_status                          │
        │ rating (practical only)                │
        │ rating_status (practical only)         │
        │ assessor_id (FK → facilitator)        │
        │ assessor_comments                      │
        │ created_at                             │
        │ updated_at                             │
        └────────────────┬───────────────────────┘
                         │
                    FK: assessor_id
                         │
        ┌────────────────▼────────────────┐
        │      facilitator                │
        ├─────────────────────────────────┤
        │ id (PK)                         │
        │ firstName                       │
        │ lastName                        │
        │ email                           │
        │ role: 'arpl_assessor'           │
        └─────────────────────────────────┘
```

---

## File Size Handling

```
Maximum Per-Paper Size: 10MB

File Size Check:
  if (filesize($file) < 10485760) {  // 10MB in bytes
    // Embed in PDF
  } else {
    // Show warning: File too large
    // Provide link to download separately
  }

Benefits:
  ✓ Browser won't freeze on large PDFs
  ✓ PDF output remains manageable
  ✓ Users can download papers separately if needed
  ✓ Graceful degradation
```

---

## Error Handling

```
Scenario 1: File Not Found
  ├─ Theory paper metadata in DB
  ├─ But file doesn't exist on disk
  └─ Display: ⚠ Theory Paper 1 Not Available

Scenario 2: File Too Large
  ├─ File exists but > 10MB
  ├─ Can't embed in PDF
  └─ Display: ⚠ File too large for embedding

Scenario 3: Path Resolution Failure
  ├─ Try multiple paths
  ├─ If all fail, show warning
  └─ Continue with other papers

Scenario 4: No Papers Uploaded
  ├─ Query returns empty array
  ├─ Section not displayed or shows "0 papers"
  └─ Registers show placeholder status
```

---

## Security Measures

1. **SQL Injection Prevention**
   - All queries use prepared statements
   - Parameters bound with appropriate types

2. **File Access Control**
   - Check file_exists() before reading
   - Check is_readable() before processing
   - Validate file path against expected directories

3. **XSS Prevention**
   - All HTML output escaped with htmlspecialchars()
   - File names properly escaped

4. **File Size Validation**
   - Limit: 10MB per paper
   - Prevents memory issues
   - Protects against DoS attacks

5. **Base64 Encoding**
   - Binary data safely embedded
   - No file path exposure
   - Cross-origin safe

---

## Performance Optimization

```
Database Queries:
  ✓ Indexed on: learnerID, ofo_number, section_type
  ✓ Limited result set (only target learner/OFO)
  ✓ Prepared statements (cached)
  
File Operations:
  ✓ One read per file (no duplicate opens)
  ✓ Base64 encoding done once
  ✓ Large files skipped (10MB limit)
  
PDF Rendering:
  ✓ Lazy loading of embedded PDFs in browser
  ✓ Base64 reduces HTTP requests
  ✓ Inline embedding reduces latency
```

---

## Testing Checklist

- [ ] Create test learner with OFO code
- [ ] Upload theory paper via Flutter app
- [ ] Upload practical paper via Flutter app
- [ ] Generate ARPL PDF
- [ ] Verify Appendix L displays theory paper
- [ ] Verify Appendix M shows "Not Uploaded"
- [ ] Verify Appendix N displays practical paper
- [ ] Verify Appendix O shows "Not Uploaded"
- [ ] Verify Appendix P shows employment history or placeholder
- [ ] Test with missing file (should show warning)
- [ ] Test with file > 10MB (should show warning)
- [ ] Test with no papers uploaded (sections should adapt)
- [ ] Verify all signatures embedded
- [ ] Validate PDF structure and rendering

---

**System Status**: ✓ COMPLETE & READY FOR TESTING
