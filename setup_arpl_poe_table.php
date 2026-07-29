<?php
/**
 * Setup ARPL POE Unified Table
 * Creates the unified ARPL table with proper foreign key constraints and indexes
 * Table stores both theory and practical papers with optional rating support
 * 
 * Created: July 7, 2026
 * Last Updated: July 7, 2026
 * Status: PRODUCTION READY
 * 
 * Features:
 * - Foreign key constraint to learnerdetails(LearnerID) with CASCADE delete
 * - Foreign key constraint to facilitator(facilitator_id) with SET NULL
 * - Unique constraint on (learnerID, ofo_number, paper_number, section_type)
 * - Comprehensive indexing for performance
 * - Proper error handling and validation
 */

include_once 'connection.php';

if (!$conn) {
    die('{"status":"error","message":"Database connection failed"}');
}

header('Content-Type: application/json');

// First, try to drop the table if it exists (fresh start)
$dropSQL = "DROP TABLE IF EXISTS arpl_poe";
if (!$conn->query($dropSQL)) {
    echo json_encode([
        'status' => 'warning',
        'message' => 'Could not drop existing table (may not exist): ' . $conn->error
    ]);
}

// Create the table WITH foreign keys
$createSQL = "CREATE TABLE arpl_poe (
    id INT PRIMARY KEY AUTO_INCREMENT,
    learnerID INT NOT NULL,
    ofo_number VARCHAR(50) NOT NULL,
    paper_title VARCHAR(255) NOT NULL,
    paper_number INT NOT NULL,
    section_type ENUM('theory', 'practical') NOT NULL,
    question_count INT DEFAULT 0,
    combined_pdf_path VARCHAR(500),
    file_name VARCHAR(500),
    upload_status ENUM('pending', 'uploaded', 'synced') DEFAULT 'pending',
    rating DECIMAL(5,2) DEFAULT NULL,
    rating_status ENUM('pending_rating', 'rated', 'reviewed') DEFAULT 'pending_rating',
    assessor_id INT,
    assessor_comments TEXT,
    rated_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_arpl_upload (learnerID, ofo_number, paper_number, section_type),
    FOREIGN KEY (learnerID) REFERENCES learnerdetails(learnerID) ON DELETE CASCADE,
    FOREIGN KEY (assessor_id) REFERENCES facilitator(facilitator_id) ON DELETE SET NULL
)";

if ($conn->query($createSQL) === true) {
    // Create indexes
    $indexes = [
        "CREATE INDEX idx_arpl_poe_learner ON arpl_poe(learnerID)",
        "CREATE INDEX idx_arpl_poe_ofo ON arpl_poe(ofo_number)",
        "CREATE INDEX idx_arpl_poe_section ON arpl_poe(section_type)",
        "CREATE INDEX idx_arpl_poe_upload_status ON arpl_poe(upload_status)",
        "CREATE INDEX idx_arpl_poe_rating_status ON arpl_poe(rating_status)",
        "CREATE INDEX idx_arpl_poe_assessor ON arpl_poe(assessor_id)",
        "CREATE INDEX idx_arpl_poe_learner_section ON arpl_poe(learnerID, section_type)"
    ];
    
    $indexStatus = [];
    foreach ($indexes as $idx) {
        if ($conn->query($idx)) {
            $indexStatus[] = "✓ Index created";
        } else {
            if (strpos($conn->error, 'Duplicate key name') !== false) {
                $indexStatus[] = "✓ Index already exists";
            } else {
                $indexStatus[] = "✗ " . $conn->error;
            }
        }
    }
    
    echo json_encode([
        'status' => 'success',
        'message' => 'ARPL POE table created successfully',
        'table_info' => [
            'name' => 'arpl_poe',
            'columns' => 17,
            'has_unique_constraint' => true,
            'has_foreign_keys' => 2,
            'indexes_created' => count($indexStatus)
        ],
        'index_results' => $indexStatus
    ]);
} else {
    echo json_encode([
        'status' => 'error',
        'message' => 'Failed to create table',
        'error' => $conn->error
    ]);
}

$conn->close();
