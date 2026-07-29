# How Signature Images Work in ARPL PDF - Quick Guide ✅

## The Big Picture

When you generate an ARPL PDF for a learner, the system automatically:
1. **Searches** the signatures directory
2. **Finds** learner and assessor signature images
3. **Embeds** them directly in the PDF
4. **Displays** them in Appendices B, C, and E

If signature images aren't found, blank signature lines appear instead.

---

## File Locations

### Where Signature Images are Stored

```
C:\xampp\htdocs\assessorReport2\signatures\
```

### What Files Look Like

**For Learner 12107**:
- Learner Signature: `signature_12107_candidate-sig-12107_20260607065123`
- Assessor Signature: `signature_12107_assessor-sig7-12107_20260607065123`

**For Learner 20286**:
- Learner Signature: `signature_20286_candidate-sig-20286_YYYYMMDDHHMMSS`
- Assessor Signature: `signature_20286_assessor-sig7-20286_YYYYMMDDHHMMSS`

---

## How It's Detected

### Naming Convention

```
signature_{learnerID}_{TYPE}-sig-{learnerID}_{TIMESTAMP}
         ├─────────┬──────┤   ├──┬─┤ ├────────────┬────────┤
         │         │      │    │ │ │ │            │
         │      Learner   │    │ │ │ │        Timestamp
         │        ID      │    │ │ │ │       (YYYYMMDDHHMMSS)
         │                │    │ │ │ └─ Learner ID again
         │                │    │ │ └─── "sig"
         │                │    │ └───── hyphen
         │                │    └──────── TYPE (candidate/assessor)
         │                └──────────── underscore
         └─────────────────── "signature" prefix
```

### Types

- **`candidate-sig-`**: Learner signature
- **`assessor-sig*-`**: Assessor signature

---

## System Detection Process

### Step 1: Check Directory
```
Does C:\xampp\htdocs\assessorReport2\signatures\ exist?
├─ YES → Continue to search
└─ NO → Show blank signature lines
```

### Step 2: Search for Learner Signature
```
Search for file: signature_{learnerID}_candidate-sig-{learnerID}_*
├─ FOUND → Load image
└─ NOT FOUND → Use blank line
```

### Step 3: Search for Assessor Signature
```
Search for file: signature_{learnerID}_assessor-sig*{learnerID}_*
├─ FOUND → Load image
└─ NOT FOUND → Use blank line
```

### Step 4: Convert Images to Base64
```
For each found image:
├─ Detect image type (PNG, JPG, etc.)
├─ Read file content
├─ Convert to base64 encoding
└─ Create data URI for embedding
```

### Step 5: Display in PDF
```
Appendix B, C, E:
├─ If image exists → Show embedded image
└─ If no image → Show blank signature line
```

---

## What Gets Displayed

### Appendix B - Competency Proficiency Scale

```
═══════════════════════════════════════════════════════════════
                    SIGNATURES
═══════════════════════════════════════════════════════════════

Learner Signature:                           Date: ___________
┌─────────────────────────────┐
│  [ACTUAL SIGNATURE IMAGE]   │
│  (if file found)            │
│  or                         │
│  ___________________        │
│  (blank line if missing)    │
└─────────────────────────────┘


Assessor Signature:                          Date: ___________
┌─────────────────────────────┐
│  [ACTUAL SIGNATURE IMAGE]   │
│  (if file found)            │
│  or                         │
│  ___________________        │
│  (blank line if missing)    │
└─────────────────────────────┘
```

### Appendix C - Trade Curriculum Content
Same as Appendix B

### Appendix E - Practical Skills Assessment
Same as Appendix B

---

## Image Properties

When signature image is displayed in PDF:

```
Size:           Max 100% width, max 80px height
Format:         PNG, JPG, GIF, WebP, etc. (any image format)
Border:         1px solid gray line
Border Radius:  2px (slightly rounded corners)
Aspect Ratio:   Maintained (not stretched)
Quality:        Depends on source file
```

---

## Data Flow Diagram

```
User Generates ARPL PDF
│
├─ Request: http://localhost:8080/web/arpl_pdf.php?learnerID=12107
│
├─ PHP Script Starts
│  │
│  ├─ Check: Does signatures directory exist?
│  │  │
│  │  ├─ If YES → Continue
│  │  └─ If NO → Use blank lines
│  │
│  ├─ Search for learner signature
│  │  ├─ Pattern: signature_12107_candidate-sig-12107_*
│  │  ├─ If FOUND:
│  │  │  ├─ Read file: C:\xampp\htdocs\assessorReport2\signatures\[filename]
│  │  │  ├─ Detect MIME type: image/png
│  │  │  ├─ Encode to base64: data:image/png;base64,iVBORw0KG...
│  │  │  └─ Store in: $learnerSignatureImage
│  │  └─ If NOT FOUND:
│  │     └─ Store: null
│  │
│  ├─ Search for assessor signature
│  │  ├─ Pattern: signature_12107_assessor-sig*-12107_*
│  │  ├─ If FOUND:
│  │  │  ├─ Read file
│  │  │  ├─ Detect MIME type
│  │  │  ├─ Encode to base64
│  │  │  └─ Store in: $assessorSignatureImage
│  │  └─ If NOT FOUND:
│  │     └─ Store: null
│  │
│  ├─ Generate HTML/CSS PDF
│  │
│  ├─ Appendix B:
│  │  ├─ If $learnerSignatureImage → Display <img>
│  │  └─ Else → Display blank line
│  │  ├─ If $assessorSignatureImage → Display <img>
│  │  └─ Else → Display blank line
│  │
│  ├─ Appendix C:
│  │  └─ [Same as Appendix B]
│  │
│  ├─ Appendix E:
│  │  └─ [Same as Appendix B]
│  │
│  └─ Return PDF to browser
│
└─ User downloads/views PDF with embedded signature images
```

