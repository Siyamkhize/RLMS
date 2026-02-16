# Quick Deployment Guide: Assessor Fix

## Files to Deploy

### PHP Files (Upload to server)
Upload these files to `https://rlms.rlms.co.za/mobile/`:

1. **get_classes.php** (from previous fix)
2. **get_learners.php** (NEW)
3. **get_poe.php** (NEW)

## Deployment Steps

### Step 1: Upload PHP Files

Using FTP/SFTP or cPanel:
```
Source → Destination
get_classes.php → /public_html/rlms.rlms.co.za/mobile/get_classes.php
get_learners.php → /public_html/rlms.rlms.co.za/mobile/get_learners.php
get_poe.php → /public_html/rlms.rlms.co.za/mobile/get_poe.php
```

### Step 2: Test Endpoints

Run the test script:
```bash
php test_assessor_endpoints.php
```

Or test manually in browser:
```
https://rlms.rlms.co.za/mobile/get_classes.php?facilitator_id=1
https://rlms.rlms.co.za/mobile/get_learners.php?classID=YOUR_CLASS_ID
https://rlms.rlms.co.za/mobile/get_poe.php?learnerId=YOUR_LEARNER_ID
```

### Step 3: Rebuild Flutter App

```bash
# Clean previous build
flutter clean

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

### Step 4: Install and Test

1. Install APK on test device
2. Log in as Assessor
3. Verify:
   - ✓ Classes list shows
   - ✓ Click "View" shows learners
   - ✓ Learner details display
   - ✓ POE data loads

## Quick Test Checklist

- [ ] PHP files uploaded to correct location
- [ ] File permissions set (644 or 755)
- [ ] get_classes.php returns JSON array
- [ ] get_learners.php returns learners for a class
- [ ] get_poe.php returns POE structure
- [ ] Flutter app rebuilt successfully
- [ ] App installed on device
- [ ] Assessor login works
- [ ] Classes display correctly
- [ ] Learners display when clicking "View"
- [ ] All learner information shows
- [ ] POE data displays correctly

## Rollback Plan

If issues occur:

**Server-side:**
- Rename or delete the new PHP files
- Keep get_classes.php from previous fix

**App-side:**
- Revert to previous APK version

## Support

If you encounter issues:
1. Check server error logs
2. Check app console logs (flutter logs)
3. Run test_assessor_endpoints.php
4. Verify database has data for test IDs

## Summary

This fix addresses:
1. ✓ "No classes found" - Fixed with get_classes.php
2. ✓ "No learners found" - Fixed with get_learners.php + AppConfig updates
3. ✓ POE data loading - Fixed with get_poe.php

All endpoints now use AppConfig for consistent URL management.
