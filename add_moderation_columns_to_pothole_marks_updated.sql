-- Add moderation columns to pothole_checklist_marks table
-- These columns will store the moderator's approval status and comments

-- Add moderator_status column (enum with Upheld/Withdrawn)
ALTER TABLE pothole_checklist_marks 
ADD COLUMN moderator_status ENUM('Upheld', 'Withdrawn') NULL DEFAULT NULL
AFTER marks_scored;

-- Add moderator_comment column for moderator comments
ALTER TABLE pothole_checklist_marks 
ADD COLUMN moderator_comment TEXT NULL DEFAULT NULL
AFTER moderator_status;

-- Add moderator_id to track who moderated
ALTER TABLE pothole_checklist_marks 
ADD COLUMN moderator_id VARCHAR(50) NULL DEFAULT NULL
AFTER moderator_comment;

-- Add moderation_date to track when moderation occurred
ALTER TABLE pothole_checklist_marks 
ADD COLUMN moderation_date DATETIME NULL DEFAULT NULL
AFTER moderator_id;

-- Verify the changes
DESCRIBE pothole_checklist_marks;
