# SDP Learner View - Image Upload Fix for "Other" Documents

## Problem
Currently, the `sdp_learnerView.php` file only allows PDF uploads for all document types, including when "Other" is selected. Users need to be able to upload PNG and other image file types when selecting "Other" as the document type.

## Solution
Modify the file input's `accept` attribute and validation to allow image files when "Other" is selected.

## Changes Required

### 1. Update the file input HTML (around line 445)

**Current code:**
```html
<input type="file" class="form-control-file" id="document" name="learner_document" accept="application/pdf" required>
```

**Replace with:**
```html
<input type="file" class="form-control-file" id="document" name="learner_document" accept="application/pdf" required>
```

### 2. Update the label text (around line 443)

**Current code:**
```html
<label for="document">Upload Document: <span class="text-muted">(PDF only, max 30MB)</span></label>
```

**Replace with:**
```html
<label for="document">Upload Document: <span class="text-muted" id="fileTypeHint">(PDF only, max 30MB)</span></label>
```

### 3. Update the toggleOtherField() JavaScript function (around line 785)

**Current code:**
```javascript
function toggleOtherField() {
    const documentDropdown = document.getElementById('name').value;
    const otherField = document.getElementById('otherDocumentField');
    otherField.style.display = (documentDropdown === 'Other') ? 'block' : 'none';
}
```

**Replace with:**
```javascript
function toggleOtherField() {
    const documentDropdown = document.getElementById('name').value;
    const otherField = document.getElementById('otherDocumentField');
    const fileInput = document.getElementById('document');
    const fileTypeHint = document.getElementById('fileTypeHint');
    
    if (documentDropdown === 'Other') {
        otherField.style.display = 'block';
        // Allow both PDF and image files for "Other" documents
        fileInput.accept = 'application/pdf,image/*,.png,.jpg,.jpeg,.gif,.bmp,.webp';
        fileTypeHint.textContent = '(PDF or Image files, max 30MB)';
    } else {
        otherField.style.display = 'none';
        // Only PDF for standard document types
        fileInput.accept = 'application/pdf';
        fileTypeHint.textContent = '(PDF only, max 30MB)';
    }
}
```

### 4. Add file validation in the form submission (around line 714)

Add this validation code in the `$('#documentUploadForm').on('submit', function (e) {` section, after the existing validations:

```javascript
// Validate file type based on document selection
const fileInput = document.getElementById('document');
const selectedFile = fileInput.files[0];

if (selectedFile) {
    const fileName = selectedFile.name.toLowerCase();
    const documentType = $('#name').val();
    
    if (documentType === 'Other') {
        // Allow PDF and common image formats for "Other"
        const allowedExtensions = ['.pdf', '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
        const isValidFile = allowedExtensions.some(ext => fileName.endsWith(ext));
        
        if (!isValidFile) {
            uploadStatus.html('<div class="alert alert-danger">For "Other" documents, please upload a PDF or image file (PNG, JPG, JPEG, GIF, BMP, WEBP).</div>');
            return;
        }
    } else {
        // Only PDF for standard document types
        if (!fileName.endsWith('.pdf')) {
            uploadStatus.html('<div class="alert alert-danger">Please upload a PDF file for this document type.</div>');
            return;
        }
    }
}
```

## Backend Considerations

You may also need to update the backend PHP script that handles the file upload to properly handle image files. Check the following files:
- `upload_temp_document.php` (referenced in the JavaScript)
- Any file validation on the server side

Make sure the server-side validation also allows image files when the document type is "Other".

## Testing

After implementing these changes:

1. Select "Other" from the document dropdown
2. Verify that the file input now accepts both PDF and image files
3. Try uploading a PNG file
4. Verify that standard document types still only accept PDF files
5. Test the file size validation still works (30MB limit)

## File Location

The file to modify is: `c:\Users\Administrator\Downloads\sdp_learnerView.php`