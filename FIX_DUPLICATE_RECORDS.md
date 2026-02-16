# Fix Duplicate Records Issue

## Problem
When clocking in/out, multiple records are created on the server:
1. Clock-in creates 1st record
2. Clock-out creates 2nd record (should UPDATE, not INSERT)
3. Re-sync creates 3rd record

## Root Cause
The PHP files and database need proper constraints to prevent duplicates.

---

## Solution 1: Add UNIQUE Constraint to Database

### Step 1: Check Current Constraints
```sql
-- Check if UNIQUE constraint exists
SHOW CREATE TABLE learner_clocking;

-- Check for existing duplicates
SELECT LearnerID, clock_date, COUNT(*) as count
FROM learner_clocking
GROUP BY LearnerID, clock_date
HAVING count > 1;
```

### Step 2: Clean Up Existing Duplicates
```sql
-- Backup first!
CREATE TABLE learner_clocking_backup AS SELECT * FROM learner_clocking;

-- Keep only the latest record for each learner per day
DELETE t1 FROM learner_clocking t1
INNER JOIN learner_clocking t2 
WHERE t1.clocking_id < t2.clocking_id 
AND t1.LearnerID = t2.LearnerID 
AND t1.clock_date = t2.clock_date;
```

### Step 3: Add UNIQUE Constraint
```sql
-- Add UNIQUE constraint on LearnerID + clock_date
ALTER TABLE learner_clocking 
ADD UNIQUE KEY unique_learner_date (LearnerID, clock_date);
```

This ensures only ONE record per learner per day!

---

## Solution 2: Fix PHP Clock-In (Already Done)

The `clockin_updated.php` now uses:
```php
INSERT INTO learner_clocking (...) VALUES (...)
ON DUPLICATE KEY UPDATE 
    clock_in_time = VALUES(clock_in_time),
    synced = VALUES(synced),
    user_latitude = VALUES(user_latitude),
    user_longitude = VALUES(user_longitude),
    user_accuracy = VALUES(user_accuracy)
```

This means:
- If record doesn't exist → INSERT new record
- If record exists → UPDATE existing record

---

## Solution 3: Fix PHP Clock-Out

The clock-out should ALWAYS update, never insert. Let me check the current code...

### Current Issue
Clock-out might be trying to INSERT instead of UPDATE.

### Fix
Clock-out should ONLY update existing records:
```php
UPDATE learner_clocking 
SET clock_out_time = ?, 
    contact_time = ?, 
    synced = ?,
    user_latitude = ?,
    user_longitude = ?,
    user_accuracy = ?
WHERE LearnerID = ? 
AND clock_date = ?
```

---

## Solution 4: Fix Sync Logic

The sync should check if record exists on server before inserting.

### Current Flow (WRONG):
```
1. Clock-in → INSERT to server ✅
2. Clock-out → INSERT to server ❌ (should UPDATE)
3. Re-sync → INSERT to server ❌ (should UPDATE)
```

### Correct Flow:
```
1. Clock-in → INSERT or UPDATE on server ✅
2. Clock-out → UPDATE existing record ✅
3. Re-sync → UPDATE existing record ✅
```

---

## Quick Fix Steps

### Step 1: Add UNIQUE Constraint
```sql
-- This is the most important fix!
ALTER TABLE learner_clocking 
ADD UNIQUE KEY unique_learner_date (LearnerID, clock_date);
```

### Step 2: Deploy Updated PHP Files
The `clockin_updated.php` already has the fix. Just deploy it:
```bash
cp php/clockin_updated.php php/clockin.php
scp php/clockin.php user@server:/path/to/mobile/
```

