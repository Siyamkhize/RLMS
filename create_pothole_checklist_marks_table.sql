-- Create table for storing pothole checklist marks
CREATE TABLE IF NOT EXISTS pothole_checklist_marks (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    assessor_id VARCHAR(50) NOT NULL,
    assessment_date DATE NOT NULL,
    marks INT(3) NOT NULL,
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_mark (learner_id, assessor_id, assessment_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add indexes for faster lookups
CREATE INDEX idx_learner_id ON pothole_checklist_marks(learner_id);
CREATE INDEX idx_assessor_id ON pothole_checklist_marks(assessor_id);
CREATE INDEX idx_assessment_date ON pothole_checklist_marks(assessment_date);
