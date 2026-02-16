# Chunked Bulk Export System - Deployment Guide

## 🎯 Overview

This system enables bulk downloading of 2000+ learner reports with sick notes and manual registers **without timing out**. It uses a chunked processing approach that breaks large exports into small manageable pieces.

## ✨ Key Features

- ✅ **No Timeout Issues**: Processes in small chunks (10 learners at a time)
- ✅ **Real-time Progress**: Shows live progress updates
- ✅ **Includes Documents**: Automatically includes sick notes and manual registers
- ✅ **Scalable**: Can handle 2000+ learners efficiently
- ✅ **PDF Reports**: Generates individual PDF attendance reports
- ✅ **Organized ZIP**: Creates structured ZIP with folders for reports, sick notes, and manual registers

## 📁 Files to Upload

Upload these files to your server:

### 1. Core Processing Files
- `bulk_export_chunked.php` - Backend processor (handles chunked processing)
- `bulk_download_chunked.js` - Frontend JavaScript (manages UI and API calls)

### 2. Updated Files
- `bulk_down_register.php` - Updated with new button and script include

### 3. Test File (Optional)
- `test_chunked_export.php` - Test page to verify system works

## 🚀 Deployment Steps

### Step 1: Upload Files

Upload all files to your server root directory (same location as bulk_down_register.php):

```
/your-server-root/
├── bulk_export_chunked.php          ← NEW
├── bulk_download_chunked.js         ← NEW
├── bulk_down_register.php           ← UPDATED
├── test_chunked_export.php          ← NEW (optional)
├── connection.php                   (existing)
├── vendor/                          (existing - Composer dependencies)
└── temp_reports/                    (will be created automatically)
```

### Step 2: Set Permissions

Ensure the server can create directories:

```bash
chmod 755 bulk_export_chunked.php
chmod 755 bulk_download_chunked.js
chmod 755 test_chunked_export.php
```

Create temp_reports directory if it doesn't exist:

```bash
mkdir -p temp_reports
chmod 777 temp_reports
```

### Step 3: Verify Dependencies

Ensure these are installed:

1. **PHP Extensions**:
   - mysqli (database)
   - zip (ZIP file creation)
   - gd or imagick (image processing)

2. **Composer Packages**:
   - mpdf/mpdf (PDF generation)

Check with:
```bash
php -m | grep -E 'mysqli|zip|gd'
composer show mpdf/mpdf
```

### Step 4: Test the System

1. Open `test_chunked_export.php` in your browser
2. Run all 4 tests:
   - Test 1: Small batch (10 learners)
   - Test 2: Medium batch (50 learners)
   - Test 3: Large batch (100 learners)
   - Test 4: API endpoint test

All tests should pass with ✅ green checkmarks.

### Step 5: Use in Production

1. Go to `bulk_down_register.php`
2. Apply your filters (district, site, date range, etc.)
3. Click "📄 Bulk Download (2000+ Learners Supported)"
4. Wait for progress bar to complete
5. ZIP file will download automatically

## 🔧 How It Works

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface                            │
│              (bulk_down_register.php)                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Click "Bulk Download"
                     ↓
┌─────────────────────────────────────────────────────────────┐
│              JavaScript Controller                           │
│          (bulk_download_chunked.js)                          │
│                                                              │
│  1. Initialize session                                       │
│  2. Process chunks sequentially                              │
│  3. Update progress bar                                      │
│  4. Finalize and download                                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ API Calls
                     ↓
