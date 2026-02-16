# Quick Deployment: Comment Update Feature

## Files to Deploy

### Server (PHP):
- `save_comment.php` → Upload to `/mobile/save_comment.php`

### App (Flutter):
- `lib/AssessorPage.dart` → Already modified, rebuild app

## Deployment Steps

### Step 1: Upload PHP File
```bash
# Upload save_comment.php to:
# /public_html/rlms.rlms.co.za/mobile/save_comment.php

# Set permissions:
chmod 644 save_comment.php
```

### Step 2: Test PHP Endpoint
```bash
# Run test script:
php test_save_comment.php

# Or test manually:
curl -X POST https://rlms.rlms.co.za/mobile/save_comment.php \
  -H "Content-Type: application/json" \
  -d '{"learnerId":"1","assessmentType":"formative","comment":"Test comment","isUpdate":false}'
```

### Step 3: Rebuild Flutter App
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Step 4: Test in App
1. Install APK on device
2. Log in as Assessor
3. View a learner's POE
4. Test submitting a new comment
5. Test updating an existing comment

## Quick Test Checklist

- [ ] PHP file uploaded
- [ ] Endpoint returns valid JSON
- [ ] New comment saves successfully
- [ ] Update comment works
- [ ] Button text changes (Submit → Update)
- [ ] Helper text shows "Editing existing comment"
- [ ] Dialog shows when updating
- [ ] All three types work (formative, summative, logbook)

## What Changed

### User Experience:
- **Before:** Comment field disabled after submission
- **After:** Comment field always editable, button shows "Update Comment"

### Technical:
- New `save_comment.php` endpoint with update support
- Modified `saveComment()` function with `isUpdate` parameter
- Updated 3 comment sections in AssessorPage.dart
- Added dialog for update confirmation

## Rollback

If issues occur:
1. Delete `save_comment.php` from server
2. Revert to previous APK version

## Success Criteria

✓ Assessors can submit new comments
✓ Assessors can update existing comments
✓ Button text changes appropriately
✓ Helper text shows when editing
✓ Dialog confirms updates
✓ Success messages display correctly
