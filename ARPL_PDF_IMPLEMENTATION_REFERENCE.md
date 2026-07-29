# ARPL PDF Implementation - Complete Reference Guide

**Last Updated**: July 11, 2026  
**Status**: ✅ PRODUCTION READY  
**Version**: 3.0 (Exact Mobile App Format)

---

## 📚 Quick Navigation

| Document | Purpose | Read When |
|----------|---------|-----------|
| **ARPL_PDF_FIX_COMPLETE.md** | Fix summary & overview | First - start here |
| **ARPL_PDF_PARAMETER_VALIDATION_FIX.md** | Technical deep-dive | Need details on what changed |
| **ARPL_PDF_QUICK_TEST.md** | Testing & troubleshooting | Before testing or debugging |
| **ARPL_PDF_IMPLEMENTATION_REFERENCE.md** | This file - full guide | Need complete reference |

---

## 🏗️ Architecture Overview

```
User Request
    ↓
http://localhost:8080/web/generate_pdf.php?learnerID=16389&ofo_code=671101
    ↓
generate_pdf.php (Wrapper)
├── Extracts: learnerID, classID (from URL or DB), ofo_code
├── Validates: All 3 parameters present
└── If valid:
    ↓
    Redirects to:
    http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=782&learnerID=16389&ofoNumber=671101
        ↓
        generate_arpl_pdf.php (Standalone Generator)
        ├── Requires session auth (facilitator or SDP)
        ├── Loads learner data from database
        ├── Loads class/site/project/SDP data
        ├── Generates 30+ page HTML/PDF document
        ├── Includes:
        │   ├── Cover page with DHET branding
        │   ├── Header on every page
        │   ├── 11 appendices (A-K)
        │   ├── Trade-specific content (Electrician, Bricklaying, Plumbing)
        │   └── Signature pads (JavaScript Signature Pad)
        └── Outputs as HTML (printable/saveable)
```

---

## 📂 File Structure

```
c:\projects\rlmss\
├── web\
│   ├── connection.php (Database connection)
│   ├── index.php (Home page)
│   ├── learners.php (Learner list)
│   ├── generate_pdf.php (✅ WRAPPER - FIXED)
│   │   └── Purpose: Extract/validate parameters, redirect to generator
│   │   └── Size: ~10KB
│   │   └── Auth: Not required (public access)
│   ├── api\
│   │   └── generate_arpl_pdf_v3.php (API version - deprecated)
│   └── web\
│       └── web\
│           ├── generate_arpl_pdf.php (✅ STANDALONE GENERATOR - Main)
│           │   └── Purpose: Generate complete 30+ page portfolio
│           │   └── Size: ~850KB with all content
│           │   └── Auth: Required (facilitator/SDP session)
│           ├── generate_arpl_pdf_v3.php (Copy for testing)
│           └── diagnose_arpl_pdf.php (Diagnostic tool)
│
├── test_arpl_setup.php (✅ NEW - Diagnostic tool at web root)
│
└── Documentation\
    ├── ARPL_PDF_FIX_COMPLETE.md (✅ Fix summary)
    ├── ARPL_PDF_PARAMETER_VALIDATION_FIX.md (✅ Technical details)
    ├── ARPL_PDF_QUICK_TEST.md (✅ Testing guide)
    └── ARPL_PDF_IMPLEMENTATION_REFERENCE.md (This file)
```

---

## 🔄 Complete Workflow

### A. User Initiates PDF Generation

**From Mobile App / Web UI**:
```
User clicks "Generate PDF" button
    ↓
Frontend routes to: web/generate_pdf.php with parameters
    ↓
URL: http://localhost:8080/web/generate_pdf.php?learnerID=16389&ofo_code=671101
```

### B. Wrapper Validates Parameters

