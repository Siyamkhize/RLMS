# ARPL Assessor Clocking - Table Schema Fix Complete

## Date: July 16, 2026

## Issue
The app code was using incorrect column names for the `facilitator_clocking` table, causing clock in/out failures for ARPL Assessors.

## Root Cause
Mismatch between:
- **App code** was using: `clockin_time`, `clockout_time` (no underscores)
- **Database schema** actually uses: `clock_in_time`, `clock_out_time`, `clock_date` (with underscores)

## Server Database Schema (MySQL)
```sql
CREATE TABLE facilitator_clocking (
  clocking_id INT(11) PRIMARY KEY AUTO_INCREMENT,
  facilitator_id INT(11) NOT NULL,
  clock_date DATE NOT NULL,
  clock_in_time DATETIME NOT NULL,
  clock_out_time DATETIME NULL,
  contact_time VARCHAR(50) NULL,
  user_latitude DECIMAL(10,6) NULL,
  user_longitude DECIMAL(10,6) NULL,
  user_accuracy DECIMAL(10,6) NULL
);
```

## Local Database Schema (SQLite)
```sql
CREATE TABLE IF NOT EXISTS facilitator_clocking (
  clocking_id INTEGER PRIMARY KEY AUTOINCREMENT,
  facilitator_id INTEGER NOT NULL,
  clock_date DATE NOT NULL,
  clock_in_time DATETIME NOT NULL,
  clock_out_time DATETIME,
  contact_time TEXT,
  synced INTEGER NOT NULL DEFAULT 0,
  user_latitude DECIMAL(10,6),
  user_longitude DECIMAL(10,6),
  user_accuracy DECIMAL(10,6)
);
```

## Files Fixed

### 1. `lib/main.dart`
**Lines affected:** Clock-in check and prompt dialog (lines 1100-1250)

**Changes:**
- ✅ Changed table name from `facilitator_attendance` to `facilitator_clocking` 
- ✅ Changed `clockin_time` to `clock_in_time`
- ✅ Changed `clockout_time` to `clock_out_time`
- ✅ Changed `DATE(clockin_time) = ?` to `clock_date = ?` (more efficient)
- ✅ Added `clock_date` field when inserting new records

**Before:**
```dart
await db.query(
  'facilitator_clocking',
  where: 'facilitator_id = ? AND DATE(clockin_time) = ?',
  whereArgs: [facilitatorId, today],
);
```

**After:**
```dart
await db.query(
  'facilitator_clocking',
  where: 'facilitator_id = ? AND clock_date = ?',
  whereArgs: [facilitatorId, today],
);
```

### 2. `lib/arpl_assessor_clocking_page.dart`
**Entire file fixed**

**Changes:**
- ✅ Changed `clockin_time` to `clock_in_time` (4 occurrences)
- ✅ Changed `clockout_time` to `clock_out_time` (5 occurrences)
- ✅ Changed `DATE(clockin_time)` to `clock_date` (more efficient query)
- ✅ Added `clock_date` field when inserting and updating records
- ✅ Fixed table reference from `facilitator_attendance` to `facilitator_clocking` (1 occurrence)

**Clock In - Before:**
```dart
await db.insert('facilitator_clocking', {
  'facilitator_id': widget.facilitatorId,
  'clockin_time': clockInTime,
  'clockout_time': null,
  'synced': 0,
});
```

**Clock In - After:**
```dart
await db.insert('facilitator_clocking', {
  'facilitator_id': widget.facilitatorId,
  'clock_date': clockDate,
  'clock_in_time': clockInTime,
  'clock_out_time': null,
  'synced': 0,
});
```

**Clock Out - Before:**
```dart
await db.update(
  'facilitator_clocking',
  {'clockout_time': clockOutTime, 'synced': 0},
  where: 'facilitator_id = ? AND DATE(clockin_time) = DATE(?) AND clockout_time IS NULL',
  whereArgs: [widget.facilitatorId, DateFormat('yyyy-MM-dd').format(now)],
);
```

**Clock Out - After:**
```dart
await db.update(
  'facilitator_clocking',
  {'clock_out_time': clockOutTime, 'synced': 0},
  where: 'facilitator_id = ? AND clock_date = ? AND clock_out_time IS NULL',
  whereArgs: [widget.facilitatorId, clockDate],
);
```

## Benefits of the Fix

1. **Correct Column Names**: Matches actual database schema
2. **More Efficient Queries**: Using `clock_date` field instead of `DATE(clock_in_time)`
3. **Proper Date Handling**: Separate date and time fields as designed
4. **Sync Compatibility**: Works with server database structure

## Testing Required

1. ✅ **Rebuild APK** with these fixes
2. ⬜ **Test ARPL Assessor Login** - Should see mandatory clock-in prompt
3. ⬜ **Test Clock In** - Should save to database correctly
4. ⬜ **Test Clock Out** - Should update record correctly
5. ⬜ **Test Learner Clocking** - Should load learners from `learnerdetails` table
6. ⬜ **Test Offline/Online Sync** - Clock records should sync to server

## Test Credentials
- **Facilitator ID**: 6
- **Role**: `arpl_Assessor`
- **ClassID**: 797
- **OFO Code**: 641201 (Bricklayer)

## Next Steps

1. **Build APK**:
   ```bash
   flutter build apk --release
   ```

2. **Install and Test**:
   - Login as ARPL Assessor (Facilitator ID 6)
   - Should see clock-in prompt immediately
   - Clock in should succeed
   - Navigate to "Clock In/Out" from menu
   - Verify clock status shows "Currently Clocked In"
   - Test learner clocking functionality

## Notes
- ARPL Assessors use the same endpoints as facilitators (`facilitator_clockin.php`, `facilitator_clockout.php`)
- ARPL Assessors use the same table as facilitators (`facilitator_clocking`)
- The mandatory clock-in prompt appears after login before accessing dashboard
- Learners are loaded from `learnerdetails` table (not `learners`)
