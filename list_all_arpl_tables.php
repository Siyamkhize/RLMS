<?php
require_once 'web/connection.php';

echo "ALL ARPL-RELATED TABLES IN DATABASE:\n";
echo str_repeat("═", 60) . "\n\n";

$result = $conn->query("SHOW TABLES LIKE 'arpl%'");

if ($result && $result->num_rows > 0) {
    echo "Found " . $result->num_rows . " tables:\n\n";
    while ($row = $result->fetch_array()) {
        $tableName = $row[0];
        echo "• $tableName\n";
        
        // Get record count
        $countResult = $conn->query("SELECT COUNT(*) as cnt FROM `$tableName`");
        if ($countResult) {
            $countRow = $countResult->fetch_assoc();
            echo "  Records: " . $countRow['cnt'] . "\n";
        }
        echo "\n";
    }
} else {
    echo "No ARPL tables found!\n";
}

echo str_repeat("═", 60) . "\n";

$conn->close();
?>
