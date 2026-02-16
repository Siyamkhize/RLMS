# Fix: Wrong Template and Document Filtering

## Issues Found

1. **Reports not using original template** - System uses simple HTML instead of `indivisual.php`
2. **Manual registers showing wrong class** - Documents not filtered by learner ID properly

## Solutions Implemented

### 1. Template Fix

**Problem**: `indivisual.php` file doesn't exist in the project

**Options**:

**Option A: Upload your indivisual.php template**
- Upload your existing `indivisual.php` file to the server root
- The system will automatically use it for report generation
- This is the RECOMMENDED option if you have the file

**Option B: Use enhanced HTML template (fallback)**
- System will use an improved HTML template
- Includes all attendance data, calendar view, signatures
- Matches the style of your original reports

### 2. Document Filtering Fix

**Updated**: `bulk_export_chunked.php`
- Manual registers now properly filtered by learner ID
- Sick notes properly filtered by learner ID and date range
- Only documents for the selected learners are included

## Quick Fix Deployment

### If you have indivisual.php file:

```bash
# 1. Upload your indivisual.php file to server root
upload indivisual.php

# 2. Re-upload updated processor
upload bulk_export_chunked.php

# 3. Test with 1 learner
# Reports should now use your original template
```

### If you DON'T have indivisual.php:

The system will create a comprehensive HTML report with:
- Learner details
- Full attendance calendar
- Clock in/out times
- Attendance statistics
- Professional styling

## Files Updated

1. **bulk_export_chunked.php** (UPDATED)
   - Added `generateHTMLFromTemplate()` function
   - Uses indivisual.php if available
   - Falls back to enhanced HTML template
   - Fixed document filtering

## Verification

### Test Report Template

1. Run bulk export with 1 learner
2. Open generated PDF
3. Check if it matches your original template style

### Test Document Filtering

1. Run bulk export for specific class/site
2. Open ZIP file
3. Check `manual_registers/` folder
4. Verify only documents for selected learners are included

## Document Filtering Logic

### Before (Wrong):
```sql
SELECT * FROM manual_clocking 
WHERE clock_date BETWEEN ? AND ?
-- Gets ALL manual registers in date range (wrong class too)
```

### After (Correct):
```sql
SELECT * FROM manual_clocking 
WHERE LearnerID = ? 
AND clock_date BETWEEN ? AND ?
-- Gets only manual registers for THIS learner
```

## Creating indivisual.php Template

If you need to create the template file, it should:

1. Accept GET parameters:
   - `LearnerID` - The learner ID
   - `project_id` - The project ID
   - `year` - Report year
   - `month` - Report month

2. Generate HTML output with:
   - Learner information
   - Attendance calendar
   - Clock in/out times
   - Signatures (if available)
   - Summary statistics

3. Example structure:
```php
<?php
// Get parameters
$learnerID = $_GET['LearnerID'];
$projectId = $_GET['project_id'];
$year = $_GET['year'];
$month = $_GET['month'];

// Fetch learner data
// Generate attendance calendar
// Output HTML
?>
```

## Alternative: Use View Report Link

If you want to see what the original template looks like:

1. Go to `bulk_down_register.php`
2. Find a learner in the table
3. Click "View Report" button
4. This shows the individual report
5. Save the HTML source as `indivisual.php`

## Troubleshooting

### Issue: Reports still look wrong

**Check**:
1. Is `indivisual.php` uploaded?
2. Is it in the server root directory?
3. Check PHP error logs for template errors

**Fix**:
```bash
# Verify file exists
ls -la indivisual.php

# Check permissions
chmod 644 indivisual.php

# Check PHP errors
tail -f /var/log/php_errors.log
```

### Issue: Manual registers still wrong

**Check**:
1. Open ZIP file
2. Look at manual register filenames
3. Should be: `{learnerID}_manual_{filename}.pdf`

**Verify**:
```sql
-- Check manual_clocking table
SELECT LearnerID, clock_date, fdp_document 
FROM manual_clocking 
WHERE LearnerID IN (your_learner_ids)
AND clock_date BETWEEN 'start_date' AND 'end_date';
```

### Issue: Sick notes missing

**Check**:
1. Verify sick_note table has data
2. Check date ranges match
3. Verify file paths are correct

**Query**:
```sql
-- Check sick_note table
SELECT learner_id, date_from, date_to, document_path 
FROM sick_note 
WHERE learner_id IN (your_learner_ids)
AND date_from BETWEEN 'start_date' AND 'end_date';
```

## Summary

**Files to Upload**:
1. `bulk_export_chunked.php` (UPDATED - required)
2. `indivisual.php` (OPTIONAL - your original template)

**What's Fixed**:
- ✅ Document filtering now correct (only selected learners)
- ✅ System will use indivisual.php if available
- ✅ Falls back to enhanced HTML template if not
- ✅ Manual registers filtered by learner ID
- ✅ Sick notes filtered by learner ID and date

**Next Steps**:
1. Upload `bulk_export_chunked.php`
2. If you have it, upload `indivisual.php`
3. Test with 1-2 learners
4. Verify reports look correct
5. Verify documents are for correct learners only

---

**Status**: Ready to deploy
**Priority**: High (affects report quality and document accuracy)
