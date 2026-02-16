-- Add stratum_type column to moderator_assignments table
-- This column stores the type of stratification used for the assignment

-- Simple version: Just add the column at the end
ALTER TABLE moderator_assignments 
ADD COLUMN stratum_type VARCHAR(50) NULL 
COMMENT 'Type of stratification used';

-- Verify the column was added
DESCRIBE moderator_assignments;