### Step 3: Test
```bash
# Test clock-in
curl -X POST https://your-server/mobile/clockin.php \
  -d "clock_in=1" \
  -d "LearnerID=999" \
  -d "classID=TEST" \
  -d "user_latitude=-26.123456" \
  -d "user_longitude=28.123456" \
  -d "user_accuracy=15.5" \
  -d "isSynced=1"

# Test clock-out
curl -X POST https://your-server/mobile/clockout.php \
  -d "clock_out=1" \
  -d "LearnerID=999" \
  -d "classID=TEST" \
  -d "user_latitude=-26.123456" \
  -d "user_longitude=28.123456" \
  -d "user_accuracy=15.5" \
  -d "isSynced=1"

# Check for duplicates
mysql -u user -p database -e "SELECT LearnerID, clock_date, COUNT(*) FROM learner_clocking WHERE LearnerID=999 GROUP BY LearnerID, clock_date;"
```

---

## Verify Fix

### Check 1: No Duplicates
```sql
SELECT LearnerID, clock_date, COUNT(*) as count
FROM learner_clocking
WHERE clock_date = CURDATE()
GROUP BY LearnerID, clock_date
HAVING count > 1;
```
Should return 0 rows.

### Check 2: Clock-Out Updates Same Record
```sql
-- Clock in
-- Then clock out
-- Then check:
SELECT clocking_id, LearnerID, clock_date, clock_in_time, clock_out_time
FROM learner_clocking
WHERE LearnerID = 999
AND clock_date = CURDATE();
```
Should show only 1 record with both clock_in_time AND clock_out_time.

### Check 3: Re-Sync Updates Same Record
```sql
-- After re-syncing, check:
SELECT clocking_id, LearnerID, clock_date, synced
FROM learner_clocking
WHERE LearnerID = 999
AND clock_date = CURDATE();
```
Should still show only 1 record with synced=1.

---

## Root Cause Analysis

### Why This Happens

1. **No UNIQUE Constraint**
   - Database allows multiple records for same learner + date
   - Nothing prevents duplicates

2. **Clock-Out Logic**
   - If clock-out doesn't find existing record, it might INSERT
   - Should always UPDATE existing record

3. **Sync Logic**
   - Sync might INSERT instead of checking if record exists
   - Should use INSERT ... ON DUPLICATE KEY UPDATE

---

## Prevention

With the UNIQUE constraint in place:
- ✅ Database will reject duplicate INSERTs
- ✅ INSERT ... ON DUPLICATE KEY UPDATE will work correctly
- ✅ Only one record per learner per day guaranteed

---

## Testing Checklist

- [ ] Add UNIQUE constraint to database
- [ ] Deploy updated clockin.php
- [ ] Test clock-in → Should create 1 record
- [ ] Test clock-out → Should update same record (not create new)
- [ ] Test re-sync → Should update same record (not create new)
- [ ] Verify only 1 record exists per learner per day
- [ ] Check synced flag is set correctly

---

## Emergency Cleanup

If you already have duplicates:

```sql
-- Find duplicates
SELECT LearnerID, clock_date, COUNT(*) as count, 
       GROUP_CONCAT(clocking_id ORDER BY clocking_id) as ids
FROM learner_clocking
GROUP BY LearnerID, clock_date
HAVING count > 1;

-- For each duplicate, keep the one with the most complete data
-- (has both clock_in_time AND clock_out_time)
DELETE FROM learner_clocking
WHERE clocking_id IN (
    SELECT clocking_id FROM (
        SELECT t1.clocking_id
        FROM learner_clocking t1
        INNER JOIN (
            SELECT LearnerID, clock_date, 
                   MAX(CASE WHEN clock_out_time IS NOT NULL THEN clocking_id END) as keep_id
            FROM learner_clocking
            GROUP BY LearnerID, clock_date
            HAVING COUNT(*) > 1
        ) t2 ON t1.LearnerID = t2.LearnerID 
            AND t1.clock_date = t2.clock_date
        WHERE t1.clocking_id != t2.keep_id
    ) as subquery
);
```

---

## Summary

**The Fix:**
1. Add UNIQUE constraint: `ALTER TABLE learner_clocking ADD UNIQUE KEY unique_learner_date (LearnerID, clock_date);`
2. Deploy updated PHP files (already fixed)
3. Test thoroughly

**Result:**
- ✅ Only 1 record per learner per day
- ✅ Clock-out updates existing record
- ✅ Re-sync updates existing record
- ✅ No more duplicates!
