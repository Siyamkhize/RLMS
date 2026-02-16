<?php
// Simplified save_marks.php to fix 500 error
error_reporting(E_ALL);
ini_set('display_errors', 1); // Enable for debugging
ini_set('log_errors', 1);

header('Content-Type: application/json; charset=UTF-8');

try {
    // Include database connection
    include('php/connection.php');
    
    // Read JSON input
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Invalid JSON: ' . json_last_error_msg());
    }
    
    // Log the received data
    error_log("Received data: " . $input);
    
    // Extract and validate basic fields
    $learnerId = isset($data['learnerId']) ? (int)$data['learnerId'] : null;
    $exercise = $data['exercise'] ?? null;
    $marksScored = isset($data['marksScored']) ? (int)$data['marksScored'] : null;
    $assessmentType = $data['assessmentType'] ?? null;
    $specificOutcome = $data['specific_outcome'] ?? null;
    $isUpdate = isset($data['isUpdate']) && $data['isUpdate'] === true;
    
    // Basic validation
    if (!$learnerId) {
        throw new Exception('Missing learnerId');
    }
    
    if (!is_array($exercise) || empty($exercise['exercise'])) {
        throw new Exception('Missing or invalid exercise');
    }
    
    if ($marksScored === null) {
        throw new Exception('Missing marksScored');
    }
    
    if (!is_array($specificOutcome) || empty($specificOutcome)) {
        throw new Exception('Missing specific_outcome');
    }
    
    $exerciseName = $exercise['exercise'];
    $specificOutcomeStr = implode(',', $specificOutcome);
    
    // Determine assessment type - SIMPLIFIED
    $type = 'Formative'; // Default
    
    // Check if exercise has type field
    if (isset($exercise['type']) && !empty($exercise['type'])) {
        $exerciseType = strtolower(trim($exercise['type']));
        if ($exerciseType === 'formative') {
            $type = 'Formative';
        } elseif ($exerciseType === 'summative') {
            $type = 'Summative';
        } elseif ($exerciseType === 'logbook') {
            $type = 'Logbook';
        }
    }
    
    error_log("Determined type: $type for exercise: $exerciseName");
    
    // Check if record exists
    $checkQuery = $conn->prepare("SELECT id, marks_scored FROM marks WHERE learnerID = ? AND exercise = ? AND type = ? AND so = ?");
    if (!$checkQuery) {
        throw new Exception("Check query failed: " . $conn->error);
    }
    
    $checkQuery->bind_param("isss", $learnerId, $exerciseName, $type, $specificOutcomeStr);
    $checkQuery->execute();
    $result = $checkQuery->get_result();
    
    if ($result->num_rows > 0) {
        // Record exists
        $existingRecord = $result->fetch_assoc();
        $recordId = $existingRecord['id'];
        $oldMarks = $existingRecord['marks_scored'];
        
        if ($isUpdate) {
            // Update existing record
            $updateQuery = $conn->prepare("UPDATE marks SET marks_scored = ? WHERE id = ?");
            if (!$updateQuery) {
                throw new Exception("Update query failed: " . $conn->error);
            }
            
            $updateQuery->bind_param("ii", $marksScored, $recordId);
            
            if ($updateQuery->execute()) {
                echo json_encode([
                    'status' => 'success',
                    'message' => 'Marks updated successfully',
                    'action' => 'update',
                    'record_id' => $recordId,
                    'old_marks' => $oldMarks,
                    'new_marks' => $marksScored,
                    'type' => $type
                ]);
            } else {
                throw new Exception("Update execution failed: " . $updateQuery->error);
            }
            
            $updateQuery->close();
        } else {
            // Record exists but not an update request
            echo json_encode([
                'status' => 'error',
                'message' => "Marks already exist for this $type assessment",
                'existing_marks' => $oldMarks,
                'record_id' => $recordId,
                'can_update' => true,
                'type' => $type
            ]);
        }
    } else {
        // Insert new record
        $insertQuery = $conn->prepare("INSERT INTO marks (learnerID, exercise, so, marks_scored, type) VALUES (?, ?, ?, ?, ?)");
        if (!$insertQuery) {
            throw new Exception("Insert query failed: " . $conn->error);
        }
        
        $insertQuery->bind_param("issis", $learnerId, $exerciseName, $specificOutcomeStr, $marksScored, $type);
        
        if ($insertQuery->execute()) {
            $newRecordId = $conn->insert_id;
            echo json_encode([
                'status' => 'success',
                'message' => 'Marks saved successfully',
                'action' => 'insert',
                'record_id' => $newRecordId,
                'type' => $type
            ]);
        } else {
            throw new Exception("Insert execution failed: " . $insertQuery->error);
        }
        
        $insertQuery->close();
    }
    
    $checkQuery->close();
    $conn->close();
    
} catch (Exception $e) {
    error_log("Error in save_marks_simple.php: " . $e->getMessage());
    
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'file' => 'save_marks_simple.php'
    ]);
}
?>