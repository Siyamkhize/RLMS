# Web ARPL Portfolio Generator - Implementation Guide

**Date:** July 10, 2026  
**Status:** Phase 1-2 Complete (Backend + Frontend UI)

---

## What Has Been Completed

### ✅ Backend API Endpoints (4/4)

1. **`web/api/get_arpl_trades.php`**
   - Returns all 3 available trades
   - No authentication required (public data)
   - Used by: Trade selection page

2. **`web/api/get_arpl_classes.php`**
   - Retrieves classes by OFO code
   - Joins with sites table for location info
   - Used by: Class selection page

3. **`web/api/get_arpl_class_learners.php`**
   - Gets enrolled learners for a class
   - Filters by active enrollment status
   - Used by: Learner list page

4. **`web/api/get_arpl_complete_data.php`**
   - Aggregates complete learner data for PDF
   - Fetches documents from learner_document table
   - Retrieves POE papers (theory & practical)
   - Used by: PDF generation module

### ✅ Frontend Web Pages (4/4)

1. **`web/index.php`** - Trade Selection
   - 3 trade cards with icons
   - Session storage for trade selection
   - Responsive Bootstrap design

2. **`web/classes.php`** - Class Selection
   - Loads classes via AJAX
   - Breadcrumb navigation
   - Error handling & loading states

3. **`web/learners.php`** - Learner List
   - Displays learners in table format
   - "Generate ARPL" button per learner
   - Session management for trade + class

4. **`web/generate_pdf.php`** - PDF Info Page
   - Shows 24-page document structure
   - Implementation roadmap
   - Placeholder for actual PDF generation

### ✅ Supporting Files

- **`web/connection.php`** - Database connection proxy
- **`web/assets/css/arpl_style.css`** - Complete responsive stylesheet
- **`web/README.md`** - Full documentation

---

## Next Steps: PDF Generation (Phase 3)

### Installation Requirements

```bash
# Install mPDF via Composer (if not already installed)
cd c:\projects\rlmss
composer require mpdf/mpdf

# Or install via PHP
php -r "require_once 'vendor/autoload.php'; echo 'mPDF ready';"
```

### PDF Generation Module Structure

Create file: `web/generate_arpl_pdf.php`

```php
<?php
// This will be the main PDF generation endpoint
// Called by learners.php when "Generate ARPL" button clicked

// 1. Get parameters
$learnerID = $_POST['learnerID'];
$ofo_code = $_POST['ofo_code'];

// 2. Fetch complete data from aggregation endpoint
$json = file_get_contents('api/get_arpl_complete_data.php');
$data = json_decode($json, true);

// 3. Instantiate mPDF
$mpdf = new \Mpdf\Mpdf();

// 4. Generate pages:
//    - Cover page
//    - Checklist (from uploaded PDF)
//    - Appendices A-I
//    - Supporting documents
//    - Gap closure
//    - Registers
//    - Assessor details
//    - etc.

// 5. Output PDF
$mpdf->Output('ARPL_' . $learnerID . '.pdf', 'D');
?>
```

### Page-by-Page Implementation

#### Page 1: Cover Page Template
```html
<html>
<head><title>ARPL Cover</title></head>
<body>
  <h1>ARPL TOOLKIT COVER PAGE</h1>
  <table>
    <tr><td>Candidate Name:</td><td>{learner_name}</td></tr>
    <tr><td>ID Number:</td><td>{id_number}</td></tr>
    <tr><td>Trade:</td><td>{trade_name} (OFO {ofo_code})</td></tr>
    <tr><td>Class:</td><td>{class_name}</td></tr>
    <tr><td>Site:</td><td>{site_name}</td></tr>
    <tr><td>Assessor:</td><td>{assessor_name}</td></tr>
    <tr><td>Date Generated:</td><td>{today}</td></tr>
  </table>
</body>
</html>
```

#### Page 2: Portfolio Checklist
- Embed the user-uploaded checklist PDF (from documents table)
- Or convert to images and insert

#### Pages 3-5: Supporting Documents
```php
// Fetch and embed each document
foreach ($data['documents']['id_copy'] as $doc) {
    $mpdf->AddPage();
    $mpdf->Image($doc['file_path']);  // Embed image
}

// Similar for CV, qualifications, service letters
```

#### Pages 6-14: Appendices A-I
```php
// Fetch from mobile toolkit endpoints or aggregate tables
// Use templates for consistent formatting
// Populate with learner data from database
```

#### Page 15: Gap Closure Report
```html
<table border="1">
  <tr>
    <th>No.</th>
    <th>Task</th>
    <th>Assessment Method</th>
    <th>BAD</th>
    <th>FAIR</th>
    <th>GOOD</th>
    <th>Assessor Comments</th>
  </tr>
  <!-- Populated from arplbricklayer_gap_unit_standards table -->
</table>
```

### Document Embedding Strategy

**Option 1: Base64 Embedding** (Safest, larger file)
```php
$imageData = file_get_contents($filePath);
$base64 = base64_encode($imageData);
$mpdf->Image('data:image/jpeg;base64,' . $base64);
```

**Option 2: File Path Reference** (Requires file server access)
```php
$mpdf->Image($filePath);
```

