// Updated toggleOtherField function for sdp_learnerView.php
// This function should replace the existing toggleOtherField() function

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

// Additional file validation function to add to the form submission handler
function validateFileType() {
    const fileInput = document.getElementById('document');
    const selectedFile = fileInput.files[0];
    const documentType = $('#name').val();
    
    if (selectedFile) {
        const fileName = selectedFile.name.toLowerCase();
        
        if (documentType === 'Other') {
            // Allow PDF and common image formats for "Other"
            const allowedExtensions = ['.pdf', '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
            const isValidFile = allowedExtensions.some(ext => fileName.endsWith(ext));
            
            if (!isValidFile) {
                return {
                    valid: false,
                    message: 'For "Other" documents, please upload a PDF or image file (PNG, JPG, JPEG, GIF, BMP, WEBP).'
                };
            }
        } else {
            // Only PDF for standard document types
            if (!fileName.endsWith('.pdf')) {
                return {
                    valid: false,
                    message: 'Please upload a PDF file for this document type.'
                };
            }
        }
    }
    
    return { valid: true };
}