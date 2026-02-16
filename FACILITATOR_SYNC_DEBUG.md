# Facilitator Sync Debugging Guide

## Problem
Local database shows empty/null values for facilitator data instead of actual server data.

## Debug Steps

### Step 1: Check Server Data
Visit: `https://your-server.com/php/test_facilitator_sync.php`

**What to verify:**
- ✅ Server has facilitator records (count > 0)
- ✅ facilitator_id = 60 exists
- ✅ firstName = "Zamokuhle"
- ✅ lastName = "MLONDO"
- ✅ password = hashed value (starts with $2y$)
- ✅ All fingerprint templates have data

**Expected Output:**
```json
{
  "facilitator_id": "60",
  "firstName": "Zamokuhle",
  "lastName": "MLONDO",
  "email": "zamokuhle@mtltechnical.co.za",
  "password": "$2y$10$NjZP3Z.QSL3Xx7dQo8A4je...",
  ...
}
```

### Step 2: Check Mobile App Logs
Run the app and trigger sync. Look for these log entries:

#### A. Server Response
```
[FAC_SYNC] Server response received, status: 200
[FAC_SYNC] Response body length: XXXX chars
[FAC_SYNC] Received X facilitators from server
```
✅ **Verify:** Status = 200, received count > 0

#### B. First Record from Server
```
[FAC_SYNC] ===== FIRST RECORD FROM SERVER =====
[FAC_SYNC]   facilitator_id: 60
[FAC_SYNC]   firstName: Zamokuhle
[FAC_SYNC]   lastName: MLONDO
[FAC_SYNC]   email: zamokuhle@mtltechnical.co.za
[FAC_SYNC]   password: $2y$10$NjZP3Z.QSL3Xx7dQo8A4je...
[FAC_SYNC] ====================================
```
✅ **Verify:** All fields have correct values from server

#### C. Table Cleared
```
[FAC_SYNC] Cleared local facilitator table
[FAC_SYNC] Table count after clear: 0
[FAC_SYNC] Table columns: [facilitator_id, firstName, lastName, role, email, ...]
```
✅ **Verify:** Count = 0, all expected columns present

#### D. Data to Insert
```
[FAC_SYNC] Data to insert: 18 fields
[FAC_SYNC]   - facilitator_id: 60
[FAC_SYNC]   - firstName: 'Zamokuhle'
[FAC_SYNC]   - lastName: 'MLONDO'
[FAC_SYNC]   - email: 'zamokuhle@mtltechnical.co.za'
[FAC_SYNC]   - password: '$2y$10$NjZP3Z.QSL3...'
```
✅ **Verify:** Values match server data

#### E. Database Insert
```
[DB_INSERT] Facilitator data being inserted:
[DB_INSERT]   ID: 60
[DB_INSERT]   Name: Zamokuhle MLONDO
[DB_INSERT]   Email: zamokuhle@mtltechnical.co.za
[DB_INSERT]   Role: Facilitator
[DB_INSERT]   ClassID: 67
[DB_INSERT]   All keys: [facilitator_id, firstName, lastName, ...]
Successfully inserted data into facilitator
```
✅ **Verify:** Insert succeeded without errors

#### F. Verification Query
```
[FAC_SYNC] ✓ VERIFIED in DB: ID=60, firstName='Zamokuhle', lastName='MLONDO'
```
✅ **Verify:** Data matches what was inserted

⚠️ **WARNING to look for:**
```
[FAC_SYNC] ⚠️ WARNING: firstName mismatch! Expected 'Zamokuhle', got ''
```
This indicates data was lost during insertion!

#### G. Final Table State
```
[FAC_SYNC] ===== FINAL TABLE STATE =====
[FAC_SYNC] Total records in table: 1
[FAC_SYNC] Record: ID=60, firstName='Zamokuhle', lastName='MLONDO', email='zamokuhle@mtltechnical.co.za'
[FAC_SYNC] =============================
```
✅ **Verify:** Correct data in final table

### Step 3: Check PHP Server Logs
Look in server error logs for:
```
[FACILITATOR_SYNC] Sending X facilitators
[FACILITATOR_SYNC] First record: {"facilitator_id":"60","firstName":"Zamokuhle",...}
```

## Common Issues & Solutions

### Issue 1: facilitator_id = 1 instead of 60
**Cause:** Old data not cleared, or wrong record being inserted
**Solution:** Check "Table count after clear" = 0

### Issue 2: Empty firstName/lastName
**Cause:** Data lost during transfer or NULL in server database
**Solution:** 
1. Check test_facilitator_sync.php shows correct data
2. Check "FIRST RECORD FROM SERVER" has values
3. Check "Data to insert" has values

### Issue 3: password = "null" (string)
**Cause:** Server database has NULL, or JSON encoding issue
**Solution:** Check server database directly with SQL:
```sql
SELECT facilitator_id, firstName, lastName, password 
FROM facilitator 
WHERE facilitator_id = 60;
```

### Issue 4: Fingerprint templates empty
**Cause:** Templates are NULL in server database
**Solution:** Check if templates exist on server using test_facilitator_sync.php

## Testing SQL Directly

To test if issue is with sync or database, try manual insert:

```dart
// Add this to your sync code temporarily
final testData = {
  'facilitator_id': 999,
  'firstName': 'Test',
  'lastName': 'User',
  'role': 'Facilitator',
  'email': 'test@example.com',
  'classID': 1,
  'password': 'test123',
};
await _dbHelper.insertData('facilitator', testData);

// Then verify
final result = await db.query('facilitator', where: 'facilitator_id = ?', whereArgs: [999]);
print("TEST INSERT RESULT: $result");
```

If test insert works but server data doesn't, the issue is with the data coming from server.

## Files Modified

1. **php/sync_facilitator.php** - Server endpoint with logging
2. **php/test_facilitator_sync.php** - Browser test tool
3. **lib/sync_service.dart** - Mobile sync with comprehensive logging
4. **lib/database_helper.dart** - Database insert with logging

## Next Steps

1. ✅ Run test_facilitator_sync.php to confirm server has correct data
2. ✅ Run app sync and collect ALL logs
3. ✅ Compare logs with this guide to find where data is lost
4. ✅ Share the specific log section showing the issue

The logs will pinpoint exactly where the data transformation is failing!

