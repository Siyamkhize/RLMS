# 🔧 ERROR 400 - IMPROVED ERROR HANDLING

**Date:** July 15, 2026  
**Progress:** 404 → 400 (endpoint found, but server error)

---

## ✅ PROGRESS MADE

**Before:** 404 Error (file not found)  
**Now:** 400 Error (file found, but server-side issue)

This is actually **GOOD NEWS** - it means:
- ✅ URL path is now correct
- ✅ Endpoint is accessible
- ❌ Server is rejecting the request data

---

## 🔧 IMPROVEMENTS MADE

### 1. Enhanced PHP Error Logging

Added detailed logging to `mobile/save_arpl_toolkit_edits.php`:

```php
// Log raw input
error_log("Raw input received: " . substr($rawInput, 0, 500));

// Log parsed data
error_log("Parsed input: " . print_r($input, true));

// Log JSON errors
if (!$input) {
    $jsonError = json_last_error_msg();
    error_log("JSON decode error: " . $jsonError);
    throw new Exception('Invalid JSON input: ' . $jsonError);
}
```

### 2. Better Error Messages in App

Improved `lib/ArplToolkitViewerPage.dart` to show actual error message:

```dart
if (response1.statusCode != 200) {
    // Try to parse error message from response
    String errorMsg = 'Failed to save Appendix B/D/E: ${response1.statusCode}';
    try {
        final errorData = jsonDecode(response1.body);
        if (errorData['message'] != null) {
            errorMsg = errorData['message'];
        }
    } catch (e) {
        // If can't parse, use default message
    }
    throw Exception(errorMsg);
}
```

### 3. Added Statement Error Checking

Added validation for SQL prepare statements:

```php
$stmtB = $conn->prepare("...");
if (!$stmtB) {
    throw new Exception('Failed to prepare Appendix B statement: ' . $conn->error);
}
```

### 4. Added Rating Validation

```php
if ($rating >= 1 && $rating <= 5) {
    // Process rating
} else {
    $errorsB[] = "Invalid rating for activity $activity_id: $rating";
}
```

---

## 🧪 DIAGNOSTIC TOOLS ADDED

### Test Request Data

Created: `mobile/test_toolkit_save_request.php`

**Purpose:** Shows exactly what data the app is sending

**URL:** `https://rlms.rlms.co.za/mobile/test_toolkit_save_request.php`

**What it shows:**
- Raw JSON received
- Parsed fields
- Sample data from each appendix
- JSON validation status

---

## 📋 FILES TO UPLOAD

1. **`mobile/save_arpl_toolkit_edits.php`** (improved error handling)
2. **`mobile/test_toolkit_save_request.php`** (diagnostic tool)

Then **REBUILD APK** with improved error display.

---

## 🔍 LIKELY CAUSES OF 400 ERROR

### 1. Missing Required Fields
- `learnerID`, `classID`, or `ofoNumber` might be null
- App might not be sending correct data structure

### 2. Invalid Data Types
- Rating values outside 1-5 range
- Non-numeric values where numbers expected

### 3. Database Column Mismatch
- Table structure might not match insert statement
- Column names might be different

### 4. facilitator_id Lookup Failing
- Class might not exist
- No facilitator assigned to class

---

## ⚡ NEXT STEPS

### 1. Upload Improved Files

```
mobile/save_arpl_toolkit_edits.php
mobile/test_toolkit_save_request.php
```

### 2. Rebuild APK

```cmd
flutter clean
flutter build apk --release
```

### 3. Test and Check Logs

After installing new APK:
- Try to save again
- Error message will now show **actual error** instead of just "400"
- Check server error logs for detailed debugging info

### 4. Use Diagnostic Tool

Visit in browser (while testing in app):
```
https://rlms.rlms.co.za/mobile/test_toolkit_save_request.php
```

This will show exactly what data the app is sending.

---

## 🎯 WHAT TO LOOK FOR

### In App Error Message:
- Will now show specific error (e.g., "Missing required field: learnerID")
- Instead of generic "Failed to save: 400"

### In Server Logs:
- Check `/home/rlmsrlmsco/logs/error_log`
- Look for lines starting with "=== ARPL Toolkit Save Request ==="
- Will show exact data received and where it failed

### In Diagnostic Tool:
- Should show all fields present
- Sample data should look correct
- JSON should be valid

---

## 📊 EXPECTED RESULTS

### If facilitator_id Issue:
```
Error: Valid facilitator_id required
```

**Solution:** Ensure classID 797 has a facilitator assigned.

### If Invalid Rating:
```
Error: Invalid rating for activity X: 0 (or >5)
```

**Solution:** Check app is sending ratings 1-5.

### If Missing Table:
```
Error: Table 'arplappxe_bricklaying_activity_ratings' does not exist
```

**Solution:** Run table creation SQL.

### If JSON Invalid:
```
Error: Invalid JSON input: Syntax error
```

**Solution:** Check app is encoding JSON correctly.

---

## ✅ IMPROVEMENTS SUMMARY

| Improvement | Before | After |
|-------------|--------|-------|
| Error Message | Generic "400" | Specific error details |
| PHP Logging | None | Detailed request logging |
| Statement Validation | Missing | Checks for SQL errors |
| Rating Validation | Weak | Strict 1-5 check |
| Diagnostic Tool | None | Test request endpoint |

---

## 🎓 DEBUGGING STRATEGY

1. **Upload improved PHP** → Get better error messages
2. **Rebuild APK** → App shows detailed errors
3. **Test save** → See specific error
4. **Check diagnostic tool** → Verify data format
5. **Fix specific issue** → Based on actual error
6. **Test again** → Verify fix works

---

**Status:** Improved error handling ready  
**Action Required:** Upload PHP + Rebuild APK  
**Expected:** Will see actual error cause instead of generic 400
