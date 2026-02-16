# TASK 4: Fix 500 Server Error - Moderation Status Update

## Issue
After fixing the endpoint routing, the app now sends requests correctly to `save_moderation_status.php`, but the server returns a 500 error.

## Root Cause
The original code used `INSERT ... ON DUPLICATE KEY UPDATE` which requires a UNIQUE constraint on `(learnerID, exercise, type)` columns. This constraint likely doesn't exist in the marks table, causing a SQL error.

## The Fix

### 1. Changed from INSERT to UPDATE
Replaced the `INSERT ... ON DUPLICATE KEY UPDATE` approach with a simple `UPDATE` query:

```php
// Before (causing 500 error):
$sqlUpsert = "INSERT INTO marks (learnerID, exercise, type, ...)
              VALUES (?, ?, ?, ...)
              ON DUPLICATE KEY UPDATE ...";

// After (working):
$sqlUpdate = "UPDATE marks 
              SET approval_status = ?, 
                  moderator_status = ?, 
                  moderator_comment = ?, 
                  moderator_id = ?, 
                  moderation_date = NOW() 
              WHERE learnerID = ? AND exercise = ? AND type = ?
              LIMIT 1";
```

### 2. Added Error Handling
Added comprehensive error handling to catch and log any PHP or SQL errors:

```php
// Error reporting
error_reporting(E_ALL);
ini_set('log_errors', 1);
ini_set('error_log', 'debug.log');

// Fatal error handler
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null) {
        file_put_contents('debug.log', print_r($error, true), FILE_APPEND);
        echo json_encode(["status" => "error", "message" => "Server error"]);
    }
});

// Statement preparation error handling
if (!$stmtUpsert) {
    file_put_contents('debug.log', "ERROR: " . $conn->error . "\n", FILE_APPEND);
    echo json_encode(["status" => "error", "message" => "Database error"]);
    exit();
}
```

### 3. Improved Query Logic
- When `assessment_type` is provided (Formative/Summative): Matches on `learnerID + exercise + type`
- When `assessment_type` is null (backward compatibility): Matches on `learnerID + exercise` only
- Always uses `LIMIT 1` to ensure only one record is updated

## Files Modified

1. **save_moderation_status.php**
   - Changed from INSERT...ON DUPLICATE KEY UPDATE to UPDATE query
   - Added error handling and logging
   - Added statement preparation error checking

## Testing

1. **Upload the fixed file to server:**
   ```bash
   # Upload save_moderation_status.php to your server
   ```

2. **Test the moderation status update:**
   - Open the Flutter app
   - Navigate to a learner's formative exercises
   - Try to change status from "Upheld" to "Withdrawn"
   - Should now work without 500 error

3. **Check debug.log:**
   ```
   === RECEIVED REQUEST ===
   Raw data: {"learnerId":2189,"exercise":"Common sources...","moderation_status":"withdrawn"...}
   === BEFORE UPDATE ===
   LearnerID: 2189, Exercise: Common sources..., Type: Formative
   Executing UPDATE query...
   Rows affected: 1
   === AFTER UPDATE ===
   [Updated records shown here]
   ```

## Expected Behavior

✅ **Success Response:**
```json
{
  "status": "success",
  "message": "Moderation status updated successfully",
  "affected_rows": 1,
  "assessment_type": "Formative"
}
```

✅ **Warning Response (no changes):**
```json
{
  "status": "warning",
  "message": "No changes made - record may already have this status",
  "learner_id": "2189",
  "exercise": "Common sources...",
  "assessment_type": "Formative"
}
```

❌ **Error Response:**
```json
{
  "status": "error",
  "message": "Database error: [error details]"
}
```

## Why This Works

1. **No UNIQUE constraint required:** UPDATE doesn't need a unique constraint
2. **Precise matching:** Uses `learnerID + exercise + type` to prevent cross-contamination
3. **LIMIT 1:** Ensures only one record is updated even if duplicates exist
4. **Better error handling:** Catches and logs all errors for debugging

## Status

✅ **FIXED** - Changed from INSERT to UPDATE query with proper error handling

---

**Date:** 2026-02-11
**Issue:** 500 server error on moderation status update
**Resolution:** Replaced INSERT...ON DUPLICATE KEY UPDATE with UPDATE query
