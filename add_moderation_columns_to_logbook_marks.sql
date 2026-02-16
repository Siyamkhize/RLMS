-- Add moderation columns to logbook_marks table
-- This script adds columns needed for moderator functionality if they don't already exist

-- Add moderator_status column
ALTER TABLE logbook_marks 
ADD COLUMN IF NOT EXISTS moderator_status VARCHAR(50) DEFAULT NULL 
COMMENT 'Moderation status: upheld or withdrawn';

-- Add moderator_comment column
ALTER TABLE logbook_marks 
ADD COLUMN IF NOT EXISTS moderator_comment TEXT DEFAULT NULL 
COMMENT 'Moderator comment on the assessment';

-- Add moderator_id column
ALTER TABLE logbook_marks 
ADD COLUMN IF NOT EXISTS moderator_id VARCHAR(50) DEFAULT NULL 
COMMENT 'ID of the moderator who reviewed the assessment';

-- Add moderation_date column
ALTER TABLE logbook_marks 
ADD COLUMN IF NOT EXISTS moderation_date TIMESTAMP NULL DEFAULT NULL 
COMMENT 'Date and time when moderation was performed';

-- Add assessor_comment column (if not exists)
ALTER TABLE logbook_marks 
ADD COLUMN IF NOT EXISTS assessor_comment TEXT DEFAULT NULL 
COMMENT 'Assessor comment on the assessment (a_comment)';

-- Add index for faster lookups
ALTER TABLE logbook_marks 
ADD INDEX IF NOT EXISTS idx_learner_unit_standard (learner_id, unit_standard_id);

-- Add index for moderator queries
ALTER TABLE logbook_marks 
ADD INDEX IF NOT EXISTS idx_moderator (moderator_id, moderation_date);

-- Verify the changes
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE, 
    COLUMN_DEFAULT,
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'logbook_marks' 
AND TABLE_SCHEMA = DATABASE()
AND COLUMN_NAME IN (
    'moderator_status', 
    'moderator_comment', 
    'moderator_id', 
    'moderation_date',
    'assessor_comment'
)
ORDER BY ORDINAL_POSITION;
