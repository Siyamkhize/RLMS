# Web-Based ARPL Portfolio Generator - Specification & Architecture

**Date:** July 10, 2026  
**Status:** 📋 SPECIFICATION PHASE

---

## 1. PROJECT OVERVIEW

### Purpose
Generate complete, printable ARPL (Assessment Requirement and Portfolio) documents for learners based on data collected through the mobile app.

### Document Structure (In Order)
1. **Cover Page** - Learner & assessor info, trade details
2. **ARPL Portfolio of Evidence Checklist** (from PDF uploaded)
3. **Appendix A** - Application Form
4. **Appendix B** - Theory Assessment Activities & Ratings
5. **Appendix C** - Trade Curriculum
6. **Appendix D** - Practical Skills Assessment (Yes/No responses)
7. **Appendix E** - Workplace Experience Activities & Ratings
8. **Appendix F** - Practical Assessment Evaluation
9. **Self-Evaluation/Interview Checklist**
10. **Gap Closure Reports & Analysis** (placeholder table)
11. **Theory Assessment Scripts** - Scanned papers for all 5 theory papers
12. **Register of Theory Assessment Sitting** (attendance placeholder)
13. **Practical Assessment Trade Tasks Scripts** (if available)
14. **Register of Practical Assessment Sitting** (attendance placeholder)
15. **Workplace Experience Evaluation Checklist** (Appendix E data)
16. **Workplace Experience Photographs** (from learner_document table)
17. **Register of Workplace Experience Evaluation Sitting** (attendance placeholder)
18. **Details of Assessor** - Artisan certificate & registration
19. **Feedback Form**
20. **Appeals Form** (Appendix G)
21. **Recommendation for Trade Testing** (Appendix H Overall Result)
22. **Statement of Results** (Appendix I)
23. **Trade Test Results** (if applicable)
24. **NAMB Moderation Report** (if Trade Test & PoE moderation chosen)

---

## 2. NAVIGATION & UI STRUCTURE

### Web Interface Flow

```
┌─────────────────────────────────────────────────────────┐
│                  ARPL PORTFOLIO GENERATOR                │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Step 1: SELECT TRADE                                   │
│  ┌────────────────────────────────────────────────────┐ │
│  │ ☐ Electrician (OFO 671101)                        │ │
│  │ ☐ Bricklaying (OFO 641201)                        │ │
│  │ ☐ Plumbing (OFO 671102)                           │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Step 2: SELECT CLASS                                   │
│  ┌────────────────────────────────────────────────────┐ │
│  │ [Dropdown: Choose class under selected trade]    │ │
│  │ Class: [________________]    [LOAD LEARNERS]     │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Step 3: SELECT LEARNER                                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Learner List:                                     │ │
│  │ ─────────────────────────────────────────────────│ │
│  │ ID    | Name              | Status               │ │
│  │ 20286 | John Doe          | GENERATE ARPL → ▶️   │ │
│  │ 20287 | Jane Smith        | GENERATE ARPL → ▶️   │ │
│  │ 20288 | Bob Johnson       | GENERATE ARPL → ▶️   │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
└─────────────────────────────────────────────────────────┘

When "GENERATE ARPL" clicked:
  → Fetch all learner data from mobile
  → Fetch documents from learner_document table
  → Generate PDF with all sections
  → Download/Print/Email
```

---

## 3. DATABASE SCHEMA & DATA SOURCES

### Tables to Query

#### Learner & Class Info
- `learnerdetails` - Learner personal info
- `class` - Class info & trade
- `arpl_trades` - Trade names & OFO codes

#### ARPL Assessment Data (Mobile Input)
- `arpl_appendix_a_[trade]` - Application form
- `arplappxb_[trade]_activities` - Theory activities
- `arplappxb_activity_ratings` - Theory ratings
- `arpl_appendix_c_[trade]` - Curriculum
- `arpl_appendix_d_[trade]` - Practical skills (yes/no)
- `arplappxe_[trade]_activities` - Workplace activities
- `arplappxe_[trade]_activity_ratings` - Workplace ratings
- `arpl_appendix_f_[trade]` - Practical assessment
- `arpl_appendix_f_practical_tasks_[trade]` - Practical tasks
- `arpl_appendix_f_workplace_observations_[trade]` - Workplace obs
- `arpl_appendix_g_[trade]` - Appeals form
- `arpl_appendix_i_[trade]` - Statement of results
- `arpl[trade]_access_recommendation` - ACR recommendations (Appendix H)

#### Supporting Documents
- `learner_document` - ID, CV, Qualification, Service letters
- `poe` - Scanned theory & practical papers
- `arpl_poe` - Theory and practical assessment documents

#### Assessor Info
- `facilitator` - Assessor details
- `artisan_certificate` (if exists) - Artisan cert & registration

---

## 4. PHP BACKEND ARCHITECTURE

