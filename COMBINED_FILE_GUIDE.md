# Combined Test + API File Guide

## ONE FILE, TWO MODES

The file `test_live_poe_direct.php` now works in **TWO MODES**:

### MODE 1: Command Line Test (Local Testing)

Run from command line to test the query:

```bash
php test_live_poe_direct.php
```

**Output**:
```
=== SIMPLE POE QUERY TEST (LIVE SERVER) ===
Server: rlms.rlms.co.za
Moderator ID: 77
Timestamp: 2026-02-05 11:00:00

Using: connection_online.php (LIVE SERVER)

✅ Database connected

Step 1: Getting moderator's classes...
Found 13 classes: 69, 93, 67, 68, 91, 81, 30, 97, 46, 86, 47

Step 2: Getting learners with POE...
✅ Query completed successfully

=== RESULTS ===

Total learners with POE: 1571

✅ SUCCESS! Got 1571 learners (expected ~1571)

First 10 learners:
  1. Surname, Name (ID: 123, Class: Class Name)
  ...

=== TEST COMPLETE ===
```

### MODE 2: HTTP API (Server Deployment)

Upload to server and access via HTTP:

```
https://rlms.rlms.co.za/mobile/test_live_poe_direct.php?moderator_id=77
```

**Response** (JSON):
```json
{
  "status": "success",
  "message": "Learners with POE retrieved successfully",
  "data": {
    "total_learners_with_poe": 1571,
    "learners": [
      {
        "LearnerID": "123",
        "Name": "John",
        "Surname": "Doe",
        "IDNumber": "9001010000000",
        "Email": "john@example.com",
        "PhoneNumber": "0821234567",
        "classID": "69",
        "className": "Class A",
        "siteID": "1",
        "poe_count": "3"
      },
      ...
    ]
  }
}
```

---

## How It Works

The file automatically detects how it's being run:

1. **Command Line** (`php test_live_poe_direct.php`):
   - Shows detailed progress
   - Displays first 10 learners
   - Uses moderator ID 77 (hardcoded for testing)
   - Perfect for testing before deployment

2. **HTTP Request** (`https://...?moderator_id=77`):
   - Returns JSON response
   - Gets moderator ID from URL parameter
   - Includes all learner fields
   - Ready for Flutter app integration

---

## Deployment Steps

### Step 1: Test Locally

```bash
php test_live_poe_direct.php
```

Expected: ~1571 learners in 2-5 seconds

### Step 2: Upload to Server

Upload `test_live_poe_direct.php` to:
```
https://rlms.rlms.co.za/mobile/test_live_poe_direct.php
```

### Step 3: Test via HTTP

Open in browser or use curl:
```bash
curl "https://rlms.rlms.co.za/mobile/test_live_poe_direct.php?moderator_id=77"
```

### Step 4: Update Flutter App

Change endpoint in `lib/ModeratorPage.dart`:

```dart
// OLD (times out)
final url = '$baseUrl/get_learners_with_poe_assigned.php?moderator_id=$moderatorId';

// NEW (fast)
final url = '$baseUrl/test_live_poe_direct.php?moderator_id=$moderatorId';

// OR rename file on server to:
final url = '$baseUrl/get_learners_with_poe_simple.php?moderator_id=$moderatorId';
```

---

## Features

### Automatic Mode Detection
- Detects if running from command line or HTTP
- Adjusts output format accordingly
- No configuration needed

### Flexible Database Connection
- Tries `connection_online.php` first (live server)
- Falls back to `connection.php` (local server)
- Works in both environments

### Different Query Fields
- **CLI Mode**: Basic fields (faster, for testing)
- **HTTP Mode**: Full fields (for app integration)

### Error Handling
- **CLI Mode**: Displays errors in terminal
- **HTTP Mode**: Returns JSON error response
- Proper HTTP status codes

---

## File Naming Options

You can use this file with different names:

1. **`test_live_poe_direct.php`** (current name)
   - Good for testing
   - Clear purpose

2. **`get_learners_with_poe_simple.php`** (production name)
   - Rename after testing
   - Matches other API files
   - More professional

Both work the same way!

---

## Comparison with Old Files

| Feature | Old Files | New Combined File |
|---------|-----------|-------------------|
| Test Script | test_live_poe_direct.php | ✅ Same file |
| API Endpoint | get_learners_with_poe_simple.php | ✅ Same file |
| Maintenance | 2 files to update | 1 file to update |
| Testing | Separate test needed | Built-in testing |
| Deployment | Upload 2 files | Upload 1 file |

---

## Quick Reference

### Test Locally
```bash
php test_live_poe_direct.php
```

### Test on Server
```
https://rlms.rlms.co.za/mobile/test_live_poe_direct.php?moderator_id=77
```

### Use in Flutter
```dart
final url = '$baseUrl/test_live_poe_direct.php?moderator_id=$moderatorId';
```

---

## Summary

**ONE FILE** = Test Script + API Endpoint

- ✅ Test locally before deployment
- ✅ Upload once, works as API
- ✅ No need for separate files
- ✅ Automatic mode detection
- ✅ Simple, fast, works!

**Run this now**: `php test_live_poe_direct.php`
