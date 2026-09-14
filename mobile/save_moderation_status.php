<?php
// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 0); // Don't display errors to client
ini_set('log_errors', 1);
ini_set('error_log', 'debug.log');

// Catch any fatal errors
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        file_put_contents('debug.log', "\n=== FATAL ERROR ===\n" . date('Y-m-d H:i:s') . "\n", FILE_APPEND);
        file_put_contents('debug.log', print_r($error, true) . "\n", FILE_APPEND);
        header('Content-Type: application/json');
        echo json_encode(["status" => "error", "message" => "Server error: " . $error['message']]);
    }
});

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    include('connection.php');
} catch (Exception $e) {
    file_put_contents('debug.log', "Connection error: " . $e->getMessage() . "\n", FILE_APPEND);
    echo json_encode(["status" => "error", "message" => "Database connection failed"]);
    exit();
}

// Check connection
if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Connection failed: " . $conn->connect_error]));
}

// Get JSON data from request
$data = json_decode(file_get_contents("php://input"), true);

// Log the received data for debugging
file_put_contents('debug.log', "\n=== RECEIVED REQUEST ===\n" . date('Y-m-d H:i:s') . "\n", FILE_APPEND);
file_put_contents('debug.log', "Raw data: " . json_encode($data) . "\n", FILE_APPEND);

// Check which parameters are missing or empty
// IMPORTANT: Accept EITHER 'exerciseId' OR 'exercise' as the identifier
$missingParams = [];
$emptyParams = [];

if (!isset($data['learnerId'])) {
    $missingParams[] = 'learnerId';
} elseif (empty($data['learnerId'])) {
    $emptyParams[] = 'learnerId (value is empty)';
}

// Accept either 'exerciseId' or 'exercise' as the exercise identifier
if (!isset($data['exerciseId']) && !isset($data['exercise'])) {
    $missingParams[] = 'exerciseId or exercise';
} elseif (empty($data['exerciseId']) && empty($data['exercise'])) {
    $emptyParams[] = 'exerciseId/exercise (both values are empty)';
}

if (!isset($data['moderation_status'])) {
    $missingParams[] = 'moderation_status';
} elseif (empty($data['moderation_status'])) {
    $emptyParams[] = 'moderation_status (value is empty)';
}

if (!empty($missingParams) || !empty($emptyParams)) {
    $allIssues = array_merge($missingParams, $emptyParams);
    $errorMsg = "Missing or empty required parameters: " . implode(', ', $allIssues);
    file_put_contents('debug.log', "ERROR: $errorMsg\n", FILE_APPEND);
    file_put_contents('debug.log', "Received data keys: " . implode(', ', array_keys($data)) . "\n", FILE_APPEND);
    file_put_contents('debug.log', "Received data values: " . json_encode($data) . "\n", FILE_APPEND);
    echo json_encode([
        "status" => "error", 
        "message" => $errorMsg,
        "received_data" => $data,
        "missing_params" => $missingParams,
        "empty_params" => $emptyParams
    ]);
    exit();
}

$learnerId = $data['learnerId'];
// Use 'exercise' if available, otherwise use 'exerciseId'
$exerciseId = isset($data['exercise']) && !empty($data['exercise']) 
    ? $data['exercise'] 
    : $data['exerciseId'];
$moderationStatus = $data['moderation_status'];
$moderatorComment = isset($data['moderator_comment']) ? $data['moderator_comment'] : '';
$moderatorId = isset($data['moderator_id']) ? $data['moderator_id'] : '';
$assessmentType = isset($data['assessment_type']) ? $data['assessment_type'] : null;

// Normalize moderation_status (case-insensitive, accept multiple variations)
$moderationStatusLower = strtolower(trim($moderationStatus));

// Map moderation_status to approval_status values
// Accept: 'uphold', 'upheld', 'withdrawn', 'withdraw'
if ($moderationStatusLower === 'uphold' || $moderationStatusLower === 'upheld') {
    $approvalStatus = 'Approved';
    $moderatorStatusValue = 'upheld';
} elseif ($moderationStatusLower === 'withdrawn' || $moderationStatusLower === 'withdraw') {
    $approvalStatus = 'Disapproved';
    $moderatorStatusValue = 'withdrawn';
} else {
    echo json_encode(["status" => "error", "message" => "Invalid moderation status: '$moderationStatus'. Expected 'Uphold', 'Upheld', 'Withdrawn', or 'Withdraw'."]);
    exit();
}

// CRITICAL FIX: Determine assessment type from exercise name if not provided
// Exercise names typically contain "Formative" or "Summative" in them
if ($assessmentType === null) {
    // Try to extract from exercise name
    $exerciseLower = strtolower($exerciseId);
    if (strpos($exerciseLower, 'formative') !== false) {
        $assessmentType = 'Formative';
    } elseif (strpos($exerciseLower, 'summative') !== false) {
        $assessmentType = 'Summative';
    } else {
        // If we can't determine, we'll try to find the record without type filter
        // This maintains backward compatibility
        $assessmentType = null;
    }
}

