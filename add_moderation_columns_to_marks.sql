-- Add moderation columns to marks table for formative/summative assessments

-- Add moderator_status column
ALTER TABLE marks 
ADD COLUMN IF NOT EXISTS moderator_status VARCHAR(20) DEFAULT NULL 
COMMENT 'Moderation status: upheld or withdrawn';

-- Add moderator_comment column
ALTER TABLE marks 
ADD COLUMN IF NOT EXISTS moderator_comment TEXT DEFAULT NULL 
COMMENT 'Moderator comment on the assessment';

-- Add moderator_id column
ALTER TABLE marks 
ADD COLUMN IF NOT EXISTS moderator_id VARCHAR(50) DEFAULT NULL 
COMMENT 'ID of the moderator who performed the moderation';

-- Add moderation_date column
ALTER TABLE marks 
ADD COLUMN IF NOT EXISTS moderation_date DATETIME DEFAULT NULL 
COMMENT 'Date and time when moderation was performed';

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_moderator_status_marks ON marks(moderator_status);

-- Verify the columns were added
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE, 
    COLUMN_DEFAULT, 
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
AND TABLE_NAME = 'marks'
AND COLUMN_NAME IN (
    'moderator_status', 
    'moderator_comment', 
    'moderator_id', 
    'moderation_date',
    'approval_status'
)
ORDER BY ORDINAL_POSITION;
