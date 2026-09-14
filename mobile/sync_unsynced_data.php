<?php

require_once __DIR__ . '/../security_functions.php';
// General Bulk Sync API for Unsynced Data (Clocking, etc.)
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
    
    foreach ($records as $record) {
        try {
            $type = $record['type'] ?? 'unknown';
            $learnerId = $record['LearnerID'] ?? $record['learner_id'] ?? null;
            
            if (!$learnerId) continue;
            
            if ($type === 'clock_in' || isset($record['clock_in_time'])) {
                // Handle clock-in sync
                $date = $record['clock_date'] ?? date('Y-m-d');
                $time = $record['clock_in_time'];
                $lat = $record['user_latitude'] ?? null;
                $lon = $record['user_longitude'] ?? null;
                $acc = $record['user_accuracy'] ?? null;
                
                // Check if already exists
                $check = $conn->prepare("SELECT id FROM learner_clocking WHERE LearnerID = ? AND clock_date = ?");
                $check->bind_param("is", $learnerId, $date);
                $check->execute();
                if ($check->get_result()->num_rows > 0) {
                    // Update existing
                    $stmt = $conn->prepare("UPDATE learner_clocking SET clock_in_time = ?, user_latitude = ?, user_longitude = ?, user_accuracy = ?, synced = 1 WHERE LearnerID = ? AND clock_date = ?");
                    $stmt->bind_param("sssiis", $time, $lat, $lon, $acc, $learnerId, $date);
                } else {
                    // Insert new
                    $stmt = $conn->prepare("INSERT INTO learner_clocking (LearnerID, clock_date, clock_in_time, user_latitude, user_longitude, user_accuracy, synced) VALUES (?, ?, ?, ?, ?, ?, 1)");
                    $stmt->bind_param("issssi", $learnerId, $date, $time, $lat, $lon, $acc);
                }
                
                if ($stmt->execute()) {
                    $successCount++;
                }
                $stmt->close();
                $check->close();
            } else if ($type === 'clock_out' || isset($record['clock_out_time'])) {
                // Handle clock-out sync
                $date = $record['clock_date'] ?? date('Y-m-d');
                $outTime = $record['clock_out_time'];
                $contactTime = $record['contact_time'] ?? null;
                
                $stmt = $conn->prepare("UPDATE learner_clocking SET clock_out_time = ?, contact_time = ?, synced = 1 WHERE LearnerID = ? AND clock_date = ?");
                $stmt->bind_param("ssis", $outTime, $contactTime, $learnerId, $date);
                if ($stmt->execute()) {
                    $successCount++;
                }
                $stmt->close();
            }
        } catch (Exception $recordError) {
            $errors[] = "Error syncing record for learner $learnerId: " . $recordError->getMessage();
        }
    }
    
    echo json_encode([
        'success' => true,
        'status' => 'success',
        'message' => "Synced $successCount records successfully",
        'count' => $successCount,
        'errors' => $errors
    ]);
    
} catch (Exception $e) {
    error_log("[SYNC_UNSYNCED] ❌ Error: " . $e->getMessage());
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
