<?php
header('Content-Type: text/plain');
include('connection.php');

echo "=== VERIFY POE ENTRY 467398 ===\n\n";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error . "\n");
}

echo "Database: $dbname\n";
echo "Server: $servername\n\n";

// Check for the specific poe_id from the upload
$poeId = 467398;
echo "Looking for poe_id: $poeId\n\n";

$stmt = $conn->prepare("SELECT * FROM poe WHERE id = ?");
$stmt->bind_param('i', $poeId);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo "✓ FOUND! Entry exists:\n\n";
    $row = $result->fetch_assoc();
    foreach ($row as $key => $value) {
        echo "  $key: $value\n";
    }
} else {
    echo "✗ NOT FOUND! Entry with id=$poeId does not exist\n\n";
    
    // Check if poe table exists
    $tableCheck = $conn->query("SHOW TABLES LIKE 'poe'");
    if ($tableCheck->num_rows > 0) {
        echo "✓ POE table exists\n";
        
        // Get total count
        $countResult = $conn->query("SELECT COUNT(*) as cnt FROM poe");
        $countRow = $countResult->fetch_assoc();
        echo "  Total entries in poe table: " . $countRow['cnt'] . "\n\n";
        
        // Get highest ID
        $maxResult = $conn->query("SELECT MAX(id) as max_id FROM poe");
        $maxRow = $maxResult->fetch_assoc();
        echo "  Highest poe_id: " . ($maxRow['max_id'] ?? 'NULL') . "\n\n";
        
        // Check for pothole entries
        $potholeResult = $conn->query("SELECT COUNT(*) as cnt FROM poe WHERE exercise LIKE '%Pothole%'");
        $potholeRow = $potholeResult->fetch_assoc();
        echo "  Pothole entries: " . $potholeRow['cnt'] . "\n\n";
        
        // Show last 5 entries
        echo "Last 5 entries in poe table:\n";
        $lastEntries = $conn->query("SELECT id, learnerID, exercise, type, filePath FROM poe ORDER BY id DESC LIMIT 5");
        if ($lastEntries && $lastEntries->num_rows > 0) {
            while ($entry = $lastEntries->fetch_assoc()) {
                echo "  ID: {$entry['id']}, Learner: {$entry['learnerID']}, Exercise: {$entry['exercise']}\n";
            }
        } else {
            echo "  No entries found\n";
        }
    } else {
        echo "✗ POE table does not exist!\n";
    }
}

echo "\n=== CHECK FILE SYSTEM ===\n\n";

$filePath = "uploads/pothole_evidence/pothole_75_2025-11-10_1762786833_6911fe11e7685.jpg";
echo "Looking for file: $filePath\n";

if (file_exists($filePath)) {
    echo "✓ File exists!\n";
    echo "  Size: " . filesize($filePath) . " bytes\n";
    echo "  Modified: " . date('Y-m-d H:i:s', filemtime($filePath)) . "\n";
} else {
    echo "✗ File does not exist\n\n";
    
    // Check directory
    $dir = "uploads/pothole_evidence/";
    if (file_exists($dir)) {
        echo "✓ Directory exists\n";
        $files = array_diff(scandir($dir), ['.', '..']);
        echo "  Files in directory: " . count($files) . "\n";
        if (count($files) > 0) {
            echo "  Recent files:\n";
            foreach (array_slice($files, -5) as $file) {
                echo "    - $file\n";
            }
        }
    } else {
        echo "✗ Directory does not exist\n";
    }
}

echo "\n=== POSSIBLE ISSUES ===\n\n";

// Check if we're on the right server
echo "Current script location: " . __FILE__ . "\n";
echo "Document root: " . $_SERVER['DOCUMENT_ROOT'] . "\n";
echo "Server name: " . $_SERVER['SERVER_NAME'] . "\n\n";

echo "Are you checking:\n";
echo "1. The correct database? (Database: $dbname)\n";
echo "2. The correct server? (Server: " . $_SERVER['SERVER_NAME'] . ")\n";
echo "3. The correct table? (Table: poe)\n\n";

echo "The app uploaded to: https://rlms.rlms.co.za/mobile/\n";
echo "You should be checking the database connected to that server.\n";

$conn->close();
?>
