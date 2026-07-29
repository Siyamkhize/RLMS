<?php
/**
 * Get the actual remedial records using correct column names
 */

echo "=== ACTUAL REMEDIAL RECORDS FOR LEARNER 11515 ===\n\n";

include_once 'connection.php';

if (!$conn) {
    echo "❌ Database connection failed\n";
    exit;
}

$query = "SELECT poe_id, learnerID, exercise, type, filePath, submitted_at FROM poe 
          WHERE learnerID = 11515 AND (type = 'FormativeRemedial' OR type = 'SummativeRemedial') 
          ORDER BY type, poe_id";
$result = $conn->query($query);

if ($result && $result->num_rows > 0) {
    echo "✅ Found " . $result->num_rows . " remedial records:\n\n";
    while ($row = $result->fetch_assoc()) {
        echo "POE ID: {$row['poe_id']}\n";
        echo "Type: '{$row['type']}'\n";
        echo "Exercise: '{$row['exercise']}'\n";
        echo "FilePath: " . ($row['filePath'] ?? 'NULL') . "\n";
        echo "Submitted: " . ($row['submitted_at'] ?? 'NULL') . "\n";
        
        // Test unit standard extraction
        $exercise = $row['exercise'];
        
        echo "Testing extraction methods:\n";
        
        // Method 1: Current complex logic from mobile/poe.php
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
        
        // Method 2: Simple split
        $parts = explode('-', $exercise);
        $method2 = isset($parts[1]) ? trim($parts[1]) : '';
        
        // Method 3: Regex for "- NUMBER -" pattern
        preg_match('/.*?-\s*(\d+)\s*-/', $exercise, $matches);
        $method3 = isset($matches[1]) ? $matches[1] : '';
        
        echo "   Current logic: '$extracted'\n";
        echo "   Simple split: '$method2'\n";
        echo "   Regex method: '$method3'\n";
        
        echo "===========================================\n";
    }
} else {
    echo "❌ No remedial records found\n";
    echo "Error: " . $conn->error . "\n";
}

$conn->close();
?>