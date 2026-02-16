-- Create table for storing pothole checklist form data
CREATE TABLE IF NOT EXISTS pothole_checklists (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    learner_name VARCHAR(255) NOT NULL,
    learner_id_number VARCHAR(50),
    assessor_id VARCHAR(50) NOT NULL,
    assessor_name VARCHAR(255) NOT NULL,
    assessor_reg_number VARCHAR(50),
    venue VARCHAR(255) NOT NULL,
    assessment_date DATE NOT NULL,
    learner_signature TEXT,
    assessor_signature TEXT,
    checklist_items JSON NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_checklist (learner_id, assessor_id, assessment_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add indexes for faster lookups
CREATE INDEX idx_learner_id ON pothole_checklists(learner_id);
CREATE INDEX idx_assessor_id ON pothole_checklists(assessor_id);
CREATE INDEX idx_assessment_date ON pothole_checklists(assessment_date);
