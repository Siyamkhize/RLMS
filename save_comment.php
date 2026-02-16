<?php
// save_comment.php - Save or update assessor comments

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error.log');

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    // Include database connection
    include('connection.php');
    
    // Read and decode JSON input
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Invalid JSON input: ' . json_last_error_msg());
    }

    error_log("Received comment payload: " . $input);

    // Validate required fields
    $learnerId = isset($data['learnerId']) ? trim($data['learnerId']) : null;
    $assessmentType = isset($data['assessmentType']) ? trim($data['assessmentType']) : null;
    $comment = isset($data['comment']) ? trim($data['comment']) : null;
    $isUpdate = isset($data['isUpdate']) && $data['isUpdate'] === true;

    // Basic validation
    if (empty($learnerId)) {
        throw new Exception('Missing or invalid learnerId');
    }

    if (empty($assessmentType)) {
        throw new Exception('Missing or invalid assessmentType');
    }

    if (empty($comment)) {
        throw new Exception('Comment cannot be empty');
    }

    // Normalize assessment type
    $assessmentType = strtolower($assessmentType);
    
    // Check database connection
    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }

    // Check for existing comment
    error_log("Checking for existing comment - learnerID: $learnerId, assessmentType: $assessmentType");
    
    $checkQuery = $conn->prepare("SELECT id, a_comment FROM marks WHERE learnerID = ? AND type = ? AND a_comment IS NOT NULL AND a_comment != '' LIMIT 1");
    if (!$checkQuery) {
        throw new Exception("Check query prepare failed: " . $conn->error);
    }

    // Capitalize first letter for database query
    $dbAssessmentType = ucfirst($assessmentType);
    $checkQuery->bind_param("ss", $learnerId, $dbAssessmentType);
    $checkQuery->execute();
    $result = $checkQuery->get_result();

    if ($result->num_rows > 0) {
        $existingRecord = $result->fetch_assoc();
        $recordId = $existingRecord['id'];
        $oldComment = $existingRecord['a_comment'];
        
        error_log("Existing comment found - ID: $recordId");
        
        if ($isUpdate) {
            // Update existing comment
            $checkQuery->close();
            
            $updateQuery = $conn->prepare("UPDATE marks SET a_comment = ? WHERE learnerID = ? AND type = ?");
            if (!$updateQuery) {
                throw new Exception("Update query prepare failed: " . $conn->error);
            }

            $updateQuery->bind_param("sss", $comment, $learnerId, $dbAssessmentType);

            if ($updateQuery->execute()) {
                if ($updateQuery->affected_rows > 0) {
                    error_log("Successfully updated comment for learner: $learnerId, type: $dbAssessmentType");
                    echo json_encode([
                        'status' => 'success', 
                        'message' => 'Comment updated successfully',
                        'action' => 'update',
                        'record_id' => $recordId
                    ]);
                } else {
                    // No rows affected might mean comment is the same
                    echo json_encode([
                        'status' => 'success', 
                        'message' => 'Comment updated (no changes detected)',
                        'action' => 'update',
                        'record_id' => $recordId
                    ]);
                }
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
                'message' => 'Comment already exists for this ' . $assessmentType . ' assessment',
                'existing_comment' => $oldComment,
                'record_id' => $recordId,
                'can_update' => true,
                'suggestion' => 'Use isUpdate: true to update existing comment'
            ]);
            $checkQuery->close();
            $conn->close();
            exit;
        }
    }

    $checkQuery->close();

    // Insert new comment (update all records of this type for this learner)
    $updateQuery = $conn->prepare("UPDATE marks SET a_comment = ? WHERE learnerID = ? AND type = ?");
    if (!$updateQuery) {
        throw new Exception("Insert prepare failed: " . $conn->error);
    }

    error_log("Inserting comment - learnerID: $learnerId, type: $dbAssessmentType, comment length: " . strlen($comment));
    $updateQuery->bind_param("sss", $comment, $learnerId, $dbAssessmentType);

    if ($updateQuery->execute()) {
        if ($updateQuery->affected_rows > 0) {
            echo json_encode([
                'status' => 'success', 
                'message' => 'Comment saved successfully', 
                'action' => 'insert',
                'affected_rows' => $updateQuery->affected_rows
            ]);
        } else {
            // No marks records exist yet for this type
            echo json_encode([
                'status' => 'error', 
                'message' => 'No marks records found for this assessment type. Please submit marks first.',
                'can_update' => false
            ]);
        }
    } else {
        throw new Exception("Execute failed: " . $updateQuery->error);
    }

    $updateQuery->close();
    $conn->close();

} catch (Exception $e) {
    error_log("Error in save_comment.php: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
