<?php
/**
 * Gap Analysis Tables Setup Script
 * Creates the three tables needed for ARPL Gap Closure Report
 * 
 * Usage: php setup_gap_analysis_tables.php
 * 
 * Database: rlmsrlmsco_ezxcmacd_rlms
 * Tables:
 * - gap_analysis_report (master tasks)
 * - gap_analysis_submissions (main records)
 * - gap_analysis_submission_items (task ratings)
 */

// ============================================================
// DATABASE CONNECTION
// ============================================================
require_once __DIR__ . '/connection.php';

if (!$conn) {
    die("❌ Database connection failed: " . mysqli_connect_error());
}

echo "✓ Connected to database successfully\n\n";

// ============================================================
// TABLE 1: gap_analysis_report
// ============================================================
echo "Creating gap_analysis_report table...\n";
$sql1 = "
CREATE TABLE IF NOT EXISTS `gap_analysis_report` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `TaskID` INT NOT NULL UNIQUE,
  `TaskNo` INT NOT NULL,
  `TaskName` VARCHAR(500) NOT NULL,
  `AssessmentMethod` VARCHAR(100),
  `TradeID` INT NOT NULL,
  `Description` TEXT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY `idx_trade_id` (`TradeID`),
  KEY `idx_task_number` (`TaskNo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
";

if ($conn->query($sql1)) {
    echo "✓ gap_analysis_report table created/verified\n";
} else {
    echo "❌ Error creating gap_analysis_report: " . $conn->error . "\n";
}

// ============================================================
// TABLE 2: gap_analysis_submissions
// ============================================================
echo "\nCreating gap_analysis_submissions table...\n";
$sql2 = "
CREATE TABLE IF NOT EXISTS `gap_analysis_submissions` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `submission_id` INT,
  `learner_id` INT NOT NULL,
  `trade_id` INT NOT NULL,
  `assessor_name` VARCHAR(255),
  `assessor_no` VARCHAR(100),
  `comments` LONGTEXT,
  `assess_date` DATE,
  `status` VARCHAR(50) DEFAULT 'Pending',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY `idx_learner_id` (`learner_id`),
  KEY `idx_trade_id` (`trade_id`),
  KEY `idx_created_at` (`created_at`),
  UNIQUE KEY `uq_learner_trade_date` (`learner_id`, `trade_id`, `assess_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
";

if ($conn->query($sql2)) {
    echo "✓ gap_analysis_submissions table created/verified\n";
} else {
    echo "❌ Error creating gap_analysis_submissions: " . $conn->error . "\n";
}

// ============================================================
// TABLE 3: gap_analysis_submission_items
// ============================================================
echo "\nCreating gap_analysis_submission_items table...\n";
$sql3 = "
CREATE TABLE IF NOT EXISTS `gap_analysis_submission_items` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `submission_id` INT NOT NULL,
  `task_id` INT NOT NULL,
  `rating` VARCHAR(50),
  `comments` TEXT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY `idx_submission_id` (`submission_id`),
  KEY `idx_task_id` (`task_id`),
  UNIQUE KEY `uq_submission_task` (`submission_id`, `task_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
";

if ($conn->query($sql3)) {
    echo "✓ gap_analysis_submission_items table created/verified\n";
    
    // Try to add foreign key constraint
    $fk_sql = "ALTER TABLE `gap_analysis_submission_items` 
               ADD CONSTRAINT `fk_submission_items_submission` 
               FOREIGN KEY (`submission_id`) 
               REFERENCES `gap_analysis_submissions` (`id`) 
               ON DELETE CASCADE";
    if ($conn->query($fk_sql)) {
        echo "✓ Foreign key constraint added\n";
    } else {
        // Non-critical error, table still created
        echo "⚠ Could not add foreign key (non-critical): " . $conn->error . "\n";
    }
} else {
    echo "❌ Error creating gap_analysis_submission_items: " . $conn->error . "\n";
}

// ============================================================
// INSERT SAMPLE DATA
// ============================================================
echo "\n" . str_repeat("=", 60) . "\n";
echo "INSERTING SAMPLE DATA\n";
echo str_repeat("=", 60) . "\n";

// Sample tasks for Electrician (TradeID = 1, assuming it exists in your trades table)
echo "\nInserting Electrician trade tasks...\n";
$electrician_tasks = [
    [1, 1, 'Safety Awareness and Compliance', 'Interview', 1],
    [2, 2, 'Electrical Circuit Analysis', 'Practical', 1],
    [3, 3, 'Cable Installation and Termination', 'Practical', 1],
    [4, 4, 'Switchgear and Protection Devices', 'Practical', 1],
    [5, 5, 'Wiring Systems and Distribution', 'Interview', 1],
    [6, 6, 'Testing and Commissioning', 'Practical', 1],
    [7, 7, 'Compliance with SANS Codes', 'Written', 1],
    [8, 8, 'Problem-Solving and Diagnostics', 'Practical', 1],
];

$inserted_electrician = 0;
foreach ($electrician_tasks as $task) {
    $sql = "INSERT IGNORE INTO gap_analysis_report 
            (TaskID, TaskNo, TaskName, AssessmentMethod, TradeID) 
            VALUES (?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    if ($stmt) {
        $stmt->bind_param("iissi", $task[0], $task[1], $task[2], $task[3], $task[4]);
        if ($stmt->execute()) {
            if ($stmt->affected_rows > 0) {
                $inserted_electrician++;
            }
        }
        $stmt->close();
    }
}
echo "✓ Inserted $inserted_electrician Electrician tasks\n";

// Sample tasks for Bricklaying (TradeID = 2)
echo "\nInserting Bricklaying trade tasks...\n";
$bricklaying_tasks = [
    [101, 1, 'Brick Bonding Patterns', 'Practical', 2],
    [102, 2, 'Mortar Preparation and Application', 'Practical', 2],
    [103, 3, 'Wall Construction Techniques', 'Practical', 2],
    [104, 4, 'Cavity Wall Construction', 'Practical', 2],
    [105, 5, 'Safety on Site', 'Interview', 2],
    [106, 6, 'Quality Control and Inspection', 'Interview', 2],
    [107, 7, 'Building Regulations Compliance', 'Written', 2],
    [108, 8, 'Material Handling and Storage', 'Observation', 2],
];

$inserted_bricklaying = 0;
foreach ($bricklaying_tasks as $task) {
    $sql = "INSERT IGNORE INTO gap_analysis_report 
            (TaskID, TaskNo, TaskName, AssessmentMethod, TradeID) 
            VALUES (?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    if ($stmt) {
        $stmt->bind_param("iissi", $task[0], $task[1], $task[2], $task[3], $task[4]);
        if ($stmt->execute()) {
            if ($stmt->affected_rows > 0) {
                $inserted_bricklaying++;
            }
        }
        $stmt->close();
    }
}
echo "✓ Inserted $inserted_bricklaying Bricklaying tasks\n";

// Sample tasks for Plumbing (TradeID = 3)
echo "\nInserting Plumbing trade tasks...\n";
$plumbing_tasks = [
    [201, 1, 'Water Supply System Installation', 'Practical', 3],
    [202, 2, 'Drainage System Installation', 'Practical', 3],
    [203, 3, 'Sanitary Ware Installation', 'Practical', 3],
    [204, 4, 'Pipe Joining and Fitting Techniques', 'Practical', 3],
    [205, 5, 'Hot Water System Installation', 'Practical', 3],
    [206, 6, 'Safety and Health Standards', 'Interview', 3],
    [207, 7, 'SANS Codes and Regulations', 'Written', 3],
    [208, 8, 'Testing and Commissioning', 'Practical', 3],
];

$inserted_plumbing = 0;
foreach ($plumbing_tasks as $task) {
    $sql = "INSERT IGNORE INTO gap_analysis_report 
            (TaskID, TaskNo, TaskName, AssessmentMethod, TradeID) 
            VALUES (?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    if ($stmt) {
        $stmt->bind_param("iissi", $task[0], $task[1], $task[2], $task[3], $task[4]);
        if ($stmt->execute()) {
            if ($stmt->affected_rows > 0) {
                $inserted_plumbing++;
            }
        }
        $stmt->close();
    }
}
echo "✓ Inserted $inserted_plumbing Plumbing tasks\n";

// ============================================================
// VERIFY TABLE CONTENTS
// ============================================================
echo "\n" . str_repeat("=", 60) . "\n";
echo "VERIFICATION\n";
echo str_repeat("=", 60) . "\n";

$result = $conn->query("SELECT COUNT(*) as count FROM gap_analysis_report");
if ($result) {
    $row = $result->fetch_assoc();
    echo "\n✓ Total gap_analysis_report records: " . $row['count'] . "\n";
}

$result = $conn->query("SELECT COUNT(*) as count FROM gap_analysis_submissions");
if ($result) {
    $row = $result->fetch_assoc();
    echo "✓ Total gap_analysis_submissions records: " . $row['count'] . "\n";
}

$result = $conn->query("SELECT COUNT(*) as count FROM gap_analysis_submission_items");
if ($result) {
    $row = $result->fetch_assoc();
    echo "✓ Total gap_analysis_submission_items records: " . $row['count'] . "\n";
}

// Show task distribution by trade
echo "\nTask Distribution by Trade:\n";
$result = $conn->query("
    SELECT TradeID, COUNT(*) as task_count 
    FROM gap_analysis_report 
    GROUP BY TradeID 
    ORDER BY TradeID
");

if ($result) {
    while ($row = $result->fetch_assoc()) {
        $trade_names = [1 => 'Electrician', 2 => 'Bricklaying', 3 => 'Plumbing'];
        $trade_name = $trade_names[$row['TradeID']] ?? 'Unknown';
        echo "  - TradeID {$row['TradeID']} ($trade_name): {$row['task_count']} tasks\n";
    }
}

// ============================================================
// COMPLETION MESSAGE
// ============================================================
echo "\n" . str_repeat("=", 60) . "\n";
echo "✅ GAP ANALYSIS TABLES SETUP COMPLETE\n";
echo str_repeat("=", 60) . "\n";
echo "\nTables created:\n";
echo "  1. gap_analysis_report - Master task definitions\n";
echo "  2. gap_analysis_submissions - Main submission records\n";
echo "  3. gap_analysis_submission_items - Task ratings\n";
echo "\nReady for ARPL Gap Closure Report integration!\n";

$conn->close();
?>