┌─────────────────────────────────────────────────────────────┐
│              Backend Processor                               │
│           (bulk_export_chunked.php)                          │
│                                                              │
│  Actions:                                                    │
│  • start: Create session, split into chunks                  │
│  • process_chunk: Process 10 learners at a time             │
│  • finalize: Create ZIP file                                 │
└─────────────────────────────────────────────────────────────┘
```

### Processing Flow

1. **Initialization**:
   - User clicks button
   - System creates a session
   - Splits learners into chunks of 10

2. **Chunk Processing** (repeats for each chunk):
   - Fetch learner data from database
   - Get sick notes and manual registers
   - Generate HTML report
   - Convert to PDF
   - Copy documents to temp folder
   - Update progress (e.g., "Processing chunk 5 of 200...")

3. **Finalization**:
   - Create ZIP file with all reports and documents
   - Add summary file
   - Trigger download
   - Clean up temp files

### Why This Doesn't Timeout

- **Small Chunks**: Each request processes only 10 learners (~10-20 seconds)
- **Sequential Processing**: Chunks are processed one at a time
- **No Long-Running Requests**: Each API call completes quickly
- **Client-Side Orchestration**: JavaScript manages the workflow

## 📊 Performance Expectations

| Learners | Chunks | Estimated Time | Notes |
|----------|--------|----------------|-------|
| 10       | 1      | 10-20 sec      | Very fast |
| 50       | 5      | 1-2 min        | Fast |
| 100      | 10     | 2-4 min        | Good |
| 500      | 50     | 10-15 min      | Acceptable |
| 1000     | 100    | 20-30 min      | Manageable |
| 2000     | 200    | 40-60 min      | Maximum recommended |

**Note**: Times vary based on:
- Server performance
- Database speed
- Number of documents per learner
- Network latency

## 🐛 Troubleshooting

### Issue: "Session not found" error

**Solution**:
- Check that `temp_reports/` directory exists and is writable
- Verify permissions: `chmod 777 temp_reports`

### Issue: "Failed to create ZIP file" error

**Solution**:
- Check PHP ZIP extension: `php -m | grep zip`
- Ensure disk space is available
- Check directory permissions

### Issue: Progress bar stuck at 0%

**Solution**:
- Open browser console (F12)
- Check for JavaScript errors
- Verify `bulk_download_chunked.js` is loaded
- Check network tab for failed API calls

### Issue: "Database connection failed"

**Solution**:
- Verify `connection.php` is correct
- Check database credentials
- Ensure database server is running

### Issue: PDFs are blank or corrupted

**Solution**:
- Check mPDF is installed: `composer show mpdf/mpdf`
- Verify PHP memory limit: `ini_set('memory_limit', '512M')`
- Check error logs for mPDF errors

## 🔒 Security Considerations

1. **Session Files**: Automatically cleaned up after finalization
2. **Temp Files**: Stored in `temp_reports/` with unique session IDs
3. **Access Control**: Inherits authentication from `bulk_down_register.php`
4. **Input Validation**: All inputs are validated and sanitized

## 📈 Optimization Tips

### For Faster Processing

1. **Increase Chunk Size** (if server is powerful):
   ```javascript
   downloader.chunkSize = 20; // Process 20 learners per chunk
   ```

2. **Optimize Database Queries**:
   - Add indexes on frequently queried columns
   - Use query caching

3. **Use SSD Storage**:
   - Faster file I/O for PDF generation

4. **Increase PHP Limits**:
   ```php
   ini_set('memory_limit', '1024M');
   ini_set('max_execution_time', '300');
   ```

### For Better User Experience

1. **Show Estimated Time**:
   - Calculate based on chunk size and total learners
   - Display in progress UI

2. **Add Cancel Button**:
   - Allow users to stop long-running exports

3. **Email Notification**:
   - Send email when export completes (for very large batches)

## 📝 Maintenance

### Regular Tasks

1. **Clean Old Files**:
   ```bash
   # Delete session files older than 24 hours
   find temp_reports/session_* -type d -mtime +1 -exec rm -rf {} \;
   ```

2. **Monitor Disk Space**:
   ```bash
   df -h
   ```

3. **Check Error Logs**:
   ```bash
   tail -f bulk_export_errors.log
   ```

### Automated Cleanup (Optional)

Add to crontab:
```bash
# Clean temp files daily at 2 AM
0 2 * * * find /path/to/temp_reports/session_* -type d -mtime +1 -exec rm -rf {} \;
```

## 🎉 Success Indicators

When working correctly, you should see:

1. ✅ Progress bar moving smoothly
2. ✅ Progress text updating (e.g., "Processing chunk 5 of 200...")
3. ✅ No browser console errors
4. ✅ ZIP file downloads automatically
5. ✅ ZIP contains:
   - `reports/` folder with PDFs
   - `sick_notes/` folder with documents
   - `manual_registers/` folder with documents
   - `SUMMARY.txt` file

## 📞 Support

If you encounter issues:

1. Check browser console for errors (F12)
2. Check PHP error logs
3. Run test_chunked_export.php
4. Verify all files are uploaded correctly
5. Check file permissions

## 🔄 Upgrade Path

To upgrade from old system:

1. Backup current files
2. Upload new files
3. Test with small batch first
4. Gradually increase batch size
5. Monitor performance

## ✅ Deployment Checklist

- [ ] Upload `bulk_export_chunked.php`
- [ ] Upload `bulk_download_chunked.js`
- [ ] Update `bulk_down_register.php`
- [ ] Create `temp_reports/` directory
- [ ] Set correct permissions (755 for files, 777 for temp_reports)
- [ ] Verify PHP extensions (mysqli, zip, gd)
- [ ] Verify Composer packages (mpdf/mpdf)
- [ ] Run `test_chunked_export.php`
- [ ] Test with 10 learners
- [ ] Test with 50 learners
- [ ] Test with 100+ learners
- [ ] Verify ZIP file structure
- [ ] Check documents are included
- [ ] Set up automated cleanup (optional)

---

**System Version**: 1.0.0  
**Last Updated**: 2024  
**Tested With**: PHP 7.4+, MySQL 5.7+, Modern browsers (Chrome, Firefox, Edge)
