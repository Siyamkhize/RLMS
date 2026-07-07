<?php
error_reporting(E_ALL);
ini_set('display_errors', 0); // Disable direct error display to prevent JSON corruption
ini_set('log_errors', 1); // Enable error logging
ini_set('error_log', __DIR__ . '/error.log'); // Valid log path

header('Content-Type: application/json; charset=UTF-8');

// Ensure we return JSON even on fatal errors (which bypass try/catch).
register_shutdown_function(function () {
    $error = error_get_last();
    if ($error === null) {
        return;
    }

    $isFatal = in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR, E_USER_ERROR], true);
    if (!$isFatal) {
        return;
    }

    // If headers/body already sent, we can't reliably emit JSON.
    if (headers_sent()) {
        error_log("Fatal error after headers sent: " . print_r($error, true));
        return;
    }

    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Server error (fatal) in save_marks.php',
        'debug_info' => [
            'type' => $error['type'],
            'file' => basename($error['file'] ?? ''),
            'line' => $error['line'] ?? null,
        ],
    ]);
});

try {
    // Include database connection
    $connectionPath = __DIR__ . '/php/connection.php';
    if (!file_exists($connectionPath)) {
        throw new Exception("Missing connection file: php/connection.php");
    }
    include($connectionPath);
    
    // Read and decode JSON input
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Invalid JSON input: ' . json_last_error_msg());
    }

    // Log raw input for debugging
    error_log("Received payload: " . $input);

    // Validate required fields with better error handling
    $learnerId = isset($data['learnerId']) ? (int)$data['learnerId'] : null;
    $exercise = $data['exercise'] ?? null;
    $marksScored = isset($data['marksScored']) ? (int)$data['marksScored'] : null;
    $assessmentType = $data['assessmentType'] ?? null;
    $specificOutcome = $data['specific_outcome'] ?? null;
    $aComment = $data['a_comment'] ?? null;
    $comment = $data['comment'] ?? $data['c'] ?? null;
    $approvalStatus = $data['approval_status'] ?? null;
    $isUpdate = isset($data['isUpdate']) && $data['isUpdate'] === true;

    // Basic validation
    if (!$learnerId) {
        throw new Exception('Missing or invalid learnerId');
    }

    if (!is_array($exercise) || !isset($exercise['exercise']) || empty($exercise['exercise'])) {
        throw new Exception('Missing or invalid exercise object');
    }

    if ($marksScored === null) {
        throw new Exception('Missing or invalid marksScored');
    }

    if (empty($assessmentType)) {
        throw new Exception('Missing or invalid assessmentType');
    }

    if (!is_array($specificOutcome) || empty($specificOutcome)) {
        throw new Exception('Missing or invalid specific_outcome');
    }

    $exerciseName = $exercise['exercise'];
    $specificOutcomeStr = implode(',', $specificOutcome);

    // Check database connection
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }

    // SIMPLIFIED TYPE DETERMINATION - ROBUST AND SAFE WITH REMEDIAL SUPPORT
    $actualAssessmentType = 'Formative'; // Safe default
    
    // Priority 1: Check exercise['type'] field (most reliable)
    if (isset($exercise['type']) && !empty($exercise['type'])) {
        $exerciseType = strtolower(trim($exercise['type']));
        error_log("Exercise type from Flutter: '$exerciseType'");
        
        if ($exerciseType === 'formative') {
            $actualAssessmentType = 'Formative';
        } elseif ($exerciseType === 'summative') {
            $actualAssessmentType = 'Summative';
        } elseif ($exerciseType === 'logbook') {
            $actualAssessmentType = 'Logbook';
        } elseif ($exerciseType === 'formativeremedial') {
            $actualAssessmentType = 'FormativeRemedial';
        } elseif ($exerciseType === 'summativeremedial') {
            $actualAssessmentType = 'SummativeRemedial';
        }
        error_log("Type determined from exercise.type: $actualAssessmentType");
    }
    // Priority 2: Check assessmentType field for type hints
    elseif (stripos($assessmentType, 'formativeremedial') !== false) {
        $actualAssessmentType = 'FormativeRemedial';
        error_log("Type determined from assessmentType: FormativeRemedial");
    } elseif (stripos($assessmentType, 'summativeremedial') !== false) {
        $actualAssessmentType = 'SummativeRemedial';
        error_log("Type determined from assessmentType: SummativeRemedial");
    } elseif (stripos($assessmentType, 'formative') !== false) {
        $actualAssessmentType = 'Formative';
        error_log("Type determined from assessmentType: Formative");
    } elseif (stripos($assessmentType, 'summative') !== false) {
        $actualAssessmentType = 'Summative';
        error_log("Type determined from assessmentType: Summative");
    }
    // Priority 3: Check exercise name for type hints
    elseif (stripos($exerciseName, 'formativeremedial') !== false) {
        $actualAssessmentType = 'FormativeRemedial';
        error_log("Type determined from exercise name: FormativeRemedial");
    } elseif (stripos($exerciseName, 'summativeremedial') !== false) {
        $actualAssessmentType = 'SummativeRemedial';
        error_log("Type determined from exercise name: SummativeRemedial");
    } elseif (stripos($exerciseName, 'formative') !== false) {
        $actualAssessmentType = 'Formative';
        error_log("Type determined from exercise name: Formative");
    } elseif (stripos($exerciseName, 'summative') !== false) {
        $actualAssessmentType = 'Summative';
        error_log("Type determined from exercise name: Summative");
    } elseif (stripos($exerciseName, 'logbook') !== false) {
        $actualAssessmentType = 'Logbook';
        error_log("Type determined from exercise name: Logbook");
    } else {
        error_log("Using default type: Formative");
    }
    
    error_log("Final assessment type: $actualAssessmentType");

    // Check for existing marks
    error_log("Checking for duplicates - learnerID: $learnerId, exercise: $exerciseName, type: $actualAssessmentType, so: $specificOutcomeStr");
    
    // Check if marks already exist for this exact combination
    $checkQuery = $conn->prepare("SELECT id, marks_scored FROM marks WHERE learnerID = ? AND exercise = ? AND type = ? AND so = ?");
    if (!$checkQuery) {
        throw new Exception("Check query prepare failed: " . $conn->error);
    }

    $checkQuery->bind_param("isss", $learnerId, $exerciseName, $actualAssessmentType, $specificOutcomeStr);
    $checkQuery->execute();
    $result = $checkQuery->get_result();

    if ($result->num_rows > 0) {
        $existingRecord = $result->fetch_assoc();
        $recordId = $existingRecord['id'];
        $oldMarks = $existingRecord['marks_scored'];
        
        error_log("Existing record found - ID: $recordId, existing marks: $oldMarks");
        
        if ($isUpdate) {
            // Update existing marks
            $checkQuery->close();
            
            $updateQuery = $conn->prepare("UPDATE marks SET marks_scored = ?, a_comment = ?, comment = ? WHERE id = ?");
            if (!$updateQuery) {
                throw new Exception("Update query prepare failed: " . $conn->error);
            }

            // Convert marksScored to integer for database int(11) type
            $marksScored = (int)$marksScored;
            $updateQuery->bind_param("issi", $marksScored, $aComment, $comment, $recordId);

            if ($updateQuery->execute()) {
                // affected_rows can be 0 if the user submits the same marks again.
                // In MySQL, this is not an error, so we treat it as success.
                error_log("Successfully processed update for record ID: $recordId (Affected rows: " . $updateQuery->affected_rows . ")");
                echo json_encode([
                    'status' => 'success', 
                    'message' => 'Marks updated successfully',
                    'action' => 'update',
                    'record_id' => $recordId,
                    'old_marks' => $oldMarks,
                    'new_marks' => $marksScored,
                    'actual_type' => $actualAssessmentType
                ]);
            } else {
                throw new Exception("Update execution failed: " . $updateQuery->error);
            }

            $updateQuery->close();
            $conn->close();
            exit;
        } else {
            // Not an update request, return error with option to update
            echo json_encode([
                'status' => 'error', 
                'message' => 'Marks already submitted for this ' . $actualAssessmentType . ' assessment (Exercise: ' . $exerciseName . ')',
                'existing_marks' => $oldMarks,
                'record_id' => $recordId,
                'can_update' => true,
                'suggestion' => 'Use isUpdate: true to update existing marks'
            ]);
            $checkQuery->close();
            $conn->close();
            exit;
        }
    }

    $checkQuery->close();

    // Insert new marks (no existing record found)
    $stmt = $conn->prepare("INSERT INTO marks (learnerID, exercise, so, marks_scored, type, a_comment, comment, approval_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    if (!$stmt) {
        throw new Exception("Insert prepare failed: " . $conn->error);
    }

    // Bind parameters with correct types
    error_log("Binding values - learnerID: $learnerId, exercise: $exerciseName, so: $specificOutcomeStr, marks_scored: $marksScored, type: $actualAssessmentType, a_comment: $aComment, comment: $comment, approval_status: $approvalStatus");
    $stmt->bind_param("ississss", $learnerId, $exerciseName, $specificOutcomeStr, $marksScored, $actualAssessmentType, $aComment, $comment, $approvalStatus);

    if ($stmt->execute()) {
        $newRecordId = $conn->insert_id;
        echo json_encode([
            'status' => 'success', 
            'message' => 'Marks saved successfully', 
            'action' => 'insert',
            'record_id' => $newRecordId,
            'actual_type' => $actualAssessmentType
        ]);
    } else {
        throw new Exception("Execute failed: " . $stmt->error);
    }

    // Close connections
    $stmt->close();
    $conn->close();

} catch (Exception $e) { 
    // Log the full error details for debugging
    $errorMessage = $e->getMessage();
    $errorFile = $e->getFile();
    $errorLine = $e->getLine();
    
    error_log("Error in save_marks.php: $errorMessage at $errorFile:$errorLine");
    error_log("Stack trace: " . $e->getTraceAsString());
    
    // Return HTTP 500 to match server failure semantics.
    // (Client can still show message; classification is in JSON.)
    http_response_code(500);
    
    echo json_encode([
        'status' => 'error', 
        'message' => $errorMessage,
        'debug_info' => [
            'file' => basename($errorFile),
            'line' => $errorLine
        ]
    ]);
    exit;
}
?>