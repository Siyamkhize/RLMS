# ARPL PDF v3 - Usage in Web Folder

## File Location
```
✅ c:\projects\rlmss\web\generate_arpl_pdf_v3.php
```

**Web URL**: `http://localhost:8080/web/generate_arpl_pdf_v3.php`

---

## How to Use

### 1. Call the API with POST Request
```javascript
async function generateARPLPDF(learnerID, classID, ofoNumber = '671101') {
  const response = await fetch('/web/generate_arpl_pdf_v3.php', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      learnerID,
      classID,
      ofoNumber
    })
  });
  
  const html = await response.text();
  const w = window.open();
  w.document.write(html);
  w.document.close();
}

// Call it
generateARPLPDF(16389, 123, '671101'); // Electrician
generateARPLPDF(16389, 123, '641201'); // Bricklayer
generateARPLPDF(16389, 123, '642601'); // Plumber
```

### 2. Use in Web UI
Add to `web/learners.php` or other pages:

```html
<button onclick="generateARPLPDF(<?= $learnerID ?>, <?= $classID ?>, '671101')">
  🖨 Generate ARPL PDF
</button>
```

### 3. Print to PDF
Once generated:
1. Click "Print / Save as PDF" button in toolbar
2. Or press `Ctrl+P` and select "Save as PDF"
3. Choose save location

---

## Trade Codes

| Trade | OFO Code |
|-------|----------|
| Electrician | 671101 |
| Bricklaying | 641201 |
| Plumbing | 642601 |

---

## Features

✅ Professional ARPL PDF with all 11 appendices
✅ Trade-specific content (Electrician, Bricklaying, Plumbing)
✅ Learner data prefilled from database
✅ Print-optimized layout
✅ Professional DHET branding
✅ Form fields ready for completion

---

## Request Parameters

```json
{
  "learnerID": 16389,      // Required: Learner ID from database
  "classID": 123,          // Required: Class ID from database
  "ofoNumber": "671101"    // Optional: OFO code (default: 671101)
}
```

---

## Response

**Success (HTTP 200)**:
- Returns complete HTML document ready for printing

**Error (HTTP 400/403/404/500)**:
```json
{
  "status": "error",
  "message": "Error description"
}
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Not authorized" | Ensure user is logged in (SDP or facilitator session) |
| "Learner not found" | Verify learnerID & classID exist in database |
| "Class data not found" | Check class has site, project, and SDP associations |
| Prefilled data missing | Verify learner data exists in `learnerdetails` table |

---

## File Structure

```
web/
├── generate_arpl_pdf_v3.php     ← Main PDF generator (this file)
├── learners.php                  ← Add button here
├── index.php                     ← Optional integration
└── ... other web files
```

---

## Database Connection

The script automatically includes the connection file from the parent directory:
```php
@include __DIR__ . '/../connection.php';
```

Ensure `c:\projects\rlmss\connection.php` exists and is properly configured.

---

## Security

✅ Session authentication required
✅ HTML escaping on all user data
✅ Prepared statements for all queries
✅ Authorization checks before generating

---

## Next Steps

1. Add JavaScript function to your web pages
2. Add button to generate PDF
3. Test with different trades
4. Print to PDF and verify output

---

**Status**: ✅ Ready to use at `/web/generate_arpl_pdf_v3.php`
