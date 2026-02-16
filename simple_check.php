<?php
header('Content-Type: text/plain');
include('connection.php');

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die("Connection failed\n");
}

echo "=== SIMPLE CHECK ===\n\n";

// Check for pothole entries
echo "1. Checking for pothole entries...\n";
$result = $conn->query("SELECT COUNT(*) as cnt FROM poe WHERE type='LogBook' AND exercise LIKE '%Pothole%'");
if ($result) {
    $row = $result->fetch_assoc();
    echo "Pothole entries found: " . $row['cnt'] . "\n";
} else {
    echo "Query failed: " . $conn->error . "\n";
}

// Check upload directory
echo "\n2. Checking upload directory...\n";
$dir = 'uploads/pothole_evidence/';
if (file_exists($dir)) {
    $files = array_diff(scandir($dir), ['.', '..']);
    echo "Directory exists with " . count($files) . " files\n";
    if (count($files) > 0) {
        echo "Files:\n";
        foreach ($files as $file) {
            echo "  - $file\n";
        }
    }
} else {
    echo "Directory does not exist\n";
}

// Try to access the specific file from the last upload
echo "\n3. Checking specific file...\n";
$testFile = 'uploads/pothole_evidence/pothole_75_2025-11-11_1762842047_6912d5bf616b8.jpg';
if (file_exists($testFile)) {
    echo "✓ File exists: $testFile\n";
    echo "  Size: " . filesize($testFile) . " bytes\n";
} else {
    echo "✗ File does not exist: $testFile\n";
}

// Check if the poe_id from the upload exists
echo "\n4. Checking for poe_id 467403...\n";
$check = $conn->query("SELECT * FROM poe WHERE poe_id = 467403");
if ($check && $check->num_rows > 0) {
    echo "✓ Entry 467403 EXISTS!\n";
    $row = $check->fetch_assoc();
    echo "  learnerID: {$row['learnerID']}\n";
    echo "  exercise: {$row['exercise']}\n";
    echo "  filePath: {$row['filePath']}\n";
} else {
    echo "✗ Entry 467403 does NOT exist\n";
}

$conn->close();

echo "\n=== DONE ===\n";
?>
