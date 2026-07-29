<?php
error_reporting(E_ALL);
ini_set('display_errors', 0); // Disable direct error display
ini_set('log_errors', 1); // Enable error logging
ini_set('error_log', __DIR__ . '/error.log'); // Valid log path

header('Content-Type: application/json; charset=UTF-8');
include('php/connection.php'); // Database connection

try {
    // Read and decode JSON input
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Invalid JSON input: ' . json_last_error_msg());
    }

    // Log raw input for debugging
    error_log("Received payload: " . $input);

    // Validate required fields
    $learnerId = $data['learnerId'] ?? null;
    $exercise = $data['exercise'] ?? null;
    $marksScored = isset($data['marksScored']) ? strval($data['marksScored']) : null;
    $assessmentType = $data['assessmentType'] ?? null;
    $specificOutcome = $data['specific_outcome'] ?? null;

    // Check for missing or invalid fields
    if (empty($learnerId) || $learnerId === null) {
        throw new Exception('Missing or invalid learnerId');
    }

    if (!is_array($exercise) || !isset($exercise['exercise']) || empty($exercise['exercise'])) {
        throw new Exception('Missing or invalid exercise object');
    }

    if ($marksScored === null || !is_numeric($marksScored)) {
        throw new Exception('Missing or invalid marksScored (must be numeric)');
    }

    if (empty($assessmentType)) {
        throw new Exception('Missing or invalid assessmentType');
    }

    if (!is_array($specificOutcome) || empty($specificOutcome)) {
        throw new Exception('Missing or invalid specific_outcome (must be a non-empty array)');
    }

    $exerciseName = $exercise['exercise'];
    $specificOutcome = implode(',', $specificOutcome);

    // Check database connection
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }

    // SIMPLIFIED TYPE DETERMINATION - ROBUST VERSION
    $actualAssessmentType = 'Formative'; // Safe default
    
    // Priority 1: Check exercise['type'] field
    if (isset($exercise['type']) && !empty($exercise['type'])) {
        $exerciseTypeContext = strtolower(trim($exercise['type']));
        error_log("Exercise type context: '$exerciseTypeContext'");
        
        if ($exerciseTypeContext === 'formative' || stripos($exerciseTypeContext, 'formative') !== false) {
            $actualAssessmentType = 'Formative';
        } elseif ($exerciseTypeContext === 'summative' || stripos($exerciseTypeContext, 'summative') !== false) {
            $actualAssessmentType = 'Summative';
        } elseif ($exerciseTypeContext === 'logbook' || stripos($exerciseTypeContext, 'logbook') !== false) {
            $actualAssessmentType = 'Logbook';
        }
        error_log("Type determined from exercise context: $actualAssessmentType");
    }
    // Priority 2: Check assessmentType field
    elseif (stripos($assessmentType, 'formative') !== false) {
        $actualAssessmentType = 'Formative';
        error_log("Type determined from assessmentType field: Formative");
    } elseif (stripos($assessmentType, 'summative') !== false) {
        $actualAssessmentType = 'Summative';
        error_log("Type determined from assessmentType field: Summative");
    }
    // Priority 3: Check exercise name
    elseif (stripos($exerciseName, 'formative') !== false) {
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

    // Check if this is an update operation
    $isUpdate = isset($data['isUpdate']) && $data['isUpdate'] === true;
    
    // Check if marks already exist
    $checkQuery = $conn->prepare("SELECT id, marks_scored FROM marks WHERE learnerID = ? AND exercise = ? AND type = ? AND so = ?");
    if (!$checkQuery) {
        throw new Exception("Check query prepare failed: " . $conn->error);
    }

    $checkQuery->bind_param("isss", $learnerId, $exerciseName, $actualAssessmentType, $specificOutcome);
    $checkQuery->execute();
    $result = $checkQuery->get_result();

    if ($result->num_rows > 0) {
        // Record exists
        $existingRecord = $result->fetch_assoc();
        $recordId = $existingRecord['id'];
        $oldMarks = $existingRecord['marks_scored'];
        
        error_log("Existing record found - ID: $recordId, existing marks: $oldMarks");
        
        if ($isUpdate) {
            // Update existing marks
            $checkQuery->close();
            
            $updateQuery = $conn->prepare("UPDATE marks SET marks_scored = ? WHERE id = ?");
            if (!$updateQuery) {
                throw new Exception("Update query prepare failed: " . $conn->error);
            }

            $marksScored = (int)$marksScored;
            $updateQuery->bind_param("ii", $marksScored, $recordId);

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
    $stmt = $conn->prepare("INSERT INTO marks (learnerID, exercise, so, marks_scored, type) VALUES (?, ?, ?, ?, ?)");
    if (!$stmt) {
        throw new Exception("Insert prepare failed: " . $conn->error);
    }

    // Convert marksScored to integer and bind parameters
    $marksScored = (int)$marksScored;
    error_log("Binding values - learnerID: $learnerId, exercise: $exerciseName, so: $specificOutcome, marks_scored: $marksScored, type: $actualAssessmentType");
    $stmt->bind_param("issis", $learnerId, $exerciseName, $specificOutcome, $marksScored, $actualAssessmentType);

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

    $stmt->close();
    $conn->close();

} catch (Exception $e) { 
    // Enhanced error handling
    $errorMessage = $e->getMessage();
    $errorFile = $e->getFile();
    $errorLine = $e->getLine();
    
    error_log("Error in save_marks_fixed.php: $errorMessage at $errorFile:$errorLine");
    
    // Return appropriate HTTP status code
    if (strpos($errorMessage, 'Connection failed') !== false) {
        http_response_code(500);
    } else {
        http_response_code(400);
    }
    
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