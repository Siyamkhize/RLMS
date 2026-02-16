# Pothole Evidence Upload Implementation Guide

## Overview
Implemented image upload functionality for pothole checklist evidence. Images are stored in the existing `poe` table and will automatically appear in the logbook section.

## Files Created/Modified

### New PHP Files
1. **upload_pothole_evidence.php** - Handles image uploads to server
2. **test_pothole_upload.php** - Test page to verify upload functionality

### Modified Flutter Files
1. **lib/AssessorPage.dart** - Added upload button and functionality

## Database Structure

Images are stored in the existing `poe` table with:
- `learnerID` - The learner's ID
- `exercise` - "Pothole Patching Evidence - [timestamp]"
- `type` - "LogBook"
- `filePath` - Path to uploaded image (uploads/pothole_evidence/)
- `logbook_text` - Notes about the upload (assessor, date)

## Deployment Steps

### 1. Upload PHP Files
Upload these files to your server:
```
upload_pothole_evidence.php
test_pothole_upload.php (optional, for testing)
```

### 2. Create Upload Directory
The script will auto-create the directory, but you can manually create it:
```bash
mkdir -p uploads/pothole_evidence
chmod 755 uploads/pothole_evidence
```

### 3. Test the Upload
1. Navigate to: `https://rlms.rlms.co.za/mobile/test_pothole_upload.php`
2. Verify:
   - ✓ Upload directory exists and is writable
   - ✓ Database connection successful
   - ✓ POE table exists
3. Use the test form to upload sample images
4. Check that images appear in the "Recent Pothole Evidence Uploads" section

### 4. Deploy Flutter App
Rebuild and deploy the Flutter app with the updated AssessorPage.dart

## How It Works

### User Flow
1. Assessor opens the Pothole Checklist learner list
2. Clicks the green "Upload" button next to a learner's name
3. Selects multiple images from device gallery
4. Images are uploaded to server
5. Success message shows number of images uploaded
6. Images automatically appear in the learner's logbook

### Technical Flow
1. User selects images via `image_picker` package
2. Flutter creates multipart HTTP request
3. PHP receives images and validates them (type, size)
4. Images are saved to `uploads/pothole_evidence/` directory
5. Each image is inserted into `poe` table as a LogBook entry
6. Response sent back to Flutter with success/error status

## Features

### Image Validation
- **Allowed types**: JPEG, JPG, PNG, GIF
- **Max size**: 10MB per image
- **Multiple uploads**: Yes, unlimited

### Error Handling
- Invalid file types rejected
- Oversized files rejected
- Database errors logged
- Failed uploads don't leave orphaned files
- Partial success supported (some images succeed, others fail)

### Security
- File type validation
- File size limits
- Unique filename generation (prevents overwrites)
- SQL injection protection (prepared statements)

## Viewing Uploaded Images

Images will appear in the logbook section alongside other POE documents because they use:
- `type` = "LogBook"
- Standard `poe` table structure

Any existing logbook viewing functionality will automatically display these images.

## Troubleshooting

### Upload fails with "Connection failed"
- Check database credentials in connection.php
- Verify database server is running

### Upload fails with "Failed to move uploaded file"
- Check directory permissions: `chmod 755 uploads/pothole_evidence`
- Verify PHP has write access to uploads directory

### Images don't appear in logbook
- Verify the logbook view queries the `poe` table
- Check that `type = 'LogBook'` entries are displayed
- Query database: `SELECT * FROM poe WHERE exercise LIKE 'Pothole%'`

### "No images uploaded" error
- Ensure images are being selected in Flutter
- Check network connectivity
- Verify PHP file upload limits in php.ini:
  ```
  upload_max_filesize = 20M
  post_max_size = 25M
  ```

## Testing Checklist

- [ ] Upload directory created and writable
- [ ] Database connection successful
- [ ] Test upload via test_pothole_upload.php works
- [ ] Images saved to uploads/pothole_evidence/
- [ ] Database entries created in poe table
- [ ] Flutter app can select multiple images
- [ ] Flutter app uploads successfully
- [ ] Success message displays in app
- [ ] Images appear in logbook section
- [ ] Error handling works (try invalid file types)

## Future Enhancements

Potential improvements:
1. Image compression before upload (reduce bandwidth)
2. Thumbnail generation for faster loading
3. Image preview before upload
4. Delete/replace uploaded images
5. Associate images directly with checklist entries
6. Offline upload queue (upload when connection restored)
7. Image annotation/markup tools

## Support

If you encounter issues:
1. Check test_pothole_upload.php for diagnostics
2. Review PHP error logs
3. Check Flutter console for errors
4. Verify database entries: `SELECT * FROM poe WHERE type='LogBook' ORDER BY id DESC LIMIT 10`
