-- SQL script to create the device_logs table for centralized logging
-- Run this in your MySQL database before using the collect_logs.php script

CREATE TABLE IF NOT EXISTS device_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    device_model VARCHAR(255),
    app_version VARCHAR(50),
    timestamp DATETIME,
    logs LONGTEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_timestamp (device_id, timestamp),
    INDEX idx_timestamp (timestamp)
);

-- Optional: Add some test data to verify the table works
-- INSERT INTO device_logs (device_id, device_model, app_version, timestamp, logs) 
-- VALUES ('test-device-001', 'Samsung Galaxy', '1.0.0', NOW(), 'Test log entry');

-- Verify table creation
-- SELECT * FROM device_logs LIMIT 5;