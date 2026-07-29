<?php
include 'connection.php';

$learnerID = 16389;

echo "Searching for learner $learnerID in all tables...\n\n";

// Get all tables
$result = $conn->query("SHOW TABLES");
$tables = [];
while ($row = $result->fetch_row()) {
    $tables[] = $row[0];
}

echo "Total tables: " . count($tables) . "\n\n";

$found = [];
foreach ($tables as $table) {
    // Try to find learnerID column
    $columnResult = $conn->query("SHOW COLUMNS FROM $table LIKE 'learnerID'");
    if ($columnResult && $columnResult->num_rows > 0) {
        $countResult = $conn->query("SELECT COUNT(*) as cnt FROM $table WHERE learnerID = $learnerID");
        if ($countResult) {
            $row = $countResult->fetch_assoc();
            if ($row['cnt'] > 0) {
                $found[$table] = $row['cnt'];
                echo "✓ $table: " . $row['cnt'] . " records\n";
            }
        }
    }
}

if (empty($found)) {
    echo "Not found in any table using learnerID column\n";
    echo "\nTrying alternative searches...\n";
    
    // Try ID columns
    $result = $conn->query("SHOW TABLES");
    while ($tableRow = $result->fetch_row()) {
        $table = $tableRow[0];
        $columnResult = $conn->query("SHOW COLUMNS FROM $table LIKE '%id'");
        if ($columnResult && $columnResult->num_rows > 0) {
            $col = null;
            while ($colRow = $columnResult->fetch_assoc()) {
                $col = $colRow['Field'];
            }
            
            if ($col) {
                $countResult = $conn->query("SELECT COUNT(*) as cnt FROM $table WHERE $col = $learnerID");
                if ($countResult) {
                    $row = $countResult->fetch_assoc();
                    if ($row['cnt'] > 0) {
                        echo "✓ $table (column: $col): " . $row['cnt'] . " records\n";
                    }
                }
            }
        }
    }
}

echo "\n=== CHECKING ARPL_POE DATA ===\n";
$result = $conn->query("SELECT id, learnerID, ofo_number, section_type, file_name FROM arpl_poe WHERE learnerID = $learnerID");
if ($result && $result->num_rows > 0) {
    echo "Found " . $result->num_rows . " papers for learner $learnerID\n";
    while ($row = $result->fetch_assoc()) {
        echo "  ID: " . $row['id'];
        echo ", Type: " . $row['section_type'];
        echo ", OFO: " . $row['ofo_number'];
        echo ", File: " . $row['file_name'] . "\n";
    }
}

?>
