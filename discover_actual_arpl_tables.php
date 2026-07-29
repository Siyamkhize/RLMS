<?php
require_once 'web/connection.php';

echo "╔════════════════════════════════════════════════════════════╗\n";
echo "║   DISCOVERING ACTUAL ARPL TRADE-SPECIFIC TABLES            ║\n";
echo "╚════════════════════════════════════════════════════════════╝\n\n";

// All possible ARPL tables
$tables_to_check = [
    'arplappxb_electrician_activities',
    'arplappxb_activity_ratings',
    'arplappxd_electrician_activities',
    'arplappxd_activity_ratings',
    'arplappxe_electrician_activities',
    'arplappxe_electrician_activity_ratings',
    'arpl_acrelectrician',
    'arplelectrician_access_recommendation',
    'arpl_competency_scale',
];

echo "CHECKING TABLES IN DATABASE:\n";
echo str_repeat("━", 60) . "\n\n";

$found_tables = [];

foreach ($tables_to_check as $table) {
    $sql = "SHOW TABLES LIKE ?";
    $stmt = $conn->prepare($sql);
    if ($stmt) {
        $stmt->bind_param('s', $table);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            echo "✅ $table\n";
            $found_tables[] = $table;
            
            // Get count
            $count_sql = "SELECT COUNT(*) as cnt FROM `$table` LIMIT 1";
            $count_result = $conn->query($count_sql);
            if ($count_result) {
                $row = $count_result->fetch_assoc();
                echo "   └─ Records: " . $row['cnt'] . "\n";
            }
        } else {
            echo "❌ $table\n";
        }
        $stmt->close();
        echo "\n";
    }
}

echo "\n" . str_repeat("═", 60) . "\n";
echo "SUMMARY - TABLES AVAILABLE FOR PDF:\n";
echo str_repeat("═", 60) . "\n\n";

foreach ($found_tables as $table) {
    echo "• $table\n";
}

echo "\nTotal tables found: " . count($found_tables) . "\n";

$conn->close();
?>
