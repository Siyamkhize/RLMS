-- Manual cleanup script for old synced records
-- Run this on your local SQLite database

-- Delete all learner_clocking records from before today
DELETE FROM learner_clocking 
WHERE clock_date < DATE('now');

-- Delete all induction_clocking records from before today  
DELETE FROM induction_clocking
WHERE clock_date < DATE('now');

-- Check remaining records
SELECT 'Learner Clocking - Remaining Records:' as info;
SELECT COUNT(*) as count, clock_date 
FROM learner_clocking 
GROUP BY clock_date 
ORDER BY clock_date;

SELECT 'Induction Clocking - Remaining Records:' as info;
SELECT COUNT(*) as count, clock_date 
FROM induction_clocking 
GROUP BY clock_date 
ORDER BY clock_date;

