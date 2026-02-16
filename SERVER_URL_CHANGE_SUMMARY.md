# Server URL Change Summary

## Overview
Successfully changed the server URL from `rlms.rlms.co.za` to `rlms.rlms.co.za` across all configuration files and test scripts.

## Files Updated

### 1. Main Configuration File
**File:** `lib/config.dart`
- **Changed:** `serverHost = 'rlms.rlms.co.za'` → `serverHost = 'rlms.rlms.co.za'`
- **Impact:** All API calls will now go to the new server
- **New Base URL:** `https://rlms.rlms.co.za/mobile`

### 2. PHP Configuration Files
**File:** `get_facilitator_profile.php`
- **Changed:** `$baseUrl = 'https://rlms.rlms.co.za/mobile'` → `$baseUrl = 'https://rlms.rlms.co.za/mobile'`
- **Impact:** Facilitator profile and signature URLs will use new domain
- **Updated Comments:** File path references in comments

### 3. Test Files Updated
**Files:**
- `test_pothole_logbook.php`
- `test_simple_api_call.php` (2 occurrences)
- `test_simple_api.php`
- `test_pothole_images_url.php` (2 occurrences)
- `learners.php`
- `debug_pothole_logbook_flutter.php`

**Changes:** All test URLs changed from `rlms.rlms.co.za` to `rlms.rlms.co.za`

### 4. Migration Script Updated
**File:** `update_pothole_image_paths.php`
- **Changed Direction:** Now migrates FROM `rlms.rlms.co.za` TO `rlms.rlms.co.za`
- **Purpose:** Reverses the previous migration direction

## New API Endpoints
All API calls will now use the new domain:

```
Base URL: https://rlms.rlms.co.za/mobile

Login: https://rlms.rlms.co.za/mobile/login.php
Clock In: https://rlms.rlms.co.za/mobile/clockin.php
Clock Out: https://rlms.rlms.co.za/mobile/clockout.php
Sync Facilitator: https://rlms.rlms.co.za/mobile/sync_facilitator.php
Sync Learner Clocking: https://rlms.rlms.co.za/mobile/sync_learner_clocking.php
... (all other endpoints follow the same pattern)
```

## Impact on App Functionality

### ✅ What Works Immediately:
- All API calls will use the new server URL
- Configuration is centralized in `config.dart`
- No code changes needed in Flutter app logic
- All endpoints automatically use the new domain

### ⚠️ What Needs Server-Side Setup:
1. **SSL Certificate:** Ensure `rlms.rlms.co.za` has valid SSL certificate
2. **PHP Files:** Upload all PHP files to the new server's `/mobile` directory
3. **Database:** Ensure database connection works on new server
4. **File Permissions:** Set proper permissions for upload directories
5. **Domain Configuration:** Ensure domain points to correct server

## Testing Checklist

### 1. Basic Connectivity
```bash
curl -I https://rlms.rlms.co.za/mobile/
# Should return 200 OK with valid SSL
```

### 2. API Endpoints
```bash
# Test login
curl -X POST https://rlms.rlms.co.za/mobile/login.php \
  -d "email=test@test.com&password=test123"

# Test facilitator sync
curl https://rlms.rlms.co.za/mobile/sync_facilitator.php
```

### 3. File Uploads
```bash
# Check upload directory exists
curl https://rlms.rlms.co.za/mobile/check_upload_status.php
```

## Rollback Plan
If needed, to revert back to the old server:

1. Change `lib/config.dart`:
   ```dart
   static const String serverHost = 'rlms.rlms.co.za';
   ```

2. Change `get_facilitator_profile.php`:
   ```php
   $baseUrl = 'https://rlms.rlms.co.za/mobile';
   ```

3. Rebuild and redeploy the app

## Status: ✅ COMPLETE
All configuration files have been updated to use the new server URL `rlms.rlms.co.za`. The app is ready for testing with the new server once the server-side setup is complete.

## Next Steps
1. Ensure the new server is properly configured
2. Upload all PHP files to the new server
3. Test all API endpoints
4. Build and deploy the updated app
5. Verify all functionality works with the new server