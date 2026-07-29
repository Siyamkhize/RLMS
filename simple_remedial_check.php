<?php
/**
 * Simple check for remedial records
 */

echo "=== SIMPLE REMEDIAL CHECK ===\n\n";

include_once 'connection.php';

if (!$conn) {
    echo "❌ Database connection failed: " . mysqli_connect_error() . "\n";
    exit;
}

echo "✅ Database connected successfully\n\n";

$learnerID = 11515;

echo "1. CHECKING POE TABLE FOR REMEDIAL RECORDS\n";
echo "==========================================\n";

$query = "SELECT COUNT(*) as total FROM poe WHERE learnerID = $learnerID";
$result = $conn->query($query);
if ($result) {
    $row = $result->fetch_assoc();
    echo "Total POE records for learner $learnerID: " . $row['total'] . "\n";
} else {
    echo "❌ Error querying POE table: " . $conn->error . "\n";
}

$query = "SELECT COUNT(*) as total FROM poe WHERE learnerID = $learnerID AND type LIKE '%Remedial%'";
$result = $conn->query($query);
if ($result) {
    $row = $result->fetch_assoc();
    echo "Remedial POE records for learner $learnerID: " . $row['total'] . "\n";
} else {
    echo "❌ Error querying remedial POE: " . $conn->error . "\n";
}

echo "\n2. SAMPLE REMEDIAL RECORDS\n";
echo "==========================\n";

$query = "SELECT id, exercise, type, filePath FROM poe WHERE learnerID = $learnerID AND type LIKE '%Remedial%' LIMIT 3";
$result = $conn->query($query);
if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        echo "ID: {$row['id']}, Type: {$row['type']}, Exercise: {$row['exercise']}\n";
    }
} else {
    echo "❌ No remedial records found or error: " . $conn->error . "\n";
}

echo "\n3. CHECKING ASSESSMENTS TABLE\n";
echo "=============================\n";

$query = "SELECT COUNT(*) as total FROM assessments";
$result = $conn->query($query);
if ($result) {
    $row = $result->fetch_assoc();
    echo "Total assessment records: " . $row['total'] . "\n";
} else {
    echo "❌ Error querying assessments: " . $conn->error . "\n";
}

echo "\n4. CHECKING LEARNER PROJECT\n";
echo "===========================\n";

$query = "SELECT ld.LearnerID, c.classID, s.siteID, pr.project_id 
          FROM learnerdetails ld 
          LEFT JOIN class c ON ld.classID = c.classID 
          LEFT JOIN sites s ON c.siteID = s.siteID 
          LEFT JOIN project pr ON s.project_id = pr.project_id
          WHERE ld.LearnerID = $learnerID";
$result = $conn->query($query);
if ($result && $result->num_rows > 0) {
    $row = $result->fetch_assoc();
    echo "Learner $learnerID project details:\n";
    echo "- Class ID: " . ($row['classID'] ?? 'NULL') . "\n";
    echo "- Site ID: " . ($row['siteID'] ?? 'NULL') . "\n";
    echo "- Project ID: " . ($row['project_id'] ?? 'NULL') . "\n";
} else {
    echo "❌ No project found for learner $learnerID or error: " . $conn->error . "\n";
}

$conn->close();
?>