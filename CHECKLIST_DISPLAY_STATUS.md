# Pothole Checklist Display - Current Status

## Issue
Neither scanned documents nor system-generated checklists are showing in the AssessorPage POE tab.

## Changes Applied

### 1. PHP Endpoint (php/view_pothole_checklists.php)
✅ Updated to check both tables with priority:
- Priority 1: `pothole_checklist_scanned_documents` (scanned PDFs)
- Priority 2: `pothole_checklists` + `pothole_checklist_items` (system forms)
- Returns type indicator: `type: 'scanned'` or `type: 'system'`

### 2. Flutter App (lib/AssessorPage.dart)
✅ Updated `_checkPotholeChecklistStatus()`:
- Now checks server first (unified endpoint)
- Falls back to local database if server fails
- Properly handles response with type indicator

✅ Updated `_viewPotholeChecklist()`:
- Fixed data structure access (removed nested 'data' key)
- Correctly routes based on type

## Current URL Structure

The app constructs:
```
https://rlms.rlms.co.za/mobile/php/view_pothole_checklists.php?learner_id=XXX
```

## Expected Response Format

```json
{
  "status": "success",
  "data": {
    "id": 1,
    "type": "scanned",
    "learner_id": "TEST123",
    "document_path": "/path/to/file.pdf",
    "assessor_id": "ASS001",
    "assessment_date": "2025-11-05"
  }
}
```

## Diagnostic Tools

### 1. Database Check
```bash
mysql -u username -p database_name < check_checklist_data.sql
```

### 2. Endpoint Test
```bash
php test_view_endpoint_simple.php
```

### 3. Flutter Debug Output
Look for these logs:
```
DEBUG Pothole: Checking server at https://...
DEBUG Pothole: Response status 200
DEBUG Pothole: Response body {...}
DEBUG Pothole: Found checklist on server, type=scanned
```

## Troubleshooting Steps

### Step 1: Verify Data Exists
Run `check_checklist_data.sql` to confirm database has records.

### Step 2: Test Endpoint
Run `test_view_endpoint_simple.php` or access via browser:
```
https://rlms.rlms.co.za/mobile/php/view_pothole_checklists.php?learner_id=KNOWN_ID
```

### Step 3: Check Flutter Logs
- Open Flutter app
- Navigate to POE tab
- Check console for DEBUG messages
- Look for errors or unexpected responses

### Step 4: Common Issues

**Issue: 404 Not Found**
- File path is incorrect
- Verify file exists at: `mobile/php/view_pothole_checklists.php`

**Issue: Empty Response**
- No data in database for this learner
- Learner ID format mismatch

**Issue: Connection Timeout**
- Server is slow or unreachable
- Check internet connection

**Issue: JSON Parse Error**
- PHP file has syntax error
- Check PHP error logs

## Quick Test

To quickly test if the endpoint works, run this in your browser:
```
https://rlms.rlms.co.za/mobile/php/view_pothole_checklists.php?learner_id=TEST123
```

Replace `TEST123` with an actual learner ID from your database.

## Files Modified

1. `lib/AssessorPage.dart` - Detection and viewing logic
2. `php/view_pothole_checklists.php` - Unified endpoint (already done)

## Files Created

1. `check_checklist_data.sql` - Database verification
2. `test_view_endpoint_simple.php` - Endpoint testing
3. `DEBUG_CHECKLIST_NOT_SHOWING.md` - Complete troubleshooting guide
4. `CHECKLIST_DISPLAY_STATUS.md` - This file

## Next Actions

1. ✅ Code changes complete
2. ⏳ Run database check
3. ⏳ Test PHP endpoint
4. ⏳ Check Flutter logs
5. ⏳ Identify specific failure point
6. ⏳ Apply targeted fix

## Status
🟡 **AWAITING DIAGNOSTICS**

The code is updated and ready. We need to run the diagnostic tools to identify why checklists aren't showing. Start with the database check to confirm data exists.
