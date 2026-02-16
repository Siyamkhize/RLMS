# Facilitator Daily Clock-In Implementation

## Overview

The facilitator fingerprint system now includes **mandatory daily clock-in** functionality. Facilitators must clock in each day before accessing their dashboard.

## Flow Diagram

```
┌─────────────────┐
│  User Logs In   │
└────────┬────────┘
         │
         ▼
┌────────────────────────────┐
│ Check Fingerprints Enrolled? │
└────────┬──────────┬─────────┘
         │          │
      NO │          │ YES
         │          │
         ▼          ▼
┌──────────────┐  ┌─────────────────────────┐
│  Enroll FP   │  │ Check Clocked In Today? │
│ (One-Time)   │  └────────┬────────┬───────┘
└──────────────┘           │        │
                        NO │        │ YES
                           │        │
                           ▼        ▼
                  ┌────────────┐  ┌──────────────┐
                  │ CLOCK IN   │  │  Welcome      │
                  │ (Required) │  │  Message      │
                  └────────────┘  └──────────────┘
                           │                │
                           └────────┬───────┘
                                    │
                                    ▼
                           ┌────────────────┐
                           │   Dashboard    │
                           └────────────────┘
```

## Key Features

### 1. **Daily Clock-In Requirement**
- Facilitators must clock in every day when they log in
- If already clocked in today → direct access to dashboard
- If NOT clocked in today → required to clock in first
- Clock-in syncs to both local database and server

### 2. **Smart Login Flow**
```dart
// Step 1: Check fingerprint enrollment (one-time)
if (!hasFingerprints) {
  → Navigate to enrollment page
  → Cannot proceed until enrolled
}

// Step 2: Check today's clock-in (daily)
if (!clockedInToday) {
  → Navigate to clock-in page (requireClockIn: true)
  → Auto-triggers fingerprint verification
  → Cannot dismiss until clocked in
} else {
  → Show "Welcome back!" message
  → Proceed to dashboard
}
```

### 3. **Server Synchronization**
Both clock-in and clock-out sync to server automatically:
- **Primary**: Save to local database first (ensures offline capability)
- **Secondary**: Attempt server sync immediately
- **Fallback**: If offline, mark as `synced: 0` for later sync

## Database Changes

### Local Database
Added two new methods in `DatabaseHelper`:

```dart
// Check if facilitator clocked in today
Future<bool> facilitatorClockedInToday(int facilitatorId)

// Get today's clock-in time
Future<String?> getFacilitatorTodayClockIn(int facilitatorId)
```

### Server Database
Requires a `facilitator_clocking` table:

```sql
CREATE TABLE facilitator_clocking (
  clocking_id INT PRIMARY KEY AUTO_INCREMENT,
  facilitator_id INT NOT NULL,
  clock_date DATE NOT NULL,
  clock_in_time DATETIME NOT NULL,
  clock_out_time DATETIME,
  contact_time VARCHAR(50),
  user_latitude DECIMAL(10,6),
  user_longitude DECIMAL(10,6),
  user_accuracy DECIMAL(10,6),
  FOREIGN KEY (facilitator_id) REFERENCES facilitator(facilitator_id)
);
```

## PHP Server Endpoints

### 1. Clock-In Endpoint
**File**: `php/facilitator_clockin.php`

**Request**:
```json
{
  "facilitator_id": 123,
  "clock_in_time": "2025-10-09 08:30:00",
  "clock_date": "2025-10-09",
  "user_latitude": "0.0",
  "user_longitude": "0.0",
  "user_accuracy": "10.0"
}
```

**Response** (Success):
```json
{
  "success": true,
  "message": "Clock-in recorded successfully",
  "facilitator_name": "John Doe",
  "clock_in_time": "2025-10-09 08:30:00"
}
```

### 2. Clock-Out Endpoint
**File**: `php/facilitator_clockout.php`

**Request**:
```json
{
  "facilitator_id": 123,
  "clock_out_time": "2025-10-09 17:30:00",
  "contact_time": "9h 0m 0s",
  "clock_date": "2025-10-09"
}
```

**Response** (Success):
```json
{
  "success": true,
  "message": "Clock-out recorded successfully",
  "facilitator_name": "John Doe",
  "clock_in_time": "2025-10-09 08:30:00",
  "clock_out_time": "2025-10-09 17:30:00",
  "contact_time": "9h 0m 0s"
}
```

## UI/UX Changes

### 1. **Required Clock-In Mode**
When `requireClockIn: true`:
- Title: "Daily Clock-In Required"
- Message: "Good [morning/afternoon/evening], [Name]!"
- Subtitle: "Please place your finger on the scanner to clock in and start your day."
- Back button: **DISABLED** (cannot dismiss)
- Auto-triggers fingerprint verification after 500ms

### 2. **Status Messages**
- **Not clocked in**: Orange warning "Please clock in to start your day"
- **Already clocked in**: Green success "Welcome back! Already clocked in at [time]"
- **Clock-in successful**: Green "Clock-in successful and synced!"
- **Clock-in offline**: Orange "Clock-in saved locally (will sync when online)"

### 3. **User Feedback**
```dart
// If online and synced
✅ "Clock-in successful and synced!"

// If offline or sync failed
⚠️  "Clock-in saved locally (will sync when online)"

// If already clocked in
🎉 "Welcome back! Already clocked in at 08:30 AM"

// If trying to skip
❌ "Clock-in is required to access the dashboard"
```

