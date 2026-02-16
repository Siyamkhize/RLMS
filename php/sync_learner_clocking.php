<?php
/**
 * Sync Learner Clocking Data - READ ONLY
 * 
 * CRITICAL: This endpoint ONLY reads data, NEVER inserts!
 * 
 * Supports date and classID filtering:
 * - Get all records: sync_learner_clocking.php
 * - Get specific date: sync_learner_clocking.php?clock_date=2025-10-11
 * - Get specific class + date: sync_learner_clocking.php?clock_date=2025-10-11&classID=123
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// CRITICAL: Only allow GET requests - prevents accidental data insertion
if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'OPTIONS') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'error' => 'Method not allowed. This endpoint is READ ONLY.'
    ]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Database connection
require_once '../connection.php';

try {
    // Log the request for debugging
    error_log("[SYNC_READ] ========== SYNC REQUEST STARTED ==========");
    error_log("[SYNC_READ] Method: " . $_SERVER['REQUEST_METHOD']);
    error_log("[SYNC_READ] Query String: " . ($_SERVER['QUERY_STRING'] ?? 'none'));
    
    // Check if parameters are provided
    $clock_date = isset($_GET['clock_date']) ? $_GET['clock_date'] : null;
    $classID = isset($_GET['classID']) ? $_GET['classID'] : null;
    
    error_log("[SYNC_READ] clock_date: " . ($clock_date ?? 'all dates'));
    error_log("[SYNC_READ] classID: " . ($classID ?? 'all classes'));
    
    // Build SQL query based on provided parameters
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
    
    // Add JOIN if classID is provided (need to filter by learner's class)
    if ($classID) {
        $sql .= " INNER JOIN learnerdetails ld ON lc.LearnerID = ld.LearnerID";
    }
    
    // Build WHERE clause
    $whereClauses = array();
    $params = array();
    $types = "";
    
    if ($clock_date) {
        $whereClauses[] = "lc.clock_date = ?";
        $params[] = $clock_date;
        $types .= "s";
    }
    
    if ($classID) {
        $whereClauses[] = "ld.classID = ?";
        $params[] = $classID;
        $types .= "s";
    }
    
    if (count($whereClauses) > 0) {
        $sql .= " WHERE " . implode(" AND ", $whereClauses);
    }
    
    $sql .= " ORDER BY lc.clocking_id DESC";
    
    error_log("[SYNC_READ] SQL: " . $sql);
    error_log("[SYNC_READ] Params: " . json_encode($params));
    
    $stmt = $conn->prepare($sql);
    
    if (!$stmt) {
        throw new Exception("Failed to prepare statement: " . $conn->error);
    }
    
    // Bind parameters if any
    if (count($params) > 0) {
        $stmt->bind_param($types, ...$params);
    }
    
    if (!$stmt->execute()) {
        throw new Exception("Failed to execute statement: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    
    $clockingData = array();
    while ($row = $result->fetch_assoc()) {
        $clockingData[] = $row;
    }
    
    $count = count($clockingData);
    
    error_log("[SYNC_READ] Returning $count records");
    error_log("[SYNC_READ] ========== SYNC REQUEST COMPLETE ==========");
    
    // Return data
    echo json_encode($clockingData);
    
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    error_log("[SYNC_READ] ========== ERROR ==========");
    error_log("[SYNC_READ] Error: " . $e->getMessage());
    error_log("[SYNC_READ] Trace: " . $e->getTraceAsString());
    
    http_response_code(500);
    echo json_encode(array(
        'success' => false,
        'error' => 'Database error: ' . $e->getMessage()
    ));
    
    if (isset($conn)) {
        $conn->close();
    }
}
?>

