-- SQL script to fix the clocking_log table accuracy field issue
-- This fixes the "Field 'accuracy' doesn't have a default value" error

-- Check current table structure first
-- DESCRIBE clocking_log;

-- Add default values to prevent the error
ALTER TABLE clocking_log 
MODIFY COLUMN accuracy VARCHAR(50) DEFAULT '0.0';

-- Also fix other location fields that might cause similar issues
ALTER TABLE clocking_log 
MODIFY COLUMN user_latitude VARCHAR(50) DEFAULT '0.0',
MODIFY COLUMN user_longitude VARCHAR(50) DEFAULT '0.0',
MODIFY COLUMN site_latitude VARCHAR(50) DEFAULT '0.0',
MODIFY COLUMN site_longitude VARCHAR(50) DEFAULT '0.0';

-- If the columns don't exist, create them with defaults
-- (uncomment these if the columns are missing)
/*
ALTER TABLE clocking_log 
ADD COLUMN IF NOT EXISTS user_latitude VARCHAR(50) DEFAULT '0.0',
ADD COLUMN IF NOT EXISTS user_longitude VARCHAR(50) DEFAULT '0.0',
ADD COLUMN IF NOT EXISTS accuracy VARCHAR(50) DEFAULT '0.0',
ADD COLUMN IF NOT EXISTS site_latitude VARCHAR(50) DEFAULT '0.0',
ADD COLUMN IF NOT EXISTS site_longitude VARCHAR(50) DEFAULT '0.0';
*/

-- Verify the changes
-- DESCRIBE clocking_log;

-- Test that the fix works by inserting a record without location data
-- INSERT INTO clocking_log (learnerID, action, attempt_time, reason) 
-- VALUES ('TEST', 'test', NOW(), 'Testing default values');

-- Check the inserted record
-- SELECT * FROM clocking_log WHERE learnerID = 'TEST' ORDER BY attempt_time DESC LIMIT 1;

-- Clean up test record
-- DELETE FROM clocking_log WHERE learnerID = 'TEST' AND action = 'test';