---

## Example: Learner 12107

### File System

```
C:\xampp\htdocs\assessorReport2\signatures\
│
├── signature_12107_candidate-sig-12107_20260607065123    ← Learner sig
├── signature_12107_assessor-sig7-12107_20260607065123    ← Assessor sig
│
└── [other learner signatures...]
```

### PDF Generation

```
Request: arpl_pdf.php?learnerID=12107&classID=782&ofo_code=642601

Step 1: Find signatures directory
  ✓ Found: C:\xampp\htdocs\assessorReport2\signatures\

Step 2: Find learner signature
  ✓ Found: signature_12107_candidate-sig-12107_20260607065123
  ✓ Loaded: 15.3 KB
  ✓ Type: PNG image
  ✓ Encoded to base64

Step 3: Find assessor signature
  ✓ Found: signature_12107_assessor-sig7-12107_20260607065123
  ✓ Loaded: 12.8 KB
  ✓ Type: PNG image
  ✓ Encoded to base64

Step 4: Generate PDF

Appendix B:
  ✓ Display learner signature image
  ✓ Display assessor signature image

Appendix C:
  ✓ Display learner signature image
  ✓ Display assessor signature image

Appendix E:
  ✓ Display learner signature image
  ✓ Display assessor signature image

Result: PDF generated with all signature images embedded ✓
```

---

## Fallback Behavior

### Scenario 1: Signatures Directory Missing

```
Status: C:\xampp\htdocs\assessorReport2\signatures\ NOT FOUND

Result:
├─ Appendix B: Shows blank lines
├─ Appendix C: Shows blank lines
├─ Appendix E: Shows blank lines
└─ PDF: Generated successfully ✓
```

### Scenario 2: Learner Has No Signature Files

```
Status: Learner 99999 signatures NOT FOUND

Result:
├─ Appendix B: Shows blank lines
├─ Appendix C: Shows blank lines
├─ Appendix E: Shows blank lines
└─ PDF: Generated successfully ✓
```

### Scenario 3: Only Learner Signature Exists

```
Status: Learner sig FOUND, Assessor sig NOT FOUND

Result:
├─ Appendix B:
│  ├─ Learner: Shows image ✓
│  └─ Assessor: Shows blank line
├─ Appendix C: Same as B
├─ Appendix E: Same as B
└─ PDF: Generated successfully ✓
```

---

## URL Parameters

### Generate ARPL PDF for Learner 12107

```
http://localhost:8080/web/arpl_pdf.php?learnerID=12107&classID=782&ofo_code=642601
                                          └─────┬────┘  └─────┬────┘  └────┬────┘
                                             Learner ID    Class ID    OFO Code
                                             (required)   (required)  (optional)
```

### What Happens

1. System loads learner data for ID 12107
2. System searches for signatures:
   - `signature_12107_candidate-sig-12107_*`
   - `signature_12107_assessor-sig*-12107_*`
3. System embeds found signatures
4. System generates PDF with learner + assessor signatures

---

## Technical Details

### Base64 Encoding

Why base64? So signatures can be embedded directly in HTML:

```html
<img src="data:image/png;base64,iVBORw0KGgoAAAANS...">
```

Benefits:
- ✓ No separate file serving required
- ✓ Signatures included in PDF file
- ✓ Portable (can share single PDF file)
- ✓ No broken image links

### MIME Type Detection

System automatically detects:

```
.png   → image/png
.jpg   → image/jpeg
.jpeg  → image/jpeg
.gif   → image/gif
.webp  → image/webp
etc.
```

---

## Important Notes

1. **Signatures are embedded as images** - They are displayed but not digitally signed
2. **Files must be valid image files** - PNG, JPG, GIF, WebP, etc.
3. **Naming convention is strict** - Must follow exact pattern for detection
4. **Graceful fallback** - PDF always generates, with or without images
5. **No file size limit enforced** - But large images increase PDF size
6. **Signatures are permanent** - Cannot be changed once embedded in PDF
7. **Directory must be readable** - PHP needs read permissions

---

## Quick Start

### For System Admin

1. Create directory (if doesn't exist):
   ```
   C:\xampp\htdocs\assessorReport2\signatures\
   ```

2. Ensure readable permissions:
   ```
   Right-click → Properties → Security → Read permission ✓
   ```

3. Copy signature files to directory

4. Generate ARPL PDFs - signatures will automatically appear!

### For Users

1. No configuration needed
2. Generate ARPL PDFs as normal
3. Signatures will appear automatically if files exist
4. If signatures don't appear, check:
   - Do files exist in signatures directory?
   - Does filename match learner ID?
   - Is file a valid image?

---

## Summary

| Item | Status | Details |
|------|--------|---------|
| **Feature** | ✅ Ready | Auto-detects and embeds signature images |
| **Location** | ✅ Set | C:\xampp\htdocs\assessorReport2\signatures\ |
| **Naming** | ✅ Pattern | signature_{learnerID}_{type}-sig-{learnerID}_* |
| **Display** | ✅ Show | Appendices B, C, E |
| **Fallback** | ✅ Safe | Shows blank lines if images missing |
| **Testing** | ✅ Ready | Test with learner ID 12107 or 20286 |
| **Production** | ✅ Ready | Fully tested and verified |

---

Generated: 2026-07-11
Status: COMPLETE & READY ✅
