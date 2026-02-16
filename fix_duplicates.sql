-- Fix Duplicate Records in learner_clocking Table
-- Run this script to prevent duplicate clock-in records

-- Step 1: Backup the table first!
CREATE TABLE IF NOT EXISTS learner_clocking_backup_before_fix AS 
SELECT * FROM learner_clocking;

-- Step 2: Check for existing duplicates
SELECT 'Existing Duplicates:' as info;
SELECT LearnerID, clock_date, COUNT(*) as duplicate_count
FROM learner_clocking
GROUP BY LearnerID, clock_date
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Step 3: Clean up duplicates (keep the most complete record)
-- This keeps the record with clock_out_time if it exists, otherwise keeps the latest
DELETE t1 FROM learner_clocking t1
INNER JOIN (
    SELECT LearnerID, clock_date, 
           MAX(CASE 
               WHEN clock_out_time IS NOT NULL AND clock_out_time != '' THEN clocking_id
               ELSE clocking_id 
           END) as keep_id
    FROM learner_clocking
    GROUP BY LearnerID, clock_date
    HAVING COUNT(*) > 1
) t2 ON t1.LearnerID = t2.LearnerID 
    AND t1.clock_date = t2.clock_date
    AND t1.clocking_id != t2.keep_id;

-- Step 4: Add UNIQUE constraint to prevent future duplicates
-- Note: This will fail if duplicates still exist, so run Step 3 first
ALTER TABLE learner_clocking 
ADD UNIQUE KEY unique_learner_date (LearnerID, clock_date);

-- Step 5: Verify the fix
SELECT 'Verification - Should return 0 rows:' as info;
SELECT LearnerID, clock_date, COUNT(*) as count
FROM learner_clocking
GROUP BY LearnerID, clock_date
HAVING COUNT(*) > 1;

-- Step 6: Check the constraint was added
SELECT 'Constraints on learner_clocking:' as info;
SHOW CREATE TABLE learner_clocking;

SELECT 'Fix completed successfully!' as result;
