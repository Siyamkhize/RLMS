<?php

require_once __DIR__ . '/../security_functions.php';
// Bulk save monitoring records (Sync approach)
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

// Include database connection
require_once 'connection.php';

try {
    // Get POST data
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Invalid JSON input: ' . json_last_error_msg());
    }
    
    // Check if it's a single record or a list of records
    $records = isset($data['records']) ? $data['records'] : [$data];
    
    if (empty($records)) {
        echo json_encode(['success' => true, 'message' => 'No records to sync', 'count' => 0]);
        exit;
    }
    
    $successCount = 0;
    $errors = [];
    
    // Prepare statements
    $checkStmt = $conn->prepare("
        SELECT id FROM monitoring_records 
        WHERE learner_id = ? AND monitoring_date = ? AND created_at = ?
        LIMIT 1
    ");
    
    $updateStmt = $conn->prepare("
        UPDATE monitoring_records SET
            learner_name = ?,
            person_type = ?,
            class_id = ?,
            attempt_1_time = ?,
            attempt_1_status = ?,
            attempt_2_time = ?,
            attempt_2_status = ?,
            attempt_3_time = ?,
            attempt_3_status = ?,
            final_status = ?,
            verification_time = ?,
            verification_method = ?,
            scanner_type = ?,
            fingerprint_matched = ?,
            session_type = ?
        WHERE id = ?
    ");
    
    $insertStmt = $conn->prepare("
        INSERT INTO monitoring_records (
            learner_id, learner_name, person_type, class_id,
            monitoring_date, attempt_1_time, attempt_1_status,
            attempt_2_time, attempt_2_status,
            attempt_3_time, attempt_3_status,
            final_status, verification_time, verification_method,
            scanner_type, fingerprint_matched, session_type, created_at, synced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
    ");
    
    foreach ($records as $record) {
        try {
            // Validate required fields
            if (empty($record['learner_id']) || empty($record['monitoring_date']) || empty($record['created_at'])) {
                continue;
            }
            
            $learnerId = strval($record['learner_id']);
            $learnerName = $record['learner_name'] ?? 'Unknown';
            $personType = $record['person_type'] ?? 'learner';
            $classId = $record['class_id'] ?? null;
            $monitoringDate = $record['monitoring_date'];
            $attempt1Time = $record['attempt_1_time'] ?? null;
            $attempt1Status = $record['attempt_1_status'] ?? null;
            $attempt2Time = $record['attempt_2_time'] ?? null;
            $attempt2Status = $record['attempt_2_status'] ?? null;
            $attempt3Time = $record['attempt_3_time'] ?? null;
            $attempt3Status = $record['attempt_3_status'] ?? null;
            $finalStatus = $record['final_status'] ?? 'UNKNOWN';
            $verificationTime = $record['verification_time'] ?? null;
            $verificationMethod = $record['verification_method'] ?? null;
            $scannerType = $record['scanner_type'] ?? null;
            $fingerprintMatched = intval($record['fingerprint_matched'] ?? 0);
            $sessionType = $record['session_type'] ?? null;
            $createdAt = $record['created_at'];
            
            // Check if exists
            $checkStmt->bind_param("sss", $learnerId, $monitoringDate, $createdAt);
            $checkStmt->execute();
            $checkResult = $checkStmt->get_result();
            
            if ($checkResult->num_rows > 0) {
                $existing = $checkResult->fetch_assoc();
                $updateStmt->bind_param("sssssssssssssisi",
                    $learnerName, $personType, $classId,
                    $attempt1Time, $attempt1Status,
                    $attempt2Time, $attempt2Status,
                    $attempt3Time, $attempt3Status,
                    $finalStatus, $verificationTime, $verificationMethod,
                    $scannerType, $fingerprintMatched, $sessionType,
                    $existing['id']
                );
                if ($updateStmt->execute()) {
                    $successCount++;
                }
            } else {
                $insertStmt->bind_param("sssssssssssssssiss",
                    $learnerId, $learnerName, $personType, $classId,
                    $monitoringDate, $attempt1Time, $attempt1Status,
                    $attempt2Time, $attempt2Status,
                    $attempt3Time, $attempt3Status,
                    $finalStatus, $verificationTime, $verificationMethod,
                    $scannerType, $fingerprintMatched, $sessionType,
                    $createdAt
                );
                if ($insertStmt->execute()) {
                    $successCount++;
                }
            }
        } catch (Exception $recordError) {
            $errors[] = "Error with learner {$record['learner_id']}: " . $recordError->getMessage();
        }
    }
    
    $checkStmt->close();
    $updateStmt->close();
    $insertStmt->close();
    
    echo json_encode([
        'success' => true,
        'status' => 'success',
        'message' => "Synced $successCount records successfully",
        'count' => $successCount,
        'errors' => $errors
    ]);
    
} catch (Exception $e) {
    error_log("[SYNC_MONITORING] ❌ Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'status' => 'error',
        'error' => $e->getMessage()
    ]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>
