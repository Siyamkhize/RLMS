-- Add moderation columns to pothole_checklist_marks table
-- These columns will store the moderator's approval status and comments

-- Add approval_status column (enum with Approved/Disapproved)
ALTER TABLE pothole_checklist_marks 
ADD COLUMN approval_status ENUM('Approved', 'Disapproved') NULL DEFAULT NULL
AFTER comments;

-- Add comment column for moderator comments
ALTER TABLE pothole_checklist_marks 
ADD COLUMN comment VARCHAR(256) NULL DEFAULT NULL
AFTER approval_status;

-- Verify the changes
DESCRIBE pothole_checklist_marks;
