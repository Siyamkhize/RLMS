  -- Add GPS coordinate columns to learner_clocking table for geofencing
-- Run this script on your database to add the necessary columns

-- Check if columns exist before adding them
-- This prevents errors if columns already exist

-- Add user_latitude column
ALTER TABLE learner_clocking 
ADD COLUMN IF NOT EXISTS user_latitude DECIMAL(10, 8) DEFAULT 0.0 
COMMENT 'GPS latitude coordinate where learner clocked in/out';

-- Add user_longitude column
ALTER TABLE learner_clocking 
ADD COLUMN IF NOT EXISTS user_longitude DECIMAL(11, 8) DEFAULT 0.0 
COMMENT 'GPS longitude coordinate where learner clocked in/out';

-- Add user_accuracy column
ALTER TABLE learner_clocking 
ADD COLUMN IF NOT EXISTS user_accuracy DECIMAL(10, 2) DEFAULT 50.0 
COMMENT 'GPS accuracy in meters at time of clocking';

-- Verify columns were added
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    COLUMN_DEFAULT, 
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'learner_clocking' 
AND COLUMN_NAME IN ('user_latitude', 'user_longitude', 'user_accuracy');

-- Sample query to view GPS data
-- SELECT 
--     LearnerID,
--     clock_date,
--     clock_in_time,
--     clock_out_time,
--     user_latitude,
--     user_longitude,
--     user_accuracy
-- FROM learner_clocking
-- WHERE clock_date = CURDATE()
-- ORDER BY clock_in_time DESC;
