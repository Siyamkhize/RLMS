-- Fix Moderator 77 Class Allocation
-- This script updates the facilitator table to assign the correct 62 classes to moderator 77
-- EXCLUDES class 74 (testing class) from the allocation

-- Step 1: Check current allocation
SELECT facilitator_id, Name, Surname, classID, role 
FROM facilitator 
WHERE facilitator_id = '77' OR facilitator_id = 77;

-- Step 2: Clear existing testing assignments (optional but recommended)
-- These 4 assignments are all from class 74 (testing class)
DELETE FROM moderator_assignments WHERE moderator_id = '77';

-- Step 3: Update facilitator table with correct 62 classes (EXCLUDING class 74)
-- Classes: 8,9,10,12,13,15,16,18,19,20,21,22,23,24,28,29,30,32,33,34,35,38,41,43,44,46,47,49,51,53,54,56,57,58,59,61,62,63,64,65,66,67,68,69,70,71,72,73,75,76,78,79,81,83,84,85,86,89,91,92,93,97
UPDATE facilitator 
SET classID = '8,9,10,12,13,15,16,18,19,20,21,22,23,24,28,29,30,32,33,34,35,38,41,43,44,46,47,49,51,53,54,56,57,58,59,61,62,63,64,65,66,67,68,69,70,71,72,73,75,76,78,79,81,83,84,85,86,89,91,92,93,97'
WHERE facilitator_id = '77' OR facilitator_id = 77;

-- Step 4: Verify the update
SELECT facilitator_id, Name, Surname, classID, role 
FROM facilitator 
WHERE facilitator_id = '77' OR facilitator_id = 77;

-- Step 5: Verify assignments are cleared
SELECT COUNT(*) as assignment_count 
FROM moderator_assignments 
WHERE moderator_id = '77';

-- Expected results:
-- - facilitator.classID should contain the 62 classes (comma-separated)
-- - moderator_assignments should have 0 records for moderator 77
-- - Ready to run sampling endpoint to create 402 assignments
