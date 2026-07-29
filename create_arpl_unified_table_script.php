<?php
/**
 * Create ARPL POE Unified Table
 * This script creates the arpl_poe table with theory/practical separation and rating support
 * Run this once to initialize the database
 */

include_once 'connection.php';

if (!$conn) {
    die('Database connection failed');
}

// SQL to create the unified arpl_poe table
$createTableSQL = "
CREATE TABLE IF NOT EXISTS arpl_poe (
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
    
    UNIQUE KEY unique_arpl_upload (learnerID, ofo_number, paper_number, section_type)
);
";

echo "Creating arpl_poe table...\n";

if ($conn->query($createTableSQL) === TRUE) {
    echo "✓ Table created successfully!\n";
    
    // Create indexes
    $indexes = [
        "CREATE INDEX idx_arpl_poe_learner ON arpl_poe(learnerID);",
        "CREATE INDEX idx_arpl_poe_ofo ON arpl_poe(ofo_number);",
        "CREATE INDEX idx_arpl_poe_section ON arpl_poe(section_type);",
        "CREATE INDEX idx_arpl_poe_upload_status ON arpl_poe(upload_status);",
        "CREATE INDEX idx_arpl_poe_rating_status ON arpl_poe(rating_status);",
        "CREATE INDEX idx_arpl_poe_assessor ON arpl_poe(assessor_id);",
        "CREATE INDEX idx_arpl_poe_learner_section ON arpl_poe(learnerID, section_type);"
    ];
    
    echo "\nCreating indexes...\n";
    foreach ($indexes as $index) {
        if ($conn->query($index) === TRUE) {
            echo "✓ Index created\n";
        } else {
            // Index might already exist, which is fine
            if (strpos($conn->error, 'Duplicate key name') === false) {
                echo "✗ Error creating index: " . $conn->error . "\n";
            } else {
                echo "✓ Index already exists\n";
            }
        }
    }
    
    echo "\n✓ Database setup complete!\n";
    echo "\nTable structure:\n";
    echo "- arpl_poe (unified table with theory/practical separation)\n";
    echo "- Stores both theory and practical papers in one table\n";
    echo "- Rating fields (rating, rating_status, assessor_id) for practical papers\n";
    echo "- Prevents duplicate uploads with unique constraint\n";
    
} else {
    if (strpos($conn->error, 'already exists') !== false) {
        echo "✓ Table already exists\n";
    } else {
        echo "✗ Error creating table: " . $conn->error . "\n";
        exit(1);
    }
}

// Verify table structure
echo "\n\nVerifying table structure...\n";
$checkSQL = "DESCRIBE arpl_poe";
$result = $conn->query($checkSQL);

if ($result) {
    echo "\nTable columns:\n";
    while ($row = $result->fetch_assoc()) {
        printf("  %-20s %-20s %-10s\n", $row['Field'], $row['Type'], $row['Null']);
    }
    echo "\n✓ Table verification complete!\n";
} else {
    echo "✗ Error verifying table: " . $conn->error . "\n";
}

$conn->close();
?>
