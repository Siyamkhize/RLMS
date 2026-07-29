<?php
require_once 'connection.php';

echo "Creating missing database tables...\n";
echo "═════════════════════════════════════════════════════\n\n";

// Create Plumbing Activity Ratings table
$sql1 = "CREATE TABLE IF NOT EXISTS `arplappxe_plumbing_activity_ratings` (
    activity_rating_id INT AUTO_INCREMENT PRIMARY KEY,
    learnerID INT NOT NULL,
    ofo_number VARCHAR(20),
    activity_id INT,
    activity_name VARCHAR(255),
    competency_scale_id INT,
    facilitator_id INT,
    rating_date DATE,
    comments TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_learner (learnerID),
    INDEX idx_activity (activity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";

// Create Appeals table
$sql2 = "CREATE TABLE IF NOT EXISTS `arpl_appendix_h` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    learnerID INT NOT NULL,
    ofo_code VARCHAR(20),
    appeal_type VARCHAR(100),
    appeal_date DATE,
    appeal_reason TEXT,
    appeal_outcome VARCHAR(100),
    appeal_response TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_learner (learnerID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";

echo "1. Creating arplappxe_plumbing_activity_ratings... ";
if ($conn->query($sql1)) {
    echo "✓\n";
} else {
    echo "Error: " . $conn->error . "\n";
}

echo "2. Creating arpl_appendix_h... ";
if ($conn->query($sql2)) {
    echo "✓\n";
} else {
    echo "Error: " . $conn->error . "\n";
}

echo "\nVerifying tables created...\n\n";

// Verify both tables exist
$tables = ['arplappxe_plumbing_activity_ratings', 'arpl_appendix_h'];

foreach ($tables as $table) {
    $result = $conn->query("SHOW TABLES LIKE '$table'");
    if ($result && $result->num_rows > 0) {
        $count = $conn->query("SELECT COUNT(*) as cnt FROM `$table`")->fetch_row()[0];
        echo "✓ $table: Created successfully ($count records)\n";
    } else {
        echo "✗ $table: Still missing\n";
    }
}

echo "\n═════════════════════════════════════════════════════\n";
echo "COMPLETE\n";

$conn->close();
?>
