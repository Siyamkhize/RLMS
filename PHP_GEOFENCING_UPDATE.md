# PHP Endpoint Updates for Geofencing

## Summary

Updated PHP endpoints to properly handle and store GPS coordinates for both clock-in and clock-out operations.

## Files Updated

### 1. ✅ `php/clockin.php` - Already Correct
**Status:** No changes needed - already handles GPS coordinates properly

The file already:
- Accepts `user_latitude`, `user_longitude`, and `user_accuracy` from POST data
- Stores all three GPS fields in the database
- Uses proper SQL statement with all parameters

**Existing Code:**
```php
$userLatitude = isset($_POST['user_latitude']) ? floatval($_POST['user_latitude']) : 0.0;
$userLongitude = isset($_POST['user_longitude']) ? floatval($_POST['user_longitude']) : 0.0;
$userAccuracy = isset($_POST['user_accuracy']) ? floatval($_POST['user_accuracy']) : 50.0;

$stmt = $conn->prepare("INSERT INTO learner_clocking (LearnerID, clock_date, clock_in_time, synced, user_latitude, user_longitude, user_accuracy) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE clock_in_time = VALUES(clock_in_time), synced = VALUES(synced), user_latitude = VALUES(user_latitude), user_longitude = VALUES(user_longitude), user_accuracy = VALUES(user_accuracy)");

$stmt->bind_param("issiddd", $learnerID, $currentDate, $currentTime, $isSynced, $userLatitude, $userLongitude, $userAccuracy);
```

### 2. ✅ `php/clockout.php` - UPDATED
**Status:** Updated to store GPS coordinates on clock-out

**Changes Made:**

#### Before:
```php
$stmt = $conn->prepare("UPDATE learner_clocking SET clock_out_time = ?, contact_time = ?, synced = ? WHERE LearnerID = ? AND clock_date = ?");

$stmt->bind_param("ssiss", $currentTime, $contactTime, $isSynced, $learnerID, $currentDate);
```

#### After:
```php
$stmt = $conn->prepare("UPDATE learner_clocking SET clock_out_time = ?, contact_time = ?, synced = ?, user_latitude = ?, user_longitude = ?, user_accuracy = ? WHERE LearnerID = ? AND clock_date = ?");

$stmt->bind_param("ssidddis", $currentTime, $contactTime, $isSynced, $userLatitude, $userLongitude, $userAccuracy, $learnerID, $currentDate);
```

**What Changed:**
1. Added `user_latitude`, `user_longitude`, and `user_accuracy` to the UPDATE statement
2. Updated bind_param to include the three GPS coordinate parameters
3. Changed parameter types from "ssiss" to "ssidddis" to handle the double values

**Note:** The GPS coordinates are already being extracted from POST data at the top of the file:
```php
$userLatitude = isset($_POST['user_latitude']) ? floatval($_POST['user_latitude']) : 0.0;
$userLongitude = isset($_POST['user_longitude']) ? floatval($_POST['user_longitude']) : 0.0;
$userAccuracy = isset($_POST['user_accuracy']) ? floatval($_POST['user_accuracy']) : 50.0;
```

## Database Schema

Ensure your `learner_clocking` table has these columns:

```sql
ALTER TABLE learner_clocking 
ADD COLUMN user_latitude DECIMAL(10, 8) DEFAULT 0.0,
ADD COLUMN user_longitude DECIMAL(11, 8) DEFAULT 0.0,
ADD COLUMN user_accuracy DECIMAL(10, 2) DEFAULT 50.0;
```

**Column Details:**
- `user_latitude`: DECIMAL(10, 8) - Stores latitude with 8 decimal places (e.g., -26.12345678)
- `user_longitude`: DECIMAL(11, 8) - Stores longitude with 8 decimal places (e.g., 28.12345678)
- `user_accuracy`: DECIMAL(10, 2) - Stores GPS accuracy in meters (e.g., 15.50)

## Data Flow

### Clock-In Flow:
1. Flutter app gets GPS coordinates (latitude, longitude, accuracy)
2. Sends to `clockin.php` via POST:
   - `user_latitude`: GPS latitude
   - `user_longitude`: GPS longitude
   - `user_accuracy`: GPS accuracy in meters
3. PHP stores coordinates in `learner_clocking` table
4. Returns success response

