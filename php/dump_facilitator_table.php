<?php
// Database table dump for facilitator
include 'connection.php';

header('Content-Type: text/plain; charset=utf-8');

echo "=================================================================\n";
echo "FACILITATOR TABLE DUMP - " . date('Y-m-d H:i:s') . "\n";
echo "=================================================================\n\n";

try {
    // Get table structure
    echo "TABLE STRUCTURE:\n";
    echo "-----------------------------------------------------------------\n";
    $structStmt = $conn->query("DESCRIBE facilitator");
    while ($row = $structStmt->fetch_assoc()) {
        printf("%-30s %-20s %-10s %-10s\n", 
            $row['Field'], 
            $row['Type'], 
            $row['Null'], 
            $row['Key']
        );
    }
    echo "\n";

    // Get row count
    $countStmt = $conn->query("SELECT COUNT(*) as total FROM facilitator");
    $count = $countStmt->fetch_assoc()['total'];
    echo "TOTAL RECORDS: $count\n";
    echo "-----------------------------------------------------------------\n\n";

    // Get all data
    $stmt = $conn->prepare("SELECT * FROM facilitator ORDER BY facilitator_id");
    $stmt->execute();
    $result = $stmt->get_result();

    $recordNum = 1;
    while ($row = $result->fetch_assoc()) {
        echo "RECORD #$recordNum - ID: {$row['facilitator_id']}\n";
        echo "=================================================================\n";
        
        foreach ($row as $key => $value) {
            $displayValue = $value;
            
            // Format the value for display
            if ($value === null) {
                $displayValue = "[NULL]";
            } elseif ($value === '') {
                $displayValue = "[EMPTY STRING]";
            } elseif (strlen($value) > 100) {
                // Truncate long values
                $displayValue = substr($value, 0, 100) . "... [" . strlen($value) . " total chars]";
            }
            
            // Highlight important fields
            $prefix = "  ";
            if (in_array($key, ['facilitator_id', 'firstName', 'lastName', 'email', 'password'])) {
                $prefix = "* ";
            }
            
            printf("%s%-30s : %s\n", $prefix, $key, $displayValue);
        }
        
        // Show fingerprint status
        echo "\n  FINGERPRINT STATUS:\n";
        echo "  - ZKTeco Left:    " . (empty($row['zkteco_left_template']) ? "❌ No" : "✓ Yes (" . strlen($row['zkteco_left_template']) . " chars)") . "\n";
        echo "  - ZKTeco Right:   " . (empty($row['zkteco_right_template']) ? "❌ No" : "✓ Yes (" . strlen($row['zkteco_right_template']) . " chars)") . "\n";
        echo "  - Futronic Left:  " . (empty($row['futronic_left_template']) ? "❌ No" : "✓ Yes (" . strlen($row['futronic_left_template']) . " chars)") . "\n";
        echo "  - Futronic Right: " . (empty($row['futronic_right_template']) ? "❌ No" : "✓ Yes (" . strlen($row['futronic_right_template']) . " chars)") . "\n";
        
        echo "\n";
        echo "-----------------------------------------------------------------\n\n";
        $recordNum++;
    }

    if ($count == 0) {
        echo "\n⚠️  NO RECORDS FOUND IN FACILITATOR TABLE\n\n";
    }

    $stmt->close();
    
    // Also show what the sync endpoint would return
    echo "\n=================================================================\n";
    echo "SYNC ENDPOINT OUTPUT (sync_facilitator.php)\n";
    echo "=================================================================\n\n";
    
    $syncStmt = $conn->prepare("SELECT * FROM facilitator ORDER BY facilitator_id");
    $syncStmt->execute();
    $syncResult = $syncStmt->get_result();
    
    $syncData = [];
    while ($row = $syncResult->fetch_assoc()) {
        $syncData[] = $row;
    }
    
    echo json_encode($syncData, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    echo "\n\n";
    
    $syncStmt->close();

} catch (Exception $e) {
    echo "\n❌ ERROR: " . $e->getMessage() . "\n\n";
}

$conn->close();

echo "=================================================================\n";
echo "END OF DUMP\n";
echo "=================================================================\n";
?>

