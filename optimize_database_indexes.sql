-- Database optimization for faster search performance
-- Run these commands to add proper indexes

-- Add indexes for learnerdetails table
ALTER TABLE learnerdetails 
ADD INDEX idx_class_id (classID),
ADD INDEX idx_id_number (IDNumber),
ADD INDEX idx_name_surname (Name, Surname),
ADD INDEX idx_phone (PhoneNumber),
ADD INDEX idx_email (Email),
ADD INDEX idx_synced (synced),
ADD INDEX idx_class_synced (classID, synced),
ADD INDEX idx_search_composite (classID, IDNumber, Name, Surname);

-- Add indexes for bankdetails table
ALTER TABLE bankdetails 
ADD INDEX idx_learner_id (LearnerID);

-- Add indexes for class table
ALTER TABLE class 
ADD INDEX idx_class_id (classID),
ADD INDEX idx_class_name (ClassName);

-- Add indexes for learner_registers table (if exists)
-- ALTER TABLE learner_registers 
-- ADD INDEX idx_learner_id (learner_id),
-- ADD INDEX idx_date (date_created);

-- Optimize table storage
OPTIMIZE TABLE learnerdetails;
OPTIMIZE TABLE bankdetails;
OPTIMIZE TABLE class;

-- Show current indexes to verify
SHOW INDEX FROM learnerdetails;
SHOW INDEX FROM bankdetails;
SHOW INDEX FROM class;