### Clock-Out Flow:
1. Flutter app gets GPS coordinates (latitude, longitude, accuracy)
2. Sends to `clockout.php` via POST:
   - `user_latitude`: GPS latitude
   - `user_longitude`: GPS longitude
   - `user_accuracy`: GPS accuracy in meters
3. PHP updates the existing record with clock-out time AND GPS coordinates
4. Returns success response with contact time

## Testing the PHP Endpoints

### Test Clock-In:
```bash
curl -X POST https://rlms.rlms.co.za/mobile/clockin.php \
  -d "LearnerID=123" \
  -d "classID=ABC123" \
  -d "user_latitude=-26.123456" \
  -d "user_longitude=28.123456" \
  -d "user_accuracy=15.5" \
  -d "isSynced=0"
```

Expected Response:
```json
{
  "success": true,
  "message": "Clock-in successful",
  "clock_in_time": "2025-10-28 14:30:00",
  "learner_id": "123",
  "clock_out_time": null,
  "contact_time": null
}
```

### Test Clock-Out:
```bash
curl -X POST https://rlms.rlms.co.za/mobile/clockout.php \
  -d "LearnerID=123" \
  -d "classID=ABC123" \
  -d "user_latitude=-26.123456" \
  -d "user_longitude=28.123456" \
  -d "user_accuracy=15.5" \
  -d "isSynced=0"
```

Expected Response:
```json
{
  "success": true,
  "message": "Clock-out successful",
  "clock_in_time": "2025-10-28 14:30:00",
  "clock_out_time": "2025-10-28 18:30:00",
  "contact_time": "04:00:00"
}
```

### Verify Database:
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

Expected Result:
```
LearnerID: 123
clock_date: 2025-10-28
clock_in_time: 2025-10-28 14:30:00
clock_out_time: 2025-10-28 18:30:00
contact_time: 04:00:00
user_latitude: -26.12345600
user_longitude: 28.12345600
user_accuracy: 15.50
```

## Logging

Both PHP files log GPS coordinates:

**Clock-In Log:**
```
2025-10-28 14:30:00 - Clock-in attempt - LearnerID: 123, Source: mobile_app, Data: {
  "class_id": "ABC123",
  "latitude": -26.123456,
  "longitude": 28.123456,
  "accuracy": 15.5,
  "synced": 0
}
```

**Clock-Out Log:**
```
2025-10-28 18:30:00 - Clock-out attempt - LearnerID: 123, Source: mobile_app, Data: {
  "class_id": "ABC123",
  "latitude": -26.123456,
  "longitude": 28.123456,
  "accuracy": 15.5,
  "synced": 0
}
```

## Security Considerations

1. **GPS Spoofing:** While the app enforces geofencing, determined users could potentially spoof GPS coordinates. Consider:
   - Server-side validation of coordinates against known site locations
   - Flagging suspicious patterns (e.g., coordinates jumping large distances)
   - Audit trail review for anomalies

2. **Data Validation:** The PHP files validate:
   - GPS coordinates are floats
   - Default values if coordinates missing (0.0, 0.0)
   - Accuracy defaults to 50.0 meters if not provided

3. **Audit Trail:** All GPS data is logged and stored for:
   - Compliance verification
   - Dispute resolution
   - Pattern analysis

## Deployment Checklist

- [x] Update `php/clockout.php` with GPS coordinate storage
- [ ] Verify database schema has GPS columns
- [ ] Test clock-in endpoint with GPS data
- [ ] Test clock-out endpoint with GPS data
- [ ] Verify GPS data is stored correctly in database
- [ ] Check log files for GPS coordinate logging
- [ ] Deploy to production server
- [ ] Monitor logs for any errors
- [ ] Verify with real device testing

## Troubleshooting

### GPS Coordinates Not Saving
1. Check database schema has the columns
2. Verify POST data includes GPS parameters
3. Check PHP error logs
4. Verify bind_param types match (ssidddis)

### Default Coordinates (0.0, 0.0) Being Stored
1. Check Flutter app is sending GPS data
2. Verify network request includes GPS parameters
3. Check PHP is receiving POST data correctly
4. Review debug logs in `debug_clockin.log` and `debug_clockout.log`

### Database Errors
1. Verify column types are correct (DECIMAL)
2. Check for NULL constraints
3. Verify bind_param parameter count matches SQL placeholders
4. Review MySQL error logs
