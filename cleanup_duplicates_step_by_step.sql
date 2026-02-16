-- Step-by-Step Cleanup of Duplicate Records
-- Run each step one at a time

-- ============================================
-- STEP 1: Backup your data (IMPORTANT!)
-- ============================================
CREATE TABLE IF NOT EXISTS learner_clocking_backup_20251028 AS 
SELECT * FROM learner_clocking;

SELECT 'Backup created!' as status;

-- ============================================
-- STEP 2: Find all duplicates
-- ============================================
SELECT 'Duplicates found:' as info;
SELECT 
    LearnerID, 
    clock_date, 
    COUNT(*) as duplicate_count,
    GROUP_CONCAT(clocking_id ORDER BY clocking_id) as all_ids
FROM learner_clocking
GROUP BY LearnerID, clock_date
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, LearnerID, clock_date;

-- ============================================
-- STEP 3: Preview which records will be kept
-- ============================================
SELECT 'Records that will be KEPT (most complete):' as info;
SELECT 
    t1.clocking_id,
    t1.LearnerID,
    t1.clock_date,
    t1.clock_in_time,
    t1.clock_out_time,
    t1.contact_time,
    t1.synced,
    'KEEP' as action
FROM learner_clocking t1
INNER JOIN (
    SELECT 
        LearnerID, 
        clock_date,
        MAX(CASE 
            -- Prefer record with clock_out_time
            WHEN clock_out_time IS NOT NULL AND clock_out_time != '' THEN clocking_id * 1000000
            -- Then prefer synced records
            WHEN synced = 1 THEN clocking_id * 1000
            -- Otherwise just keep the latest
            ELSE clocking_id
        END) as best_id_score
    FROM learner_clocking
    GROUP BY LearnerID, clock_date
    HAVING COUNT(*) > 1
) t2 ON t1.LearnerID = t2.LearnerID 
    AND t1.clock_date = t2.clock_date
WHERE (CASE 
    WHEN t1.clock_out_time IS NOT NULL AND t1.clock_out_time != '' THEN t1.clocking_id * 1000000
    WHEN t1.synced = 1 THEN t1.clocking_id * 1000
    ELSE t1.clocking_id
END) = t2.best_id_score
ORDER BY t1.LearnerID, t1.clock_date;

-- ============================================
-- STEP 4: Preview which records will be deleted
-- ============================================
SELECT 'Records that will be DELETED:' as info;
SELECT 
    t1.clocking_id,
    t1.LearnerID,
    t1.clock_date,
    t1.clock_in_time,
    t1.clock_out_time,
    t1.contact_time,
    t1.synced,
    'DELETE' as action
FROM learner_clocking t1
INNER JOIN (
    SELECT 
        LearnerID, 
        clock_date,
        MAX(CASE 
            WHEN clock_out_time IS NOT NULL AND clock_out_time != '' THEN clocking_id * 1000000
            WHEN synced = 1 THEN clocking_id * 1000
            ELSE clocking_id
        END) as best_id_score
    FROM learner_clocking
    GROUP BY LearnerID, clock_date
    HAVING COUNT(*) > 1
) t2 ON t1.LearnerID = t2.LearnerID 
    AND t1.clock_date = t2.clock_date
WHERE (CASE 
    WHEN t1.clock_out_time IS NOT NULL AND t1.clock_out_time != '' THEN t1.clocking_id * 1000000
    WHEN t1.synced = 1 THEN t1.clocking_id * 1000
    ELSE t1.clocking_id
END) != t2.best_id_score
ORDER BY t1.LearnerID, t1.clock_date;

-- ============================================
-- STEP 5: Delete duplicates (keeps best record)
-- ============================================
-- REVIEW THE PREVIEW ABOVE FIRST!
-- If it looks correct, run this:

DELETE t1 FROM learner_clocking t1
INNER JOIN (
    SELECT 
        LearnerID, 
        clock_date,
        MAX(CASE 
            -- Prefer record with clock_out_time
            WHEN clock_out_time IS NOT NULL AND clock_out_time != '' THEN clocking_id * 1000000
            -- Then prefer synced records
            WHEN synced = 1 THEN clocking_id * 1000
            -- Otherwise just keep the latest
            ELSE clocking_id
        END) as best_id_score
    FROM learner_clocking
    GROUP BY LearnerID, clock_date
    HAVING COUNT(*) > 1
) t2 ON t1.LearnerID = t2.LearnerID 
    AND t1.clock_date = t2.clock_date
WHERE (CASE 
    WHEN t1.clock_out_time IS NOT NULL AND t1.clock_out_time != '' THEN t1.clocking_id * 1000000
    WHEN t1.synced = 1 THEN t1.clocking_id * 1000
    ELSE t1.clocking_id
END) != t2.best_id_score;

SELECT 'Duplicates deleted!' as status;

-- ============================================
-- STEP 6: Verify no duplicates remain
-- ============================================
SELECT 'Verification - should return 0 rows:' as info;
SELECT 
    LearnerID, 
    clock_date, 
    COUNT(*) as count
FROM learner_clocking
GROUP BY LearnerID, clock_date
HAVING COUNT(*) > 1;

-- ============================================
-- STEP 7: Add UNIQUE constraint
-- ============================================
ALTER TABLE learner_clocking 
ADD UNIQUE KEY unique_learner_date (LearnerID, clock_date);

SELECT 'UNIQUE constraint added successfully!' as status;

-- ============================================
-- STEP 8: Final verification
-- ============================================
SHOW CREATE TABLE learner_clocking;

SELECT 'Cleanup complete! No more duplicates possible.' as final_status;
