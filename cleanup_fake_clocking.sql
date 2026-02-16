-- cleanup_fake_clocking.sql
-- Remove all fake clock-ins and clock-outs from the database

-- Set timezone to South African time
SET time_zone = '+02:00';

-- 1. Remove all records with suspicious clock-in times (00:29-00:30 range)
-- These are the batch auto-clocking records that happened around 00:29:39-00:30:24
DELETE FROM learner_clocking 
WHERE clock_in_time LIKE '00:2%' 
AND clock_in_time LIKE '%:3%'
AND clock_out_time IS NULL
AND contact_time IS NULL;

-- 2. Remove records with empty or invalid clock-in times
DELETE FROM learner_clocking 
WHERE clock_in_time IS NULL 
OR clock_in_time = '' 
OR clock_in_time = 'NULL'
OR clock_in_time = '0000-00-00 00:00:00';

-- 3. Remove records that have clock-in but no clock-out and were created in suspicious timeframes
DELETE FROM learner_clocking 
WHERE clock_in_time IS NOT NULL 
AND clock_in_time != ''
AND clock_out_time IS NULL
AND contact_time IS NULL
AND (
    clock_in_time LIKE '00:2%' 
    OR clock_in_time LIKE '00:3%'
    OR clock_in_time LIKE '00:4%'
);

-- 4. Remove duplicate records (same learner, same date, multiple clock-ins)
DELETE lc1 FROM learner_clocking lc1
INNER JOIN learner_clocking lc2 
WHERE lc1.clocking_id > lc2.clocking_id 
AND lc1.LearnerID = lc2.LearnerID 
AND lc1.clock_date = lc2.clock_date
AND lc1.clock_in_time = lc2.clock_in_time;

-- 5. Show remaining records for today
SELECT 
    COUNT(*) as remaining_records,
    MIN(clock_in_time) as earliest_clock_in,
    MAX(clock_in_time) as latest_clock_in
FROM learner_clocking 
WHERE clock_date = CURDATE();

-- 6. Show all remaining records for today (for verification)
SELECT 
    clocking_id,
    LearnerID,
    clock_date,
    clock_in_time,
    clock_out_time,
    contact_time,
    synced
FROM learner_clocking 
WHERE clock_date = CURDATE()
ORDER BY clock_in_time;
