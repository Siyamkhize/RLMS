# POE Silent Upload Failure - Fixed with Logging

## 🐛 Problem

- Scanned 2 batches (50 pages each)
- App says "uploaded successfully"
- But database is empty
- Folder is empty
- No error messages shown

## 🔍 Root Cause

The upload was **failing silently** - errors were being caught but not logged or displayed to the user.

From the logs:
```
Scan Result: {pdfUri: file:///..., pageCount: 50}
PDF exists: ..., size: 5782307 bytes
```

But no upload logs appear after this, meaning the upload code never executed or failed immediately.

## ✅ Fixes Applied

### Fix 1: Added Comprehensive Logging

Added `print()` statements throughout the upload process:

**Upload Start:**
```dart
print('=== Starting POE Document Upload ===');
print('File path: ${_pdfFile!.path}');
print('File size: $fileSize bytes');
print('Will use CHUNKED/DIRECT upload');
```

**Chunked Upload:**
```dart
print('Starting chunked upload...');
print('Total chunks: $totalChunks');
print('Uploading chunk ${i + 1} of $totalChunks...');
print('Chunk response: $responseBody');
```

**Direct Upload:**
```dart
print('Starting direct upload...');
print('Upload URL: $uri');
print('Response status: ${response.statusCode}');
print('Response body: $responseBody');
```

### Fix 2: Better Error Handling

Added error dialog to show failures:

```dart
catch (e, stackTrace) {
  print('Upload error: $e');
  print('Stack trace: $stackTrace');
  
  // Show error dialog
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Upload Failed'),
      content: Text('Error: $e'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

### Fix 3: Smaller Chunks

Changed chunk size from 5MB to 2MB for better reliability:

```dart
const chunkSize = 2 * 1024 * 1024; // 2MB chunks
```

### Fix 4: Better Response Validation

Added try-catch around JSON parsing:

```dart
try {
  final jsonResponse = json.decode(responseBody);
  if (jsonResponse['success'] != true) {
    throw Exception(jsonResponse['message']);
  }
} catch (e) {
  print('Error parsing response: $e');
  print('Raw response: $responseBody');
  throw Exception('Invalid server response');
}
```

## 🧪 Testing

### Step 1: Rebuild App

```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Step 2: Install and Test

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Step 3: Monitor Logs

```bash
# In one terminal, watch logs
adb logcat | grep -i flutter

# In another terminal, watch server logs
ssh user@server
tail -f /var/log/apache2/error.log
```

### Step 4: Scan and Upload

1. Open app
2. Scan 50 pages
3. Tap "Upload Document"
4. Watch logs for:
   - "Starting POE Document Upload"
   - "Will use CHUNKED upload"
   - "Uploading chunk 1 of 3..."
   - "Chunk 1 response: ..."
   - "Upload completed successfully!"

## 📊 Expected Log Output

### Successful Upload:
```
=== Starting POE Document Upload ===
File path: /data/user/0/.../561228362475335.pdf
File size: 5782307 bytes (5.51 MB)
Chunk threshold: 3145728 bytes
Will use CHUNKED upload
Starting chunked upload...
File read into memory: 5782307 bytes
Total chunks: 3, File ID: 1703334643000
Uploading chunk 1 of 3...
Chunk 0: 2097152 bytes (from 0 to 2097152)
Upload URL: https://rlms.rlms.co.za/mobile/upload_poe_document.php
Sending chunk 1...
Chunk 1 response status: 200
Chunk 1 response body: {"success":true,"message":"Chunk 0 received"}
Chunk 1 uploaded successfully
Uploading chunk 2 of 3...
Chunk 1: 2097152 bytes (from 2097152 to 4194304)
Sending chunk 2...
Chunk 2 response status: 200
Chunk 2 response body: {"success":true,"message":"Chunk 1 received"}
Chunk 2 uploaded successfully
Uploading chunk 3 of 3...
Chunk 2: 1588003 bytes (from 4194304 to 5782307)
Sending chunk 3...
Chunk 3 response status: 200
Chunk 3 response body: {"success":true,"message":"Document uploaded successfully","document_id":1}
Chunk 3 uploaded successfully
All chunks uploaded successfully!
Upload completed successfully!
```

### Failed Upload (Example):
```
=== Starting POE Document Upload ===
File size: 5782307 bytes
Will use CHUNKED upload
Starting chunked upload...
Uploading chunk 1 of 3...
Chunk 1 response status: 500
Chunk 1 response body: {"success":false,"message":"Database error"}
Upload error: Exception: Chunk 0 failed: Database error
```

## 🔍 Debugging Steps

### If No Logs Appear:

**Problem:** Upload code not executing

**Check:**
1. Is file path valid?
2. Is network available?
3. Is AppConfig.baseUrl correct?

**Solution:**
```dart
// Add at start of _uploadDocument
print('PDF file: ${_pdfFile?.path}');
print('File exists: ${await _pdfFile!.exists()}');
print('Base URL: ${AppConfig.baseUrl}');
```

### If "Upload completed successfully" but Database Empty:

**Problem:** Server receiving upload but not saving

**Check:**
1. Server logs: `tail -f /var/log/apache2/error.log`
2. PHP errors in response
3. Database connection
4. File permissions

**Solution:**
```bash
# Check upload directory
ls -la /path/to/mobile/uploads/poe_documents/

# Check database
mysql -u user -p database
SELECT * FROM poe_documents ORDER BY id DESC LIMIT 5;

# Check PHP errors
tail -f /var/log/apache2/error.log
```

### If Chunks Upload but Merge Fails:

**Problem:** Individual chunks saved but not merged

**Check:**
1. Temp directory exists
2. Temp files present
3. Merge logic in PHP

**Solution:**
```bash
# Check temp directory
ls -la /path/to/mobile/uploads/poe_documents/temp/

# Should see files like: chunk_1703334643000_0, chunk_1703334643000_1, etc.
```

## 📝 Common Issues

### Issue 1: Network Timeout

**Symptom:** Upload starts but hangs

**Solution:** Already handled with 2-hour timeout in PHP

### Issue 2: Memory Error

**Symptom:** App crashes when reading file

**Solution:** Chunked upload reads file once, then splits in memory

### Issue 3: Server Rejects Chunks

**Symptom:** Chunk 1 succeeds, chunk 2 fails

**Solution:** Check server logs for specific error

### Issue 4: Wrong URL

**Symptom:** 404 error in logs

**Solution:** Verify AppConfig.baseUrl is correct

## ✅ Verification

After rebuild and test, you should see:

1. **In App Logs:**
   - Upload progress messages
   - Chunk upload confirmations
   - Success or error messages

2. **In Database:**
   ```sql
   SELECT * FROM poe_documents WHERE learner_id = 1144;
   ```
   Should show uploaded documents

3. **In Folder:**
   ```bash
   ls -lh uploads/poe_documents/
   ```
   Should show PDF files

4. **In App:**
   - If success: "Part X uploaded successfully!"
   - If error: Dialog with error message

## 🎯 Summary

**Problem:** Silent upload failure - no logs, no errors

**Cause:** Errors caught but not logged or displayed

**Solution:** 
- ✅ Added comprehensive logging
- ✅ Added error dialogs
- ✅ Smaller chunks (2MB)
- ✅ Better error handling
- ✅ Response validation

**Status:** Ready to rebuild and test with full logging!

**Next Steps:**
1. Rebuild app
2. Install on device
3. Monitor logs during upload
4. Logs will show exactly what's happening
5. Fix any issues revealed by logs