**Option 3: URL Reference** (Requires web accessible path)
```php
$mpdf->Image('http://localhost/uploads/' . $fileName);
```

### Error Handling

```php
try {
    $mpdf = new \Mpdf\Mpdf();
    // ... PDF generation ...
    $mpdf->Output('ARPL_' . $learnerID . '.pdf', 'D');
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'PDF generation failed: ' . $e->getMessage()
    ]);
}
```

---

## Testing Checklist

### Phase 1-2 Testing (UI/API)
- [ ] Test trade selection page
  - [ ] Can select each trade
  - [ ] Session storage works
  - [ ] Navigation works
  
- [ ] Test class selection page
  - [ ] Classes load via AJAX
  - [ ] Correct classes for each trade
  - [ ] Can select a class
  - [ ] Breadcrumb shows correct trade
  
- [ ] Test learner list page
  - [ ] Learners load for selected class
  - [ ] Display all columns correctly
  - [ ] Generate button accessible
  - [ ] Session maintains trade & class
  
- [ ] Test API endpoints
  ```bash
  # Test trades endpoint
  curl -X POST http://localhost/web/api/get_arpl_trades.php
  
  # Test classes endpoint
  curl -X POST http://localhost/web/api/get_arpl_classes.php \
    -H "Content-Type: application/json" \
    -d '{"ofo_code":"671101"}'
  
  # Test learners endpoint
  curl -X POST http://localhost/web/api/get_arpl_class_learners.php \
    -H "Content-Type: application/json" \
    -d '{"classID":782}'
  
  # Test complete data endpoint
  curl -X POST http://localhost/web/api/get_arpl_complete_data.php \
    -H "Content-Type: application/json" \
    -d '{"learnerID":20286,"ofo_code":"671101"}'
  ```

### Phase 3 Testing (PDF Generation)
- [ ] PDF generates without errors
- [ ] Cover page displays correctly
- [ ] All 24 pages present
- [ ] Appendix data populated
- [ ] Documents embedded properly
- [ ] Test each trade (electrician, bricklaying, plumbing)
- [ ] Test learner with missing documents
- [ ] Test performance (multiple PDF generation)

### Phase 4 Testing (Refinement)
- [ ] All 3 trades work end-to-end
- [ ] Document formatting consistent
- [ ] No memory errors on large PDFs
- [ ] Mobile responsiveness (if applicable)
- [ ] Error messages helpful
- [ ] Browser compatibility

---

## Database Verification

Before deploying, verify all required tables exist:

```sql
-- Check trade/class setup
SELECT DISTINCT ofoNumber, trade FROM class;

-- Check learner enrollment
SELECT COUNT(*) FROM enrollment WHERE EnrollmentStatus IN ('Active', 'Completed', 'Enrolled');

-- Check ARPL tables for each trade
SHOW TABLES LIKE 'arpl%';
SHOW TABLES LIKE 'appxh%';

-- Check documents
SELECT DISTINCT document_type FROM learner_document;

-- Check POE papers
SELECT DISTINCT poe_type FROM poe;
```

---

## Deployment Steps

### 1. Copy Web Files
```bash
# Ensure web directory exists and has proper permissions
chmod -R 755 web/
chmod -R 777 web/uploads/  # If needed for document access
```

### 2. Create Directories
```bash
mkdir -p web/api
mkdir -p web/assets/css
mkdir -p web/assets/js
mkdir -p web/assets/images
mkdir -p web/templates
```

### 3. Update Configuration
- Edit `web/connection.php` to point to correct database
- Update any hardcoded URLs in JavaScript
- Ensure .htaccess allows access to web/index.php

### 4. Install Dependencies
```bash
cd c:\projects\rlmss
composer install  # For mPDF when ready
```

### 5. Test URL Access
```
http://localhost/web/index.php
```

---

## File Sizes & Performance Notes

### Current Implementation
- **HTML/CSS/JS:** ~50KB total
- **API Responses:** ~10-50KB depending on learner data
- **Expected PDF Size:** 20-50MB (with embedded documents)

### Optimization Opportunities
1. Minify CSS/JavaScript
2. Compress embedded images in PDF
3. Implement chunked PDF generation for large classes
4. Cache class/learner lists
5. Lazy-load learner photos in PDF

---

## Quick Reference

### File Locations
```
Backend:  /web/api/*.php
Frontend: /web/index.php, classes.php, learners.php, generate_pdf.php
Styles:   /web/assets/css/arpl_style.css
Database: rlmsrlmsco_ezxcmacd_rlms (via connection.php)
```

### Key APIs
```
GET /web/api/get_arpl_trades.php
POST /web/api/get_arpl_classes.php        (ofo_code)
POST /web/api/get_arpl_class_learners.php (classID)
POST /web/api/get_arpl_complete_data.php  (learnerID, ofo_code)
```

### Session Storage Keys
```javascript
selectedTradeOFO   // e.g., "671101"
selectedClassID    // e.g., "782"
```

---

## Contact & Support

For issues or questions about the web portal implementation:
1. Check the `web/README.md` for detailed documentation
2. Review API responses for error messages
3. Check browser console for JavaScript errors
4. Review PHP error logs for backend issues

---

**Next Session:** Implement PDF generation module (Phase 3)
