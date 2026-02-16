# Bulk Document Download Implementation Summary

## What Was Added

A new bulk download feature that allows downloading all sick notes and manual attendance documents for filtered learners in a single ZIP file.

## Files Created

### 1. `bulk_download_documents.php`
**Purpose**: Backend processor that collects documents and creates ZIP file

**Key Features**:
- Accepts learner IDs, date range, and site name via POST
- Fetches sick notes from `sick_note` table
- Fetches manual registers from `manual_clocking` table
- Organizes documents by learner in separate folders
- Creates ZIP file with all documents
- Returns JSON response with download URL

**Process Flow**:
1. Receives learner IDs and date range
2. For each learner:
   - Gets learner details (name, surname, ID number)
   - Fetches sick notes using `getSickNotes()`
   - Fetches manual registers using `getManualRegisters()`
   - Creates learner folder: `[Surname]_[Name]_[IDNumber]`
   - Copies documents to subfolders:
     - `Sick_Notes/` - All sick notes
     - `Manual_Attendance/` - All manual registers
   - If no documents found, creates `NO_DOCUMENTS_FOUND.txt`
3. Creates ZIP file in `temp_reports/` directory
4. Adds summary file with statistics
5. Returns download URL

### 2. `test_bulk_download_documents.php`
**Purpose**: Test script to verify functionality

**Tests**:
- ✅ Function availability (getSickNotes, getManualRegisters, getLearnerDocuments)
- ✅ Database connection
- ✅ Sample learner data retrieval
- ✅ Document retrieval for sample learner
- ✅ ZipArchive functionality
- ✅ Directory permissions

### 3. `BULK_DOCUMENT_DOWNLOAD_GUIDE.md`
**Purpose**: User guide and documentation

**Contents**:
- Feature overview
- Step-by-step usage instructions
- ZIP file structure
- Technical details
- Troubleshooting guide
- Performance notes

## Files Modified

### `bulk_down_register.php`

#### 1. Added Button (Line ~2358)
```html
<button type="button" id="bulkDownloadDocsBtn" onclick="startBulkDownloadDocuments()" 
        style="background: linear-gradient(135deg, #10b981, #059669);">
    📎 Bulk Download Documents (Sick Notes & Manual Attendance)
</button>
```

#### 2. Added JavaScript Function (Before closing `</script>`)
```javascript
function startBulkDownloadDocuments() {
    // Extracts learner IDs from displayed table
    // Gets date range and site info
    // Shows progress indicator
    // Makes AJAX request to bulk_download_documents.php
    // Auto-downloads ZIP file when ready
}
```

**Function Features**:
- Validates learners are displayed
- Extracts learner IDs from table
- Gets date range from form inputs
- Shows confirmation dialog
- Displays progress indicator with green theme
- Handles success/error responses
- Auto-downloads ZIP file
- Cleans up UI after download

## Integration with Existing Code

### Uses Existing Functions
The implementation leverages `get_learner_documents.php` which already has:
- `getSickNotes($conn, $learnerID, $startDate, $endDate)`
- `getManualRegisters($conn, $learnerID, $startDate, $endDate)`
- `getLearnerDocuments($conn, $learnerID, $startDate, $endDate)`

### Uses Existing Infrastructure
- Same database connection (`connection.php`)
- Same temp directory (`temp_reports/`)
- Same file serving mechanism (via `?temp_file=` parameter)
- Same filtering system (district, site, date range)

## User Experience

### Before
Users had to:
1. View each learner individually
2. Manually download each sick note
3. Manually download each manual register
4. Organize files manually

### After
Users can now:
1. Filter learners by site/district/date
2. Click one button
3. Get all documents in organized ZIP file
4. Documents are automatically named and organized

## Technical Highlights

### Smart File Path Detection
Checks multiple possible locations:
```php
$possiblePaths = [
    $filePath,
    'mobile/sicknotes/' . basename($filePath),
    '/public_html/mobile/sicknotes/' . basename($filePath),
    '../mobile/sicknotes/' . basename($filePath),
    __DIR__ . '/mobile/sicknotes/' . basename($filePath)
];
```

### Organized Structure
```
Documents_[Site]_[Date].zip
├── Learner1_Folder/
│   ├── Sick_Notes/
│   └── Manual_Attendance/
├── Learner2_Folder/
│   ├── Sick_Notes/
│   └── Manual_Attendance/
└── DOWNLOAD_SUMMARY.txt
```

### Error Handling
- Validates input parameters
- Handles missing learners gracefully
- Logs errors for debugging
- Continues processing even if one learner fails
- Includes error summary in ZIP

### Progress Feedback
- Shows processing status
- Displays learner count
- Updates progress bar
- Shows success message with statistics

## Testing

### Quick Test
```
http://your-server/test_bulk_download_documents.php
```

### Manual Test
1. Go to `bulk_down_register.php`
2. Select a site with learners
3. Set date range (e.g., last 3 months)
4. Click "Generate Report"
5. Click "📎 Bulk Download Documents"
6. Verify ZIP downloads and contains expected files

## Performance

- **Efficient**: Only copies files that exist
- **Scalable**: Handles hundreds of learners
- **Clean**: Removes temporary directories after ZIP creation
- **Fast**: Uses direct file operations (no external tools)

## Security

- ✅ Validates learner IDs
- ✅ Checks file existence before copying
- ✅ Sanitizes file names
- ✅ Only includes active learners
- ✅ Logs all operations
- ✅ Cleans up temporary files

## Future Enhancements (Optional)

1. **Email ZIP**: Option to email ZIP file instead of download
2. **Selective Download**: Checkboxes to select specific learners
3. **Document Filtering**: Option to download only sick notes OR only manual registers
4. **Date Filtering**: Filter documents by upload date vs. effective date
5. **Batch Processing**: For very large exports (1000+ learners)

## Conclusion

The bulk document download feature is now fully integrated into `bulk_down_register.php`. It provides a seamless way to download all sick notes and manual attendance documents for filtered learners, organized in a clean ZIP structure.

**Key Benefits**:
- ⏱️ Saves time (one click vs. hundreds of clicks)
- 📁 Organized output (automatic folder structure)
- 🎯 Filtered results (only relevant learners and dates)
- 📊 Summary report (statistics and errors)
- 🔄 Reusable code (leverages existing functions)
