# Geofencing Quick Test Guide

## Prerequisites
1. Ensure your `sites` table has valid GPS coordinates
2. Grant location permissions to the app
3. Enable GPS on your test device
4. Have a fingerprint enrolled for test learner

## Quick Test Steps

### Test 1: Clock-In Within Radius (Should SUCCEED)
1. Go to the site location (within 300 meters)
2. Select a learner
3. Click "Clock In" button
4. Scan fingerprint
5. Wait for "Checking location..." message
6. ✅ Should succeed with "Clock-in successful!" message
7. Check console logs for: `[GEOFENCE] ✅ Within 300 meter radius - clocking allowed`

### Test 2: Clock-In Outside Radius (Should FAIL)
1. Move away from site (more than 300 meters)
2. Select a learner
3. Click "Clock In" button
4. Scan fingerprint
5. Wait for "Checking location..." message
6. ❌ Should fail with message: "You are XXX meters away. Must be within 300 meters to clock in/out."
7. Check console logs for: `[GEOFENCE] Distance to site: XXX meters`

### Test 3: Clock-Out Within Radius (Should SUCCEED)
1. Ensure learner is already clocked in
2. Go to the site location (within 300 meters)
3. Select the same learner
4. Click "Clock Out" button
5. Scan fingerprint
6. Wait for "Checking location..." message
7. ✅ Should succeed with "Clock-out successful!" message

### Test 4: Clock-Out Outside Radius (Should FAIL)
1. Ensure learner is already clocked in
2. Move away from site (more than 300 meters)
3. Select the same learner
4. Click "Clock Out" button
5. Scan fingerprint
6. Wait for "Checking location..." message
7. ❌ Should fail with distance error message

### Test 5: Poor GPS Signal (Should FAIL)
1. Disable GPS or go indoors with poor signal
2. Try to clock in/out
3. ❌ Should fail with: "GPS accuracy too low. Please wait for better signal."

## Console Log Indicators

### Successful Geofence Check:
```
[GEOFENCE] Checking location permissions...
[GEOFENCE] Getting current position...
[GEOFENCE] Current position: -26.xxxxx, 28.xxxxx
[GEOFENCE] Accuracy: 15.2 meters
[GEOFENCE] Distance to site: 125.45 meters
[GEOFENCE] Site coordinates: -26.xxxxx, 28.xxxxx
[GEOFENCE] User coordinates: -26.xxxxx, 28.xxxxx
[GEOFENCE] ✅ Within 300 meter radius - clocking allowed
[CLOCK_IN] Location: -26.xxxxx, 28.xxxxx (accuracy: 15.2m)
```

### Failed Geofence Check (Outside Radius):
```
[GEOFENCE] Distance to site: 450.23 meters
[GEOFENCE] Site coordinates: -26.xxxxx, 28.xxxxx
[GEOFENCE] User coordinates: -26.xxxxx, 28.xxxxx
[CLOCK_IN] ❌ Geofence check failed - user not within 300 meters
```

### Failed Geofence Check (Poor Accuracy):
```
[GEOFENCE] Geolocation accuracy too low: 85.5 meters
```

## Database Verification

After successful clock-in/out, check the `learner_clocking` table:
```sql
SELECT LearnerID, clock_in_time, user_latitude, user_longitude, user_accuracy 
FROM learner_clocking 
WHERE LearnerID = 'TEST_LEARNER_ID' 
ORDER BY clock_date DESC 
LIMIT 1;
```

Should show:
- `user_latitude`: Actual GPS latitude (e.g., -26.123456)
- `user_longitude`: Actual GPS longitude (e.g., 28.123456)
- `user_accuracy`: GPS accuracy in meters (e.g., 15.2)

## Troubleshooting

### "Location services are disabled"
- Enable GPS/Location Services on device
- Check device settings

### "Location permissions are denied"
- Grant location permissions to the app
- Check app settings → Permissions → Location

### "No site coordinates found"
- Verify `sites` table has data
- Check `class` table links to correct `siteID`
- Run query: `SELECT c.classID, s.latitude, s.longitude FROM class c JOIN sites s ON c.siteID = s.siteID`

### "Invalid site coordinates"
- Check latitude/longitude values in `sites` table
- Ensure they are valid decimal numbers (not NULL or empty)
- Valid range: Latitude -90 to 90, Longitude -180 to 180

### GPS Takes Too Long
- Move to open area with clear sky view
- Wait for GPS to acquire satellites
- Check device GPS settings

## Expected Behavior Summary

| Scenario | Fingerprint | Location | Expected Result |
|----------|-------------|----------|-----------------|
| Clock-in within 300m | ✅ Match | ✅ Within | ✅ SUCCESS |
| Clock-in outside 300m | ✅ Match | ❌ Outside | ❌ FAIL - Distance error |
| Clock-in poor GPS | ✅ Match | ❌ Poor accuracy | ❌ FAIL - Accuracy error |
| Clock-in no permission | ✅ Match | ❌ No permission | ❌ FAIL - Permission error |
| Clock-out within 300m | ✅ Match | ✅ Within | ✅ SUCCESS |
| Clock-out outside 300m | ✅ Match | ❌ Outside | ❌ FAIL - Distance error |

## Production Deployment Notes

1. **Test with real site coordinates** before deployment
2. **Verify GPS accuracy** at actual site locations
3. **Consider building obstructions** that may affect GPS
4. **Document site coordinates** for each location
5. **Train users** on GPS requirements
6. **Monitor logs** for geofencing issues in production
