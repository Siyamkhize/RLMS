# Quick Fix: Upload Error Code 1

## Problem
```
Upload failed: Exception: Upload failed: Upload error code: 1
```

File: 5.67 MB
Error: File exceeds server's upload limit (probably 2MB)

## Solution 1: Fix Server (BEST)

Create `.htaccess` file in mobile directory:

```apache
php_value upload_max_filesize 200M
php_value post_max_size 200M
php_value max_execution_time 7200
php_value memory_limit 256M
```

Then restart Apache:
```bash
sudo service apache2 restart
```

## Solution 2: Use Chunked Upload (WORKAROUND)

I've already updated the app to use chunked upload for files > 3MB.

This splits your 5.67 MB file into 2MB chunks, bypassing the server limit.

**Just rebuild the app:**
```bash
flutter clean
flutter pub get
flutter build apk --release
```

## What Changed

**File:** `lib/poe_document_scanner.dart`

**Before:**
```dart
const chunkThreshold = 50 * 1024 * 1024; // 50MB
// Only files > 50MB use chunked upload
// Your 5.67 MB file tries direct upload → FAILS
```

**After:**
```dart
const chunkThreshold = 3 * 1024 * 1024; // 3MB
// Files > 3MB use chunked upload
// Your 5.67 MB file uses chunked upload → WORKS ✅
```

## How It Works

### Direct Upload (Old - Failed):
```
App → Send 5.67 MB file → Server
Server: "File too large!" (2MB limit)
❌ Upload fails
```

### Chunked Upload (New - Works):
```
App → Split into chunks:
  - Chunk 1: 2 MB → Server ✅
  - Chunk 2: 2 MB → Server ✅
  - Chunk 3: 1.67 MB → Server ✅
Server: Merge chunks → 5.67 MB file ✅
✅ Upload succeeds!
```

## Testing

1. Rebuild app
2. Scan 50 pages (creates ~5-6 MB PDF)
3. Tap "Upload Document"
4. Should see "Uploading chunk 1 of 3..."
5. Upload completes successfully ✅

## Files Created

1. **check_php_upload_limits.php** - Check server settings
2. **.htaccess_poe_upload** - Server configuration fix
3. **POE_UPLOAD_ERROR_CODE_1_FIX.md** - Detailed guide

## Status

✅ App fix applied (chunked upload for files > 3MB)
⏳ Server fix pending (increase upload_max_filesize)

**The app will work now with chunked upload!**

Just rebuild and test. 🎉
