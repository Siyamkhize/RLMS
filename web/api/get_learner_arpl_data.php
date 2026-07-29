<?php
/**
 * Get Complete ARPL Data for Learner
 * Fetches all data needed for ARPL portfolio generation
 * 
 * Endpoint: POST web/api/get_learner_arpl_data.php
 * 
 * Request:
 * {
 *   "learnerID": 16389,
 *   "ofo_code": "671101"
 * }
 * 
 * Response:
 * {
 *   "status": "success",
 *   "learner": {...},
 *   "trade": {...},
 *   "appendices": {...},
 *   "poe_data": {...}
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
    
    $learnerID = isset($data['learnerID']) ? intval($data['learnerID']) : 0;
    $ofo_code = isset($data['ofo_code']) ? trim($data['ofo_code']) : '';
    
    if ($learnerID <= 0 || empty($ofo_code)) {
        throw new Exception('Missing or invalid learnerID or ofo_code parameter');
    }
    
    // 1. Get learner details
    $sql_learner = "
        SELECT 
            learnerID,
            name,
            surname,
            idNumber,
            gender,
            dateOfBirth,
            email,
            cellphone,
            classID
        FROM learnerdetails
        WHERE learnerID = ?
    ";
    
    $stmt = $conn->prepare($sql_learner);
    if (!$stmt) {
        throw new Exception('Database error: ' . $conn->error);
    }
    
    $stmt->bind_param('i', $learnerID);
    if (!$stmt->execute()) {
        throw new Exception('Query execution failed: ' . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $learner = $result->fetch_assoc();
    $stmt->close();
    
    if (!$learner) {
        throw new Exception('Learner not found');
    }
    
    // 2. Get trade information
    $tradeNames = [
        '671101' => ['name' => 'Electrician', 'nqf_level' => 4],
        '641201' => ['name' => 'Bricklaying', 'nqf_level' => 4],
        '642601' => ['name' => 'Plumbing', 'nqf_level' => 4],
        '651302' => ['name' => 'Welding', 'nqf_level' => 4]
    ];
    
    $trade = isset($tradeNames[$ofo_code]) ? $tradeNames[$ofo_code] : [
        'name' => 'Unknown Trade',
        'nqf_level' => 4
    ];
    $trade['ofo_code'] = $ofo_code;
    
    // 3. Get appendices data (theory papers, practical assessment, etc)
    // This is where ARPL specific assessment data would be stored
    $sql_appendices = "
        SELECT 
            appendix_type,
            content,
            created_date
        FROM arpl_appendices
        WHERE learnerID = ? AND ofo_code = ?
        ORDER BY appendix_type ASC
    ";
    
    $stmt = $conn->prepare($sql_appendices);
    $stmt->bind_param('is', $learnerID, $ofo_code);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $appendices = [];
    while ($row = $result->fetch_assoc()) {
        $appendices[$row['appendix_type']] = $row['content'];
    }
    $stmt->close();
    
    // 4. Get POE (Proof of Evidence) documents
    $sql_poe = "
        SELECT 
            poetype,
            file_path,
            upload_date
        FROM arpl_poe
        WHERE learnerID = ? AND ofo_code = ?
        ORDER BY poetype ASC
    ";
    
    $stmt = $conn->prepare($sql_poe);
    $stmt->bind_param('is', $learnerID, $ofo_code);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $poe_data = [];
    while ($row = $result->fetch_assoc()) {
        if (!isset($poe_data[$row['poetype']])) {
            $poe_data[$row['poetype']] = [];
        }
        $poe_data[$row['poetype']][] = [
            'file_path' => $row['file_path'],
            'upload_date' => $row['upload_date']
        ];
    }
    $stmt->close();
    
    // 5. Calculate age from ID number (South African ID format: YYMMDDSSSS)
    $dob = null;
    if (strlen($learner['idNumber']) >= 6) {
        $yy = substr($learner['idNumber'], 0, 2);
        $mm = substr($learner['idNumber'], 2, 2);
        $dd = substr($learner['idNumber'], 4, 2);
        
        // Determine century
        $year = (intval($yy) <= 30) ? 2000 + intval($yy) : 1900 + intval($yy);
        
        $dob = sprintf('%04d-%02d-%02d', $year, intval($mm), intval($dd));
    }
    
    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'learner' => [
            'learnerID' => intval($learner['learnerID']),
            'fullName' => trim($learner['name'] . ' ' . $learner['surname']),
            'firstName' => $learner['name'],
            'lastName' => $learner['surname'],
            'idNumber' => $learner['idNumber'],
            'gender' => $learner['gender'],
            'dateOfBirth' => $dob,
            'email' => $learner['email'],
            'cellphone' => $learner['cellphone'],
            'classID' => intval($learner['classID'])
        ],
        'trade' => $trade,
        'appendices' => $appendices,
        'poe_data' => $poe_data,
        'generation_date' => date('Y-m-d H:i:s'),
        'portfolio_pages' => 24
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
