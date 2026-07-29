<?php
require_once 'web/connection.php';

echo "=== Creating Missing ARPL Appendix Tables ===\n\n";

// APPENDIX A
$sql_a = "CREATE TABLE IF NOT EXISTS arpl_appendix_a (
  id INT AUTO_INCREMENT PRIMARY KEY,
  learnerID INT NOT NULL,
  ofo_number VARCHAR(10) NOT NULL,
  specialization VARCHAR(255) DEFAULT NULL,
  postal_address1 VARCHAR(255) DEFAULT NULL,
  postal_address2 VARCHAR(255) DEFAULT NULL,
  postal_code VARCHAR(10) DEFAULT NULL,
  fax_number VARCHAR(20) DEFAULT NULL,
  currently_employed ENUM('yes','no') DEFAULT NULL,
  self_employed ENUM('yes','no') DEFAULT NULL,
  current_employer VARCHAR(255) DEFAULT NULL,
  position_job_title VARCHAR(255) DEFAULT NULL,
  employer_address TEXT DEFAULT NULL,
  reference VARCHAR(255) DEFAULT NULL,
  employer_tel VARCHAR(20) DEFAULT NULL,
  employer_fax VARCHAR(20) DEFAULT NULL,
  employer_cell VARCHAR(20) DEFAULT NULL,
  employer_email VARCHAR(255) DEFAULT NULL,
  employment_history JSON DEFAULT NULL,
  candidate_signature VARCHAR(255) DEFAULT NULL,
  signature_date DATE DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_learner_ofo (learnerID, ofo_number),
  INDEX idx_learner (learnerID),
  INDEX idx_ofo (ofo_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;";

// APPENDIX C
$sql_c = "CREATE TABLE IF NOT EXISTS arpl_appendix_c (
  id INT AUTO_INCREMENT PRIMARY KEY,
  learnerID INT NOT NULL,
  ofo_number VARCHAR(10) NOT NULL,
  curriculum_overview TEXT DEFAULT NULL,
  module_summary TEXT DEFAULT NULL,
  learning_outcomes TEXT DEFAULT NULL,
  additional_notes TEXT DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_learner_ofo (learnerID, ofo_number),
  INDEX idx_learner (learnerID),
  INDEX idx_ofo (ofo_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;";

// APPENDIX F
$sql_f = "CREATE TABLE IF NOT EXISTS arpl_appendix_f (
  id INT AUTO_INCREMENT PRIMARY KEY,
  learnerID INT NOT NULL,
  ofo_number VARCHAR(10) NOT NULL,
  knowledge_acknowledged ENUM('yes','no') DEFAULT 'no',
  practical_acknowledged ENUM('yes','no') DEFAULT 'no',
  workplace_acknowledged ENUM('yes','no') DEFAULT 'no',
  assessor_acknowledged ENUM('yes','no') DEFAULT 'no',
  candidate_signature VARCHAR(255) DEFAULT NULL,
  assessor_signature VARCHAR(255) DEFAULT NULL,
  agreement_date DATE DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_learner_ofo (learnerID, ofo_number),
  INDEX idx_learner (learnerID),
  INDEX idx_ofo (ofo_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;";

// APPENDIX G
$sql_g = "CREATE TABLE IF NOT EXISTS arpl_appendix_g (
  id INT AUTO_INCREMENT PRIMARY KEY,
  learnerID INT NOT NULL,
  ofo_number VARCHAR(10) NOT NULL,
  appeal_subject VARCHAR(255) DEFAULT NULL,
  grounds_for_appeal TEXT DEFAULT NULL,
  moderator_name VARCHAR(255) DEFAULT NULL,
  appeal_status ENUM('Submitted','Under Review','Resolved') DEFAULT 'Submitted',
  assessor_findings TEXT DEFAULT NULL,
  candidate_signature VARCHAR(255) DEFAULT NULL,
  assessor_signature VARCHAR(255) DEFAULT NULL,
  candidate_signed_at VARCHAR(255) DEFAULT NULL,
  assessor_signed_at VARCHAR(255) DEFAULT NULL,
  candidate_date DATE DEFAULT NULL,
  assessor_date DATE DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_learner_ofo (learnerID, ofo_number),
  INDEX idx_learner (learnerID),
  INDEX idx_ofo (ofo_number),
  INDEX idx_status (appeal_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;";

// APPENDIX I
$sql_i = "CREATE TABLE IF NOT EXISTS arpl_appendix_i (
  id INT AUTO_INCREMENT PRIMARY KEY,
  learnerID INT NOT NULL,
  ofo_number VARCHAR(10) NOT NULL,
  provider_type ENUM('Assessment Centre','Skills Development Provider') DEFAULT 'Skills Development Provider',
  knowledge_result ENUM('Competent','Not Yet Competent') DEFAULT NULL,
  practical_result ENUM('Competent','Not Yet Competent') DEFAULT NULL,
  workplace_result ENUM('Competent','Not Yet Competent') DEFAULT NULL,
  overall_competency_rating TINYINT(1) DEFAULT NULL,
  assessor_name VARCHAR(255) DEFAULT NULL,
  assessor_reg_number VARCHAR(50) DEFAULT NULL,
  certification_date DATE DEFAULT NULL,
  additional_notes TEXT DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_learner_ofo (learnerID, ofo_number),
  INDEX idx_learner (learnerID),
  INDEX idx_ofo (ofo_number),
  INDEX idx_competency (overall_competency_rating)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;";

$statements = [
    'arpl_appendix_a' => $sql_a,
    'arpl_appendix_c' => $sql_c,
    'arpl_appendix_f' => $sql_f,
    'arpl_appendix_g' => $sql_g,
    'arpl_appendix_i' => $sql_i
];

foreach ($statements as $table => $sql) {
    if ($conn->query($sql)) {
        echo "✓ $table created/verified\n";
    } else {
        echo "✗ $table error: " . $conn->error . "\n";
    }
}

// Insert sample data for learner 16389
echo "\n=== Inserting Sample Data for Learner 16389 ===\n\n";

$insert_a = "INSERT IGNORE INTO arpl_appendix_a 
(learnerID, ofo_number, current_employer, position_job_title, employment_history) 
VALUES (16389, '671101', 'ABC Electrical Contractors', 'Electrician Technician', 
'{\"years_experience\": 5, \"previous_employers\": [\"XYZ Power Ltd\", \"City Electrical\"]}')";

$insert_c = "INSERT IGNORE INTO arpl_appendix_c 
(learnerID, ofo_number, curriculum_overview, learning_outcomes) 
VALUES (16389, '671101', 
'Electrician NQF Level 4 - Comprehensive training in electrical installation, maintenance and troubleshooting',
'Students will be able to: Install electrical circuits safely, Perform preventive maintenance, Diagnose and repair electrical faults, Apply health and safety regulations')";

$insert_d = "INSERT IGNORE INTO arpl_appendix_d 
(learnerID, ofo_number, 
activity_1, activity_2, activity_3, activity_4, activity_5,
activity_6, activity_7, activity_8, activity_9, activity_10,
activity_11, activity_12, activity_13, activity_14, activity_15,
activity_16, activity_17, activity_18, activity_19, activity_20,
activity_21, activity_22) 
VALUES (16389, '671101',
'yes', 'yes', 'yes', 'yes', 'yes',
'yes', 'yes', 'yes', 'yes', 'yes',
'yes', 'yes', 'yes', 'yes', 'yes',
'yes', 'yes', 'yes', 'pending', 'yes',
'yes', 'yes')";

$insert_f = "INSERT IGNORE INTO arpl_appendix_f 
(learnerID, ofo_number, knowledge_acknowledged, practical_acknowledged, workplace_acknowledged, assessor_acknowledged) 
VALUES (16389, '671101', 'yes', 'yes', 'yes', 'yes')";

$insert_g = "INSERT IGNORE INTO arpl_appendix_g 
(learnerID, ofo_number, appeal_status) 
VALUES (16389, '671101', 'Resolved')";

$insert_i = "INSERT IGNORE INTO arpl_appendix_i 
(learnerID, ofo_number, knowledge_result, practical_result, workplace_result, overall_competency_rating, assessor_name, certification_date) 
VALUES (16389, '671101', 'Competent', 'Competent', 'Competent', 5, 'John Smith', '2026-07-10')";

$inserts = [
    'arpl_appendix_a' => $insert_a,
    'arpl_appendix_c' => $insert_c,
    'arpl_appendix_d' => $insert_d,
    'arpl_appendix_f' => $insert_f,
    'arpl_appendix_g' => $insert_g,
    'arpl_appendix_i' => $insert_i
];

foreach ($inserts as $table => $sql) {
    if ($conn->query($sql)) {
        echo "✓ Sample data inserted into $table\n";
    } else {
        echo "✗ Error inserting into $table: " . $conn->error . "\n";
    }
}

echo "\n=== Setup Complete ===\n";
echo "✓ All ARPL appendix tables created\n";
echo "✓ Sample data inserted for learner 16389\n";

$conn->close();
?>
