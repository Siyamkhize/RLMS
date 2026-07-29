<?php
/**
 * Get ARPL Trades
 * Returns list of all available trades for ARPL portfolio generation
 * 
 * Endpoint: GET web/api/get_arpl_trades.php
 * 
 * Response:
 * {
 *   "status": "success",
 *   "trades": [
 *     {"trade_id": 1, "trade_name": "Electrician", "ofo_code": "671101"},
 *     {"trade_id": 2, "trade_name": "Bricklaying", "ofo_code": "641201"},
 *     {"trade_id": 3, "trade_name": "Plumbing", "ofo_code": "642601"}
 *   ]
 * }
 */

// CRITICAL: Set headers BEFORE ANY OUTPUT
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

// Suppress ALL errors from output
ini_set('display_errors', 1);
error_reporting(E_ALL);

try {
    // Load connection
    $root_conn_file = __DIR__ . '/../connection.php';
    if (!file_exists($root_conn_file)) {
        throw new Exception('Connection file not found');
    }
    
    @require_once $root_conn_file;
    
    if (!isset($conn) || !$conn || $conn->connect_error) {
        throw new Exception('Database connection failed');
    }
    
    // Get active trades from database
    $sql = "SELECT trade_id, trade_name, ofo_number, description FROM arpl_trades WHERE is_active = 1 ORDER BY trade_name ASC";
    $result = $conn->query($sql);
    
    if (!$result) {
        throw new Exception('Query failed: ' . $conn->error);
    }
    
    $trades = [];
    while ($row = $result->fetch_assoc()) {
        $trades[] = [
            'trade_id' => intval($row['trade_id']),
            'trade_name' => $row['trade_name'],
            'ofo_code' => $row['ofo_number'],
            'description' => $row['description']
        ];
    }
    
    $conn->close();
    
    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'trades' => $trades,
        'count' => count($trades)
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