### API Endpoints Required

#### `web/get_arpl_trades.php`
```
GET /web/get_arpl_trades.php
Returns: [
  {"trade_id": 1, "trade_name": "Electrician", "ofo_code": "671101"},
  {"trade_id": 2, "trade_name": "Bricklaying", "ofo_code": "641201"},
  {"trade_id": 3, "trade_name": "Plumbing", "ofo_code": "671102"}
]
```

#### `web/get_arpl_classes.php`
```
POST /web/get_arpl_classes.php
Body: {"trade_id": 1}
Returns: [
  {"classID": 782, "className": "Electrician Class A", "siteName": "Site 1"},
  ...
]
```

#### `web/get_arpl_class_learners.php`
```
POST /web/get_arpl_class_learners.php
Body: {"classID": 782}
Returns: [
  {
    "learnerID": 20286,
    "learnerName": "John Doe",
    "IDNumber": "1234567890",
    "status": "enrolled"
  },
  ...
]
```

#### `web/get_arpl_complete_data.php` (MAIN - Fetch all data for PDF)
```
POST /web/get_arpl_complete_data.php
Body: {
  "learnerID": 20286,
  "trade": "electrician"
}

Returns: {
  "learner": {...},
  "trade": {...},
  "assessor": {...},
  "appendixA": {...},
  "appendixB": [...],
  "appendixC": {...},
  "appendixD": {...},
  "appendixE": [...],
  "appendixF": {...},
  "appendixG": {...},
  "appendixH": {...},
  "appendixI": {...},
  "documents": {
    "id_copy": "path/to/document",
    "cv": "path/to/document",
    "qualification": "path/to/document",
    "service_letters": ["path1", "path2"],
    "theory_papers": ["paper1.pdf", "paper2.pdf", ...],
    "practical_papers": ["paper1.pdf", ...],
    "workplace_photos": ["photo1.jpg", "photo2.jpg", ...]
  }
}
```

---

## 5. FRONTEND TECHNOLOGY STACK

### Recommended
- **Framework:** Laravel (PHP) or Node.js/Express (for web interface)
- **PDF Generation:** 
  - PHP: `mPDF` or `TCPDF`
  - Node: `puppeteer` or `pdfkit`
- **Frontend:** HTML/CSS/JavaScript or Bootstrap
- **Document Upload/Attachment:** jQuery File Upload or similar

### Alternative (Simpler)
- Plain PHP with mPDF
- Bootstrap for UI
- Simple form-based navigation

---

## 6. PDF DOCUMENT STRUCTURE

### Page 1: Cover Page
```
┌──────────────────────────────────┐
│     ARPL TOOLKIT COVER PAGE      │
│                                  │
│  Candidate Name: John Doe        │
│  ID Number: 1234567890          │
│  Trade: Electrician              │
│  OFO Code: 671101               │
│  Class: Electrician Class A      │
│  Site: Training Site 1           │
│                                  │
│  Assessor: Jane Smith            │
│  Assessor Cert No: 12345         │
│  Date Generated: 2026-07-10      │
└──────────────────────────────────┘
```

### Page 2: ARPL Portfolio Checklist
```
[EMBED THE PDF CHECKLIST YOU UPLOADED]
```

### Subsequent Pages: Appendices
```
Each appendix formatted with:
- Title & section number
- Populated data from database
- Supporting documents embedded where applicable
```

### Gap Closure Section
```
┌────────────────────────────────────────────────────────┐
│  Gap Closure Report & Analysis                         │
├────────────────────────────────────────────────────────┤
│ No. │ Task              │ Method │ BAD │ FAIR │ GOOD │ Assessor Comments
│ 1   │ [Placeholder]     │ [...] │ [ ] │ [ ]  │ [ ]  │ [...............]
│ 2   │ [Placeholder]     │ [...] │ [ ] │ [ ]  │ [ ]  │ [...............]
│ ... │                   │       │     │      │      │
└────────────────────────────────────────────────────────┘
```

---

## 7. DOCUMENT ATTACHMENT STRATEGY

### Theory Assessment Scripts
```
Query: SELECT * FROM poe 
       WHERE learnerID = 20286 
       AND poe_type = 'theory'
       AND ofo_code IN ('671101', '641201', '671102')

Result: Get file paths for all 5 theory papers
Action: Embed in PDF or link to files
```

### Learner Documents (ID, CV, Qualifications)
```
Query: SELECT * FROM learner_document 
       WHERE learner_id = 20286

Include:
- ID Copy
- CV
- Qualification Certificate
- Service Letters (if available)
```

### Workplace Photographs
```
Query: SELECT * FROM learner_document 
       WHERE learner_id = 20286 
       AND document_type = 'photo'

Result: Get all photos for workplace experience section
```