// Debug: Log all rows for this learnerID before any operation
$logQuery = "SELECT id, learnerID, exercise, type, approval_status, moderator_status FROM marks WHERE learnerID = ?";
$logStmt = $conn->prepare($logQuery);
$logStmt->bind_param("s", $learnerId);
$logStmt->execute();
$logResult = $logStmt->get_result();
$beforeRows = $logResult->fetch_all(MYSQLI_ASSOC);
file_put_contents('debug.log', "\n=== BEFORE UPDATE ===\n" . date('Y-m-d H:i:s') . "\n", FILE_APPEND);
file_put_contents('debug.log', "LearnerID: $learnerId, Exercise: $exerciseId, Type: " . ($assessmentType ?? 'NULL') . "\n", FILE_APPEND);
file_put_contents('debug.log', "All records for learner: " . json_encode($beforeRows) . "\n", FILE_APPEND);
$logStmt->close();

// CRITICAL FIX FOR CROSS-CONTAMINATION:
// Use UPDATE with precise matching to prevent cross-contamination
// This approach:
// 1. Allows updating existing moderation status (Upheld → Withdrawn or vice versa)
// 2. Prevents cross-contamination by matching on learnerID + exercise + type
// 3. Uses LIMIT 1 to ensure only one record is updated

if ($assessmentType !== null) {
    // We know the assessment type - use it for precise matching
    $sqlUpdate = "UPDATE marks 
                  SET approval_status = ?, 
                      moderator_status = ?, 
                      moderator_comment = ?, 
                      moderator_id = ?, 
                      moderation_date = NOW() 
                  WHERE learnerID = ? AND exercise = ? AND type = ?
                  LIMIT 1";
    
    $stmtUpsert = $conn->prepare($sqlUpdate);
    if (!$stmtUpsert) {
        file_put_contents('debug.log', "ERROR: Failed to prepare statement: " . $conn->error . "\n", FILE_APPEND);
        echo json_encode(["status" => "error", "message" => "Database error: " . $conn->error]);
        exit();
    }
    $stmtUpsert->bind_param("sssssss", $approvalStatus, $moderatorStatusValue, $moderatorComment, $moderatorId, $learnerId, $exerciseId, $assessmentType);
} else {
    // Fallback: No assessment type - use UPDATE with LIMIT 1 (backward compatibility)
    // This is less precise but maintains compatibility with old data
    $sqlUpdate = "UPDATE marks 
                  SET approval_status = ?, 
                      moderator_status = ?, 
                      moderator_comment = ?, 
                      moderator_id = ?, 
                      moderation_date = NOW() 
                  WHERE learnerID = ? AND exercise = ? 
                  LIMIT 1";
    
    $stmtUpsert = $conn->prepare($sqlUpdate);
    if (!$stmtUpsert) {
        file_put_contents('debug.log', "ERROR: Failed to prepare statement: " . $conn->error . "\n", FILE_APPEND);
        echo json_encode(["status" => "error", "message" => "Database error: " . $conn->error]);
        exit();
    }
    $stmtUpsert->bind_param("ssssss", $approvalStatus, $moderatorStatusValue, $moderatorComment, $moderatorId, $learnerId, $exerciseId);
}

file_put_contents('debug.log', "Executing UPDATE query...\n", FILE_APPEND);
if ($stmtUpsert->execute()) {
    $affectedRows = $stmtUpsert->affected_rows;
    
    file_put_contents('debug.log', "Rows affected: $affectedRows\n", FILE_APPEND);

    // Debug: Log all rows after update
    $logQuery = "SELECT id, learnerID, exercise, type, approval_status, moderator_status FROM marks WHERE learnerID = ?";
    $logStmt = $conn->prepare($logQuery);
    $logStmt->bind_param("s", $learnerId);
    $logStmt->execute();
    $logResult = $logStmt->get_result();
    $afterUpdateRows = $logResult->fetch_all(MYSQLI_ASSOC);
    file_put_contents('debug.log', "=== AFTER UPDATE ===\n" . json_encode($afterUpdateRows) . "\n\n", FILE_APPEND);
    $logStmt->close();

    if ($affectedRows > 0) { 
        echo json_encode([
            "status" => "success", 
            "message" => "Moderation status updated successfully",
            "affected_rows" => $affectedRows,
            "assessment_type" => $assessmentType
        ]);
    } else {
        echo json_encode([
            "status" => "warning", 
            "message" => "No changes made - record may already have this status",
            "learner_id" => $learnerId,
            "exercise" => $exerciseId,
            "assessment_type" => $assessmentType
        ]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Failed to update moderation status: " . $conn->error]);
}
$stmtUpsert->close();

$conn->close();
?>