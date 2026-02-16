# Bulk Download Enhancement - Sick Notes & Manual Registers

## Overview
The bulk download system has been enhanced to include sick notes and manual registers for the filtered date period.

## What's New

### 1. **Sick Notes Inclusion**
- All sick notes within the filtered date range are now included in the bulk download
- Sick notes are fetched from the `sick_note` table
- File path: `/public_html/mobile/sicknotes/[filename]`
- Includes notes where:
  - `date_from` is within the range
  - `date_to` is within the range
  - The date range spans across the filtered period

### 2. **Manual Registers Inclusion**
- All manual uploaded registers within the filtered date range are included
- Manual registers are fetched from the `manual_clocking` table
- File path: `/public_html/uploads/[filename]`
- Only includes records where `fdp_document` is not null/empty

### 3. **ZIP File Structure**
The downloaded ZIP file now contains:
```
bulk_reports_[timestamp].zip
├── reports/
│   ├── [learner_id]_report.json
│   └── ...
├── sick_notes/
│   ├── [learner_id]_[filename].pdf
│   └── ...
├── manual_registers/
│   ├── [learner_id]_[filename].pdf
│   └── ...
└── SUMMARY.txt
```

## Database Tables Used

### sick_note Table
```
- note_id (Primary Key)
- learner_id
- document_path (File path to sick note PDF)
- practice_name
- medical_practitioner
- practitioner_name
- date_from (Start date of sick leave)
- date_to (End date of sick leave)
- upload_date
- status (PENDING, APPROVED, Declined)
- rejection_reason
```

### manual_clocking Table
```
- manual_id (Primary Key)
- clocking_id
- LearnerID
- clock_date (Date of manual attendance)
- clock_in_time
- clock_out_time
- contact_time
- manual_reason
- fdp_document (File path to manual register PDF)
- status (Pending, Approved, Declined)
- reviewed_by
- reviewed_at
- is_manual_attendance
```

## Files Modified

### 1. `bulk_down_register.php`
- Updated SQL query to include LEFT JOINs for sick_note and manual_clocking tables
- Modified data structure to include sick_notes and manual_registers arrays
- Updated JavaScript to pass date range parameters (start_date, end_date)
- Changed progress display to mention document inclusion

### 2. `bulk_export_api.php`
- Updated to use the new `bulk_export_with_documents.php` processor
- Now accepts `start_date` and `end_date` parameters
- Returns detailed results including document counts

## New Files Created

### 1. `get_learner_documents.php`
Helper script to fetch sick notes and manual registers for individual learners.

**Functions:**
- `getSickNotes($conn, $learnerID, $startDate, $endDate)` - Fetches sick notes
- `getManualRegisters($conn, $learnerID, $startDate, $endDate)` - Fetches manual registers
- `getLearnerDocuments($conn, $learnerID, $startDate, $endDate)` - Fetches both

**Features:**
- Checks multiple possible file paths
- Validates file existence
- Returns normalized file paths

### 2. `bulk_export_with_documents.php`
Enhanced bulk export processor that includes documents.

**Features:**
- Processes multiple learners in batch
- Copies sick notes and manual registers to temp directory
- Creates organized ZIP file structure
- Generates summary report
- Handles errors gracefully

**Response Format:**
```json
{
  "success": true,
  "total_learners": 50,
  "processed": 48,
  "failed": 2,
  "reports": [...],
  "documents_included": {
    "sick_notes": 15,
    "manual_registers": 23
  },
  "zip_file": "bulk_reports_20251030_123456.zip",
  "errors": []
}
```

## Usage

### From UI
1. Navigate to the bulk download page
2. Apply filters (district, site, date range, etc.)
3. Click "Bulk Download" button
4. System will:
   - Generate reports for all filtered learners
   - Include sick notes for the date range
   - Include manual registers for the date range
   - Package everything into a ZIP file
   - Automatically download the ZIP

### API Usage
```javascript
// POST to bulk_export_api.php
const requestData = {
    learner_ids: JSON.stringify([123, 456, 789]),
    start_date: '2025-10-01',
    end_date: '2025-10-31',
    project_id: '76'
};

fetch('bulk_export_api.php', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams(requestData)
})
.then(response => response.json())
.then(data => {
    console.log('Export results:', data);
    // Download ZIP file
    window.location.href = `bulk_down_register.php?temp_file=${data.zip_file}`;
});
```

## Testing

### Test Individual Document Fetching
```
http://your-domain.com/get_learner_documents.php?learner_id=123&start_date=2025-10-01&end_date=2025-10-31
```

### Test Bulk Export
```
http://your-domain.com/bulk_export_with_documents.php?test=1
```

## File Path Resolution

The system checks multiple possible locations for documents:

**Sick Notes:**
- Original path from database
- `mobile/sicknotes/[filename]`
- `/public_html/mobile/sicknotes/[filename]`
- `../mobile/sicknotes/[filename]`
- `__DIR__/mobile/sicknotes/[filename]`

**Manual Registers:**
- Original path from database
- `uploads/[filename]`
- `/public_html/uploads/[filename]`
- `../uploads/[filename]`
- `__DIR__/uploads/[filename]`

## Error Handling

- Missing files are logged but don't stop the export
- Failed learner processing is tracked in the response
- All errors are logged to `bulk_export_errors.log`
- User receives summary of successes and failures

## Performance Considerations

- Execution time limit: 600 seconds (10 minutes)
- Memory limit: 512MB
- Suitable for batches up to 500 learners
- For larger batches, consider implementing background job processing

## Future Enhancements

1. **PDF Report Generation**: Replace JSON reports with full PDF attendance reports
2. **Email Delivery**: Option to email the ZIP file instead of direct download
3. **Background Processing**: Queue system for very large batches (1000+ learners)
4. **Progress Tracking**: Real-time progress updates via WebSocket or polling
5. **Selective Document Inclusion**: Allow users to choose which document types to include
6. **Document Preview**: Preview documents before downloading
7. **Compression Options**: Different compression levels for ZIP files

## Troubleshooting

### Documents Not Included
1. Check if files exist at the specified paths
2. Verify file permissions (should be readable)
3. Check database records for correct file paths
4. Review `bulk_export_errors.log` for specific errors

### ZIP File Not Created
1. Verify ZipArchive extension is installed: `php -m | grep zip`
2. Check directory permissions for `temp_reports/`
3. Ensure sufficient disk space
4. Review error logs

### Slow Performance
1. Reduce batch size
2. Check database indexes on learner_id and date fields
3. Optimize file system access
4. Consider implementing caching

## Support

For issues or questions, check:
- Error logs: `bulk_export_errors.log`
- PHP error log
- Database connection status
- File system permissions