**In generate_pdf.php (Lines 68-119)**:
```php
// Extract parameters
$learnerID = isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0;
$classID = isset($_GET['classID']) ? intval($_GET['classID']) : 0;
$ofo_code = isset($_GET['ofo_code']) ? trim($_GET['ofo_code']) : '';

// If classID missing, lookup from database
if ($classID <= 0 && $learnerID > 0) {
    // Query: SELECT classID FROM learnerdetails WHERE LearnerID = ?
    // Result: Find learner's class enrollment
}

// Validate all 3 parameters
if ($learnerID <= 0 || $classID <= 0 || empty($ofo_code)) {
    // Show error
} else {
    // Redirect to generator
}
```

### C. Browser Redirects to Generator

**JavaScript (Lines 321-328)**:
```javascript
function generatePDF() {
    const learnerID = <php classID>;
    const classID = <php classID>;
    const ofo_code = '<php ofo_code>';
    
    const url = `http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=${classID}&learnerID=${learnerID}&ofoNumber=${ofo_code}`;
    window.location.href = url;  // Redirect
}
```

### D. Standalone Generator Creates PDF

**In generate_arpl_pdf.php**:
1. Verify user is authenticated (facilitator or SDP)
2. Extract parameters from GET
3. Query database for:
   - Learner details
   - Class details
   - Site details
   - Project details
   - SDP details
   - Facilitator details
4. Generate 30+ page HTML document:
   - Cover page
   - Contents & index
   - Appendix A-K (form pages)
   - Trade-specific sections
   - Signature pads
5. Output as HTML (browser can print to PDF)

### E. User Downloads/Prints PDF

**Browser Options**:
```
Print Dialog (Ctrl+P)
    ↓
    Save as PDF
    ↓
    Portfolio_Electrician_16389.pdf

OR

Right-click → Save Page As
    ↓
    HTML file with all styling
```

---

## 🔌 API Endpoints

### Main Endpoints (Both Working)

#### 1. **Wrapper Endpoint** (Recommended)
```
GET /web/generate_pdf.php

Parameters:
  - learnerID: required (int) - learner ID from database
  - ofo_code: required (string) - trade code (671101, 641201, 642601)
  - classID: optional (int) - if omitted, auto-lookup from database

Example:
  http://localhost:8080/web/generate_pdf.php?learnerID=16389&ofo_code=671101
  http://localhost:8080/web/generate_pdf.php?learnerID=16389&classID=782&ofo_code=671101

Response:
  - Redirect to /web/web/web/generate_arpl_pdf.php
  - Or: Error page with debug info
```

#### 2. **Generator Endpoint** (Direct)
```
GET /web/web/web/generate_arpl_pdf.php

Parameters:
  - learnerID: required (int) - learner ID
  - classID: required (int) - class ID
  - ofoNumber: required (string) - trade code (format: ofoNumber not ofo_code)

Example:
  http://localhost:8080/web/web/web/generate_arpl_pdf.php?classID=782&learnerID=16389&ofoNumber=671101

Response:
  - 30+ page HTML portfolio (printable/saveable)
  - Session must be active (facilitator or SDP)
```

#### 3. **Deprecated API** (DO NOT USE)
```
POST /web/api/generate_arpl_pdf_v3.php

Status: ❌ Deprecated
Reason: Complex JSON/fetch workflow, path routing issues
Replace with: Direct call to /web/web/web/generate_arpl_pdf.php
```

---

## 🧮 Trade Codes Reference

| OFO Code | Trade Name | Table Suffix | Status |
|----------|-----------|--------------|--------|
| **671101** | Electrician | electrician | ✅ Supported |
| **641201** | Bricklaying | bricklaying | ✅ Supported |
| **642601** | Plumbing | plumbing | ✅ Supported |
| 651302 | Welding | - | ⚠️ Listed but not implemented |

**Usage in URLs**:
```
ofo_code parameter (in wrapper): 671101
ofoNumber parameter (in generator): 671101
```

---

## 📋 Database Requirements

### Tables Required

1. **learnerdetails**
   ```sql
   - LearnerID (int, primary)
   - classID (int, foreign key to class)
   - FirstName, LastName, EmailAddress
   - DOB, Gender, Province, Municipality
   - etc.
   ```

2. **class**
   ```sql
   - classID (int, primary)
   - class_name
   - siteID (foreign key to sites)
   ```

