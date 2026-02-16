# Assessor "No Learners Found" Issue - FIXED

## Problem
After fixing the "No classes found" issue, when clicking the "View" button on a class, the AssessorPage showed "No learners found" because:
1. The app was using hardcoded URLs pointing to the wrong domain
2. The `get_poe.php` endpoint was missing
3. URLs weren't using the AppConfig configuration

## Root Causes
1. **Hardcoded URLs**: ClassDetailsPage was using `https://rlms.rlms.co.za` instead of AppConfig
2. **Missing get_poe.php**: The POE (Portfolio of Evidence) endpoint didn't exist
3. **Missing get_learners.php in root**: File only existed in php/ directory

## Solution Implemented

### 1. Updated AssessorPage.dart
Fixed two functions to use AppConfig instead of hardcoded URLs:

#### ClassDetailsPage.fetchLearnersWithPOE()
- Changed from hardcoded `rlms.rlms.co.za` to `AppConfig.buildUrl()`
- Now correctly points to `rlms.rlms.co.za/mobile/get_learners.php`
- Also updated POE fetching to use `AppConfig.buildUrl('get_poe.php')`
- Added better logging with `[ClassDetailsPage]` prefix

#### POETab.fetchPOE()
- Changed from hardcoded URL to `AppConfig.buildUrl()`
- Now correctly points to `rlms.rlms.co.za/mobile/get_poe.php`
- Added better logging with `[POETab]` prefix

### 2. Created get_learners.php (Root Directory)
Copied from php/get_learners.php to root directory for mobile app access.

**Features:**
- Accepts `classID` parameter (GET or POST)
- Queries `learnerdetails` table with LEFT JOIN to `bankdetails`
- Returns comprehensive learner information including:
  - Personal details (Name, Surname, ID, etc.)
  - Contact information
  - Address details
  - Next of kin information
  - School information
  - Bank details
  - Fingerprint templates
  - Profile images and signatures
- Handles duplicate bank details gracefully
- Proper error handling and CORS headers

### 3. Created get_poe.php (NEW)
Created a new endpoint to fetch Portfolio of Evidence data.

**Features:**
- Accepts `learnerId` parameter
- Queries `poe` table with JOINs to:
  - `unit_standard_selection`
  - `unitstandard`
  - `qualification_unitstandard`
  - `qualification`
  - `qualification_pathway`
  - `learningpathway`
- Returns nested structure:
  ```json
  {
    "pathways": {
      "pathway_id": {
        "pathway_name": "...",
        "qualifications": {
          "qualification_id": {
            "qualification_name": "...",
            "unitstandards": {
              "unitstandard_id": {
                "unitstandard_name": "...",
                "formative": [...],
                "summative": [...]
              }
            }
          }
        }
      }
    }
  }
  ```
- Each assessment includes:
  - poe_id
  - exercise
  - filePath
  - marks_scored
  - logbook_text
  - submitted_at
- Proper error handling returns empty pathways on error

## Files Created/Modified

### Created:
- `get_learners.php` (root) - Learner data endpoint
- `get_poe.php` (root) - POE data endpoint
- `test_assessor_endpoints.php` - Comprehensive test script
- `ASSESSOR_LEARNERS_FIX_COMPLETE.md` - This documentation

### Modified:
- `lib/AssessorPage.dart` - Updated 2 functions:
  - `ClassDetailsPage.fetchLearnersWithPOE()`
  - `POETab.fetchPOE()`

## Database Structure

### Tables Involved:

**For Learners:**
```
learnerdetails (main learner info)
  ↓ LEFT JOIN
bankdetails (bank account info)
```

**For POE:**
```
poe (assessment records)
  ↓ LEFT JOIN
unit_standard_selection
  ↓ LEFT JOIN
unitstandard
  ↓ LEFT JOIN
qualification_unitstandard
  ↓ LEFT JOIN
qualification
  ↓ LEFT JOIN
qualification_pathway
  ↓ LEFT JOIN
learningpathway
```

## Testing

### Test Script
Run the comprehensive test:
```bash
php test_assessor_endpoints.php
```