## Code Changes

### Main.dart - Updated Login Navigation
```dart
void _navigateBasedOnRole(...) async {
  // All facilitator roles use the same flow
  await _handleFacilitatorLogin(
    facilitatorId: facilitator_id,
    facilitatorName: 'Facilitator',
    onSuccess: () {
      // Navigate to dashboard
    },
  );
}

Future<void> _handleFacilitatorLogin(...) async {
  // Step 1: Check fingerprint enrollment
  if (!hasFingerprints) {
    await enrollFingerprints();
  }
  
  // Step 2: Check daily clock-in
  if (!clockedInToday) {
    await requireClockIn();
  }
  
  // Step 3: Proceed to dashboard
  onSuccess();
}
```

### FacilitatorFingerprintPage - New Features

1. **requireClockIn Parameter**
```dart
FacilitatorFingerprintPage(
  facilitatorId: facilitatorId,
  facilitatorName: facilitatorName,
  requireClockIn: true, // Forces clock-in mode
)
```

2. **Auto-Trigger Clock-In**
```dart
void initState() {
  if (widget.requireClockIn) {
    Future.delayed(Duration(milliseconds: 500), () {
      _verifyAndClock('in'); // Auto-start verification
    });
  }
}
```

3. **Prevent Dismissal**
```dart
WillPopScope(
  onWillPop: () async {
    if (widget.requireClockIn) {
      // Show warning and prevent back
      return false;
    }
    return true;
  },
)
```

4. **Server Sync Methods**
```dart
Future<bool> _syncClockInToServer(Map<String, dynamic> attendance)
Future<bool> _syncClockOutToServer(Map<String, dynamic> attendance)
```

## Testing Scenarios

### Scenario 1: First-Time User
1. ✅ User logs in
2. ✅ System detects no fingerprints
3. ✅ Redirect to enrollment page
4. ✅ User enrolls fingerprints
5. ✅ System detects not clocked in today
6. ✅ Redirect to clock-in page (requireClockIn: true)
7. ✅ Auto-triggers fingerprint verification
8. ✅ User places finger → Clock-in successful
9. ✅ Redirect to dashboard

### Scenario 2: Returning User (Same Day)
1. ✅ User logs in
2. ✅ System detects fingerprints enrolled
3. ✅ System checks today's clock-in → **FOUND**
4. ✅ Show "Welcome back! Already clocked in at [time]"
5. ✅ Direct access to dashboard

### Scenario 3: Returning User (Next Day)
1. ✅ User logs in
2. ✅ System detects fingerprints enrolled
3. ✅ System checks today's clock-in → **NOT FOUND**
4. ✅ Redirect to clock-in page (requireClockIn: true)
5. ✅ User places finger → Clock-in successful
6. ✅ Redirect to dashboard

### Scenario 4: Offline Clock-In
1. ✅ User logs in (no internet)
2. ✅ Required to clock in
3. ✅ Clock-in saved to local database with `synced: 0`
4. ✅ Message: "Clock-in saved locally (will sync when online)"
5. ✅ Access to dashboard granted
6. ✅ When online, background sync should update server

## Benefits

### For Facilitators
- ✅ Quick biometric clock-in (no manual entry)
- ✅ Only once per day (not on every login)
- ✅ Works offline
- ✅ Accurate time tracking

### For Management
- ✅ Accurate attendance records
- ✅ Cannot skip or forget to clock in
- ✅ Real-time server synchronization
- ✅ Audit trail of all clock-ins
- ✅ Contact time automatically calculated

### For System
- ✅ Consistent with learner clocking flow
- ✅ Secure biometric verification
- ✅ Offline-first architecture
- ✅ Automatic sync when online

## Migration Notes

### Existing Installations
For systems upgrading from previous versions:

1. **Database Migration**: Runs automatically when app opens (version 3)
   - Adds fingerprint columns to facilitator table
   - Creates facilitator_clocking table

2. **First Use**: All existing facilitators will need to:
   - Enroll their fingerprints (one-time)
   - Clock in on their next login

3. **Server Setup**: Deploy new PHP files:
   - `php/facilitator_clockin.php`
   - `php/facilitator_clockout.php`
   - Ensure `facilitator_clocking` table exists on server

### Fresh Installations
Everything works out of the box:
- Database schema includes all required tables
- No migration needed

## Troubleshooting

### Issue: "Clock-in is required to access the dashboard"
**Cause**: User tried to skip clock-in
**Solution**: Place finger on scanner to complete clock-in

### Issue: "No fingerprints enrolled"
**Cause**: First-time user
**Solution**: Complete fingerprint enrollment first

### Issue: Clock-in saved locally but not synced
**Cause**: No internet connection
**Solution**: Automatic - will sync when connection restored

### Issue: Cannot dismiss clock-in page
**Cause**: By design when `requireClockIn: true`
**Solution**: Complete the clock-in to proceed

## Summary

The daily clock-in system ensures:
1. ✅ **Security**: Biometric verification for every clock-in
2. ✅ **Compliance**: Cannot access system without clocking in
3. ✅ **Accuracy**: Exact timestamps and contact time
4. ✅ **Reliability**: Works offline, syncs when online
5. ✅ **User Experience**: Fast, intuitive, one-time per day

Perfect for attendance tracking and accountability! 🎯

