-- ========================================
-- DELETE OLD LEARNER_CLOCKING RECORDS
-- (Keep induction_clocking permanently)
-- ========================================

-- This script will:
-- ✅ DELETE synced learner_clocking records (synced=1)
-- ✅ DELETE old learner_clocking records (date < today)
-- ✅ KEEP induction_clocking records (NOT deleted)
-- ✅ KEEP current day unsynced learner_clocking records

-- Step 1: Show what we have BEFORE cleanup
SELECT 'BEFORE CLEANUP:' as status;
SELECT COUNT(*) as learner_clocking_count FROM learner_clocking;
SELECT COUNT(*) as induction_clocking_count FROM induction_clocking;

-- Step 2: DELETE synced learner_clocking records (already on server)
DELETE FROM learner_clocking WHERE synced = 1;

-- Step 3: DELETE old learner_clocking records from previous days
DELETE FROM learner_clocking WHERE clock_date < CURDATE();

-- Step 4: Show what we have AFTER cleanup
SELECT 'AFTER CLEANUP:' as status;
SELECT COUNT(*) as learner_clocking_remaining FROM learner_clocking;
SELECT COUNT(*) as induction_clocking_kept FROM induction_clocking;

-- Step 5: Show what's left (should be only current day unsynced)
SELECT 'REMAINING LEARNER_CLOCKING RECORDS:' as info;
SELECT LearnerID, clock_date, clock_in_time, synced 
FROM learner_clocking 
ORDER BY clock_date DESC 
LIMIT 10;

SELECT 'INDUCTION_CLOCKING (NOT DELETED):' as info;
SELECT COUNT(*) as total_induction_records FROM induction_clocking;
