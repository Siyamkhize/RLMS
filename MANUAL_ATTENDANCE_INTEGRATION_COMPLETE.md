# Manual Attendance Integration - Complete ✅

## Overview
Successfully integrated approved manual attendance records into the attendance calculation system. The system now counts both regular clocking and approved manual attendance when calculating learner attendance and stipend amounts.

## Changes Made

### 1. Database Schema Update (`lib/database_helper.dart`)

#### Added `manual_clocking` Table
```dart
CREATE TABLE manual_clocking (
  manual_id INTEGER PRIMARY KEY AUTOINCREMENT,
  clocking_id INTEGER,
  LearnerID INTEGER NOT NULL,
  clock_date TEXT NOT NULL,
  clock_in_time TEXT,
  clock_out_time TEXT,
  contact_time TEXT,
  manual_reason TEXT,
  fdp_document TEXT,
  status TEXT DEFAULT 'Pending',
  reviewed_by TEXT,
  reviewed_at TEXT,
  rejection_reason TEXT,
  is_manual_attendance INTEGER DEFAULT 1,
  synced INTEGER DEFAULT 0
)
```

**Key Fields:**
- `status`: Enum values ('Pending', 'Approved', 'Declined')
- `is_manual_attendance`: Flag to identify manual attendance records
- `synced`: Track sync status with server

#### Added Database Method
```dart
Future<int> getApprovedManualAttendanceDays(int learnerId, String monthStr)
```

**Purpose:** Query local database for approved manual attendance records
**Returns:** Count of distinct approved manual attendance days for a learner in a specific month
**Filter:** Only counts records with status = 'Approved' (case-insensitive)

### 2. Attendance Page Updates (`lib/attendance_page.dart`)

#### Updated `_loadLocalAttendanceRecords()` Method
- Now queries both `learner_clocking` and `manual_clocking` tables
- Enriches local records with approved manual attendance count
- Maintains offline-first approach

**Before:**
```dart
return localRecords
    .map((record) => Map<String, dynamic>.from(record))
    .toList();
```

**After:**
```dart
// Enrich local records with manual attendance data
final enrichedRecords = <Map<String, dynamic>>[];
for (final record in localRecords) {
  final learnerId = record['LearnerID'] as int;
  
  // Get approved manual attendance days for this learner
  final manualDays = await DatabaseHelper()
      .getApprovedManualAttendanceDays(learnerId, monthStr);

  enrichedRecords.add({
    ...Map<String, dynamic>.from(record),
    'manual_days_clocked': manualDays,
  });
}

return enrichedRecords;
```

#### Updated Local Data Processing
**Total Attendance Calculation:**
```dart
final localDaysClocked = record['local_days_clocked'] ?? 0;
final manualDaysClocked = record['manual_days_clocked'] ?? 0;

// Total attendance includes both regular clocking and approved manual attendance
final totalDaysAttended = localDaysClocked + manualDaysClocked;
```

#### Updated Tooltip Breakdown
**Offline Mode:**
```
Regular clocking: X
Manual attendance: Y
Total: Z
📱 Offline mode
```

**Online Mode:**
```
Regular: X
Manual: Y
Sick Notes: Z
Holidays: H
Total: T
```

### 3. Server Endpoint (Already Implemented)

The server endpoint `mobile/get_attendance.php` already includes manual attendance:

```php
// Get manual clocking attendance (only approved)
$manualQuery = "SELECT DATE(clock_date) as clock_date
               FROM manual_clocking 
               WHERE LearnerID = ? 
               AND DATE(clock_date) >= ? AND DATE(clock_date) <= ?
               AND (status = 'Approved' OR status = 'approved' OR status = 'APPROVED')
               AND DAYOFWEEK(clock_date) BETWEEN 2 AND 6
               GROUP BY DATE(clock_date)";
```

**Server Response Includes:**
- `days_clocked`: Regular clocking days
- `manual_days_clocked`: Approved manual attendance days
- `sick_note_days`: Approved sick note days
- `total_days_attended`: Sum of all attendance types

## How It Works

### Online Mode (Server Data Available)
1. App syncs with server via `mobile/get_attendance.php`
2. Server queries both `learner_clocking` and `manual_clocking` tables
3. Server filters manual attendance by status = 'Approved'
4. Server returns complete attendance breakdown
5. App displays server data with full breakdown

