<?php
require_once 'mobile/connection.php';

echo "╔════════════════════════════════════════════════════════════════════════════╗\n";
echo "║ Creating Bricklayer ARPL Gap Closure Tables                               ║\n";
echo "╚════════════════════════════════════════════════════════════════════════════╝\n\n";

$tables_created = 0;
$errors = [];

// ══════════════════════════════════════════════════════════════════════════════
// 1. CREATE ACCESS RECOMMENDATIONS TABLE
// ══════════════════════════════════════════════════════════════════════════════
echo "Step 1: Creating arplbricklayer_access_recommendation table...\n";

$sql1 = "CREATE TABLE IF NOT EXISTS arplbricklayer_access_recommendation (
    RecommendationID INT(10) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    LearnerID INT(11) NOT NULL,
    ACRID TINYINT(3) UNSIGNED NOT NULL,
    Trade VARCHAR(100) DEFAULT 'bricklayer',
    OFOCode VARCHAR(20) DEFAULT '641201',
    Status VARCHAR(50) NOT NULL DEFAULT '',
    Remarks TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_learner_acr (LearnerID, ACRID),
    INDEX idx_learnerid (LearnerID),
    INDEX idx_status (Status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

if ($conn->query($sql1)) {
    echo "  ✓ Table arplbricklayer_access_recommendation created/verified\n";
    $tables_created++;
} else {
    echo "  ✗ Error: " . $conn->error . "\n";
    $errors[] = "Failed to create arplbricklayer_access_recommendation";
}

echo "\n";

// ══════════════════════════════════════════════════════════════════════════════
// 2. CREATE GAP UNIT STANDARDS TABLE
// ══════════════════════════════════════════════════════════════════════════════
echo "Step 2: Creating arplbricklayer_gap_unit_standards table...\n";

$sql2 = "CREATE TABLE IF NOT EXISTS arplbricklayer_gap_unit_standards (
    id INT(10) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    learner_id INT(11) NOT NULL,
    recommendation_id INT(10) UNSIGNED,
    unit_standard_id VARCHAR(50) NOT NULL,
    unit_standard_name TEXT,
    qualification_id INT(11) NOT NULL DEFAULT 65409,
    ofo_code VARCHAR(20) DEFAULT '641201',
    assigned_date DATE,
    status VARCHAR(50) DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_learner_id (learner_id),
    INDEX idx_recommendation_id (recommendation_id),
    INDEX idx_qualification_id (qualification_id),
    FOREIGN KEY (recommendation_id) REFERENCES arplbricklayer_access_recommendation(RecommendationID) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

if ($conn->query($sql2)) {
    echo "  ✓ Table arplbricklayer_gap_unit_standards created/verified\n";
    $tables_created++;
} else {
    echo "  ✗ Error: " . $conn->error . "\n";
    $errors[] = "Failed to create arplbricklayer_gap_unit_standards";
}

echo "\n";

// ══════════════════════════════════════════════════════════════════════════════
// 3. VERIFY TABLES
// ══════════════════════════════════════════════════════════════════════════════
echo "Step 3: Verifying tables...\n";

$result = $conn->query("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_SCHEMA = DATABASE() 
    AND TABLE_NAME IN ('arplbricklayer_access_recommendation', 'arplbricklayer_gap_unit_standards')
    ORDER BY TABLE_NAME");

if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        echo "  ✓ Verified: " . $row['TABLE_NAME'] . "\n";
    }
} else {
    echo "  ✗ Could not verify tables\n";
}

echo "\n";

// ══════════════════════════════════════════════════════════════════════════════
// 4. SHOW TABLE STRUCTURES
// ══════════════════════════════════════════════════════════════════════════════
echo "Step 4: Access Recommendation Table Structure:\n";
$result = $conn->query("DESCRIBE arplbricklayer_access_recommendation");
if ($result) {
    while ($row = $result->fetch_assoc()) {
        printf("  %-20s %-30s %s\n", $row['Field'], $row['Type'], $row['Null']);
    }
}

echo "\nStep 5: Gap Unit Standards Table Structure:\n";
$result = $conn->query("DESCRIBE arplbricklayer_gap_unit_standards");
if ($result) {
    while ($row = $result->fetch_assoc()) {
        printf("  %-20s %-30s %s\n", $row['Field'], $row['Type'], $row['Null']);
    }
}

echo "\n";

// ══════════════════════════════════════════════════════════════════════════════
// SUMMARY
// ══════════════════════════════════════════════════════════════════════════════
echo "╔════════════════════════════════════════════════════════════════════════════╗\n";
if (count($errors) === 0) {
    echo "║ ✅ SUCCESS: All bricklayer gap closure tables created/verified              ║\n";
} else {
    echo "║ ⚠️  COMPLETED WITH ERRORS:                                                 ║\n";
    foreach ($errors as $error) {
        echo "║   - $error\n";
    }
}
echo "╚════════════════════════════════════════════════════════════════════════════╝\n";

$conn->close();
?>
