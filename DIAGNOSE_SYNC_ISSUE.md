# Diagnose Sync Issue - 3 Records Problem

## 🔍 What's Happening

You're getting 3 records because:
1. **Clock-in** → Creates record on server
2. **Clock-out** → Creates ANOTHER record (should UPDATE)
3. **Re-login/sync** → Creates THIRD record (should UPDATE)

## 🎯 Root Causes

### Cause 1: No UNIQUE Constraint on Server
Without this, the database allows multiple records for same learner + date.

### Cause 2: Server PHP Files Not Updated
Your server might still have the OLD PHP files that INSERT instead of UPDATE.

### Cause 3: Sync Logic Issues
The app might be syncing records that are already on the server.

---

## 🔧 Step-by-Step Fix

### Step 1: Check Server Database Constraints

Run this on your **SERVER** database:
```sql
-- Check if UNIQUE constraint exists
SHOW CREATE TABLE learner_clocking;
```

Look for: `UNIQUE KEY unique_learner_date (LearnerID, clock_date)`

**If NOT found, add it:**
```sql
ALTER TABLE learner_clocking 
ADD UNIQUE KEY unique_learner_date (LearnerID, clock_date);
```

---

### Step 2: Verify Server PHP Files

Check what's actually on your server:

```bash
# SSH to your server
ssh user@server

# Check clockin.php
grep "ON DUPLICATE KEY UPDATE" /path/to/mobile/clockin.php

# Check clockout.php  
grep "UPDATE learner_clocking SET clock_out_time" /path/to/mobile/clockout.php
```

**Expected Results:**
- `clockin.php` should have: `ON DUPLICATE KEY UPDATE`
- `clockout.php` should have: `UPDATE learner_clocking SET clock_out_time`

**If NOT found, upload the updated files:**
```bash
scp php/clockin_updated.php user@server:/path/to/mobile/clockin.php
scp php/clockout_updated.php user@server:/path/to/mobile/clockout.php
```

---

### Step 3: Check Server Logs

Look at the server logs to see what's happening:

```bash
# On server
tail -f /path/to/mobile/debug_clockin.log
tail -f /path/to/mobile/debug_clockout.log
```

Then test clock-in/out and watch the logs.

---

### Step 4: Test the Flow

#### Test 1: Clock-In
```bash
curl -X POST https://rlms.rlms.co.za/mobile/clockin.php \
  -d "clock_in=1" \
  -d "LearnerID=999" \
  -d "classID=TEST" \
  -d "user_latitude=-26.123456" \
  -d "user_longitude=28.123456" \
  -d "user_accuracy=15.5" \
  -d "isSynced=1"
```

**Check database:**
```sql
SELECT COUNT(*) FROM learner_clocking WHERE LearnerID=999 AND clock_date=CURDATE();
```
Should show: **1 record**

#### Test 2: Clock-Out
```bash
curl -X POST https://rlms.rlms.co.za/mobile/clockout.php \
  -d "clock_out=1" \
  -d "LearnerID=999" \
  -d "classID=TEST" \
  -d "user_latitude=-26.123456" \
  -d "user_longitude=28.123456" \
  -d "user_accuracy=15.5" \
  -d "isSynced=1"
```

**Check database:**
```sql
SELECT COUNT(*) FROM learner_clocking WHERE LearnerID=999 AND clock_date=CURDATE();
```
Should STILL show: **1 record** (updated, not new)

#### Test 3: Re-Sync
```bash
# Send same clock-in request again
curl -X POST https://rlms.rlms.co.za/mobile/clockin.php \
  -d "clock_in=1" \
  -d "LearnerID=999" \
  -d "classID=TEST" \
  -d "user_latitude=-26.123456" \
  -d "user_longitude=28.123456" \
  -d "user_accuracy=15.5" \
  -d "isSynced=1"
```

**Check database:**
```sql
SELECT COUNT(*) FROM learner_clocking WHERE LearnerID=999 AND clock_date=CURDATE();
```
Should STILL show: **1 record** (updated, not new)

---

## 🐛 Debug: Find Where Duplicates Come From

### Check 1: When Does Each Record Get Created?

Run this query after each step:
```sql
SELECT 
    clocking_id,
    LearnerID,
    clock_date,
    clock_in_time,
    clock_out_time,
    synced,
    'After Clock-In' as step
FROM learner_clocking
WHERE LearnerID = 999 AND clock_date = CURDATE();
```