3. **sites**
   ```sql
   - siteID (int, primary)
   - siteName, Province, District, Municipality
   - cell_phone, email, project_id, sdp_id, qualification_id
   ```

4. **project**
   ```sql
   - project_id (int, primary)
   - Project_name, Contract_no, Financial_year
   - Start_date, End_date
   ```

5. **sdp**
   ```sql
   - sdp_id (int, primary)
   - sdp_name, accreditation_n, p_address, email
   ```

6. **facilitator**
   ```sql
   - facilitator_id (int, primary)
   - firstName, lastName, assessorNo
   - classID (foreign key or list)
   ```

### Verify Data

```bash
# Check test learner
SELECT * FROM learnerdetails WHERE LearnerID = 16389;

# Check enrollment
SELECT * FROM learnerdetails WHERE LearnerID = 16389 AND classID = 782;

# Check class
SELECT * FROM class WHERE classID = 782;

# Check site
SELECT * FROM sites WHERE siteID = (SELECT siteID FROM class WHERE classID = 782);
```

---

## 🔐 Authentication & Permissions

### Required Session Variables

```php
// One of these must be set:
$_SESSION['facilitator_id']   // Facilitator user
$_SESSION['sdp_id']           // SDP admin user

// If neither, redirect to login
if (!isset($_SESSION['sdp_id']) && !isset($_SESSION['facilitator_id'])) {
    header("Location: index.php");
    exit;
}
```

### How to Test Without Session

1. Create test session manually:
   ```php
   // At top of test_arpl_setup.php before other code:
   $_SESSION['facilitator_id'] = 1;  // Or any valid ID
   ```

2. Or access via logged-in account:
   - Login as facilitator
   - Navigate to learner list
   - Click "Generate PDF"

---

## 📊 Content Structure (30+ Pages)

### Page 1: Cover Page
```
- DHET Logo & Branding
- Portfolio Title
- Trade Information (Electrician, Bricklaying, Plumbing)
- Watermark
- Learner Name & ID
- Generation Date
```

### Pages 2-3: Index & Contents
```
- Table of contents with page numbers
- Document structure overview
- Navigation guide
```

### Pages 4-XX: Appendices (A-K)

| Appendix | Title | Content |
|----------|-------|---------|
| **A** | Application Form | Learner details, employment history, signatures |
| **B** | Competency Scale | Reference: 1=Fundamental, 2=Intermediate, 3=Competent, 4=Proficient, 5=Expert |
| **C** | Self-Evaluation Checklist | Activities rated 1-5 with assessor verification |
| **D** | Trade Curriculum | Curriculum standards & requirements |
| **E** | Practical Skills Assessment | Trade-specific practical criteria (15+ items) |
| **F** | Workplace Experience | Activities rated 1-5 with witness verification |
| **G** | Assessment Agreement | Assessment terms & conditions |
| **H** | Appeals Form | Appeal procedures & contact details |
| **I** | Access Recommendation | Assessor recommendation section |
| **J** | Statement of Results | Final results & competency statement |
| **K** | Pre-Assessment Agreement | Candidate pre-assessment consent |

### Trade-Specific Content

**Electrician (671101)**:
- Electrical installation activities
- Safety procedures
- Circuit design & installation
- Cable management
- Testing & commissioning

**Bricklaying (641201)**:
- Brickwork techniques
- Mortar preparation
- Wall construction
- Quality standards
- Health & safety

**Plumbing (642601)**:
- Pipe installation
- Fitting connections
- Drainage systems
- Water pressure testing
- Code compliance

---

## 🐛 Common Issues & Solutions

### Issue 1: "Invalid parameters. Please start over."

**Symptoms**: Error page shows when accessing generate_pdf.php

**Cause**: 
- learnerID not in URL or invalid
- ofo_code not in URL or invalid
- classID not in URL and auto-lookup failed

**Solution**:
```bash
# 1. Verify learner exists
SELECT * FROM learnerdetails WHERE LearnerID = 16389;

# 2. Verify class enrollment
SELECT * FROM learnerdetails WHERE LearnerID = 16389 AND classID = 782;

# 3. Use full parameter URL
http://localhost:8080/web/generate_pdf.php?learnerID=16389&classID=782&ofo_code=671101
```

