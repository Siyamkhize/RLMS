<?php

require_once __DIR__ . '/../security_functions.php';
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'config.php';

// Enable error logging
error_log("[MONITORING_CLOCKIN] Request received at " . date('Y-m-d H:i:s'));

try {
    // Get JSON input
    $input = file_get_contents('php://input');
    error_log("[MONITORING_CLOCKIN] Raw input: " . substr($input, 0, 500));
    
    $data = json_decode($input, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Invalid JSON: ' . json_last_error_msg());
    }
    
    // Validate required fields
    $required = ['person_id', 'person_name', 'person_type', 'class_id', 'monitoring_date', 
                 'monitoring_time', 'verification_status', 'session_type'];
    
    foreach ($required as $field) {
        if (!isset($data[$field]) || empty($data[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    // Extract data with defaults
    $person_id = $data['person_id'];
    $person_name = $data['person_name'];
    $person_type = $data['person_type']; // 'learner' or 'facilitator'
    $class_id = $data['class_id'];
    $monitoring_date = $data['monitoring_date'];
    $monitoring_time = $data['monitoring_time'];
    $monitoring_datetime = $monitoring_date . ' ' . $monitoring_time;
    $verification_status = $data['verification_status']; // 'PRESENT', 'ABSENT', 'PENDING'
    $session_type = $data['session_type']; // 'morning' or 'afternoon'
    
    // Optional fields
    $verification_method = $data['verification_method'] ?? 'fingerprint_zkteco';
    $attempt_number = $data['attempt_number'] ?? 1;
    $is_lunch_break = isset($data['is_lunch_break']) ? (int)$data['is_lunch_break'] : 0;
    $fingerprint_matched = isset($data['fingerprint_matched']) ? (int)$data['fingerprint_matched'] : 0;
    $scanner_type = $data['scanner_type'] ?? null;
    
    error_log("[MONITORING_CLOCKIN] Processing: Person=$person_id, Type=$person_type, Status=$verification_status, Date=$monitoring_date");
    
    // Check for duplicate entry (same person, same date)
    // We remove session_type from check to ensure only one record per day per learner as requested
    $check_sql = "SELECT id FROM monitoring_clockin 
                  WHERE person_id = ? 
                  AND monitoring_date = ? 
                  LIMIT 1";
    
    $check_stmt = $conn->prepare($check_sql);
    $check_stmt->bind_param("ss", $person_id, $monitoring_date);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    
    if ($check_result->num_rows > 0) {
        // Update existing record instead of creating duplicate
        $existing = $check_result->fetch_assoc();
        $update_sql = "UPDATE monitoring_clockin 
                       SET verification_status = ?,
                           monitoring_time = ?,
                           monitoring_datetime = ?,
                           verification_method = ?,
                           attempt_number = ?,
                           fingerprint_matched = ?,
                           scanner_type = ?,
                           synced = 1,
                           updated_at = NOW()
                       WHERE id = ?";
        
        $update_stmt = $conn->prepare($update_sql);
        $update_stmt->bind_param("ssssiisi", 
            $verification_status,
            $monitoring_time,
            $monitoring_datetime,
            $verification_method,
            $attempt_number,
            $fingerprint_matched,
            $scanner_type,
            $existing['id']
        );
        
        if ($update_stmt->execute()) {
            error_log("[MONITORING_CLOCKIN] Updated existing record ID: " . $existing['id']);
            echo json_encode([
                'success' => true,
                'message' => 'Monitoring clock-in updated successfully',
                'record_id' => $existing['id'],
                'action' => 'updated'
            ]);
        } else {
            throw new Exception('Failed to update record: ' . $update_stmt->error);
        }
        
        $update_stmt->close();
    } else {
        // Insert new record
        $insert_sql = "INSERT INTO monitoring_clockin (
            person_id, person_name, person_type, class_id,
            monitoring_date, monitoring_time, monitoring_datetime,
            verification_method, verification_status, attempt_number,
            session_type, is_lunch_break,
            fingerprint_matched, scanner_type,
            synced, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())";
        
        $insert_stmt = $conn->prepare($insert_sql);
        $insert_stmt->bind_param("sssssssssissis",
            $person_id,
            $person_name,
            $person_type,
            $class_id,
            $monitoring_date,
            $monitoring_time,
            $monitoring_datetime,
            $verification_method,
            $verification_status,
            $attempt_number,
            $session_type,
            $is_lunch_break,
            $fingerprint_matched,
            $scanner_type
        );
        
        if ($insert_stmt->execute()) {
            $record_id = $insert_stmt->insert_id;
            error_log("[MONITORING_CLOCKIN] Inserted new record ID: $record_id");
            
            echo json_encode([
                'success' => true,
                'message' => 'Monitoring clock-in saved successfully',
                'record_id' => $record_id,
                'action' => 'inserted'
            ]);
        } else {
            throw new Exception('Failed to insert record: ' . $insert_stmt->error);
        }
        
        $insert_stmt->close();
    }
    
    $check_stmt->close();
    
} catch (Exception $e) {
    error_log("[MONITORING_CLOCKIN] Error: " . $e->getMessage());
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

$conn->close();
?>
