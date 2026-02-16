<?php
error_reporting(E_ALL);
ini_set('display_errors', 0); // Disable direct error display to prevent JSON corruption
ini_set('log_errors', 1); // Enable error logging
ini_set('error_log', __DIR__ . '/error.log'); // Valid log path

header('Content-Type: application/json; charset=UTF-8');

try {
    // Include database connection
    include('php/connection.php');
    
    // Read and decode JSON input
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Invalid JSON input: ' . json_last_error_msg());
    }

    // Log raw input for debugging
    error_log("Update marks payload: " . $input);

    // Validate required fields with better error handling
    $learnerId = isset($data['learnerId']) ? (int)$data['learnerId'] : null;
    $exercise = $data['exercise'] ?? null;
    $marksScored = isset($data['marksScored']) ? (int)$data['marksScored'] : null;
    $assessmentType = $data['assessmentType'] ?? null;
    $specificOutcome = $data['specific_outcome'] ?? null;
    $markId = $data['markId'] ?? null; // Optional: specific mark ID to update

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

    // SIMPLIFIED TYPE DETERMINATION - ROBUST AND SAFE
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
        }
        error_log("Type determined from exercise.type: $actualAssessmentType");
    }
    // Priority 2: Check assessmentType field for type hints
    elseif (stripos($assessmentType, 'formative') !== false) {
        $actualAssessmentType = 'Formative';
        error_log("Type determined from assessmentType: Formative");
    } elseif (stripos($assessmentType, 'summative') !== false) {
        $actualAssessmentType = 'Summative';
        error_log("Type determined from assessmentType: Summative");
    }
    // Priority 3: Check exercise name for type hints
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

    // Find the existing record to update
    $findQuery = $conn->prepare("SELECT id, marks_scored FROM marks WHERE learnerID = ? AND exercise = ? AND type = ? AND so = ?");
    if (!$findQuery) {
        throw new Exception("Find query prepare failed: " . $conn->error);
    }

    $findQuery->bind_param("isss", $learnerId, $exerciseName, $actualAssessmentType, $specificOutcomeStr);
    $findQuery->execute();
    $result = $findQuery->get_result();

    if ($result->num_rows === 0) {
        echo json_encode([
            'status' => 'error', 
            'message' => 'No existing marks found for this ' . $actualAssessmentType . ' assessment (Exercise: ' . $exerciseName . '). Use save instead of update.'
        ]);
        $findQuery->close();
        $conn->close();
        exit;
    }

    $existingRecord = $result->fetch_assoc();
    $recordId = $existingRecord['id'];
    $oldMarks = $existingRecord['marks_scored'];
    
    error_log("Found existing record ID: $recordId, old marks: $oldMarks, new marks: $marksScored");
    
    $findQuery->close();

    // Update the existing marks
    $updateQuery = $conn->prepare("UPDATE marks SET marks_scored = ? WHERE id = ?");
    if (!$updateQuery) {
        throw new Exception("Update query prepare failed: " . $conn->error);
    }

    // Convert marksScored to integer for database int(11) type
    $marksScored = (int)$marksScored;
    $updateQuery->bind_param("ii", $marksScored, $recordId);

    if ($updateQuery->execute()) {
        if ($updateQuery->affected_rows > 0) {
            error_log("Successfully updated marks for record ID: $recordId from $oldMarks to $marksScored");
            echo json_encode([
                'status' => 'success', 
                'message' => 'Marks updated successfully',
                'record_id' => $recordId,
                'old_marks' => $oldMarks,
                'new_marks' => $marksScored,
                'assessment_type' => $actualAssessmentType
            ]);
        } else {
            throw new Exception("No rows were updated. Record may not exist or marks are the same.");
        }
    } else {
        throw new Exception("Update execution failed: " . $updateQuery->error);
    }

    // Close connections
    $updateQuery->close();
    $conn->close();

} catch (Exception $e) { 
    // Log the full error details for debugging
    $errorMessage = $e->getMessage();
    $errorFile = $e->getFile();
    $errorLine = $e->getLine();
    
    error_log("Error in update_marks.php: $errorMessage at $errorFile:$errorLine");
    error_log("Stack trace: " . $e->getTraceAsString());
    
    // Return appropriate HTTP status code
    if (strpos($errorMessage, 'Connection failed') !== false) {
        http_response_code(500); // Database connection issues
    } else {
        http_response_code(400); // Client request issues
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