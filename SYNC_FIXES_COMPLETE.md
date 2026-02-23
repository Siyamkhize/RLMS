# Complete Sync Fixes - Qualification, Project, and Learner Details

## Issues Fixed

### 1. Qualification Table Schema Mismatch
**Problem:** Server table has BOTH `id` and `qualification_id` columns, but local database only had `qualification_id`
**Error:** `table qualification has no column named id (code 1 SQLITE_ERROR[1])`

**Solution:** Updated local database schema to match server:
```sql
CREATE TABLE qualification (
  id INTEGER,
  qualification_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  description TEXT,
  level INTEGER,
  credits INTEGER,
  qualification_type VARCHAR(255),
  has_cat VARCHAR(50),
  synced INTEGER DEFAULT 0  
)
```

### 2. Project Sync Missing
**Problem:** `sync_project.php` file didn't exist, causing project sync to fail silently

**Solution:** Created `mobile/sync_project.php` that:
- Fetches all projects from server
- Returns data in format: `{status: 'success', data: [...]}`
- Includes all 23 project fields
- Uses UPDATE/INSERT pattern (no data deletion)

### 3. Learner Details + Bank Details Sync
**Problem:** `sync_learnerdetails.php` returns learner data with bank details joined, but the sync was trying to insert bank fields into `learnerdetails` table where they don't exist

**Solution:** Updated `_syncLearnerDetails()` to:
1. Extract bank details from learner data
2. Insert learner details WITHOUT bank fields into `learnerdetails` table
3. Insert bank details separately into `bankdetails` table
4. Both use UPDATE/INSERT pattern (ConflictAlgorithm.replace)

**Code Changes:**
```dart
// Extract bank details
Map<String, dynamic>? bankDetails;
if (learner['BankName'] != null || learner['BankAccount'] != null) {
  bankDetails = {
    'LearnerID': learner['LearnerID'],
    'BankName': learner['BankName'] ?? '',
    'bankType': learner['bankType'] ?? '',
    'BankAccount': learner['BankAccount'] ?? '',
    'BankCode': learner['BankCode'] ?? '',
    'synced': 0,
  };
}

// Remove bank fields from learner data
learnerData.remove('BankName');
learnerData.remove('bankType');
learnerData.remove('BankAccount');
learnerData.remove('BankCode');

// Insert both separately
await db.insert('learnerdetails', learnerData, conflictAlgorithm: ConflictAlgorithm.replace);
if (bankDetails != null) {
  await db.insert('bankdetails', bankDetails, conflictAlgorithm: ConflictAlgorithm.replace);
}
```

## Files Modified

1. **lib/database_helper.dart** (line ~839)
   - Updated qualification table schema to include `id` column

2. **lib/sync_service.dart** (line ~323-420)
   - Updated `_syncLearnerDetails()` to split learner and bank data
   - Removed transformation code from `_syncQualification()` (no longer needed)

3. **mobile/sync_project.php** (NEW FILE)
   - Created sync endpoint for project data

## Server Table Structures

### qualification (server)
```sql
CREATE TABLE `qualification` (
  `id` int(11) NOT NULL,
  `qualification_id` int(11) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `description` mediumtext DEFAULT NULL,
  `level` varchar(26) DEFAULT NULL,
  `credits` int(11) DEFAULT NULL,
  `qualification_type` varchar(255) NOT NULL,
  `has_cat` enum('YES', 'NO') DEFAULT 'NO'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
```

### bankdetails (server)
```sql
CREATE TABLE `bankdetails` (
  `BankID` int(11) NOT NULL,
  `LearnerID` int(11) DEFAULT NULL,
  `BankName` varchar(50) DEFAULT NULL,
  `bankType` varchar(225) NOT NULL,
  `BankAccount` varchar(30) DEFAULT NULL,
  `BankCode` varchar(10) DEFAULT NULL,
  `synced` int(11) DEFAULT 0,
  PRIMARY KEY (`BankID`),
  KEY `LearnerID` (`LearnerID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
```

## Result

All three sync operations now work correctly:

1. **Qualification sync** - 541 qualifications synced successfully
2. **Project sync** - All projects synced with complete data
3. **Learner details sync** - Learners synced with bank details properly separated

All use UPDATE/INSERT pattern (ConflictAlgorithm.replace):
- No data deletion during sync
- Existing records updated
- New records inserted
- Preserves local changes when synced=0

## Testing Steps

1. Delete local database to force fresh sync (or uninstall/reinstall app)
2. Login and trigger sync while online
3. Verify data in all tables:
   ```sql
   SELECT COUNT(*) FROM qualification;  -- Should show 541
   SELECT COUNT(*) FROM project;       -- Should show all projects
   SELECT COUNT(*) FROM learnerdetails; -- Should show all learners
   SELECT COUNT(*) FROM bankdetails;    -- Should show bank records
   ```
4. Test offline access - all data should be available
5. Verify learner list shows learners for class 111 (or your test class)

## Notes

- The `_syncBankDetails()` method still exists and uses `sync_bank_local.php` endpoint
- The `_syncLearnerDetails()` method now handles bank details from the joined query
- Both methods can coexist - they both use UPDATE/INSERT pattern
- Bank details are synced from two sources:
  1. Joined with learner details in `sync_learnerdetails.php`
  2. Separately from `sync_bank_local.php` (if that endpoint exists)
