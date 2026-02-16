# clockin.php GPS Coordinate Updates

## Summary
Updated your `clockin.php` to handle GPS coordinates for geofencing. The updated file is saved as `php/clockin_updated.php`.

---

## Key Changes Made

### 1. Extract GPS Coordinates from POST Data
**Added after line with `$classID`:**

```php
// GEOFENCING: Extract GPS coordinates
$userLatitude = isset($_POST['user_latitude']) ? floatval($_POST['user_latitude']) : 0.0;
$userLongitude = isset($_POST['user_longitude']) ? floatval($_POST['user_longitude']) : 0.0;
$userAccuracy = isset($_POST['user_accuracy']) ? floatval($_POST['user_accuracy']) : 50.0;
```

### 2. Log GPS Data in Debug Log
**Updated the debug log to include GPS coordinates:**

```php
$debugLog = "Received POST data: " . json_encode([
    'LearnerID' => $learnerID,
    'classID' => $classID,
    'isSynced' => $isSynced,
    'user_latitude' => $userLatitude,      // NEW
    'user_longitude' => $userLongitude,    // NEW
    'user_accuracy' => $userAccuracy,      // NEW
    'signature' => isset($_POST['signature']) ? 'Provided' : 'Not provided'
], JSON_UNESCAPED_SLASHES);
```

### 3. Update INSERT Statement for New Clock-Ins
**Changed FROM:**
```php
$stmt = $conn->prepare("INSERT INTO learner_clocking (LearnerID, clock_date, clock_in_time, synced) VALUES (?, ?, ?, ?)");
$stmt->bind_param("issi", $learnerID, $currentDate, $currentTime, $isSynced);
```

**Changed TO:**
```php
// GEOFENCING: Insert clock-in time WITH GPS coordinates
$stmt = $conn->prepare("INSERT INTO learner_clocking (LearnerID, clock_date, clock_in_time, synced, user_latitude, user_longitude, user_accuracy) VALUES (?, ?, ?, ?, ?, ?, ?)");

// GEOFENCING: Bind GPS parameters (issiddd = int, string, string, int, double, double, double)
$stmt->bind_param("issiddd", $learnerID, $currentDate, $currentTime, $isSynced, $userLatitude, $userLongitude, $userAccuracy);
```

### 4. Update Sync Statement
**Changed FROM:**
```php
$stmt = $conn->prepare("UPDATE learner_clocking SET synced = 1 WHERE LearnerID = ? AND clock_date = ?");
$stmt->bind_param("is", $learnerID, $currentDate);
```

**Changed TO:**
```php
// GEOFENCING: Update synced status AND GPS coordinates if syncing
$stmt = $conn->prepare("UPDATE learner_clocking SET synced = 1, user_latitude = ?, user_longitude = ?, user_accuracy = ? WHERE LearnerID = ? AND clock_date = ?");
$stmt->bind_param("dddis", $userLatitude, $userLongitude, $userAccuracy, $learnerID, $currentDate);
```

### 5. Enhanced Success Logging
**Updated success log to include GPS data:**
```php
logClockingAttempt($conn, $learnerID, "Successful clock-in with GPS: lat=$userLatitude, lon=$userLongitude, acc=$userAccuracy");
```

---

## What These Changes Do

1. **Extracts GPS coordinates** from the POST request sent by the Flutter app
2. **Stores GPS coordinates** in the database when learner clocks in
3. **Updates GPS coordinates** when syncing offline records
4. **Logs GPS data** for debugging and audit purposes
5. **Maintains backward compatibility** - defaults to 0.0, 0.0 if GPS not provided

---

## Parameter Type Reference

### bind_param Types:
- `i` = integer
- `s` = string
- `d` = double (float)

### New Parameter String: `"issiddd"`
- `i` = LearnerID (integer)
- `s` = clock_date (string)
- `s` = clock_in_time (string)
- `i` = synced (integer)
- `d` = user_latitude (double)
- `d` = user_longitude (double)
- `d` = user_accuracy (double)

---

## Deployment Steps