### Issue 2: Blank page / No content

**Symptoms**: Page loads but nothing displays

**Cause**:
- Session not authenticated
- Database query failed
- PDF generator not found

**Solution**:
```bash
# 1. Check session (login as facilitator first)
# 2. Check file exists
ls -la /web/web/web/generate_arpl_pdf.php
# 3. Check database connection
php -r "include 'connection.php'; var_dump($conn);"
```

### Issue 3: 404 on redirect

**Symptoms**: "404 Not Found" error

**Cause**:
- Wrong URL path
- Extra or missing `/web/` segments
- File moved to wrong location

**Solution**:
```
Expected URL structure:
http://localhost:8080/web/web/web/generate_arpl_pdf.php
                       ↑      ↑     ↑
                    base   web   web  (3 segments)

Verify file exists at:
c:\projects\rlmss\web\web\web\generate_arpl_pdf.php
                        ↑      ↑     ↑
                       web    web   web  (3 segments)
```

### Issue 4: PDF looks different than mobile app

**Symptoms**: Layout or styling doesn't match

**Cause**:
- CSS not applied
- Wrong template version
- Browser print settings

**Solution**:
```bash
# 1. Use latest generate_arpl_pdf.php (v3)
# 2. Check print CSS in browser DevTools
# 3. Use Chrome/Chromium (best PDF rendering)
# 4. Set print margins: None
```

---

## ✅ Deployment Checklist

Before deploying to production:

- [ ] **Files in place**:
  - [ ] `/web/generate_pdf.php` (wrapper)
  - [ ] `/web/web/web/generate_arpl_pdf.php` (generator)
  - [ ] `/web/test_arpl_setup.php` (diagnostic)

- [ ] **Database verified**:
  - [ ] Test learner exists (16389)
  - [ ] Test class exists (782)
  - [ ] Enrollment link exists
  - [ ] Tables have required columns

- [ ] **Files have correct permissions**:
  - [ ] Readable by web server
  - [ ] PDFs can be written (if saving to disk)
  - [ ] Session directory writable

- [ ] **Testing complete**:
  - [ ] Diagnostic tool shows all ✅
  - [ ] Auto-lookup URL works
  - [ ] Full-parameter URL works
  - [ ] PDF generates with all 30+ pages
  - [ ] All appendices present
  - [ ] Trade content correct
  - [ ] No browser console errors

- [ ] **Documentation**:
  - [ ] Team trained on new system
  - [ ] Support docs shared
  - [ ] Troubleshooting guide reviewed

---

## 🆘 Support & Troubleshooting

### Resources Available

1. **Diagnostic Tool** (Recommended first step):
   ```
   http://localhost:8080/web/test_arpl_setup.php
   ```
   Tests: Database, files, learner data, URLs

2. **Technical Documentation**:
   - `ARPL_PDF_PARAMETER_VALIDATION_FIX.md` - Deep technical details
   - `ARPL_PDF_QUICK_TEST.md` - Testing & debugging

3. **Browser Console** (For real-time debugging):
   ```
   F12 → Console tab
   Look for: 🔷, 📄, 📨, 🔗 messages
   ```

### Quick Debug Commands

```bash
# Test PHP syntax
php -l /web/generate_pdf.php
php -l /web/web/web/generate_arpl_pdf.php

# Test database connection
php -r "include 'connection.php'; echo $conn->ping() ? 'Connected' : 'Failed';"

# Test file permissions
ls -la /web/generate_pdf.php
ls -la /web/web/web/generate_arpl_pdf.php

# Test learner data
mysql -u root -p -e "SELECT * FROM learnerdetails WHERE LearnerID = 16389;"
```

### Contact Support

If issues persist:
1. Run diagnostic tool: `http://localhost:8080/web/test_arpl_setup.php`
2. Share diagnostic output
3. Share browser console errors (F12)
4. Share database query results for learner/class

---

**Last Updated**: July 11, 2026  
**Version**: 3.0  
**Status**: ✅ PRODUCTION READY
