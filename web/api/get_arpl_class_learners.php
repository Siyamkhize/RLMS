<?php
/**
 * Get ARPL Learners by Class
 * For ARPL, learners are registered in classes that belong to specific trades
 * 
 * Endpoint: POST web/api/get_arpl_class_learners.php
 * 
 * Request:
 * {
 *   "classID": 783
 * }
 * 
 * Response:
 * {
 *   "status": "success",
 *   "learners": [...],
 *   "count": 25
 * }
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

ini_set('display_errors', 0);
error_reporting(E_ALL);

$root_conn_file = __DIR__ . '/../connection.php';
if (!file_exists($root_conn_file)) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Connection file not found'
    ]);
    exit;
}

@require_once $root_conn_file;

try {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Invalid JSON request');
    }
    
    if (!isset($conn) || !$conn) {
        throw new Exception('Database connection failed');
    }
    
    $classID = isset($data['classID']) ? intval($data['classID']) : 0;
    
    if ($classID <= 0) {
        throw new Exception('Missing or invalid classID parameter');
    }
    
    // Get learners from learnerdetails table for this ARPL class
    // ARPL learners are linked to classes via classID in learnerdetails table
    $sql = "
        SELECT 
            ld.learnerID,
            CONCAT(COALESCE(ld.name, ''), ' ', COALESCE(ld.surname, '')) as learnerName,
            ld.idNumber,
            ld.gender,
            ld.classID
        FROM learnerdetails ld
        WHERE ld.classID = ?
        ORDER BY ld.surname ASC, ld.name ASC
    ";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Database error: ' . $conn->error);
    }
    
    $stmt->bind_param('i', $classID);
    if (!$stmt->execute()) {
        throw new Exception('Query execution failed: ' . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $learners = [];
    
    while ($row = $result->fetch_assoc()) {
        $learners[] = [
            'learnerID' => intval($row['learnerID']),
            'learnerName' => trim($row['learnerName']) ?: 'Unknown',
            'idNumber' => $row['idNumber'] ?? '',
            'gender' => $row['gender'] ?? '',
            'status' => 'Enrolled',
            'classID' => intval($row['classID'])
        ];
    }
    $stmt->close();
    
    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'classID' => $classID,
        'learners' => $learners,
        'count' => count($learners)
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}

