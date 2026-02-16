-- Add moderation columns to assessments table
ALTER TABLE assessments 
ADD COLUMN IF NOT EXISTS moderator_status VARCHAR(20) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_comment TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_id VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderation_date DATETIME DEFAULT NULL;

-- Add moderation columns to logbook_marks table
ALTER TABLE logbook_marks 
ADD COLUMN IF NOT EXISTS moderator_status VARCHAR(20) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_comment TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_id VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderation_date DATETIME DEFAULT NULL;

-- Add moderation columns to pothole_checklist_marks table
ALTER TABLE pothole_checklist_marks 
ADD COLUMN IF NOT EXISTS moderator_status VARCHAR(20) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_comment TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_id VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderation_date DATETIME DEFAULT NULL;

-- Add moderation columns to pothole_checklist_scanned table
ALTER TABLE pothole_checklist_scanned 
ADD COLUMN IF NOT EXISTS moderator_status VARCHAR(20) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_comment TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderator_id VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS moderation_date DATETIME DEFAULT NULL;

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_moderator_status ON assessments(moderator_status);
CREATE INDEX IF NOT EXISTS idx_moderator_status_logbook ON logbook_marks(moderator_status);
CREATE INDEX IF NOT EXISTS idx_moderator_status_pothole ON pothole_checklist_marks(moderator_status);
CREATE INDEX IF NOT EXISTS idx_moderator_status_pothole_scanned ON pothole_checklist_scanned(moderator_status);
