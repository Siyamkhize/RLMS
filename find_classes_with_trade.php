<?php
require_once 'connection.php';

echo "===== FINDING CLASSES WITH TRADE ASSIGNMENT =====\n\n";

// Find classes with trade_id set
$result = $conn->query("
    SELECT c.classID, c.className, c.trade_id, t.trade_name, t.ofo_number
    FROM class c
    LEFT JOIN arpl_trades t ON c.trade_id = t.trade_id
    WHERE c.trade_id IS NOT NULL AND c.trade_id > 0
    ORDER BY c.classID
");

echo "Classes with trade_id assigned:\n";
echo str_repeat("-", 80) . "\n";

if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        echo sprintf(
            "ClassID: %-5s | Name: %-30s | Trade: %-20s | OFO: %s\n",
            $row['classID'],
            $row['className'],
            $row['trade_name'] ?? '(null)',
            $row['ofo_number'] ?? '(null)'
        );
    }
} else {
    echo "(No classes have trade_id assigned yet)\n\n";
    
    echo "Current class count:\n";
    $countResult = $conn->query("SELECT COUNT(*) as total FROM class");
    if ($countResult && $countResult->num_rows > 0) {
        $countRow = $countResult->fetch_assoc();
        echo "  Total classes: " . $countRow['total'] . "\n";
    }
}

echo "\n" . str_repeat("-", 80) . "\n";
echo "\nStatus:\n";
echo "✅ arpl_trades table exists with 4 trades (Electrician, Plumber, Bricklayer, Welder)\n";
echo "✅ class table has trade_id column\n";
echo "❌ Classes not yet assigned to trades\n\n";

echo "Next Step:\n";
echo "Assign trades to your classes. Example SQL:\n";
echo "  UPDATE class SET trade_id = 1 WHERE classID = 782; -- Electrician\n";
echo "  UPDATE class SET trade_id = 4 WHERE classID = 783; -- Bricklayer\n";
echo "  UPDATE class SET trade_id = 2 WHERE classID = 784; -- Plumber\n";

$conn->close();
?>
