<?php
header('Content-Type: text/html; charset=utf-8');
include('connection.php');

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

echo "<h1>Recent Pothole Image Uploads</h1>";
echo "<p><strong>Database:</strong> $dbname</p>";
echo "<p><strong>Server:</strong> " . $_SERVER['SERVER_NAME'] . "</p>";
echo "<hr>";

// Get all pothole evidence entries
$query = "SELECT * FROM poe 
          WHERE type = 'LogBook' 
          AND exercise LIKE '%Pothole%' 
          ORDER BY id DESC 
          LIMIT 20";

$result = $conn->query($query);

if ($result && $result->num_rows > 0) {
    echo "<h2>✓ Found " . $result->num_rows . " pothole image entries</h2>";
    echo "<table border='1' cellpadding='10' style='border-collapse: collapse; width: 100%;'>";
    echo "<tr style='background: #4CAF50; color: white;'>";
    echo "<th>ID</th>";
    echo "<th>Learner ID</th>";
    echo "<th>Exercise</th>";
    echo "<th>File Path</th>";
    echo "<th>File Exists?</th>";
    echo "<th>LogBook Text</th>";
    echo "</tr>";
    
    while ($row = $result->fetch_assoc()) {
        $fileExists = file_exists($row['filePath']) ? '✓ YES' : '✗ NO';
        $fileColor = file_exists($row['filePath']) ? 'green' : 'red';
        
        echo "<tr>";
        echo "<td><strong>{$row['id']}</strong></td>";
        echo "<td>{$row['learnerID']}</td>";
        echo "<td>" . htmlspecialchars($row['exercise']) . "</td>";
        echo "<td>" . htmlspecialchars($row['filePath']) . "</td>";
        echo "<td style='color: $fileColor; font-weight: bold;'>$fileExists</td>";
        echo "<td>" . htmlspecialchars($row['logbook_text'] ?? '') . "</td>";
        echo "</tr>";
    }
    
    echo "</table>";
    
    // Check for the specific entry from the upload
    echo "<hr>";
    echo "<h2>Looking for Entry ID 467398</h2>";
    $specificQuery = "SELECT * FROM poe WHERE id = 467398";
    $specificResult = $conn->query($specificQuery);
    
    if ($specificResult && $specificResult->num_rows > 0) {
        $row = $specificResult->fetch_assoc();
        echo "<p style='color: green; font-weight: bold;'>✓ FOUND!</p>";
        echo "<table border='1' cellpadding='10' style='border-collapse: collapse;'>";
        foreach ($row as $key => $value) {
            echo "<tr>";
            echo "<td><strong>$key</strong></td>";
            echo "<td>" . htmlspecialchars($value ?? 'NULL') . "</td>";
            echo "</tr>";
        }
        echo "</table>";
    } else {
        echo "<p style='color: red; font-weight: bold;'>✗ NOT FOUND in this database</p>";
        echo "<p>This means you might be checking a different database than where the app uploaded.</p>";
    }
    
} else {
    echo "<h2 style='color: red;'>✗ No pothole image entries found</h2>";
    echo "<p>Total entries in poe table: ";
    $countResult = $conn->query("SELECT COUNT(*) as cnt FROM poe");
    $countRow = $countResult->fetch_assoc();
    echo $countRow['cnt'] . "</p>";
}

echo "<hr>";
echo "<h2>File System Check</h2>";
$dir = "uploads/pothole_evidence/";
if (file_exists($dir)) {
    $files = array_diff(scandir($dir), ['.', '..']);
    echo "<p>✓ Directory exists: <code>$dir</code></p>";
    echo "<p>Files in directory: <strong>" . count($files) . "</strong></p>";
    
    if (count($files) > 0) {
        echo "<h3>Files:</h3>";
        echo "<ul>";
        foreach ($files as $file) {
            $size = filesize($dir . $file);
            $modified = date('Y-m-d H:i:s', filemtime($dir . $file));
            echo "<li><code>$file</code> - " . round($size/1024, 2) . " KB - Modified: $modified</li>";
        }
        echo "</ul>";
    }
} else {
    echo "<p style='color: red;'>✗ Directory does not exist: <code>$dir</code></p>";
}

echo "<hr>";
echo "<h2>Summary</h2>";
echo "<p>If you see entries above but they don't appear in your admin panel, you might be:</p>";
echo "<ul>";
echo "<li>Checking a different database</li>";
echo "<li>Looking at a different server (production vs testing)</li>";
echo "<li>Using a filter that excludes these entries</li>";
echo "</ul>";

$conn->close();
?>
