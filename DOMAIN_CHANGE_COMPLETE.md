# Domain Change Complete: tesing.mtltechnical.co.za → rlms.rlms.co.za

## Summary

Successfully changed all URLs from `tesing.mtltechnical.co.za` to `rlms.rlms.co.za` across the entire project.

### Statistics
- **Files Updated:** 137
- **Total Replacements:** 504
- **Date:** January 6, 2026

## Files Changed by Type

### Flutter/Dart Files (3 files, 24 replacements)
- `lib/AssessorPage.dart` - 22 replacements
- `lib/config.dart` - 1 replacement
- `test_enhanced_clocking_days.dart` - 1 replacement

### PHP Files (22 files, 30 replacements)
- `debug_add_learner_sync.php`
- `debug_pothole_logbook_flutter.php`
- `get_facilitator_profile.php` - 5 replacements
- `learners.php` - 2 replacements
- `test_account_login.php`
- `test_add_learner_direct.php`
- `test_add_learner_endpoint.php`
- `test_assessor_endpoints.php`
- `test_finance_system.php`
- `test_get_classes.php` - 2 replacements
- `test_login.php`
- `test_merge_poe.php`
- `test_pothole_images_url.php` - 2 replacements
- `test_pothole_logbook.php`
- `test_save_comment.php`
- `test_simple_api.php`
- `test_simple_api_call.php` - 2 replacements
- `update_pothole_image_paths.php` - 4 replacements
- `verify_poe_entry.php`
- `php/test_sync_endpoint.php` - 2 replacements

### Documentation Files (108 files, 443 replacements)
All markdown documentation files have been updated with the new domain.

### Other Files (4 files, 7 replacements)
- Batch files (.bat)
- PowerShell scripts (.ps1)
- Text files (.txt)
- HTML files (.html)

## Critical Files Updated

### 1. Main Configuration
**File:** `lib/config.dart`
- Updated base URL comment from `tesing.mtltechnical.co.za` to `rlms.rlms.co.za`

### 2. Assessor Page
**File:** `lib/AssessorPage.dart`
- Updated 22 hardcoded URLs including:
  - Assessment preparation endpoints
  - Assessment plan endpoints
  - Facilitator details endpoints
  - Class name endpoints
  - Save marks endpoints
  - Learner fetching endpoints
  - POE image URLs

### 3. PHP API Files
All test and debug PHP files now point to the new domain for API testing.

### 4. Documentation
All deployment guides, troubleshooting docs, and implementation summaries updated.

## Next Steps

### 1. Review Changes
```bash
git diff
```
Review all changes to ensure accuracy.

### 2. Rebuild Flutter App
```bash
flutter clean
flutter pub get
flutter build apk
```

### 3. Test API Endpoints
Test critical endpoints on the new domain:

#### Login
```bash
curl -X POST https://rlms.rlms.co.za/mobile/login.php \
  -d "email=test@test.com" \
  -d "password=test123"
```

#### Get Classes
```bash
curl https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=1
```

#### Clock In
```bash
curl -X POST https://rlms.rlms.co.za/mobile/clockin.php \
  -d "LearnerID=1" \
  -d "classID=1" \
  -d "user_latitude=0.0" \
  -d "user_longitude=0.0"
```

### 4. Server-Side Verification
Ensure the new domain `rlms.rlms.co.za` is properly configured:
- [ ] DNS points to correct server
- [ ] SSL certificate is valid
- [ ] All PHP files are uploaded to `/mobile/` directory
- [ ] Database connection is configured
- [ ] File permissions are correct (uploads, facilitatorProfiles, etc.)

### 5. Test All Features
- [ ] Login (Admin, Finance, Facilitator, Assessor)
- [ ] Clock In/Out with GPS
- [ ] Learner sync
- [ ] POE document upload
- [ ] Pothole checklist scanning
- [ ] Logbook marking
- [ ] Finance register system
- [ ] Bulk document downloads

## Important Notes

### Image URLs
All image URLs in `AssessorPage.dart` have been updated:
```dart
// Old
final imageUrl = 'https://tesing.mtltechnical.co.za/mobile/${image['file_path']}';

// New
final imageUrl = 'https://rlms.rlms.co.za/mobile/${image['file_path']}';
```

### Facilitator Profile Images
The `get_facilitator_profile.php` file constructs full URLs:
```php
// Old
$baseUrl = 'https://tesing.mtltechnical.co.za/mobile';

// New
$baseUrl = 'https://rlms.rlms.co.za/mobile';
```

### Test Files
All test PHP files now point to the new domain for easy testing.

## Rollback Instructions

If you need to revert to the old domain:
```powershell
# Edit replace_domain_to_rlms.ps1 and swap the domains:
$oldDomain = "rlms.rlms.co.za"
$newDomain = "tesing.mtltechnical.co.za"

# Then run the script again
powershell -ExecutionPolicy Bypass -File replace_domain_to_rlms.ps1
```

## Verification Checklist

- [x] All Dart files updated
- [x] All PHP files updated
- [x] All documentation updated
- [x] All test files updated
- [ ] Flutter app rebuilt
- [ ] API endpoints tested
- [ ] Server DNS configured
- [ ] SSL certificate verified
- [ ] All features tested

## Status: ✅ DOMAIN REPLACEMENT COMPLETE

All 504 occurrences of `tesing.mtltechnical.co.za` have been successfully replaced with `rlms.rlms.co.za` across 137 files.

**Ready for rebuild and testing!**
