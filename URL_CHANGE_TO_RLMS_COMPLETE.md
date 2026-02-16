# URL Change Complete: rlms.rlms.co.za → rlms.rlms.co.za

## Summary
All references to `rlms.rlms.co.za` have been changed to `rlms.rlms.co.za` across the codebase.

## Files Modified

### 1. **lib/config.dart** ✅ (CRITICAL - Main Configuration)
Changed the main server configuration:
```dart
// Before:
static const String serverHost = 'rlms.rlms.co.za';

// After:
static const String serverHost = 'rlms.rlms.co.za';
```

This change automatically updates ALL API endpoints since they use `baseUrl`:
- Login URL: `https://rlms.rlms.co.za/mobile/login.php`
- Clock-in URL: `https://rlms.rlms.co.za/mobile/clocking/clockin.php`
- Clock-out URL: `https://rlms.rlms.co.za/mobile/clocking/clockout.php`
- Sync URLs: `https://rlms.rlms.co.za/mobile/sync_*`
- All other endpoints...

### 2. **get_facilitator_profile.php** ✅
Changed base URL for image paths:
```php
// Before:
$baseUrl = 'https://rlms.rlms.co.za/mobile';

// After:
$baseUrl = 'https://rlms.rlms.co.za/mobile';
```

Updated comments:
- Profile path: `/home/ezxcmacd/public_html/rlms.rlms.co.za/mobile/facilitatorProfiles/...`
- Signature path: `/home/ezxcmacd/public_html/rlms.rlms.co.za/mobile/facilitatorSignatures/...`

### 3. **debug_add_learner_sync.php** ✅
```php
// Before:
$url = 'https://rlms.rlms.co.za/mobile/add_learner.php';

// After:
$url = 'https://rlms.rlms.co.za/mobile/add_learner.php';
```

### 4. **debug_pothole_logbook_flutter.php** ✅
```php
// Before:
$url = "https://rlms.rlms.co.za/mobile/get_logbook_unit_standards.php?learner_id=$learner_id";

// After:
$url = "https://rlms.rlms.co.za/mobile/get_logbook_unit_standards.php?learner_id=$learner_id";
```

### 5. **learners.php** ✅
Updated documentation comments:
```php
// Before:
* URL: https://rlms.rlms.co.za/learners.php or https://rlms.rlms.co.za/learners

// After:
* URL: https://rlms.rlms.co.za/learners.php or https://rlms.rlms.co.za/learners
```

## Documentation Files (Informational Only)
The following markdown files contain references to the old URL in examples and documentation. These are for reference and don't affect the running application:

- `CLOCKIN_PHP_CHANGES.md`
- `DEBUG_CHECKLIST_NOT_SHOWING.md`
- `DIAGNOSE_SCANNED_DOCUMENT_ISSUE.md`
- `DIAGNOSE_SYNC_ISSUE.md`
- `DEPLOY_VIEW_POTHOLE_CHECKLISTS.md`
- `ENHANCED_CLOCKING_DAYS_IMPLEMENTATION.md`
- `FACILITATOR_SYNC_DEBUG.md`
- `FACILITATOR_SYNC_FIXED.md`
- `FACILITATOR_SYNC_SOLUTION_SUMMARY.md`
- `FILE_LOCATION_FIXED.md`
- `FINAL_DEPLOYMENT_CHECKLIST.md`
- `FINAL_DEPLOYMENT_CHECKLIST_POTHOLE.md`
- `FINAL_FIX_LEARNER_ID_TYPE.md`
- `FINAL_SUMMARY.md`
- `FIXED_URL_PATH.md`
- `FIX_TABLE_COLUMNS_MISMATCH.md`
- `FIX_UNIT_STANDARDS_TABLE.md`
- `DEBUG_LOGBOOK_NOT_SHOWING.md`
- `insert_scanned_document_record.sql`
- `PHP_GEOFENCING_UPDATE.md`
- `POTHOLE_UPLOAD_URL_FIX.md`
- `READY_TO_DEPLOY.md`
- `SCANNED_PDF_VIEWER_FIXED.md`

## Impact

### ✅ What Changed
1. **All Flutter API calls** now point to `rlms.rlms.co.za`
2. **Image URLs** (facilitator profiles, signatures) now use `rlms.rlms.co.za`
3. **Debug/test scripts** now point to the new server

### ⚠️ Important Notes
1. **Server Files**: Make sure all PHP files are uploaded to `rlms.rlms.co.za` server
2. **Database**: The database connection should point to the correct database on the new server
3. **File Paths**: Ensure file paths on the new server match (e.g., `/mobile/facilitatorProfiles/`, `/mobile/signatures/`)
4. **SSL Certificate**: Verify HTTPS is working on `rlms.rlms.co.za`

## Testing Checklist

### Test API Endpoints:
```bash
# Test login
curl -X POST https://rlms.rlms.co.za/mobile/login.php \
  -d "username=test" \
  -d "password=test"

# Test clock-in
curl -X POST https://rlms.rlms.co.za/mobile/clocking/clockin.php \
  -d "LearnerID=123" \
  -d "clock_in=1"

# Test facilitator profile
curl https://rlms.rlms.co.za/mobile/get_facilitator_profile.php?facilitator_id=1
```

### Test in Flutter App:
1. Rebuild the app with the new config
2. Test login functionality
3. Test clock-in/clock-out
4. Test image loading (profiles, signatures)
5. Test all sync operations

## Rebuild Required
After these changes, you MUST rebuild the Flutter app:
```bash
flutter clean
flutter pub get
flutter build apk --release
```

## Status
✅ **COMPLETE** - All URLs changed from `rlms.rlms.co.za` to `rlms.rlms.co.za`

## Old Domain References
The old domain `rlms.rlms.co.za` also had a typo ("tesing" instead of "testing"). The new domain `rlms.rlms.co.za` is correct.

Note: Some references to `rlms.mtltechnical.co.za` (without the typo) may still exist in comments - these are different from the old testing server.
