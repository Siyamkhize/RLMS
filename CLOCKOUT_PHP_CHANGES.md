# clockout.php GPS Coordinate Updates

## Summary
Updated your `clockout.php` to handle GPS coordinates for geofencing. The updated file is saved as `php/clockout_updated.php`.

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

### 3. Update Clock-Out Statement
**Changed FROM:**
```php
$stmt = $conn->prepare("UPDATE learner_clocking SET clock_out_time = ?, contact_time = ?, synced = ? WHERE LearnerID = ? AND clock_date = ?");
$stmt->bind_param("ssiss", $currentTime, $contactTime, $isSynced, $learnerID, $currentDate);
```

**Changed TO:**
```php
// GEOFENCING: Update clock-out time, contact time, AND GPS coordinates
$stmt = $conn->prepare("UPDATE learner_clocking SET clock_out_time = ?, contact_time = ?, synced = ?, user_latitude = ?, user_longitude = ?, user_accuracy = ? WHERE LearnerID = ? AND clock_date = ?");

// GEOFENCING: Bind GPS parameters (ssidddis = string, string, int, double, double, double, int, string)
$stmt->bind_param("ssidddis", $currentTime, $contactTime, $isSynced, $userLatitude, $userLongitude, $userAccuracy, $learnerID, $currentDate);
```

### 4. Enhanced Debug Logging
**Updated debug log to include GPS data:**
```php
file_put_contents('debug_clockout.log', "Updated learner_clocking: clock_out_time=$currentTime, contact_time=$contactTime, synced=$isSynced, GPS: lat=$userLatitude, lon=$userLongitude, acc=$userAccuracy for learnerID=$learnerID, date=$currentDate" . PHP_EOL, FILE_APPEND);
```

### 5. Enhanced Success Logging
**Updated success log to include GPS data:**
```php
logClockingAttempt($conn, $learnerID, "Successful clock-out with GPS: lat=$userLatitude, lon=$userLongitude, acc=$userAccuracy");
```

---

## What These Changes Do

1. **Extracts GPS coordinates** from the POST request sent by the Flutter app
2. **Stores GPS coordinates** in the database when learner clocks out
3. **Logs GPS data** for debugging and audit purposes
4. **Maintains backward compatibility** - defaults to 0.0, 0.0 if GPS not provided
5. **Updates existing record** with clock-out GPS location

---

## Parameter Type Reference

### bind_param Types:
- `s` = string
- `i` = integer
- `d` = double (float)

### New Parameter String: `"ssidddis"`
- `s` = clock_out_time (string)
- `s` = contact_time (string)
- `i` = synced (integer)
- `d` = user_latitude (double)
- `d` = user_longitude (double)
- `d` = user_accuracy (double)
- `i` = LearnerID (integer)
- `s` = clock_date (string)

---

## Deployment Steps

### Option 1: Replace Existing File
```bash
# Backup your current file first
cp php/clockout.php php/clockout.php.backup

# Replace with updated version
cp php/clockout_updated.php php/clockout.php

# Upload to server
scp php/clockout.php user@server:/path/to/mobile/clockout.php
```

### Option 2: Manual Update
Open your existing `php/clockout.php` and make the 5 changes listed above.

---

## Testing

### Test Clock-Out with GPS:
```bash
# First clock in
curl -X POST https://rlms.rlms.co.za/mobile/clockin.php \
  -d "clock_in=1" \
  -d "LearnerID=123" \
  -d "classID=ABC123" \
  -d "user_latitude=-26.123456" \
  -d "user_longitude=28.123456" \
  -d "user_accuracy=15.5" \
  -d "isSynced=1"

# Then clock out
curl -X POST https://rlms.rlms.co.za/mobile/clockout.php \
  -d "clock_out=1" \
  -d "LearnerID=123" \
  -d "classID=ABC123" \
  -d "user_latitude=-26.123457" \
  -d "user_longitude=28.123457" \
  -d "user_accuracy=12.3" \
  -d "isSynced=1"
```

### Expected Response:
```json
{
  "success": true,
  "message": "Learner successfully clocked out.",
  "clock_in_time": "2025-10-28 14:30:00",
  "clock_out_time": "2025-10-28 18:30:00",
  "contact_time": "04:00:00"
}
```

### Verify in Database:
```sql
SELECT 
    LearnerID,
    clock_date,
    clock_in_time,
    clock_out_time,
    contact_time,
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
tail -f debug_clockout.log
```

Should show:
```
Received POST data: {"LearnerID":"123","classID":"ABC123","isSynced":1,"user_latitude":-26.123457,"user_longitude":28.123457,"user_accuracy":12.3,"signature":"Not provided"}
Updated learner_clocking: clock_out_time=2025-10-28 18:30:00, contact_time=04:00:00, synced=1, GPS: lat=-26.123457, lon=28.123457, acc=12.3 for learnerID=123, date=2025-10-28
About to send response: {"success":true,"message":"Learner successfully clocked out.","clock_in_time":"2025-10-28 14:30:00","clock_out_time":"2025-10-28 18:30:00","contact_time":"04:00:00"}
```

---

## Comparison: Before vs After

### Before (No GPS):
```php
UPDATE learner_clocking 
SET clock_out_time = ?, contact_time = ?, synced = ? 
WHERE LearnerID = ? AND clock_date = ?
```

### After (With GPS):
```php
UPDATE learner_clocking 
SET clock_out_time = ?, contact_time = ?, synced = ?, 
    user_latitude = ?, user_longitude = ?, user_accuracy = ? 
WHERE LearnerID = ? AND clock_date = ?
```

---

## Important Notes

### GPS Coordinates on Clock-Out
The GPS coordinates stored during clock-out represent **where the learner was when they clocked out**. This may be different from the clock-in location if the learner moved during the day (though both should be within the 300m geofence).

### Use Cases for Clock-Out GPS:
1. **Verify learner stayed at site** - Compare clock-in and clock-out locations
2. **Detect anomalies** - Large distance between clock-in/out locations
3. **Audit trail** - Complete location history for the day
4. **Compliance** - Prove learner was at site for entire duration

---

## Troubleshooting

### Issue: "Prepare failed for updating clock-out"
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
**Solution:** Ensure using `"ssidddis"` not `"ssiss"`

### Issue: Clock-out GPS different from clock-in GPS
**Cause:** This is normal if learner moved during the day
**Solution:** 
1. Verify both locations are within 300m of site
2. Check if distance between them is reasonable
3. Use this data to detect anomalies

---

## Checklist

- [ ] Backup current `clockout.php`
- [ ] Update `clockout.php` with GPS handling
- [ ] Verify database has GPS columns
- [ ] Upload updated file to server
- [ ] Test clock-out with GPS data
- [ ] Check debug logs
- [ ] Verify GPS data in database
- [ ] Test with Flutter app
- [ ] Monitor for errors

---

## Summary

Your `clockout.php` now:
- ✅ Accepts GPS coordinates from POST data
- ✅ Stores GPS coordinates in database
- ✅ Logs GPS data for debugging
- ✅ Maintains backward compatibility
- ✅ Provides complete location audit trail

The updated file is ready to deploy: **`php/clockout_updated.php`**
