# Pothole Evidence Upload URL Fix

## Problem
Pothole evidence images were being uploaded to the old server (`rlms.rlms.co.za`) instead of the new server (`rlms.rlms.co.za`).

## Root Cause
Found **hardcoded URL** in `lib/AssessorPage.dart` at line 5710:
```dart
Uri.parse('https://rlms.rlms.co.za/mobile/upload_pothole_evidence.php?v=2')
```

## Files Fixed

### 1. lib/AssessorPage.dart - Line 5710
**Before:**
```dart
Uri.parse('https://rlms.rlms.co.za/mobile/upload_pothole_evidence.php?v=2')
```

**After:**
```dart
Uri.parse('${AppConfig.baseUrl}/upload_pothole_evidence.php?v=2')
```

### 2. lib/AssessorPage.dart - Line 6875 (Document URL)
**Before:**
```dart
documentUrl = 'https://rlms.rlms.co.za/$documentUrl';
```

**After:**
```dart
final baseDomain = AppConfig.baseUrl.replaceAll('/mobile', '');
documentUrl = '$baseDomain/$documentUrl';
```

### 3. lib/AssessorPage.dart - Lines 6479 & 7012 (Image Display)
**Note:** These were temporarily set to old domain for displaying existing images.
```dart
final imageUrl = 'https://rlms.rlms.co.za/${image['file_path']}';
```

## Next Steps

1. **Rebuild the Flutter app:**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk
   ```

2. **Upload PHP files to new server** (`rlms.rlms.co.za/mobile/`):
   - `upload_pothole_evidence.php`
   - `get_pothole_images.php`
   - `connection.php` (ensure it connects to correct database)

3. **Create upload directory on new server:**
   ```bash
   mkdir -p uploads/pothole_evidence
   chmod 755 uploads/pothole_evidence
   ```

4. **Uninstall old app and install new APK** on your device

5. **Test upload:**
   - Upload a new pothole evidence image
   - Verify it goes to `rlms.rlms.co.za/mobile/uploads/pothole_evidence/`
   - Check database `poe` table for new entry

## Image Display Strategy

**For NEW uploads:** Will automatically use new server (rlms.rlms.co.za)

**For OLD images:** Currently hardcoded to display from old server. Options:
- **Option A:** Copy all files from old server to new server
- **Option B:** Keep displaying old images from old server until migrated

## Verification

After deploying, test the upload endpoint:
```
https://rlms.rlms.co.za/mobile/test_upload_endpoint.php
```

Should return JSON with server info showing `rlms.rlms.co.za`.
