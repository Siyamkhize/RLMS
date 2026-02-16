<?php
// clockin_debug.php - Enhanced clockin.php with comprehensive logging

header('Content-Type: application/json');
include 'connection.php';
include 'clocking_debug_logger.php';

$response = array("success" => false, "message" => "Unknown error occurred");

try {
    logClockingEvent('INFO', 'CLOCK-IN REQUEST STARTED', [
        'post_data' => $_POST,
        'request_time' => date('Y-m-d H:i:s'),
        'request_method' => $_SERVER['REQUEST_METHOD']
    ]);

    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        // Extract data
        $learnerID = $_POST['LearnerID'] ?? null;
        $currentTime = date('Y-m-d H:i:s');
        $currentDate = date('Y-m-d');
        $isSynced = isset($_POST['isSynced']) ? (int)$_POST['isSynced'] : 0;
        $userLatitude = isset($_POST['user_latitude']) ? floatval($_POST['user_latitude']) : 0.0;
        $userLongitude = isset($_POST['user_longitude']) ? floatval($_POST['user_longitude']) : 0.0;
        $userAccuracy = isset($_POST['user_accuracy']) ? floatval($_POST['user_accuracy']) : 50.0;
        $classID = $_POST['classID'] ?? null;

        logClockIn($learnerID, 'mobile_app', [
            'class_id' => $classID,
            'latitude' => $userLatitude,
            'longitude' => $userLongitude,
            'accuracy' => $userAccuracy,
            'synced' => $isSynced
        ]);

        // Get database state before clock-in
        global $clockingLogger;
        $clockingLogger->conn = $conn;
        $beforeState = $clockingLogger->getCurrentDatabaseState($learnerID, $currentDate);

        // Validate inputs
        if (empty($learnerID) || empty($classID)) {
            $reason = "Invalid input data: " . 
                      (empty($learnerID) ? "Missing LearnerID" : "") . 
                      (empty($classID) ? " Missing classID" : "");
            
            logClockingEvent('ERROR', 'Clock-in validation failed', [
                'learner_id' => $learnerID,
                'reason' => $reason,
                'provided_data' => $_POST
            ]);
            
            $response['message'] = $reason;
            echo json_encode($response);
            exit;
        }

        // Check if learner exists
        $learnerCheck = $conn->prepare("SELECT * FROM learnerdetails WHERE LearnerID = ?");
        $learnerCheck->bind_param("i", $learnerID);
        $learnerCheck->execute();
        $learnerResult = $learnerCheck->get_result();

        if ($learnerResult->num_rows == 0) {
            logClockingEvent('ERROR', 'Learner not found', [
                'learner_id' => $learnerID
            ]);
            $response['message'] = "Learner not found";
            echo json_encode($response);
            exit;
        }
        $learnerCheck->close();

        // Check if already clocked in today
        $stmt = $conn->prepare("SELECT * FROM learner_clocking WHERE LearnerID = ? AND clock_date = ?");
        $stmt->bind_param("is", $learnerID, $currentDate);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            $existingRecord = $result->fetch_assoc();
            
            logClockingEvent('WARNING', 'Duplicate clock-in attempt', [
                'learner_id' => $learnerID,
                'existing_record' => $existingRecord,
                'new_attempt_time' => $currentTime
            ]);

            if (!empty($existingRecord['clock_in_time'])) {
                $response['success'] = true;
                $response['message'] = "Already clocked in today at " . $existingRecord['clock_in_time'];
                echo json_encode($response);
                exit;
            }
        }
        $stmt->close();

        // Insert or update clock-in record
        $stmt = $conn->prepare("INSERT INTO learner_clocking (LearnerID, clock_date, clock_in_time, synced, user_latitude, user_longitude, user_accuracy) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE clock_in_time = VALUES(clock_in_time), synced = VALUES(synced), user_latitude = VALUES(user_latitude), user_longitude = VALUES(user_longitude), user_accuracy = VALUES(user_accuracy)");
        
        if (!$stmt) {
            logClockingEvent('ERROR', 'Failed to prepare clock-in statement', [
                'error' => $conn->error,
                'learner_id' => $learnerID
            ]);
            $response['message'] = "Database prepare error";
            echo json_encode($response);
            exit;
        }

        $stmt->bind_param("issidd", $learnerID, $currentDate, $currentTime, $isSynced, $userLatitude, $userLongitude);
        
        logDbUpdate('learner_clocking', [
            'LearnerID' => $learnerID,
            'clock_date' => $currentDate,
            'clock_in_time' => $currentTime,
            'synced' => $isSynced,
            'user_latitude' => $userLatitude,
            'user_longitude' => $userLongitude,
            'user_accuracy' => $userAccuracy
        ]);

        if ($stmt->execute()) {
            logClockingEvent('SUCCESS', 'Clock-in recorded successfully', [
                'learner_id' => $learnerID,
                'clock_in_time' => $currentTime,
                'affected_rows' => $stmt->affected_rows
            ]);

            $response['success'] = true;
            $response['message'] = 'Clock-in successful';
            $response['clock_in_time'] = $currentTime;
            $response['learner_id'] = $learnerID;
            
            // Get database state after clock-in
            $afterState = $clockingLogger->getCurrentDatabaseState($learnerID, $currentDate);
            
            // Check for any unexpected changes
            if ($afterState && isset($afterState['learner_clocking']['clock_out_time']) && 
                !empty($afterState['learner_clocking']['clock_out_time'])) {
                logAutoClockOut($learnerID, 'Clock-out time appeared immediately after clock-in', [
                    'before_state' => $beforeState,
                    'after_state' => $afterState
                ]);
            }
            
        } else {
            logClockingEvent('ERROR', 'Failed to execute clock-in', [
                'error' => $stmt->error,
                'learner_id' => $learnerID
            ]);
            $response['message'] = "Failed to record clock-in: " . $stmt->error;
        }

        $stmt->close();

    } else {
        logClockingEvent('ERROR', 'Invalid request method', [
            'method' => $_SERVER['REQUEST_METHOD']
        ]);
        $response['message'] = "Invalid request method";
    }

    logClockingEvent('INFO', 'CLOCK-IN RESPONSE SENT', [
        'learner_id' => $learnerID ?? 'unknown',
        'response' => $response
    ]);

} catch (Exception $e) {
    logClockingEvent('CRITICAL', 'Exception in clock-in', [
        'error' => $e->getMessage(),
        'trace' => $e->getTraceAsString(),
        'learner_id' => $learnerID ?? 'unknown'
    ]);
    
    $response['success'] = false;
    $response['message'] = 'Server error occurred';
    $response['error_details'] = $e->getMessage();
}

$conn->close();
echo json_encode($response);
?>