<?php
/**
 * Get the actual remedial records for learner 11515
 */

echo "=== ACTUAL REMEDIAL RECORDS FOR LEARNER 11515 ===\n\n";

include_once 'connection.php';

if (!$conn) {
    echo "❌ Database connection failed\n";
    exit;
}

$query = "SELECT id, learnerID, exercise, type, filePath, created_at FROM poe 
          WHERE learnerID = 11515 AND (type = 'FormativeRemedial' OR type = 'SummativeRemedial') 
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
        
        // Try different extraction methods
        echo "Testing extraction methods:\n";
        
        // Method 1: Current complex logic
        $method1 = trim(
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
        
        // Method 3: Regex
        preg_match('/.*?-\s*(\d+)\s*-/', $exercise, $matches);
        $method3 = isset($matches[1]) ? $matches[1] : '';
        
        echo "   Method 1 (current): '$method1'\n";
        echo "   Method 2 (simple): '$method2'\n";
        echo "   Method 3 (regex): '$method3'\n";
        
        echo "===========================================\n";
    }
} else {
    echo "❌ No remedial records found\n";
}

$conn->close();
?>