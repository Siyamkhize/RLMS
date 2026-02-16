<?php
// clockout_debug.php - Enhanced clockout.php with comprehensive logging

header('Content-Type: application/json');
include 'connection.php';
include 'clocking_debug_logger.php';

$response = array("success" => false, "message" => "Unknown error occurred");

try {
    logClockingEvent('INFO', 'CLOCK-OUT REQUEST STARTED', [
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

        logClockOut($learnerID, 'mobile_app', [
            'class_id' => $classID,
            'latitude' => $userLatitude,
            'longitude' => $userLongitude,
            'accuracy' => $userAccuracy,
            'synced' => $isSynced
        ]);

        // Get database state before clock-out
        global $clockingLogger;
        $clockingLogger->conn = $conn;
        $beforeState = $clockingLogger->getCurrentDatabaseState($learnerID, $currentDate);

        // Validate inputs
        if (empty($learnerID) || empty($classID)) {
            $reason = "Invalid input data: " . 
                      (empty($learnerID) ? "Missing LearnerID" : "") . 
                      (empty($classID) ? " Missing classID" : "");
            
            logClockingEvent('ERROR', 'Clock-out validation failed', [
                'learner_id' => $learnerID,
                'reason' => $reason,
                'provided_data' => $_POST
            ]);
            
            $response['message'] = $reason;
            echo json_encode($response);
            exit;
        }

        // Check if learner has clocked in today
        $stmt = $conn->prepare("SELECT * FROM learner_clocking WHERE LearnerID = ? AND clock_date = ?");
        $stmt->bind_param("is", $learnerID, $currentDate);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows == 0) {
            logClockingEvent('ERROR', 'No clock-in record found for clock-out', [
                'learner_id' => $learnerID,
                'clock_date' => $currentDate
            ]);
            $response['message'] = "No clock-in record found for today";
            echo json_encode($response);
            exit;
        }

        $clockingRecord = $result->fetch_assoc();
        $stmt->close();

        // Check if already clocked out
        if (!empty($clockingRecord['clock_out_time'])) {
            logClockingEvent('WARNING', 'Duplicate clock-out attempt', [
                'learner_id' => $learnerID,
                'existing_clock_out' => $clockingRecord['clock_out_time'],
                'new_attempt_time' => $currentTime
            ]);

            $response['success'] = true;
            $response['message'] = "Already clocked out today at " . $clockingRecord['clock_out_time'];
            $response['clock_in_time'] = $clockingRecord['clock_in_time'];
            $response['clock_out_time'] = $clockingRecord['clock_out_time'];
            echo json_encode($response);
            exit;
        }

        // Calculate contact time
        $contactTime = null;
        if (!empty($clockingRecord['clock_in_time'])) {
            try {
                $clockInTime = new DateTime($clockingRecord['clock_in_time']);
                $clockOutTime = new DateTime($currentTime);
                $interval = $clockOutTime->diff($clockInTime);
                $contactTime = $interval->format('%H:%i:%s');
                
                logClockingEvent('DEBUG', 'Contact time calculated', [
                    'learner_id' => $learnerID,
                    'clock_in' => $clockingRecord['clock_in_time'],
                    'clock_out' => $currentTime,
                    'contact_time' => $contactTime
                ]);
            } catch (Exception $e) {
                logClockingEvent('WARNING', 'Failed to calculate contact time', [
                    'learner_id' => $learnerID,
                    'error' => $e->getMessage()
                ]);
            }
        }

        // Update with clock-out time
        $stmt = $conn->prepare("UPDATE learner_clocking SET clock_out_time = ?, contact_time = ?, synced = ? WHERE LearnerID = ? AND clock_date = ?");
        
        if (!$stmt) {
            logClockingEvent('ERROR', 'Failed to prepare clock-out statement', [
                'error' => $conn->error,
                'learner_id' => $learnerID
            ]);
            $response['message'] = "Database prepare error";
            echo json_encode($response);
            exit;
        }

        $stmt->bind_param("ssiss", $currentTime, $contactTime, $isSynced, $learnerID, $currentDate);
        
        logDbUpdate('learner_clocking', [
            'clock_out_time' => $currentTime,
            'contact_time' => $contactTime,
            'synced' => $isSynced
        ], [
            'LearnerID' => $learnerID,
            'clock_date' => $currentDate
        ]);

        if ($stmt->execute()) {
            logClockingEvent('SUCCESS', 'Clock-out recorded successfully', [
                'learner_id' => $learnerID,
                'clock_out_time' => $currentTime,
                'contact_time' => $contactTime,
                'affected_rows' => $stmt->affected_rows
            ]);

            $response['success'] = true;
            $response['message'] = 'Clock-out successful';
            $response['clock_in_time'] = $clockingRecord['clock_in_time'];
            $response['clock_out_time'] = $currentTime;
            $response['contact_time'] = $contactTime;
            
            // Get database state after clock-out
            $afterState = $clockingLogger->getCurrentDatabaseState($learnerID, $currentDate);
            
        } else {
            logClockingEvent('ERROR', 'Failed to execute clock-out', [
                'error' => $stmt->error,
                'learner_id' => $learnerID
            ]);
            $response['message'] = "Failed to record clock-out: " . $stmt->error;
        }

        $stmt->close();

    } else {
        logClockingEvent('ERROR', 'Invalid request method', [
            'method' => $_SERVER['REQUEST_METHOD']
        ]);
        $response['message'] = "Invalid request method";
    }

    logClockingEvent('INFO', 'CLOCK-OUT RESPONSE SENT', [
        'learner_id' => $learnerID ?? 'unknown',
        'response' => $response
    ]);

} catch (Exception $e) {
    logClockingEvent('CRITICAL', 'Exception in clock-out', [
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