### Assessor Artisan Certificate
```
Query: SELECT * FROM facilitator 
       WHERE facilitator_id = [assessor_id]
       AND artisan_cert_path IS NOT NULL

Include: Artisan certificate & registration number
```

---

## 8. IMPLEMENTATION ROADMAP

### Phase 1: Backend API (Week 1)
- [ ] Create `web/` directory for web-specific endpoints
- [ ] Create `web/get_arpl_trades.php`
- [ ] Create `web/get_arpl_classes.php`
- [ ] Create `web/get_arpl_class_learners.php`
- [ ] Create `web/get_arpl_complete_data.php` (main data fetcher)

### Phase 2: Frontend Interface (Week 2)
- [ ] Create `web/index.php` - Trade selection
- [ ] Create `web/classes.php` - Class selection
- [ ] Create `web/learners.php` - Learner list with "Generate ARPL" buttons
- [ ] Integrate Bootstrap for responsive design
- [ ] Add AJAX loading indicators

### Phase 3: PDF Generation (Week 3)
- [ ] Install mPDF library
- [ ] Create `web/generate_arpl_pdf.php` - Main PDF generator
- [ ] Create PDF template with all sections
- [ ] Implement dynamic content population
- [ ] Add supporting document embedding
- [ ] Test with multiple trades

### Phase 4: Testing & Refinement (Week 4)
- [ ] Test PDF generation for all 3 trades
- [ ] Verify all document attachments
- [ ] Test with multiple learners
- [ ] Add error handling & logging
- [ ] Performance optimization

---

## 9. FILE STRUCTURE

```
web/
├── index.php                          (Trade selection)
├── classes.php                        (Class selection)
├── learners.php                       (Learner list)
├── generate_arpl_pdf.php              (PDF generation - main)
├── api/
│   ├── get_arpl_trades.php
│   ├── get_arpl_classes.php
│   ├── get_arpl_class_learners.php
│   └── get_arpl_complete_data.php
├── templates/
│   ├── arpl_cover.html               (Cover page template)
│   ├── arpl_checklist.html           (Checklist template)
│   ├── appendix_*.html               (Individual appendix templates)
│   └── gap_closure.html              (Gap closure template)
├── assets/
│   ├── css/
│   │   └── arpl_style.css
│   ├── js/
│   │   └── arpl_script.js
│   └── images/
│       └── department_logo.png
└── README.md
```

---

## 10. KEY CONSIDERATIONS

### Data Mapping
- Trade name consistency (database vs display)
- OFO code mapping for each trade
- Handling missing data gracefully

### Document Management
- File path resolution for stored documents
- Embedded vs linked documents in PDF
- Handling missing documents (show placeholder)

### Error Handling
- Learner with incomplete data
- Missing supporting documents
- Database connection failures

### Performance
- Large PDF generation (50+ pages)
- Multiple document embeddings
- Caching strategies

### Security
- User authentication & authorization
- Ensure users can only generate their trade's ARPLs
- Audit trail for PDF generation

### Accessibility
- Readable PDF structure
- Proper heading hierarchy
- Alt text for images

---

## 11. SUPPORTING DOCUMENT CHECKLIST

From the uploaded checklist, the web version must handle:

1. ✅ Application form (Appendix A)
2. ✅ Certified ID copy (from learner_document)
3. ✅ Curriculum Vitae (from learner_document)
4. ✅ Certification copies & service letters (from learner_document)
5. ✅ Fees payment records (placeholder)
6. ✅ Self-Evaluation/Interview checklist (placeholder)
7. ✅ Gap closure reports (placeholder + table)
8. ✅ Theory Assessment scripts (from poe table)
9. ✅ Register of Theory Assessment sitting (placeholder)
10. ✅ Practical Assessment of trade tasks (from poe table)
11. ✅ Register of Practical Assessment sitting (placeholder)
12. ✅ Workplace Experience evaluation + photos (from learner_document)
13. ✅ Register of Workplace Experience sitting (placeholder)
14. ✅ Details of Assessor with Artisan cert (from facilitator table)
15. ✅ Feedback form (Appendix H or custom)
16. ✅ Appeals form (Appendix G)
17. ✅ Recommendation for trade testing (Appendix H)
18. ✅ Statement of Results (Appendix I)
19. ✅ Trade test serial number & results (if applicable)
20. ✅ NAMB moderation report (if applicable)

---

## 12. NEXT STEPS

1. **Review & Confirm** - Approval of this specification
2. **Database Audit** - Verify all required tables & fields exist
3. **Backend Development** - Create API endpoints
4. **Frontend Development** - Build web interface
5. **PDF Template Creation** - Design & test PDF layout
6. **Integration Testing** - Connect all components
7. **User Testing** - Test with real data from mobile

---

**Status:** Ready for implementation
**Complexity:** High (15-20 development days)
**Priority:** Critical for documentation workflow
