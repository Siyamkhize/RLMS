-- Add stratification metadata columns to moderator_assignments table
-- This allows fast retrieval without recalculating stratification data

-- Add class_id column (if not exists)
ALTER TABLE moderator_assignments 
ADD COLUMN IF NOT EXISTS class_id VARCHAR(50) NULL 
COMMENT 'Class ID for stratification';

-- Add site_id column
ALTER TABLE moderator_assignments 
ADD COLUMN IF NOT EXISTS site_id VARCHAR(50) NULL 
COMMENT 'Site ID for stratification';

-- Add poe_completeness column
ALTER TABLE moderator_assignments 
ADD COLUMN IF NOT EXISTS poe_completeness VARCHAR(20) NULL 
COMMENT 'Complete/Partial/Incomplete';

-- Add marking_status column
ALTER TABLE moderator_assignments 
ADD COLUMN IF NOT EXISTS marking_status VARCHAR(20) NULL 
COMMENT 'Marked/Not Marked';

-- Add performance_level column
ALTER TABLE moderator_assignments 
ADD COLUMN IF NOT EXISTS performance_level VARCHAR(20) NULL 
COMMENT 'High/Medium/Low/Not Assessed';

-- Add poe_count column
ALTER TABLE moderator_assignments 
ADD COLUMN IF NOT EXISTS poe_count INT(11) DEFAULT 0 
COMMENT 'Number of POE documents';

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_site ON moderator_assignments(site_id);
CREATE INDEX IF NOT EXISTS idx_poe_completeness ON moderator_assignments(poe_completeness);
CREATE INDEX IF NOT EXISTS idx_marking_status ON moderator_assignments(marking_status);
CREATE INDEX IF NOT EXISTS idx_performance_level ON moderator_assignments(performance_level);

-- Verify the changes
DESCRIBE moderator_assignments;
