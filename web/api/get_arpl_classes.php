<?php
/**
 * Get ARPL Classes by Trade
 * Returns classes that belong to a specific ARPL trade
 * Classes are linked via trade_id
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

ini_set('display_errors', 0);
error_reporting(E_ALL);

try {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Invalid JSON request');
    }
    
    $ofo_code = isset($data['ofo_code']) ? trim($data['ofo_code']) : '';
    
    if (empty($ofo_code)) {
        throw new Exception('Missing ofo_code parameter');
    }
    
    // Load connection
    $root_conn_file = __DIR__ . '/../connection.php';
    if (!file_exists($root_conn_file)) {
        throw new Exception('Connection file not found');
    }
    
    @require_once $root_conn_file;
    
    if (!isset($conn) || !$conn || $conn->connect_error) {
        throw new Exception('Database connection failed');
    }
    
    // Get trade_id from OFO code
    $sql = "SELECT trade_id, trade_name FROM arpl_trades WHERE ofo_number = ? AND is_active = 1";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Query error');
    }
    
    $stmt->bind_param('s', $ofo_code);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        throw new Exception('Trade not found or inactive in ARPL system');
    }
    
    $trade_row = $result->fetch_assoc();
    $trade_id = $trade_row['trade_id'];
    $trade_name = $trade_row['trade_name'];
    
    $stmt->close();
    
    // Now get classes for this trade
    $sql_classes = "
        SELECT 
            c.classID,
            c.className,
            c.numberOfLearners,
            c.siteID,
            c.trade_id
        FROM class c
        WHERE c.trade_id = ?
        ORDER BY c.className ASC
    ";
    
    $stmt_classes = $conn->prepare($sql_classes);
    if (!$stmt_classes) {
        throw new Exception('Query error');
    }
    
    $stmt_classes->bind_param('i', $trade_id);
    $stmt_classes->execute();
    $classes_result = $stmt_classes->get_result();
    
    $classes = [];
    while($row = $classes_result->fetch_assoc()) {
        $classes[] = [
            'classID' => intval($row['classID']),
            'className' => $row['className'],
            'numberOfLearners' => intval($row['numberOfLearners']),
            'siteID' => intval($row['siteID']),
            'trade_id' => intval($row['trade_id'])
        ];
    }
    
    $stmt_classes->close();
    $conn->close();
    
    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'trade_name' => $trade_name,
        'ofo_code' => $ofo_code,
        'trade_id' => intval($trade_id),
        'classes' => $classes,
        'count' => count($classes)
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

