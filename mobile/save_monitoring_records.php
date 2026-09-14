<?php
require_once __DIR__ . '/../security_functions.php';
// Save single monitoring record (Robust Online/Offline approach)
error_reporting(E_ALL);
ini_set('log_errors', 1);
ini_set('display_errors', 0);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

require_once 'connection.php';

try {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Invalid JSON input');
    }
    
    // Extract data
    $learnerId = strval($data['learner_id']);
    $learnerName = $data['learner_name'] ?? 'Unknown';
    $personType = $data['person_type'] ?? 'learner';
    $classId = $data['class_id'] ?? null;
    $monitoringDate = $data['monitoring_date'];
    $attempt1Time = $data['attempt_1_time'] ?? null;
    $attempt1Status = $data['attempt_1_status'] ?? null;
    $attempt2Time = $data['attempt_2_time'] ?? null;
    $attempt2Status = $data['attempt_2_status'] ?? null;
    $attempt3Time = $data['attempt_3_time'] ?? null;
    $attempt3Status = $data['attempt_3_status'] ?? null;
    $finalStatus = $data['final_status'];
    $verificationTime = $data['verification_time'] ?? null;
    $verificationMethod = $data['verification_method'] ?? null;
    $scannerType = $data['scanner_type'] ?? null;
    $fingerprintMatched = intval($data['fingerprint_matched'] ?? 0);
    $sessionType = $data['session_type'] ?? null;
    $createdAt = $data['created_at'];
    
    // Check if record already exists based on Learner and Date
    // This prevents duplicates for the same date for the same learnerid
    $checkStmt = $conn->prepare("SELECT id FROM monitoring_records WHERE learner_id = ? AND monitoring_date = ? LIMIT 1");
    $checkStmt->bind_param("ss", $learnerId, $monitoringDate);
    $checkStmt->execute();
    $result = $checkStmt->get_result();
    
    if ($result->num_rows > 0) {
        $existing = $result->fetch_assoc();
        $stmt = $conn->prepare("UPDATE monitoring_records SET attempt_1_time=?, attempt_1_status=?, attempt_2_time=?, attempt_2_status=?, attempt_3_time=?, attempt_3_status=?, final_status=?, fingerprint_matched=?, session_type=? WHERE id=?");
        $stmt->bind_param("ssssssisii", $attempt1Time, $attempt1Status, $attempt2Time, $attempt2Status, $attempt3Time, $attempt3Status, $finalStatus, $fingerprintMatched, $sessionType, $existing['id']);
        $action = 'update';
    } else {
        $stmt = $conn->prepare("INSERT INTO monitoring_records (learner_id, learner_name, person_type, class_id, monitoring_date, attempt_1_time, attempt_1_status, attempt_2_time, attempt_2_status, attempt_3_time, attempt_3_status, final_status, verification_time, verification_method, scanner_type, fingerprint_matched, session_type, created_at, synced) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)");
        $stmt->bind_param("sssssssssssssssiss", $learnerId, $learnerName, $personType, $classId, $monitoringDate, $attempt1Time, $attempt1Status, $attempt2Time, $attempt2Status, $attempt3Time, $attempt3Status, $finalStatus, $verificationTime, $verificationMethod, $scannerType, $fingerprintMatched, $sessionType, $createdAt);
        $action = 'insert';
    }
    
    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'status' => 'success',
            'message' => 'Monitoring record saved successfully',
            'action' => $action
        ]);
    } else {
        throw new Exception($stmt->error);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'status' => 'error', 'error' => $e->getMessage()]);
}
?>