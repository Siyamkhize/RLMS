# Bulk Document Download Feature

## Overview
This feature allows you to download all sick notes and manual attendance documents for filtered learners in a single ZIP file.

## What Gets Downloaded
- **Sick Notes**: All approved, pending, and rejected sick notes within the date range
- **Manual Attendance**: All manual attendance registers (FDP documents) within the date range

## How to Use

### Step 1: Filter Learners
1. Go to `bulk_down_register.php`
2. Select your filters:
   - **District**: Choose the district
   - **Site**: Choose the specific site
   - **Date Range**: Select start and end dates
   - **Attendance Filters**: (Optional) Filter by attendance percentage
3. Click **"📈 Generate Report"** to display learners

### Step 2: Download Documents
1. Once learners are displayed, click the **"📎 Bulk Download Documents"** button
2. Confirm the download (shows number of learners and date range)
3. Wait for processing (progress indicator will show)
4. ZIP file will automatically download when ready

## ZIP File Structure
```
Documents_[SiteName]_[Date].zip
├── [Surname]_[Name]_[IDNumber]/
│   ├── Sick_Notes/
│   │   ├── SickNote_2024-01-15_to_2024-01-17.pdf
│   │   └── SickNote_2024-02-20_to_2024-02-22.jpg
│   ├── Manual_Attendance/
│   │   ├── ManualAttendance_2024-01-10.pdf
│   │   └── ManualAttendance_2024-01-25.pdf
│   └── NO_DOCUMENTS_FOUND.txt (if no documents exist)
└── DOWNLOAD_SUMMARY.txt
```

## Features

### Organized by Learner
- Each learner gets their own folder named: `[Surname]_[Name]_[IDNumber]`
- Documents are organized into subfolders:
  - `Sick_Notes/` - All sick notes
  - `Manual_Attendance/` - All manual attendance documents

### Smart File Naming
- **Sick Notes**: `SickNote_[DateFrom]_to_[DateTo].[ext]`
- **Manual Attendance**: `ManualAttendance_[Date].[ext]`

### Summary Report
The ZIP includes a `DOWNLOAD_SUMMARY.txt` file with:
- Site name
- Date range
- Total learners processed
- Total documents included
- Any errors encountered

### No Documents Handling
If a learner has no documents in the date range, a `NO_DOCUMENTS_FOUND.txt` file is created in their folder explaining why.

## Technical Details

### Files Involved
1. **bulk_down_register.php** - Main page with the download button
2. **bulk_download_documents.php** - Backend processor that creates the ZIP
3. **get_learner_documents.php** - Helper functions to fetch documents from database

### Database Tables Used
- `sick_note` - Sick note records and file paths
- `manual_clocking` - Manual attendance records and FDP documents
- `learnerdetails` - Learner information

### File Locations Checked
The system checks multiple possible locations for documents:
- `mobile/sicknotes/` - Sick notes
- `uploads/` - Manual attendance documents
- `mobile/uploads/` - Alternative upload location
- `mobile/Uploads/` - Case-sensitive alternative

## Testing

### Test the Feature
Run the test script to verify everything is working:
```
http://your-server/test_bulk_download_documents.php
```

This will check:
- ✅ Function availability
- ✅ Database connection
- ✅ Sample document retrieval
- ✅ ZIP functionality
- ✅ Directory permissions

## Troubleshooting

### No Documents Found
- **Check date range**: Ensure documents exist within the selected dates
- **Check file paths**: Documents must be in the expected directories
- **Check database**: Verify records exist in `sick_note` and `manual_clocking` tables

### ZIP Download Fails
- **Check permissions**: Ensure `temp_reports/` directory is writable
- **Check ZipArchive**: Verify PHP ZipArchive extension is installed
- **Check disk space**: Ensure sufficient space for temporary files

### Button Not Working
- **Check filters**: Ensure you've generated a report first (learners must be displayed)
- **Check JavaScript**: Open browser console (F12) to see any errors
- **Check date range**: Start and end dates must be selected

## Performance Notes

- **Small batches** (< 50 learners): Processes quickly (seconds)
- **Medium batches** (50-200 learners): May take 10-30 seconds
- **Large batches** (200+ learners): May take 1-2 minutes

The system shows a progress indicator during processing.

## Security

- Only active learners are included (activity_statu = '' or NULL)
- File paths are validated before copying
- Temporary directories are cleaned up after ZIP creation
- All file operations are logged for audit purposes

## Integration with Existing Features

This feature works alongside:
- **Bulk Reports**: Download attendance PDFs
- **Export to Excel**: Export attendance data
- **Individual Reports**: View single learner reports

All features use the same filtering system for consistency.
