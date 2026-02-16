-- Create table for storing scanned pothole checklist documents
CREATE TABLE IF NOT EXISTS pothole_checklist_scanned_documents (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    assessor_id VARCHAR(50) NOT NULL,
    document_path TEXT NOT NULL,
    assessment_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_learner_assessor_date (learner_id, assessor_id, assessment_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add index for faster lookups
CREATE INDEX idx_learner_id ON pothole_checklist_scanned_documents(learner_id);
CREATE INDEX idx_assessment_date ON pothole_checklist_scanned_documents(assessment_date);
