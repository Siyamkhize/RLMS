# ARPL Web Portfolio Generator

**Status:** Phase 1-2 Complete (Backend APIs + Frontend UI)  
**Last Updated:** July 10, 2026

---

## Overview

The ARPL Web Portfolio Generator is a web-based system for generating complete, printable ARPL (Assessment Requirement and Portfolio) documents for learners across three trades:
- **Electrician** (OFO 671101)
- **Bricklaying** (OFO 641201)  
- **Plumbing** (OFO 671102)

The system aggregates data collected through the mobile ARPL toolkit and combines it with supporting documents to produce a comprehensive 24-page portfolio PDF for each learner.

---

## Architecture

### Navigation Flow

```
Trade Selection → Class Selection → Learner List → Generate PDF
   (index.php)  →  (classes.php)  → (learners.php) → (generate_pdf.php)
```

### Directory Structure

```
web/
├── index.php                    # Trade selection page (Step 1)
├── classes.php                  # Class selection page (Step 2)
├── learners.php                 # Learner list with generate buttons (Step 3)
├── generate_pdf.php             # PDF generation page (placeholder)
├── connection.php               # Database connection proxy
├── api/
│   ├── get_arpl_trades.php      # Get available trades
│   ├── get_arpl_classes.php     # Get classes by trade
│   ├── get_arpl_class_learners.php  # Get learners in class
│   └── get_arpl_complete_data.php   # Aggregate all learner data
├── assets/
│   ├── css/
│   │   └── arpl_style.css       # Main stylesheet
│   ├── js/
│   │   └── arpl_script.js       # Shared JavaScript (future)
│   └── images/
│       └── (department logo, etc.)
└── templates/
    ├── arpl_cover.html          # Cover page template (future)
    ├── appendix_*.html          # Appendix templates (future)
    └── gap_closure.html         # Gap closure template (future)
```

---

## API Endpoints

### 1. GET ARPL Trades
**Endpoint:** `POST api/get_arpl_trades.php`

Returns list of available trades.

```json
{
  "status": "success",
  "trades": [
    {"trade_id": 1, "trade_name": "Electrician", "ofo_code": "671101"},
    {"trade_id": 2, "trade_name": "Bricklaying", "ofo_code": "641201"},
    {"trade_id": 3, "trade_name": "Plumbing", "ofo_code": "671102"}
  ],
  "count": 3
}
```

### 2. GET ARPL Classes
**Endpoint:** `POST api/get_arpl_classes.php`

**Request:**
```json
{
  "ofo_code": "671101"
}
```

**Response:**
```json
{
  "status": "success",
  "trade": "Electrician",
  "ofo_code": "671101",
  "classes": [
    {"classID": 782, "className": "Electrician Class A", "siteName": "Training Site 1"},
    ...
  ],
  "count": 5
}
```

### 3. GET Class Learners
**Endpoint:** `POST api/get_arpl_class_learners.php`

**Request:**
```json
{
  "classID": 782
}
```

**Response:**
```json
{
  "status": "success",
  "classID": 782,
  "learners": [
    {
      "learnerID": 20286,
      "learnerName": "John Doe",
      "firstName": "John",
      "lastName": "Doe",
      "idNumber": "1234567890",
      "gender": "M",
      "status": "enrolled",
      "classID": 782,
      "className": "Electrician Class A"
    },
    ...
  ],
  "count": 25
}
```

### 4. GET Complete ARPL Data
**Endpoint:** `POST api/get_arpl_complete_data.php`

Aggregates all learner data for PDF generation.

**Request:**
```json
{
  "learnerID": 20286,
  "ofo_code": "671101",
  "trade": "electrician"
}
```

**Response:**
```json
{
  "status": "success",
  "learnerID": 20286,
  "trade": "electrician",
  "ofo_code": "671101",
  "learner": {...},
  "class_info": {...},
  "assessor": {...},
  "documents": {
    "id_copy": {...},
    "cv": {...},
    "qualifications": [...],
    "service_letters": [...],
    "workplace_photos": [...],
    "theory_papers": [...],
    "practical_papers": [...]
  },
  "appendices": {...},
  "generated_at": "2026-07-10 16:00:00"
}
```

---

## Database Tables Used

### Learner Information
- `learnerdetails` - Personal and demographic information
- `enrollment` - Class enrollment records
- `class` - Class information with trade/OFO mapping
- `sites` - Training site information

### ARPL Assessment Data
- `arpl_appendix_a_*` - Application forms (trade-specific)
- `arplappxb_*_activities` - Theory assessment activities
- `arpl_appendix_d_*` - Practical skills assessments
- `arplappxe_*_activities` - Workplace experience activities
- `arpl_appendix_f_*` - Practical assessment evaluations
- `arplbricklayer_access_recommendation` - ACR recommendations (Appendix H)
- `arplbricklayer_gap_unit_standards` - Gap closure unit standards

### Supporting Documents
- `learner_document` - ID copies, CVs, qualifications, service letters, photos
- `poe` - Scanned assessment papers (theory & practical)
- `facilitator` - Assessor information

---

## Implementation Status

### Phase 1: Backend API ✅ COMPLETE
- [x] Trade retrieval endpoint
- [x] Class retrieval endpoint  
- [x] Learner retrieval endpoint
- [x] Complete data aggregation endpoint
- [x] Database connection setup

