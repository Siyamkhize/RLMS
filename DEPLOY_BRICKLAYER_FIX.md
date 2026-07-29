# Deploy Bricklayer Toolkit Fix

## Issue
API endpoint `mobile/get_bricklayer_toolkit_data.php` returns 400 error with message:
```
Unknown column 'aar.competency_scale_id' in 'SELECT'
```

## Root Cause
The PHP code was using incorrect column names:
- Used: `competency_scale_id` (doesn't exist)
- Should be: `competency_level` (actual column name)

## Fix Applied
Updated `mobile/get_bricklayer_toolkit_data.php` to use correct column names:

### Change 1: Appendix B Ratings Query (Line ~105)
**BEFORE:**
```php
$stmt = $conn->prepare("
    SELECT 
        aar.activity_id,
        aar.competency_scale_id as rating_score,  ← WRONG
        aar.comments,
        aar.rating_date,  ← WRONG
        acs.proficiency_level,
        acs.description as scale_description
    FROM " . $conn->real_escape_string($appendixB_ratings_table) . " aar
    LEFT JOIN arpl_competency_scale acs ON aar.competency_scale_id = acs.score  ← WRONG
    WHERE aar.learnerID = ?
");
```

**AFTER:**
```php
$stmt = $conn->prepare("
    SELECT 
        aar.activity_id,
        aar.competency_level,  ← CORRECT
        aar.rating as rating_score,  ← CORRECT
        aar.comments,
        aar.assessment_date as rating_date,  ← CORRECT
        acs.proficiency_level,
        acs.description as scale_description
    FROM " . $conn->real_escape_string($appendixB_ratings_table) . " aar
    LEFT JOIN arpl_competency_scale acs ON aar.competency_level = acs.level  ← CORRECT
    WHERE aar.learnerID = ?
");
```

### Change 2: Appendix E Ratings Query (Line ~180)
**BEFORE:**
```php
$sql_ratings = "SELECT activity_id, competency_scale_id as rating_score, comments, rating_date FROM " . $conn->real_escape_string($appendixE_ratings_table) . " WHERE learnerID = ? AND ofo_number = ?";
```

**AFTER:**
```php
$sql_ratings = "SELECT activity_id, competency_level, rating as rating_score, comments, assessment_date as rating_date FROM " . $conn->real_escape_string($appendixE_ratings_table) . " WHERE learnerID = ? AND ofo_number = ?";
```

## Correct Table Schema
Based on `create_arpl_complete_tables.sql`, the correct column names are:

### `arplappxb_activity_ratings` table:
- `competency_level` (INT) - NOT `competency_scale_id`
- `rating` (INT) - NOT `competency_scale_id`
- `assessment_date` (TIMESTAMP) - NOT `rating_date`
- `comments` (TEXT)

### `arplappxe_bricklaying_activity_ratings` table:
- `competency_level` (INT) - NOT `competency_scale_id`
- `rating` (INT) - NOT `competency_scale_id`
- `assessment_date` (TIMESTAMP) - NOT `rating_date`
- `comments` (TEXT)

## Deployment Steps

### Option 1: Manual Upload via FTP/cPanel
1. Connect to ONLINE server (rlms.rlms.co.za)
2. Navigate to `/home/rlmsrlmsco/public_html/mobile/`
3. Upload the fixed file: `mobile/get_bricklayer_toolkit_data.php`
4. Verify file permissions (should be 644)

### Option 2: Manual Copy-Paste via cPanel File Manager
1. Login to cPanel for rlms.rlms.co.za
2. Open File Manager
3. Navigate to `/home/rlmsrlmsco/public_html/mobile/`
4. Edit `get_bricklayer_toolkit_data.php`
5. Replace lines ~105-115 with Change 1 above
6. Replace line ~180 with Change 2 above
7. Save file

### Option 3: Use Deployment Script (if available)
```bash
# Copy the fixed file to server
scp mobile/get_bricklayer_toolkit_data.php user@rlms.rlms.co.za:/home/rlmsrlmsco/public_html/mobile/
```

## Testing After Deployment

Run the test script to verify the fix:
```bash
php test_online_bricklayer_toolkit.php
```

Expected output:
```
HTTP Status Code: 200
✓ API call successful!
Response Summary:
  Status: success
  Learner ID: 11701
  Class ID: 797
  Trade: bricklayer
  OFO Number: 641201
  ...
```

## APK Update Required
After deploying the fixed PHP file, the existing APK will work correctly. No rebuild needed since this was a server-side fix.

## Test on Device
1. Ensure the PHP file is deployed to ONLINE server
2. Open the existing APK on device
3. Login with facilitator ID 6
4. Navigate to "View Complete Toolkit"
5. Select candidate "Anele Cele"
6. Verify OFO Number shows: 641201
7. Click "Open Complete Toolkit"
8. Should now load successfully (no 400 error)

## Files Modified
- `mobile/get_bricklayer_toolkit_data.php` (2 SQL query fixes)

## Status
- ✅ Fix applied to local copy
- ⏳ Needs deployment to ONLINE server
- ⏳ Needs testing after deployment