### Option 1: Replace Existing File
```bash
# Backup your current file first
cp php/clockin.php php/clockin.php.backup

# Replace with updated version
cp php/clockin_updated.php php/clockin.php

# Upload to server
scp php/clockin.php user@server:/path/to/mobile/clockin.php
```

### Option 2: Manual Update
Open your existing `php/clockin.php` and make the 5 changes listed above.

---

## Testing

### Test Clock-In with GPS:
```bash
curl -X POST https://rlms.rlms.co.za/mobile/clockin.php \
  -d "clock_in=1" \
  -d "LearnerID=123" \
  -d "classID=ABC123" \
  -d "user_latitude=-26.123456" \
  -d "user_longitude=28.123456" \
  -d "user_accuracy=15.5" \
  -d "isSynced=1"
```

### Expected Response:
```json
{
  "success": true,
  "message": "Learner successfully clocked in.",
  "clock_in_time": "2025-10-28 14:30:00",
  "clock_out_time": null,
  "contact_time": null,
  "learner_id": "123"
}
```

### Verify in Database:
```sql
SELECT 
    LearnerID,
    clock_date,
    clock_in_time,
    user_latitude,
    user_longitude,
    user_accuracy
FROM learner_clocking
WHERE LearnerID = 123
ORDER BY clock_date DESC
LIMIT 1;
```

### Check Debug Log:
```bash
tail -f debug_clockin.log
```

Should show:
```
Received POST data: {"LearnerID":"123","classID":"ABC123","isSynced":1,"user_latitude":-26.123456,"user_longitude":28.123456,"user_accuracy":15.5,"signature":"Not provided"}
About to send response: {"success":true,"message":"Learner successfully clocked in.","clock_in_time":"2025-10-28 14:30:00","clock_out_time":null,"contact_time":null,"learner_id":"123"}
```

---

## Comparison: Before vs After

### Before (No GPS):
```php
INSERT INTO learner_clocking 
(LearnerID, clock_date, clock_in_time, synced) 
VALUES (?, ?, ?, ?)
```

### After (With GPS):
```php
INSERT INTO learner_clocking 
(LearnerID, clock_date, clock_in_time, synced, user_latitude, user_longitude, user_accuracy) 
VALUES (?, ?, ?, ?, ?, ?, ?)
```

---

## Troubleshooting

### Issue: "Prepare failed for inserting clock-in"
**Cause:** Database columns don't exist
**Solution:** Run the SQL script to add GPS columns:
```sql
ALTER TABLE learner_clocking 
ADD COLUMN user_latitude DECIMAL(10, 8) DEFAULT 0.0,
ADD COLUMN user_longitude DECIMAL(11, 8) DEFAULT 0.0,
ADD COLUMN user_accuracy DECIMAL(10, 2) DEFAULT 50.0;
```

### Issue: GPS coordinates showing as 0.0, 0.0
**Cause:** Flutter app not sending GPS data
**Solution:** 
1. Check Flutter app is updated
2. Verify location permissions granted
3. Check debug log for received POST data

### Issue: "bind_param expects parameter 1 to be string"
**Cause:** Wrong parameter type string
**Solution:** Ensure using `"issiddd"` not `"issi"`

---

## Files to Update

1. ✅ **`php/clockin.php`** - Replace with `php/clockin_updated.php`
2. ✅ **`php/clockout.php`** - Already updated
3. ✅ **Database** - Add GPS columns (use `add_gps_columns.sql`)
4. ✅ **Flutter app** - Already updated (`lib/clock_in_page.dart`)

---

## Checklist

- [ ] Backup current `clockin.php`
- [ ] Update `clockin.php` with GPS handling
- [ ] Verify database has GPS columns
- [ ] Upload updated file to server
- [ ] Test clock-in with GPS data
- [ ] Check debug logs
- [ ] Verify GPS data in database
- [ ] Test with Flutter app
- [ ] Monitor for errors

---

## Summary

Your `clockin.php` now:
- ✅ Accepts GPS coordinates from POST data
- ✅ Stores GPS coordinates in database
- ✅ Updates GPS coordinates when syncing
- ✅ Logs GPS data for debugging
- ✅ Maintains backward compatibility

The updated file is ready to deploy: **`php/clockin_updated.php`**