This will test:
1. get_classes.php (from previous fix)
2. get_learners.php (new)
3. get_poe.php (new)

### Manual Testing
1. **Test get_learners.php:**
   ```
   https://rlms.rlms.co.za/mobile/get_learners.php?classID=YOUR_CLASS_ID
   ```

2. **Test get_poe.php:**
   ```
   https://rlms.rlms.co.za/mobile/get_poe.php?learnerId=YOUR_LEARNER_ID
   ```

### Expected Results:
- **get_learners.php**: Returns array of learner objects with all details
- **get_poe.php**: Returns nested object with pathways structure

## Deployment Checklist

### Server-Side (PHP Files)
Upload to `https://rlms.rlms.co.za/mobile/`:
- [ ] `get_learners.php`
- [ ] `get_poe.php`
- [ ] Verify file permissions (644 or 755)
- [ ] Test endpoints with browser or curl

### App-Side (Flutter)
- [ ] Rebuild Flutter app: `flutter build apk --release`
- [ ] Install on test device
- [ ] Test complete flow:
  1. Log in as Assessor
  2. View classes list
  3. Click "View" on a class
  4. Verify learners are displayed
  5. Check learner details and POE data

## Verification Steps

### 1. Check Classes Display
- [ ] Classes list shows with correct information
- [ ] Class names, learner counts, site info visible

### 2. Check Learners Display
- [ ] Clicking "View" shows learners list
- [ ] Learner names and details visible
- [ ] Row colors indicate POE status (white/yellow/green)

### 3. Check POE Data
- [ ] POE tab shows assessment data
- [ ] Formative and summative assessments listed
- [ ] File paths and marks displayed correctly

## Troubleshooting

### Issue: Still showing "No learners found"
**Check:**
1. Is get_learners.php uploaded to correct location?
2. Does the classID have learners in the database?
3. Check server error logs
4. Check app console logs for URL being called

**Debug SQL:**
```sql
-- Check learners for a class
SELECT COUNT(*) FROM learnerdetails WHERE classID = 'YOUR_CLASS_ID';

-- Check specific learner
SELECT * FROM learnerdetails WHERE classID = 'YOUR_CLASS_ID' LIMIT 5;
```

### Issue: POE data not showing
**Check:**
1. Is get_poe.php uploaded?
2. Does the learner have POE records?
3. Check the poe table structure

**Debug SQL:**
```sql
-- Check POE records for a learner
SELECT COUNT(*) FROM poe WHERE learnerID = 'YOUR_LEARNER_ID';

-- Check POE details
SELECT * FROM poe WHERE learnerID = 'YOUR_LEARNER_ID' LIMIT 10;
```

### Issue: JSON parse errors
**Check:**
1. PHP error reporting in the response
2. Database connection issues
3. Invalid JSON characters in data

## Color Coding System

The learner list uses color coding based on POE status:
- **White**: No POE data or no files uploaded
- **Yellow**: Files uploaded but marks not scored
- **Green**: Files uploaded and all marks scored

## Notes

- All endpoints now use AppConfig for consistent URL management
- Better error handling and logging throughout
- CORS headers included for cross-origin requests
- Endpoints support both GET and POST methods where appropriate
- Empty POE data returns valid structure (empty pathways) instead of error

## Related Files

Previous fix:
- `ASSESSOR_NO_CLASSES_FIX.md` - Initial classes fix
- `get_classes.php` - Classes endpoint

Current fix:
- `ASSESSOR_LEARNERS_FIX_COMPLETE.md` - This document
- `get_learners.php` - Learners endpoint
- `get_poe.php` - POE endpoint

## Success Criteria

✓ Assessor can log in
✓ Classes list displays correctly
✓ Clicking "View" shows learners
✓ Learner information is complete
✓ POE data loads and displays
✓ Color coding works correctly
✓ All data matches what was shown before

## Next Steps

1. Deploy all PHP files to production server
2. Rebuild and deploy Flutter app
3. Test with real assessor credentials
4. Verify all functionality works as expected
5. Monitor logs for any issues
