<?php
/**
 * Setup Plumber Access Recommendation Table
 * Creates the table if it doesn't exist
 */

require_once __DIR__ . '/connection.php';

echo "=== CREATING PLUMBER ACCESS RECOMMENDATION TABLE ===\n\n";

$sql = "CREATE TABLE IF NOT EXISTS arplplumber_access_recommendation (
    RecommendationID int(10) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
    LearnerID int(11) NOT NULL,
    ACRID tinyint(3) unsigned,
    Trade varchar(100),
    OFOCode varchar(20),
    Status varchar(50),
    Remarks text,
    CreatedAt timestamp DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    KEY idx_learner (LearnerID),
    KEY idx_ofo (OFOCode),
    KEY idx_status (Status),
    KEY idx_acrid (ACRID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

if ($conn->query($sql)) {
    echo "✅ Table created successfully\n\n";
    
    // Add composite index
    $indexSql = "ALTER TABLE arplplumber_access_recommendation ADD INDEX idx_learner_ofo (LearnerID, OFOCode)";
    if ($conn->query($indexSql)) {
        echo "✅ Composite index created successfully\n\n";
    } else {
        echo "⚠ Warning: Could not create composite index (may already exist)\n\n";
    }
    
    // Verify table structure
    echo "--- TABLE STRUCTURE ---\n";
    $result = $conn->query("DESCRIBE arplplumber_access_recommendation");
    while ($row = $result->fetch_assoc()) {
        echo "  - {$row['Field']} ({$row['Type']}) " . ($row['Null'] === 'NO' ? 'NOT NULL' : 'NULL') . 
             ($row['Key'] ? " [{$row['Key']}]" : "") . "\n";
    }
    
    echo "\n✅ SETUP COMPLETE\n";
    echo "   Table: arplplumber_access_recommendation\n";
    echo "   Status: Ready for data insertion\n";
    
} else {
    echo "❌ Error creating table: " . $conn->error . "\n";
}

$conn->close();
?>
