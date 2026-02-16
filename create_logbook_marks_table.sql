-- Create table for storing LogBook unit standard marks
CREATE TABLE IF NOT EXISTS logbook_marks (
    id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    unit_standard_id VARCHAR(50) NOT NULL,
    assessor_id VARCHAR(50) NOT NULL,
    marks INT(11) NOT NULL,
    assessment_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_marking (learner_id, unit_standard_id, assessor_id, assessment_date),
    INDEX idx_learner (learner_id),
    INDEX idx_unit_standard (unit_standard_id),
    INDEX idx_assessor (assessor_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