### Offline Mode (Local Data Only)
1. App queries local `learner_clocking` table for regular clocking
2. App queries local `manual_clocking` table for approved manual attendance
3. App combines both counts: `totalDaysAttended = regularDays + manualDays`
4. App calculates stipend: `totalDue = dailyRate × totalDaysAttended`
5. App displays local data with 📱 indicator

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    ATTENDANCE CALCULATION                    │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
              ┌─────▼─────┐      ┌─────▼─────┐
              │  ONLINE   │      │  OFFLINE  │
              │   MODE    │      │   MODE    │
              └─────┬─────┘      └─────┬─────┘
                    │                   │
         ┌──────────▼──────────┐       │
         │  Server Endpoint    │       │
         │  get_attendance.php │       │
         └──────────┬──────────┘       │
                    │                   │
         ┌──────────▼──────────┐  ┌────▼────────────────┐
         │  learner_clocking   │  │  Local Database     │
         │  manual_clocking    │  │  - learner_clocking │
         │  sick_note          │  │  - manual_clocking  │
         └──────────┬──────────┘  └────┬────────────────┘
                    │                   │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │  FILTER APPROVED  │
                    │  status='Approved'│
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │  CALCULATE TOTAL  │
                    │  Regular + Manual │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │  DISPLAY RESULT   │
                    │  with breakdown   │
                    └───────────────────┘
```

## Status Filtering

**Only Approved Records Are Counted:**
- Status must be exactly 'Approved', 'approved', or 'APPROVED'
- Pending records are NOT counted
- Declined records are NOT counted

**Database Query:**
```sql
WHERE (status = 'Approved' OR status = 'approved' OR status = 'APPROVED')
```

## User Experience

### Attendance Display
- **Days Attended Column:** Shows `X/Y` format (attended/expected)
- **Tooltip on Hover:** Shows detailed breakdown
- **Color Coding:**
  - Green: >80% attendance
  - Orange: 50-80% attendance
  - Red: <50% attendance

### Data Source Indicator
- **📱 Icon:** Appears next to learner name when using local data
- **Offline Message:** "📱 Showing local clocking records (offline mode)"

### Breakdown Details
**Online:**
```
Regular: 15
Manual: 3
Sick Notes: 2
Holidays: 1
Total: 21
```

**Offline:**
```
Regular clocking: 15
Manual attendance: 3
Total: 18
📱 Offline mode
```

## Testing Checklist

### Online Mode
- [ ] Verify server returns manual_days_clocked field
- [ ] Confirm only approved manual attendance is counted
- [ ] Check tooltip shows correct breakdown
- [ ] Verify total calculation includes manual days

### Offline Mode
- [ ] Verify local database query works
- [ ] Confirm manual attendance is retrieved from local DB
- [ ] Check 📱 indicator appears
- [ ] Verify total calculation: regular + manual

### Edge Cases
- [ ] No manual attendance records
- [ ] All manual attendance pending (should not count)
- [ ] Mix of approved/pending/declined (only approved counted)
- [ ] Manual attendance on weekends (should be excluded by server)
- [ ] Manual attendance on holidays

## Database Sync

The `manual_clocking` table includes a `synced` field for bidirectional sync:

**From Server to App:**
- Server provides approved manual attendance in API response
- App stores in local database with synced=1

**From App to Server:**
- Manual attendance created on app marked synced=0
- Sync service uploads to server
- Server updates status (Pending/Approved/Declined)
- Next sync downloads updated status

## Benefits

1. **Accurate Attendance:** Counts both regular and manual attendance
2. **Fair Stipend Calculation:** Learners get credit for approved manual attendance
3. **Offline Support:** Manual attendance available even without internet
4. **Transparency:** Breakdown shows exactly what's counted
5. **Status Control:** Only approved records affect attendance

## Next Steps

1. **Build APK:** Compile and install updated app
2. **Test Online Mode:** Verify server data includes manual attendance
3. **Test Offline Mode:** Verify local manual attendance query works
4. **User Testing:** Confirm tooltip and breakdown display correctly
5. **Monitor Logs:** Check for any errors in manual attendance queries

## Files Modified

1. `lib/database_helper.dart`
   - Added `manual_clocking` table schema
   - Added `getApprovedManualAttendanceDays()` method

2. `lib/attendance_page.dart`
   - Updated `_loadLocalAttendanceRecords()` to include manual attendance
   - Updated local data processing to sum regular + manual days
   - Updated tooltip breakdown to show manual attendance separately

3. `mobile/get_attendance.php` (Already implemented)
   - Already queries manual_clocking table
   - Already filters by status='Approved'
   - Already returns manual_days_clocked in response

## Status: ✅ READY FOR BUILD

All code changes complete. Ready to build and test APK.