Do this:
1. Clock-in → Run query → Note clocking_id
2. Clock-out → Run query → Check if same clocking_id or new one
3. Re-login → Run query → Check if same clocking_id or new one

### Check 2: What's in the Logs?

Look for these patterns in `clocking_log` table:
```sql
SELECT 
    log_id,
    learnerID,
    action,
    attempt_time,
    reason
FROM clocking_log
WHERE learnerID = 999
AND DATE(attempt_time) = CURDATE()
ORDER BY attempt_time DESC;
```

This shows every attempt and what happened.

---

## 🔍 Common Issues

### Issue 1: UNIQUE Constraint Not on Server
**Symptom:** Multiple records with same LearnerID + date
**Fix:** Run `ALTER TABLE` on SERVER database

### Issue 2: Old PHP Files on Server
**Symptom:** Clock-out creates new record instead of updating
**Fix:** Upload updated PHP files to server

### Issue 3: Sync Logic Syncing Already-Synced Records
**Symptom:** Records marked synced=1 get synced again
**Fix:** Check Flutter app sync logic

---

## 🎯 Expected Behavior

### Correct Flow:
```
1. Clock-In:
   - App → Server: INSERT or UPDATE
   - Server: Creates/updates 1 record
   - Database: 1 record with clock_in_time

2. Clock-Out:
   - App → Server: UPDATE existing record
   - Server: Updates same record
   - Database: SAME 1 record with clock_out_time

3. Re-Sync:
   - App → Server: UPDATE existing record
   - Server: Updates same record
   - Database: SAME 1 record with synced=1
```

**Result: Only 1 record total!**

---

## 🚨 Emergency: Clean Up Existing Duplicates

If you already have many duplicates:

```sql
-- See all duplicates
SELECT 
    LearnerID, 
    clock_date, 
    COUNT(*) as count,
    GROUP_CONCAT(clocking_id ORDER BY clocking_id) as ids
FROM learner_clocking
GROUP BY LearnerID, clock_date
HAVING count > 1
ORDER BY count DESC;

-- Keep only the most complete record (with clock_out_time)
DELETE FROM learner_clocking
WHERE clocking_id NOT IN (
    SELECT keep_id FROM (
        SELECT 
            MAX(CASE 
                WHEN clock_out_time IS NOT NULL THEN clocking_id
                ELSE clocking_id
            END) as keep_id
        FROM learner_clocking
        GROUP BY LearnerID, clock_date
    ) as subquery
);
```

---

## ✅ Verification Checklist

After applying fixes:

- [ ] UNIQUE constraint exists on server database
- [ ] Server has updated clockin.php with ON DUPLICATE KEY UPDATE
- [ ] Server has updated clockout.php with UPDATE statement
- [ ] Test clock-in creates 1 record
- [ ] Test clock-out updates same record (not creates new)
- [ ] Test re-sync updates same record (not creates new)
- [ ] No duplicates in database

---

## 📊 Quick Check Query

Run this to see the current state:
```sql
SELECT 
    LearnerID,
    clock_date,
    COUNT(*) as record_count,
    GROUP_CONCAT(clocking_id) as ids,
    GROUP_CONCAT(clock_in_time) as clock_ins,
    GROUP_CONCAT(clock_out_time) as clock_outs,
    GROUP_CONCAT(synced) as synced_flags
FROM learner_clocking
WHERE clock_date >= CURDATE() - INTERVAL 1 DAY
GROUP BY LearnerID, clock_date
HAVING record_count > 1
ORDER BY record_count DESC;
```

This shows all duplicates from today and yesterday.

---

## 🎯 Summary

**The 3 fixes you need:**

1. **Add UNIQUE constraint to SERVER database**
   ```sql
   ALTER TABLE learner_clocking ADD UNIQUE KEY unique_learner_date (LearnerID, clock_date);
   ```

2. **Upload updated PHP files to SERVER**
   ```bash
   scp php/clockin_updated.php user@server:/path/to/mobile/clockin.php
   scp php/clockout_updated.php user@server:/path/to/mobile/clockout.php
   ```

3. **Test thoroughly**
   - Clock-in → 1 record
   - Clock-out → SAME record updated
   - Re-sync → SAME record updated

**Do all 3 and the problem will be fixed!** 🚀
