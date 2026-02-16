-- Create work_experience table for storing learner work history
CREATE TABLE IF NOT EXISTS work_experience (
    id INT AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    employer_name VARCHAR(255) NOT NULL,
    position_held VARCHAR(255) NOT NULL,
    period_from DATE NOT NULL,
    period_to DATE NOT NULL,
    responsibilities TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    synced TINYINT(1) DEFAULT 1,
    INDEX idx_learner_id (learner_id),
    INDEX idx_period_from (period_from)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
