-- Optional: Add unique constraint to marks table for better moderation performance
-- This ensures no duplicate records and optimizes ON DUPLICATE KEY UPDATE

-- IMPORTANT: Run this AFTER verifying there are no duplicate records
-- If duplicates exist, clean them up first

-- Step 1: Check for duplicates (run this first)
SELECT learnerID, exercise, type, COUNT(*) as count
FROM marks
GROUP BY learnerID, exercise, type
HAVING count > 1;

-- If the above query returns any rows, you have duplicates that need to be cleaned up first
-- Contact your database administrator to resolve duplicates before proceeding

-- Step 2: Add unique constraint (only if no duplicates found)
ALTER TABLE marks 
ADD UNIQUE KEY unique_moderation (learnerID, exercise, type);

-- Verification: Check that constraint was added
SHOW INDEX FROM marks WHERE Key_name = 'unique_moderation';

-- Expected result: Should show the unique index on (learnerID, exercise, type)
