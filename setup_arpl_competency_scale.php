<?php
/**
 * Setup ARPL Competency Scale and Activity Data
 * For OFO 671101 Electrician - Appendix B
 * Uses EXISTING tables:
 * - arpl_competency_scale
 * - arplappxb_electrician_activities
 * - arplappxb_activity_ratings
 */

require_once 'connection.php';

if (!$conn) {
    die("❌ Database connection failed\n");
}

// 1. Create Competency Scale Table (if not exists)
$competencyScaleSQL = "
CREATE TABLE IF NOT EXISTS arpl_competency_scale (
    score INT PRIMARY KEY,
    proficiency_level VARCHAR(255),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
";

// 2. Create Electrician Activities Table (if not exists)
$activitiesSQL = "
CREATE TABLE IF NOT EXISTS arplappxb_electrician_activities (
    activity_id INT AUTO_INCREMENT PRIMARY KEY,
    activity_number INT,
    activity_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_activity (activity_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
";

// 3. Create Activity Ratings Table (if not exists)
$activityRatingsSQL = "
CREATE TABLE IF NOT EXISTS arplappxb_activity_ratings (
    activity_rating_id INT AUTO_INCREMENT PRIMARY KEY,
    learnerID INT NOT NULL,
    activity_id INT NOT NULL,
    rating_score INT,
    assessor_id INT,
    rating_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    comments TEXT,
    FOREIGN KEY (learnerID) REFERENCES learnerdetails(learnerID) ON DELETE CASCADE,
    FOREIGN KEY (activity_id) REFERENCES arplappxb_electrician_activities(activity_id) ON DELETE CASCADE,
    KEY idx_learner_activity (learnerID, activity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
";

// Create tables
if ($conn->query($competencyScaleSQL)) {
    echo "✅ Competency Scale table created/verified\n";
} else {
    echo "❌ Error creating competency scale table: " . $conn->error . "\n";
}

if ($conn->query($activitiesSQL)) {
    echo "✅ Electrician Activities table created/verified\n";
} else {
    echo "❌ Error creating electrician activities table: " . $conn->error . "\n";
}

if ($conn->query($activityRatingsSQL)) {
    echo "✅ Activity Ratings table created/verified\n";
} else {
    echo "❌ Error creating activity ratings table: " . $conn->error . "\n";
}

// Insert Competency Scale data - EXACT from Appendix B document
$scaleData = [
    [1, 'Fundamental (basic knowledge)', 'Knowledge is minimal'],
    [2, 'Novice (limited experience)', 'You have experienced some aspects related to this topic but you require more knowledge, practical skills and experience'],
    [3, 'Advanced (intermediate experience)', 'You have all the required knowledge related to this topic but you are still limited to topic and experience'],
    [4, 'Advanced (applied authority)', 'You have the required knowledge practical skills and experience related'],
    [5, 'Expert (recognized authority)', 'You have all the required knowledge to teach and can teach others']
];

foreach ($scaleData as $scale) {
    $checkSQL = "SELECT score FROM arpl_competency_scale WHERE score = " . $scale[0];
    $result = $conn->query($checkSQL);

    if ($result->num_rows == 0) {
        $proficiency = $conn->real_escape_string($scale[1]);
        $description = $conn->real_escape_string($scale[2]);

        $insertSQL = "INSERT INTO arpl_competency_scale (score, proficiency_level, description)
                     VALUES ({$scale[0]}, '{$proficiency}', '{$description}')";
        if ($conn->query($insertSQL)) {
            echo "✅ Scale Score {$scale[0]} ({$scale[1]}) inserted\n";
        } else {
            echo "❌ Error inserting scale {$scale[0]}: " . $conn->error . "\n";
        }
    }
}

// Insert 22 Electrician Activities - EXACT from document
$activities = [
    [1, 'Health, Safety, Quality and Assessment of Units'],
    [2, 'Knowledge and practical skills'],
    [3, 'Safety, Quality and Regulations'],
    [4, 'Equipment and Materials'],
    [5, 'Mechanics and resistors of electricity'],
    [6, 'Electrics and Wires'],
    [7, 'Wire mods'],
    [8, 'A.C modes'],
    [9, 'Alternators and supply systems and commonments'],
    [10, 'Electrical supplies'],
    [11, 'Batteries'],
    [12, 'Transformers'],
    [13, 'Types of cables and applications'],
    [14, 'Low Voltage Protection'],
    [15, 'Fault finding'],
    [16, 'Plan worksite set up for installing wiring and connecting'],
    [17, 'Electrical Equipment and Controls Systems'],
    [18, 'Prepare to site set up for installing wiring and connecting'],
    [19, 'Install and Complete Electrical installations'],
    [20, 'Conduct pre-commission inspection (prove of Competence)'],
    [21, 'New and existing Installation systems'],
    [22, 'Fault line and Repair Electrical installation']
];

foreach ($activities as $activity) {
    $checkSQL = "SELECT activity_id FROM arplappxb_electrician_activities WHERE activity_number = {$activity[0]}";
    $result = $conn->query($checkSQL);

    if ($result->num_rows == 0) {
        $actName = $conn->real_escape_string($activity[1]);
        $insertSQL = "INSERT INTO arplappxb_electrician_activities (activity_number, activity_name)
                     VALUES ({$activity[0]}, '{$actName}')";
        if ($conn->query($insertSQL)) {
            echo "✅ Activity {$activity[0]}: {$activity[1]} inserted\n";
        } else {
            echo "❌ Error inserting activity {$activity[0]}: " . $conn->error . "\n";
        }
    }
}

echo "\n✅ All tables and data setup complete for OFO 671101 - Electrician!\n";

$conn->close();

