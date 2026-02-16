<?php
// get_clocking_data_debug.php - Enhanced version of get_clocking_data.php with comprehensive logging

header('Content-Type: application/json');
include 'connection.php';
include 'clocking_debug_logger.php';

$response = array("success" => false, "message" => "Unknown error occurred");

try {
    logClockingEvent('INFO', 'GET_CLOCKING_DATA REQUEST STARTED', [
        'get_params' => $_GET,
        'request_time' => date('Y-m-d H:i:s')
    ]);

    // Get parameters
    $learnerID = $_GET['LearnerID'] ?? null;
    $clockDate = $_GET['clock_date'] ?? date('Y-m-d');
    
    if (empty($learnerID)) {
        $response['message'] = 'LearnerID parameter is required';
        logClockingEvent('ERROR', 'Missing LearnerID parameter', $_GET);
        echo json_encode($response);
        exit;
    }

    logClockingEvent('INFO', 'Fetching clocking data', [
        'learner_id' => $learnerID,
        'clock_date' => $clockDate
    ]);

    // Get current database state BEFORE any operations
    global $clockingLogger;
    $clockingLogger->conn = $conn;
    $beforeState = $clockingLogger->getCurrentDatabaseState($learnerID, $clockDate);
    
    // Check learner_clocking table
    $stmt = $conn->prepare("SELECT * FROM learner_clocking WHERE LearnerID = ? AND clock_date = ?");
    if (!$stmt) {
        logClockingEvent('ERROR', 'Failed to prepare statement', [
            'error' => $conn->error,
            'learner_id' => $learnerID
        ]);
        $response['message'] = 'Database prepare error';
        echo json_encode($response);
        exit;
    }

    $stmt->bind_param("is", $learnerID, $clockDate);
    logDbQuery("SELECT * FROM learner_clocking WHERE LearnerID = ? AND clock_date = ?", [$learnerID, $clockDate]);
    
    if (!$stmt->execute()) {
        logClockingEvent('ERROR', 'Failed to execute query', [
            'error' => $stmt->error,
            'learner_id' => $learnerID
        ]);
        $response['message'] = 'Database execution error';
        echo json_encode($response);
        exit;
    }

    $result = $stmt->get_result();
    $clockingData = $result->fetch_assoc();
    $stmt->close();

    logClockingEvent('DEBUG', 'Query result', [
        'learner_id' => $learnerID,
        'found_records' => $result->num_rows,
        'data' => $clockingData
    ]);

    if ($clockingData) {
        // Log what we're about to return
        $responseData = [
            'clock_in_time' => $clockingData['clock_in_time'],
            'clock_out_time' => $clockingData['clock_out_time'],
            'contact_time' => $clockingData['contact_time']
        ];

        // CRITICAL: Check if we're returning a clock_out_time for an active session
        if (!empty($clockingData['clock_in_time']) && !empty($clockingData['clock_out_time'])) {
            logClockingEvent('WARNING', 'RETURNING CLOCK-OUT TIME FOR EXISTING SESSION', [
                'learner_id' => $learnerID,
                'clock_in_time' => $clockingData['clock_in_time'],
                'clock_out_time' => $clockingData['clock_out_time'],
                'contact_time' => $clockingData['contact_time'],
                'potential_auto_clockout' => true
            ]);
        } elseif (!empty($clockingData['clock_in_time']) && empty($clockingData['clock_out_time'])) {
            logClockingEvent('INFO', 'RETURNING ACTIVE CLOCK-IN SESSION (NO CLOCK-OUT)', [
                'learner_id' => $learnerID,
                'clock_in_time' => $clockingData['clock_in_time'],
                'session_active' => true
            ]);
        } elseif (empty($clockingData['clock_in_time']) && !empty($clockingData['clock_out_time'])) {
            logClockingEvent('ERROR', 'SUSPICIOUS: CLOCK-OUT WITHOUT CLOCK-IN', [
                'learner_id' => $learnerID,
                'clock_out_time' => $clockingData['clock_out_time'],
                'data_integrity_issue' => true
            ]);
        }

        $response['success'] = true;
        $response['message'] = 'Data found';
        $response = array_merge($response, $responseData);

        logDataFetch('get_clocking_data.php', $learnerID, $responseData);
    } else {
        logClockingEvent('INFO', 'No clocking data found', [
            'learner_id' => $learnerID,
            'clock_date' => $clockDate
        ]);
        
        $response['success'] = false;
        $response['message'] = 'No clocking data found for the specified date';
    }

    // Get database state AFTER operations and compare
    $afterState = $clockingLogger->getCurrentDatabaseState($learnerID, $clockDate);
    $clockingLogger->detectAutoClockOut($learnerID, $beforeState, $afterState);

    // Log what we're returning to the client
    logClockingEvent('INFO', 'RESPONSE SENT TO CLIENT', [
        'learner_id' => $learnerID,
        'response' => $response
    ]);

} catch (Exception $e) {
    logClockingEvent('CRITICAL', 'Exception in get_clocking_data', [
        'error' => $e->getMessage(),
        'trace' => $e->getTraceAsString(),
        'learner_id' => $learnerID ?? 'unknown'
    ]);
    
    $response['success'] = false;
    $response['message'] = 'Server error occurred';
    $response['error_details'] = $e->getMessage();
}

echo json_encode($response);
?>