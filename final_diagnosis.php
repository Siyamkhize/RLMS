<?php
header('Content-Type: text/html; charset=utf-8');
include('connection.php');

echo "<h1>Final Diagnosis - Image Upload Issue</h1>";
echo "<hr>";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die("<p style='color: red;'>Connection failed: " . $conn->connect_error . "</p>");
}

echo "<h2>1. Database Connection</h2>";
echo "<p>✓ Connected to database: <strong>$dbname</strong></p>";
echo "<p>✓ Server: <strong>$servername</strong></p>";
echo "<p>✓ Website: <strong>" . $_SERVER['SERVER_NAME'] . "</strong></p>";

echo "<h2>2. POE Table Check</h2>";
$tableCheck = $conn->query("SHOW TABLES LIKE 'poe'");
if ($tableCheck && $tableCheck->num_rows > 0) {
    echo "<p>✓ POE table exists</p>";
    
    // Get total count
    $totalResult = $conn->query("SELECT COUNT(*) as cnt FROM poe");
    $totalRow = $totalResult->fetch_assoc();
    echo "<p>Total entries in POE table: <strong>" . $totalRow['cnt'] . "</strong></p>";
    
    // Get pothole count
    $potholeResult = $conn->query("SELECT COUNT(*) as cnt FROM poe WHERE type='LogBook' AND exercise LIKE '%Pothole%'");
    $potholeRow = $potholeResult->fetch_assoc();
    echo "<p>Pothole evidence entries: <strong>" . $potholeRow['cnt'] . "</strong></p>";
    
    if ($potholeRow['cnt'] == 0) {
        echo "<p style='color: red; font-weight: bold;'>⚠️ NO POTHOLE ENTRIES FOUND!</p>";
        echo "<p>This means the database INSERT is failing.</p>";
    }
    
} else {
    echo "<p style='color: red;'>✗ POE table does NOT exist!</p>";
}

echo "<h2>3. Check for Entry ID 467398</h2>";
$checkId = $conn->query("SELECT * FROM poe WHERE id = 467398");
if ($checkId && $checkId->num_rows > 0) {
    echo "<p style='color: green; font-weight: bold;'>✓ Entry 467398 EXISTS!</p>";
    $row = $checkId->fetch_assoc();
    echo "<pre>";
    print_r($row);
    echo "</pre>";
} else {
    echo "<p style='color: red; font-weight: bold;'>✗ Entry 467398 does NOT exist</p>";
    echo "<p>The poe_id returned by the upload was fake or the INSERT failed.</p>";
}

echo "<h2>4. File System Check</h2>";
$uploadDir = "uploads/pothole_evidence/";
if (file_exists($uploadDir)) {
    echo "<p>✓ Upload directory exists: <code>$uploadDir</code></p>";
    $files = array_diff(scandir($uploadDir), ['.', '..']);
    echo "<p>Files in directory: <strong>" . count($files) . "</strong></p>";
    
    if (count($files) > 0) {
        echo "<h3>Files found:</h3><ul>";
        foreach ($files as $file) {
            echo "<li>$file</li>";
        }
        echo "</ul>";
    } else {
        echo "<p style='color: orange;'>⚠️ Directory is empty - no files uploaded</p>";
    }
} else {
    echo "<p style='color: red;'>✗ Upload directory does NOT exist</p>";
}

echo "<h2>5. Check POE Table Structure</h2>";
$structure = $conn->query("DESCRIBE poe");
if ($structure) {
    echo "<table border='1' cellpadding='5' style='border-collapse: collapse;'>";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th></tr>";
    while ($col = $structure->fetch_assoc()) {
        echo "<tr>";
        echo "<td>{$col['Field']}</td>";
        echo "<td>{$col['Type']}</td>";
        echo "<td>{$col['Null']}</td>";
        echo "<td>{$col['Key']}</td>";
        echo "<td>" . ($col['Default'] ?? 'NULL') . "</td>";
        echo "</tr>";
    }
    echo "</table>";
    
    // Check if required columns exist
    $requiredColumns = ['learnerID', 'exercise', 'type', 'filePath', 'logbook_text'];
    $structure->data_seek(0);
    $existingColumns = [];
    while ($col = $structure->fetch_assoc()) {
        $existingColumns[] = $col['Field'];
    }
    
    echo "<h3>Required Columns Check:</h3>";
    foreach ($requiredColumns as $reqCol) {
        if (in_array($reqCol, $existingColumns)) {
            echo "<p>✓ $reqCol exists</p>";
        } else {
            echo "<p style='color: red;'>✗ $reqCol is MISSING!</p>";
        }
    }
}

echo "<h2>6. Test Database INSERT</h2>";
$testLearnerID = 'TEST_' . time();
$testExercise = 'Test Pothole Evidence';
$testType = 'LogBook';
$testFilePath = 'test.jpg';
$testLogbookText = 'Test insert';

$testStmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, filePath, logbook_text) VALUES (?, ?, ?, ?, ?)');
if ($testStmt) {
    $testStmt->bind_param('sssss', $testLearnerID, $testExercise, $testType, $testFilePath, $testLogbookText);
    
    if ($testStmt->execute()) {
        $testId = $testStmt->insert_id;
        echo "<p style='color: green;'>✓ Test INSERT successful! ID: $testId</p>";
        
        // Clean up
        $conn->query("DELETE FROM poe WHERE id = $testId");
        echo "<p>✓ Test entry cleaned up</p>";
    } else {
        echo "<p style='color: red;'>✗ Test INSERT failed: " . $testStmt->error . "</p>";
    }
    $testStmt->close();
} else {
    echo "<p style='color: red;'>✗ Failed to prepare statement: " . $conn->error . "</p>";
}

echo "<h2>7. Conclusion</h2>";

// Determine the issue
$potholeCount = 0;
$potholeResult = $conn->query("SELECT COUNT(*) as cnt FROM poe WHERE type='LogBook' AND exercise LIKE '%Pothole%'");
if ($potholeResult) {
    $potholeRow = $potholeResult->fetch_assoc();
    $potholeCount = $potholeRow['cnt'];
}

$fileCount = 0;
if (file_exists($uploadDir)) {
    $files = array_diff(scandir($uploadDir), ['.', '..']);
    $fileCount = count($files);
}

if ($potholeCount > 0 && $fileCount > 0) {
    echo "<p style='color: green; font-weight: bold; font-size: 18px;'>✓ UPLOADS ARE WORKING!</p>";
    echo "<p>You have $potholeCount database entries and $fileCount files.</p>";
    echo "<p>If you don't see them in your admin panel, you're checking the wrong place.</p>";
} elseif ($fileCount > 0 && $potholeCount == 0) {
    echo "<p style='color: orange; font-weight: bold; font-size: 18px;'>⚠️ FILES EXIST BUT NO DATABASE ENTRIES</p>";
    echo "<p>Files are being uploaded but database INSERT is failing.</p>";
    echo "<p>Check the POE table structure - some required columns might be missing.</p>";
} elseif ($fileCount == 0 && $potholeCount == 0) {
    echo "<p style='color: red; font-weight: bold; font-size: 18px;'>✗ NOTHING IS BEING SAVED</p>";
    echo "<p>Neither files nor database entries exist.</p>";
    echo "<p>The upload might be going to a different server or the response is fake.</p>";
} else {
    echo "<p style='color: orange; font-weight: bold; font-size: 18px;'>⚠️ INCONSISTENT STATE</p>";
    echo "<p>Database entries: $potholeCount, Files: $fileCount</p>";
}

$conn->close();
?>
