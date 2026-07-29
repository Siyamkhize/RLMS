<?php
/**
 * Show the actual remedial records for learner 11515
 */

echo "=== ACTUAL REMEDIAL RECORDS FOR LEARNER 11515 ===\n\n";

include_once 'connection.php';

if (!$conn) {
    echo "❌ Database connection failed\n";
    exit;
}

$query = "SELECT id, learnerID, exercise, type, filePath, created_at FROM poe 
          WHERE learnerID = 11515 AND type IN ('FormativeRemedial', 'SummativeRemedial') 
          ORDER BY type, id";
$result = $conn->query($query);

if ($result && $result->num_rows > 0) {
    echo "✅ Found " . $result->num_rows . " remedial records:\n\n";
    while ($row = $result->fetch_assoc()) {
        echo "ID: {$row['id']}\n";
        echo "Type: '{$row['type']}'\n";
        echo "Exercise: '{$row['exercise']}'\n";
        echo "FilePath: " . ($row['filePath'] ?? 'NULL') . "\n";
        echo "Created: " . ($row['created_at'] ?? 'NULL') . "\n";
        
        // Test unit standard extraction
        $exercise = $row['exercise'];
        $extracted = trim(
            substr(
                strstr(
                    substr(strstr($exercise, '-'), 1), 
                    '-', 
                    true
                ) ?: substr(strstr($exercise, '-'), 1), 
                0, 
                strpos(substr(strstr($exercise, '-'), 1), ' ') ?: strlen(substr(strstr($exercise, '-'), 1))
            )
        );
        echo "Extracted Unit Standard: '$extracted'\n";
        echo "---\n";
    }
} else {
    echo "❌ No remedial records found\n";
}

$conn->close();
?>