-- Add 29 Supplemental Learners to Moderator 77
-- Run this in phpMyAdmin SQL tab

-- This script:
-- 1. Finds learners with POE who are NOT already assigned
-- 2. Randomly selects 29 of them
-- 3. Adds them to moderator_assignments

-- Insert 29 random learners who have POE but are not yet assigned
INSERT INTO moderator_assignments (moderator_id, learner_id, stratum_type, poe_completeness, marking_status, performance_level, poe_count)
SELECT 
    '77' as moderator_id,
    l.LearnerID as learner_id,
    'supplemental' as stratum_type,
    'Unknown' as poe_completeness,
    'Unknown' as marking_status,
    'Unknown' as performance_level,
    0 as poe_count
FROM learnerdetails l
INNER JOIN poe p ON l.LearnerID = p.learnerID
LEFT JOIN moderator_assignments ma ON l.LearnerID = ma.learner_id
WHERE p.filePath IS NOT NULL 
AND p.filePath != ''
AND ma.learner_id IS NULL
AND l.classID != '74'
ORDER BY RAND()
LIMIT 29;

-- Verify the result
SELECT COUNT(*) as total_assignments 
FROM moderator_assignments 
WHERE moderator_id = '77';

-- Expected result: 402 (373 + 29)
