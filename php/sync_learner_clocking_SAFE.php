<?php
/**
 * SAFE Sync Endpoint - READ ONLY with strict validation
 * 
 * This version has maximum security to prevent auto-insertion
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// CRITICAL: Only allow GET requests
if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'OPTIONS') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'error' => 'Method not allowed. This endpoint is READ ONLY.',
        'method_received' => $_SERVER['REQUEST_METHOD']
    ]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Log every request for debugging
$logEntry = date('Y-m-d H:i:s') . " - SYNC REQUEST\n";
$logEntry .= "IP: " . $_SERVER['REMOTE_ADDR'] . "\n";
$logEntry .= "User-Agent: " . ($_SERVER['HTTP_USER_AGENT'] ?? 'unknown') . "\n";
$logEntry .= "Query: " . ($_SERVER['QUERY_STRING'] ?? 'none') . "\n";
$logEntry .= "Method: " . $_SERVER['REQUEST_METHOD'] . "\n\n";
file_put_contents('sync_requests.log', $logEntry, FILE_APPEND);

// Database connection
require_once '../connection.php';

try {
    // Get parameters
    $clock_date = isset($_GET['clock_date']) ? $_GET['clock_date'] : null;
    $classID = isset($_GET['classID']) ? $_GET['classID'] : null;
    
    // Log parameters
    error_log("[SAFE_SYNC] clock_date: " . ($clock_date ?? 'all'));
    error_log("[SAFE_SYNC] classID: " . ($classID ?? 'all'));
    
    // Build SELECT query (READ ONLY)
    $sql = "SELECT 
                lc.clocking_id,
                lc.LearnerID,
                lc.clock_date,
                lc.clock_in_time,
                lc.clock_out_time,
                lc.contact_time,
                lc.signature,
                lc.synced,
                lc.user_latitude,
                lc.user_longitude,
                lc.user_accuracy
            FROM learner_clocking lc";
    
    $whereClauses = [];
    $params = [];
    $types = "";
    
    if ($clock_date) {
        $whereClauses[] = "lc.clock_date = ?";
        $params[] = $clock_date;
        $types .= "s";
    }
    
    if ($classID) {
        $sql .= " INNER JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID";
        $whereClauses[] = "ld.classID = ?";
        $params[] = $classID;
        $types .= "s";
    }
    
    if (count($whereClauses) > 0) {
        $sql .= " WHERE " . implode(" AND ", $whereClauses);
    }
    
    $sql .= " ORDER BY lc.clocking_id DESC";
    
    error_log("[SAFE_SYNC] SQL: " . $sql);
    
    $stmt = $conn->prepare($sql);
    
    if (!$stmt) {
        throw new Exception("Failed to prepare SELECT statement: " . $conn->error);
    }
    
    if (count($params) > 0) {
        $stmt->bind_param($types, ...$params);
    }
    
    if (!$stmt->execute()) {
        throw new Exception("Failed to execute SELECT statement: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $clockingData = [];
    
    while ($row = $result->fetch_assoc()) {
        $clockingData[] = $row;
    }
    
    $count = count($clockingData);
    error_log("[SAFE_SYNC] Returning $count records (READ ONLY)");
    
    // Return data
    echo json_encode($clockingData);
    
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    error_log("[SAFE_SYNC] ERROR: " . $e->getMessage());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Database error: ' . $e->getMessage()
    ]);
    
    if (isset($conn)) {
        $conn->close();
    }
}
?>
