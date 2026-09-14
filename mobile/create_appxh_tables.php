<?php
header('Content-Type: application/json');
require_once('connection.php');

$results = [
    'timestamp' => date('Y-m-d H:i:s'),
    'tables_created' => []
];

// 1. Create arpl_gap_analysis_unit_standards table
$sql_gap_analysis = "CREATE TABLE IF NOT EXISTS `arpl_gap_analysis_unit_standards` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `learner_id` INT NOT NULL,
    `unit_standard_id` INT NOT NULL,
    `unit_standard_name` VARCHAR(255),
    `module_code` VARCHAR(50),
    `ofo_code` VARCHAR(20),
    `trade` VARCHAR(100),
    `recommendation_id` INT,
    `assigned_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `completion_date` DATE NULL,
    `status` VARCHAR(50) DEFAULT 'Pending',
    `remarks` TEXT,
    INDEX `idx_learner` (`learner_id`),
    INDEX `idx_unit_standard` (`unit_standard_id`),
    INDEX `idx_recommendation` (`recommendation_id`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci";

if (mysqli_query($conn, $sql_gap_analysis)) {
    $results['tables_created']['arpl_gap_analysis_unit_standards'] = [
        'success' => true,
        'message' => 'Table created successfully'
    ];
} else {
    $results['tables_created']['arpl_gap_analysis_unit_standards'] = [
        'success' => false,
        'error' => mysqli_error($conn)
    ];
}

// 2. Create arpl_trade_test_recommended table
$sql_trade_test = "CREATE TABLE IF NOT EXISTS `arpl_trade_test_recommended` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `learner_id` INT NOT NULL,
    `recommendation_id` INT,
    `ofo_code` VARCHAR(20),
    `trade` VARCHAR(100),
    `recommended_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `test_date` DATE NULL,
    `test_center` VARCHAR(200),
    `test_result` VARCHAR(50),
    `certificate_number` VARCHAR(100),
    `test_status` VARCHAR(50) DEFAULT 'Pending',
    `remarks` TEXT,
    INDEX `idx_learner` (`learner_id`),
    INDEX `idx_recommendation` (`recommendation_id`),
    INDEX `idx_test_status` (`test_status`),
    INDEX `idx_ofo` (`ofo_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci";

if (mysqli_query($conn, $sql_trade_test)) {
    $results['tables_created']['arpl_trade_test_recommended'] = [
        'success' => true,
        'message' => 'Table created successfully'
    ];
} else {
    $results['tables_created']['arpl_trade_test_recommended'] = [
        'success' => false,
        'error' => mysqli_error($conn)
    ];
}

echo json_encode($results, JSON_PRETTY_PRINT);
mysqli_close($conn);
?>
