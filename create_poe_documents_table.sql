-- Table for storing scanned POE documents (Portfolio of Evidence)
-- Supports large multi-page documents up to 195 pages

CREATE TABLE IF NOT EXISTS poe_documents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    learner_id VARCHAR(50) NOT NULL,
    learner_name VARCHAR(255) NOT NULL,
    document_type VARCHAR(50) DEFAULT 'POE' COMMENT 'POE, SDP, or other document types',
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size BIGINT NOT NULL COMMENT 'File size in bytes',
    page_count INT DEFAULT 0 COMMENT 'Number of pages in the document',
    mime_type VARCHAR(100) DEFAULT 'application/pdf',
    uploaded_by VARCHAR(100) COMMENT 'Username or ID of person who uploaded',
    upload_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    class_id VARCHAR(50) COMMENT 'Associated class ID',
    site_name VARCHAR(255) COMMENT 'Site where learner is located',
    status VARCHAR(50) DEFAULT 'active' COMMENT 'active, archived, deleted',
    notes TEXT COMMENT 'Additional notes about the document',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_learner_id (learner_id),
    INDEX idx_class_id (class_id),
    INDEX idx_upload_date (upload_date),
    INDEX idx_status (status),
    INDEX idx_document_type (document_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
