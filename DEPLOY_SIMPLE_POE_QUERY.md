# Deploy Simple POE Query - Checklist

## Pre-Deployment: Test Locally

✅ **Step 1**: Run the test script

```bash
php test_live_poe_direct.php
```

**Expected Output**:
- ✅ Database connected
- ✅ Found 13 classes
- ✅ Query completed successfully
- ✅ Total learners with POE: ~1571
- ✅ Execution time: 2-5 seconds

---

## Deployment: Upload to Server

✅ **Step 2**: Upload the API file

**File to Upload**: `get_learners_with_poe_simple.php`

**Upload Location**: 
```
https://rlms.rlms.co.za/mobile/get_learners_with_poe_simple.php
```

**Upload Method**:
- FTP/SFTP to `/public_html/mobile/` directory
- Or use cPanel File Manager

---

## Post-Deployment: Update Flutter App

✅ **Step 3**: Update the endpoint in Flutter

**File**: `lib/ModeratorPage.dart`

**Find this line** (around line 150-200):
```dart
final url = '$baseUrl/get_learners_with_poe_assigned.php?moderator_id=$moderatorId';
```

**Replace with**:
```dart
final url = '$baseUrl/get_learners_with_poe_simple.php?moderator_id=$moderatorId';
```

---

## Testing: Verify in App

✅ **Step 4**: Test in the Flutter app

1. Open the app
2. Login as moderator (ID: 77)
3. Go to "Moderation Sampling" page
4. Click to load learners with POE

**Expected Result**:
- ✅ Loads in 2-5 seconds (no timeout)
- ✅ Shows ~1571 learners
- ✅ Displays correct total count
- ✅ No error messages

---

## Rollback Plan (If Needed)

If the new endpoint has issues:

**Revert Flutter App**:
```dart
// Change back to old endpoint
final url = '$baseUrl/get_learners_with_poe_assigned.php?moderator_id=$moderatorId';
```

**Note**: The old endpoint still exists on the server, so you can switch back anytime.

---

## What Changed

### Before (Complex Query)
- ❌ Timeout after 60 seconds
- ❌ Shows 273 instead of 1571
- ❌ Complex stratification
- ❌ Temporary tables
- ❌ Sampling calculations

### After (Simple Query)
- ✅ Completes in 2-5 seconds
- ✅ Shows correct count: 1571
- ✅ Simple JOIN query
- ✅ No temporary tables
- ✅ No complex calculations

---

## API Response Format

The new endpoint returns:

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

## Troubleshooting

### If test fails locally

1. Check database connection in `connection_online.php`
2. Verify moderator ID 77 exists in database
3. Check if moderator has classes allocated

### If API returns 0 learners

1. Verify moderator has classes in `facilitator` table
2. Check if learners have POE files in `poe` table
3. Verify class IDs match between tables

### If API times out on server

1. Check server PHP timeout settings
2. Verify database connection is working
3. Check server error logs

---

## Files Involved

### Upload to Server
- ✅ `get_learners_with_poe_simple.php` - New API endpoint

### Modify in Flutter
- ✅ `lib/ModeratorPage.dart` - Change endpoint URL

### Keep for Reference
- 📄 `test_live_poe_direct.php` - Test script
- 📄 `get_learners_with_poe_assigned.php` - Old complex version
- 📄 `SIMPLE_POE_QUERY_SOLUTION.md` - Documentation

---

## Success Criteria

✅ Test script runs successfully locally  
✅ API file uploaded to server  
✅ Flutter app updated with new endpoint  
✅ App loads learners in 2-5 seconds  
✅ Correct count displayed (1571)  
✅ No timeout errors  

---

## Support

If you encounter any issues:

1. Check the test output from `test_live_poe_direct.php`
2. Review server error logs
3. Verify database connection
4. Check Flutter app console for errors

---

**Ready to deploy?** Start with Step 1: Run `php test_live_poe_direct.php`
