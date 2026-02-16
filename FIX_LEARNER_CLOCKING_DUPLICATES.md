# Fix: Learner Clocking Duplicate Records Issue

## Problem Analysis

The daily attendance system (`learner_clocking` table) was creating duplicate records where:
1. One record had complete data (clock_in_time, clock_out_time, contact_time) from server
2. Another record had only partial data (clock_in_time only) from local manual clock-in

## Root Cause

The issue was caused by **conflicting merge strategies** between different parts of the app:

### **Three Methods Writing to `learner_clocking`:**

1. **Clock-in Page** (`lib/clock_in_page.dart`):
   - Uses `DatabaseHelper().insertClocking()`
   - ✅ **Smart duplicate prevention** (checks existing + updates)

2. **LearnerListPage Offline** (`lib/LearnerListPage.dart`):
   - Uses `dbHelper.insertClockInOffline()`
   - ✅ **Smart duplicate prevention** (checks existing + updates)

3. **Sync Service** (`lib/sync_service.dart`):
   - Used `db.insert(conflictAlgorithm: ConflictAlgorithm.replace)`
   - ❌ **BLINDLY REPLACED** local records with server data

### **The Problem Scenario:**
1. User clocks in manually → Local record created with only `clock_in_time`
2. Server generates auto clock-out → Server record has `clock_out_time` 
3. Sync runs → `ConflictAlgorithm.replace` overwrites local record
4. Result: Active user session gets auto-clocked out!

## The Fix

**Updated `_syncLearnerClocking()` in `lib/sync_service.dart`:**

### **Before (Problematic):**
```dart
await db.insert('learner_clocking', mappedClocking, 
  conflictAlgorithm: ConflictAlgorithm.replace);
```

### **After (Fixed):**
```dart
// Check if record exists locally
final existingRecords = await db.query(
  'learner_clocking',
  where: 'LearnerID = ? AND clock_date = ?',
  whereArgs: [mappedClocking['LearnerID'], mappedClocking['clock_date']],
);

if (existingRecords.isNotEmpty) {
  final existingRecord = existingRecords.first;
  
  // PRESERVE local clock-in state if learner is currently clocked in
  if (existingRecord['clock_in_time'] != null && 
      existingRecord['clock_out_time'] == null &&
      mappedClocking['clock_out_time'] != null) {
    // Server has clock-out but we have active local session
    // DON'T overwrite - preserve active session
    print("PRESERVING local clock-in state - rejecting server auto clock-out");
    continue;
  }
  
  // Safe to update with server data
  await db.update('learner_clocking', mappedClocking, ...);
} else {
  // Insert new record
  await db.insert('learner_clocking', mappedClocking);
}
```

## How This Prevents Duplicates

### **Before the Fix:**
1. User clocks in → Local record: `{clock_in_time: "09:00", clock_out_time: null}`
2. Server generates auto clock-out → Server record: `{clock_in_time: "09:00", clock_out_time: "11:00"}`
3. Sync runs → `ConflictAlgorithm.replace` overwrites local record
4. User appears clocked out when they're actually still working

### **After the Fix:**
1. User clocks in → Local record: `{clock_in_time: "09:00", clock_out_time: null}`
2. Server generates auto clock-out → Server record: `{clock_in_time: "09:00", clock_out_time: "11:00"}`
3. Sync runs → **Detects active session and PRESERVES local record**
4. User remains clocked in until they manually clock out

## Benefits

1. **No More Duplicates**: Consistent merge strategy across all insertion methods
2. **Preserves Active Sessions**: Users won't be auto-clocked out during work
3. **Server Data Sync**: Non-conflicting server data still syncs properly
4. **Prevents Data Loss**: Local changes aren't overwritten by stale server data

## Files Modified

- `lib/sync_service.dart` - Updated `_syncLearnerClocking()` function to use intelligent merge logic

## Testing Recommendations

1. **Test Manual Clock-in**: Clock in manually and verify sync doesn't auto clock-out
2. **Test Offline Scenarios**: Clock in offline, come online, verify no duplicates
3. **Test Server Data**: Ensure legitimate server updates still sync properly
4. **Test Active Session Protection**: Verify users stay clocked in during sync operations

This fix ensures that the daily attendance sync process respects active user sessions and prevents the creation of duplicate or conflicting records.