# Geofencing Quick Reference Card

## 🎯 What You Need to Update

### 1. Database (REQUIRED)
```sql
ALTER TABLE learner_clocking 
ADD COLUMN user_latitude DECIMAL(10, 8) DEFAULT 0.0,
ADD COLUMN user_longitude DECIMAL(11, 8) DEFAULT 0.0,
ADD COLUMN user_accuracy DECIMAL(10, 2) DEFAULT 50.0;
```

### 2. PHP File (REQUIRED)
**File:** `php/clockout.php`
**Status:** Already updated ✅

### 3. Flutter App (REQUIRED)
**File:** `lib/clock_in_page.dart`
**Status:** Already updated ✅

### 4. Site Coordinates (REQUIRED)
Ensure your `sites` table has valid GPS coordinates:
```sql
UPDATE sites SET 
  latitude = -26.123456,  -- Replace with actual latitude
  longitude = 28.123456   -- Replace with actual longitude
WHERE siteID = 'YOUR_SITE_ID';
```

---

## 🚀 Quick Deploy

```bash
# 1. Update database
mysql -u user -p database < add_gps_columns.sql

# 2. Upload PHP file
scp php/clockout.php server:/path/to/mobile/

# 3. Build Flutter app
flutter build apk --release

# 4. Done!
```

---

## ✅ Quick Test

1. **Within 300m:** Should succeed ✅
2. **Outside 300m:** Should fail with distance ❌
3. **Poor GPS:** Should fail with accuracy error ❌

---

## 🔍 Quick Verify

```sql
-- Check GPS data is being stored
SELECT LearnerID, clock_in_time, user_latitude, user_longitude, user_accuracy
FROM learner_clocking
WHERE clock_date = CURDATE()
ORDER BY clock_in_time DESC
LIMIT 5;
```

---

## ⚙️ Quick Config

**Change radius:** Edit line ~984 in `clock_in_page.dart`
```dart
if (distance > 300) { // Change 300 to desired meters
```

**Change accuracy:** Edit line ~950 in `clock_in_page.dart`
```dart
if (userAccuracy > 50) { // Change 50 to desired meters
```

---

## 🐛 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| GPS shows 0.0, 0.0 | Check permissions & GPS enabled |
| "No site coordinates" | Update sites table with GPS coords |
| Always denied at site | Verify site coordinates are correct |
| GPS too slow | Move to open area, wait for signal |

---

## 📋 Deployment Checklist

- [ ] Run SQL script to add GPS columns
- [ ] Upload updated `clockout.php`
- [ ] Deploy Flutter app
- [ ] Verify site coordinates in database
- [ ] Test clock-in within 300m
- [ ] Test clock-in outside 300m
- [ ] Test clock-out within 300m
- [ ] Test clock-out outside 300m
- [ ] Verify GPS data in database
- [ ] Monitor logs for errors

---

## 📞 Quick Support

**Console logs:** Look for `[GEOFENCE]` prefix
**PHP logs:** Check `debug_clockin.log` and `debug_clockout.log`
**Database:** Verify GPS columns exist and have data

---

## 🎉 Success Indicators

✅ Learners can clock in/out at site
❌ Learners cannot clock in/out remotely
✅ GPS coordinates stored in database
✅ Clear error messages shown
✅ Audit trail complete
