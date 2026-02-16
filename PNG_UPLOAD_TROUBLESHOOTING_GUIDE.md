# PNG Upload Troubleshooting Guide

## Issue
Getting "Only PDF files are allowed" error when trying to upload PNG files under "Other" document type.

## Debugging Steps

### Step 1: Clear Browser Cache
1. **Hard refresh** the page: `Ctrl+F5` (Windows) or `Cmd+Shift+R` (Mac)
2. **Clear browser cache** completely
3. **Open Developer Tools** (`F12`) and go to Console tab

### Step 2: Test the Correct Sequence
**IMPORTANT**: You must select "Other" from the dropdown BEFORE selecting the file.

**Correct Order:**
1. Click "Add Learner Document" button
2. **First**: Select "Other" from the "Select Name" dropdown
3. **Wait** for the text to change to "(PDF or Image files, max 30MB)"
4. **Then**: Click "Choose File" and select your PNG file

**Wrong Order (will cause error):**
1. Select file first
2. Then select "Other" ← This won't work!

### Step 3: Check Console Logs
With Developer Tools open (F12 → Console tab), you should see these debug messages:

**When selecting "Other":**
```
Document type selected: Other
Other selected - allowing image files
```

**When selecting PNG file:**
```
File extension: png Allowed: ['pdf', 'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp']
```

**During form submission:**
```
Form submission - Document type: Other File: yourfile.png
Other validation - Valid file: true Extensions: ['.pdf', '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp']
```

### Step 4: Verify UI Changes
When you select "Other":
- ✅ The text should change from "(PDF only, max 30MB)" to "(PDF or Image files, max 30MB)"
- ✅ An additional text field should appear asking for document name
- ✅ The file input should now accept image files

### Step 5: Test Different File Types
Try uploading these file types when "Other" is selected:
- ✅ PNG files (.png)
- ✅ JPG files (.jpg, .jpeg)
- ✅ GIF files (.gif)
- ✅ BMP files (.bmp)
- ✅ WEBP files (.webp)
- ✅ PDF files (.pdf)

## Common Issues and Solutions

### Issue 1: "Only PDF files are allowed" still appears
**Cause**: File was selected before choosing "Other"
**Solution**: 
1. Select "Other" from dropdown first
2. Wait for UI to update
3. Then select your PNG file

### Issue 2: UI doesn't update when selecting "Other"
**Cause**: JavaScript not loading or browser cache
**Solution**:
1. Hard refresh page (Ctrl+F5)
2. Check browser console for JavaScript errors
3. Ensure JavaScript is enabled

### Issue 3: File uploads but gets rejected
**Cause**: Backend validation might not be updated
**Solution**: Check these backend files:
- `upload_temp_document.php`
- `learnerDocument.php`

## Backend Files to Check

If the frontend works but backend rejects the file, update these files:

### 1. upload_temp_document.php
Add image file validation:
```php
$allowedTypes = ['application/pdf'];
if (isset($_POST['documentType']) && $_POST['documentType'] === 'Other') {
    $allowedTypes = [
        'application/pdf',
        'image/png',
        'image/jpeg',
        'image/jpg',
        'image/gif',
        'image/bmp',
        'image/webp'
    ];
}
```

### 2. learnerDocument.php
Update file type validation for "Other" documents.

## Testing Checklist

- [ ] Clear browser cache
- [ ] Open Developer Tools (F12)
- [ ] Select "Other" from dropdown FIRST
- [ ] Verify text changes to "(PDF or Image files, max 30MB)"
- [ ] Select PNG file
- [ ] Check console logs for debug messages
- [ ] Verify no JavaScript errors in console
- [ ] Test file upload

## If Still Not Working

1. **Check browser console** for any JavaScript errors
2. **Verify the file** `sdp_learnerView.php` was saved correctly
3. **Test with different browsers** (Chrome, Firefox, Edge)
4. **Check server logs** for any PHP errors
5. **Verify file permissions** on the server

## Contact Information

If the issue persists after following these steps, provide:
1. Browser console logs (screenshots)
2. Exact error messages
3. Browser and version being used
4. Steps you followed exactly