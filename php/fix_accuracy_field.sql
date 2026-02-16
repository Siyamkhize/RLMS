-- SQL script to fix the accuracy field issue
-- This adds a default value to the accuracy field in the clocking_log table

-- First, let's check the current table structure
-- DESCRIBE clocking_log;

-- Add default value to accuracy field (if it doesn't have one)
ALTER TABLE clocking_log 
MODIFY COLUMN accuracy VARCHAR(50) DEFAULT '0.0';

-- Also make sure other related fields have defaults to prevent similar issues
ALTER TABLE clocking_log 
MODIFY COLUMN user_latitude VARCHAR(50) DEFAULT '0.0',
MODIFY COLUMN user_longitude VARCHAR(50) DEFAULT '0.0',
MODIFY COLUMN site_latitude VARCHAR(50) DEFAULT '0.0',
MODIFY COLUMN site_longitude VARCHAR(50) DEFAULT '0.0';

-- Verify the changes
-- DESCRIBE clocking_log;

-- Test insert to make sure it works
-- INSERT INTO clocking_log (learnerID, action, attempt_time, reason) 
-- VALUES ('TEST', 'test', NOW(), 'Testing default values');

-- Clean up test record
-- DELETE FROM clocking_log WHERE learnerID = 'TEST' AND action = 'test';