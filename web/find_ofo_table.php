<?php
header('Content-Type: application/json; charset=utf-8');

try {
    require_once __DIR__ . '/connection.php';
    
    // Look for tables with OFO or trade info
    $tables_to_check = ['qualification', 'trade', 'ofo', 'arpl_qualification', 'arpl_trade'];
    
    $result = [];
    
    foreach ($tables_to_check as $table) {
        $check = $conn->query("SHOW TABLES LIKE '$table'");
        if ($check && $check->num_rows > 0) {
            $cols = $conn->query("DESCRIBE $table");
            $columns = [];
            while ($row = $cols->fetch_assoc()) {
                $columns[] = $row['Field'];
            }
            $result[] = [
                'table' => $table,
                'exists' => true,
                'columns' => $columns
            ];
        }
    }
    
    // Also check for any tables with 'qualification' in name
    $alltables = $conn->query("SHOW TABLES");
    $all = [];
    while ($row = $alltables->fetch_row()) {
        if (stripos($row[0], 'qualification') !== false || stripos($row[0], 'trade') !== false || stripos($row[0], 'ofo') !== false) {
            $all[] = $row[0];
        }
    }
    
    echo json_encode([
        'status' => 'success',
        'checked_tables' => $result,
        'all_matching_tables' => $all
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>
