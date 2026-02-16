CREATE TABLE IF NOT EXISTS learner_attendance (
    id INT AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    class_id VARCHAR(50) NOT NULL,
    finance_id VARCHAR(50),
    attendance_date DATE NOT NULL,
    attendance_month INT NOT NULL,
    attendance_year INT NOT NULL,
    marked_by VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_learner (learner_id),
    INDEX idx_class (class_id),
    INDEX idx_date (attendance_date),
    INDEX idx_month_year (attendance_month, attendance_year),
    UNIQUE KEY unique_attendance (learner_id, attendance_date)
);
