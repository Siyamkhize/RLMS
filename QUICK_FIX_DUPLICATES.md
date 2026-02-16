# Quick Fix for Duplicate Records

## 🔴 Problem
You're getting 3 records per learner per day:
1. Clock-in creates record
2. Clock-out creates another record (should update)
3. Re-sync creates third record (should update)

## ✅ Solution (5 minutes)

### Step 1: Run This SQL (2 minutes)
```bash
mysql -u your_user -p your_database < fix_duplicates.sql
```

Or manually run:
```sql
-- Add UNIQUE constraint to prevent duplicates
ALTER TABLE learner_clocking 
ADD UNIQUE KEY unique_learner_date (LearnerID, clock_date);
```

### Step 2: Deploy Updated PHP (2 minutes)
```bash
# The clockin_updated.php already has the fix
cp php/clockin_updated.php php/clockin.php
scp php/clockin.php user@server:/path/to/mobile/
```

### Step 3: Test (1 minute)
```sql
-- Clock in and out for same learner
-- Then check:
SELECT LearnerID, clock_date, COUNT(*) as count
FROM learner_clocking
WHERE clock_date = CURDATE()
GROUP BY LearnerID, clock_date;
```

Should show count = 1 for each learner!

---

## 🧹 Clean Up Existing Duplicates

If you already have duplicates:

```sql
-- Keep the most complete record (with clock_out_time)
DELETE t1 FROM learner_clocking t1
INNER JOIN (
    SELECT LearnerID, clock_date, 
           MAX(clocking_id) as keep_id
    FROM learner_clocking
    GROUP BY LearnerID, clock_date
    HAVING COUNT(*) > 1
) t2 ON t1.LearnerID = t2.LearnerID 
    AND t1.clock_date = t2.clock_date
    AND t1.clocking_id != t2.keep_id;
```

---

## ✅ Verify Fix

```sql
-- Should return 0 rows (no duplicates)
SELECT LearnerID, clock_date, COUNT(*) as count
FROM learner_clocking
GROUP BY LearnerID, clock_date
HAVING count > 1;
```

---

## 🎯 What This Does

**UNIQUE Constraint:**
- Ensures only ONE record per learner per day
- Database will reject duplicate INSERTs
- Forces INSERT ... ON DUPLICATE KEY UPDATE to work correctly

**Updated PHP:**
- Clock-in uses INSERT ... ON DUPLICATE KEY UPDATE
- If record exists → updates it
- If record doesn't exist → creates it
- No more duplicates!

---

## 📊 Expected Behavior After Fix

### Clock-In:
```
Record 1: LearnerID=123, clock_date=2025-10-28, clock_in_time=08:30, clock_out_time=NULL
```

### Clock-Out (Updates Same Record):
```
Record 1: LearnerID=123, clock_date=2025-10-28, clock_in_time=08:30, clock_out_time=17:30
```

### Re-Sync (Updates Same Record):
```
Record 1: LearnerID=123, clock_date=2025-10-28, clock_in_time=08:30, clock_out_time=17:30, synced=1
```

**Result: Only 1 record!** ✅

---

## 🚨 If You Get an Error

If the ALTER TABLE fails with "Duplicate entry" error:

1. **Clean up duplicates first:**
   ```sql
   -- Run the cleanup script
   mysql -u user -p database < fix_duplicates.sql
   ```

2. **Then add constraint:**
   ```sql
   ALTER TABLE learner_clocking 
   ADD UNIQUE KEY unique_learner_date (LearnerID, clock_date);
   ```

---

## ✅ Done!

After this fix:
- ✅ Only 1 record per learner per day
- ✅ Clock-out updates existing record
- ✅ Re-sync updates existing record
- ✅ No more duplicates!