### Phase 2: Frontend UI ✅ COMPLETE
- [x] Trade selection interface
- [x] Class selection interface
- [x] Learner list with generate buttons
- [x] Session management (SessionStorage)
- [x] Responsive Bootstrap UI
- [x] Error handling & validation

### Phase 3: PDF Generation ⏳ IN PROGRESS
- [ ] PDF template design (Cover, Checklists, Appendices)
- [ ] mPDF library integration
- [ ] Dynamic content population
- [ ] Document embedding strategy
- [ ] Gap closure report template
- [ ] Theory/practical assessment registers
- [ ] Workplace experience evaluation section

### Phase 4: Testing & Refinement ⏳ PENDING
- [ ] Test PDF generation for all 3 trades
- [ ] Verify document attachments
- [ ] Performance optimization
- [ ] Error handling refinement

---

## Usage

### For End Users

1. **Navigate to the portal:** `http://localhost/web/index.php`

2. **Step 1: Select Trade**
   - Choose from Electrician, Bricklaying, or Plumbing
   - Click "Continue to Classes"

3. **Step 2: Select Class**
   - View all available classes for the selected trade
   - Choose a class
   - Click "View Learners"

4. **Step 3: Generate Portfolio**
   - See all enrolled learners in the class
   - Click "Generate ARPL ▶" next to a learner's name
   - PDF will be generated and downloaded

### For Developers

#### Adding Support for a New Trade

1. **Create trade-specific tables** (see mobile implementation for pattern):
   ```sql
   CREATE TABLE arpl_appendix_a_new_trade (...)
   CREATE TABLE arpl_appendix_d_new_trade (...)
   ...
   ```

2. **Update trade mappings** in API endpoints:
   ```php
   $ofoMapping = [
       '671101' => 'Electrician',
       '641201' => 'Bricklaying',
       '671102' => 'Plumbing',
       '671103' => 'New Trade'  // Add here
   ];
   ```

3. **Test the flow** through all three pages

#### Implementing PDF Generation

The PDF generation module should:

1. Fetch complete learner data using `get_arpl_complete_data.php`
2. Use mPDF library to create PDF instance
3. Generate pages in this order:
   - Cover page (learner & trade info)
   - Portfolio checklist (from uploaded document)
   - Appendices A-I (from database)
   - Supporting documents (embedded PDFs/images)
   - Gap closure report (if applicable)
   - Assessment registers (placeholders)
   - Assessor details & certificates
   - Trade test results & NAMB report (if applicable)
4. Return PDF for download or email

---

## Document Structure (24 Pages)

The complete ARPL portfolio includes:

1. **Cover Page** - Learner, assessor, trade info
2. **Portfolio Checklist** - Compliance checklist (from uploaded PDF)
3-5. **Supporting Documents** - ID, CV, Qualifications, Service letters
6-14. **Appendices A-I** - All assessment sections
15. **Gap Closure Report** - Analysis & recommendations (if applicable)
16-17. **Theory Assessment** - Papers + attendance register
18-19. **Practical Assessment** - Trade tasks + attendance register
20-22. **Workplace Experience** - Evaluation + photos + attendance register
23-24. **Forms & Reports** - Feedback, appeals, assessor certs, trade test results

---

## Configuration

### Database Connection

Edit `web/connection.php` to point to your database:

```php
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "your_database_name";
```

### Web Server

- **PHP Version:** 7.4+
- **Apache Modules:** mod_rewrite
- **Document Root:** Point to `/web/` directory
- **Upload Directory:** Ensure `uploads/` has proper permissions

---

## Security Considerations

- ✅ Input validation on all API endpoints
- ✅ SQL prepared statements to prevent injection
- ✅ User authentication (to be implemented)
- ✅ Access control (trade/class filtering)
- ⏳ Audit logging for PDF generation
- ⏳ Rate limiting on API endpoints

---

## Future Enhancements

1. **User Authentication** - Restrict access by role (Admin, Assessor, Manager)
2. **Audit Trail** - Log all PDF generation for compliance
3. **Email Integration** - Send PDF to learners/assessors
4. **Bulk Generation** - Generate PDFs for entire class at once
5. **Dashboard** - Statistics on portfolio generation
6. **Mobile App Link** - QR codes to link web/mobile data
7. **Template Customization** - Custom cover pages, branding
8. **Multi-language Support** - Translations for forms & reports

---

## Troubleshooting

### "No classes found for this trade"
- Verify trade OFO code in database
- Check `class` table has correct `ofoNumber` values
- Ensure enrollment records exist

### "No learners in class"
- Verify learners are enrolled via `enrollment` table
- Check enrollment status is 'Active', 'Completed', or 'Enrolled'
- Ensure learner records exist in `learnerdetails`

### API Returns 400 Error
- Check request JSON format
- Verify required parameters are provided
- Check database connection
- Review error message in response

### Documents Not Embedding in PDF
- Verify `learner_document` table has file paths
- Check file paths are accessible from server
- Ensure file permissions allow reading
- Check PDF library permissions

---

## Support & Contact

For issues, questions, or feature requests, contact the development team.

**Last Modified:** July 10, 2026  
**Version:** 1.0.0 (Beta)
