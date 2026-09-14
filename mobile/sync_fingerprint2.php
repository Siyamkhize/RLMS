<?php
// sync_fingerprint.php - Updated for dual scanner support

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ==== DATABASE CONNECTION ====
include('connection.php');

if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database connection failed']);
    exit;
}

// ==== INPUT VALIDATION ====
// Handle both old format (JSON) and new format (POST body)
$input = null;
$contentType = $_SERVER['CONTENT_TYPE'] ?? '';

if (strpos($contentType, 'application/json') !== false) {
    // Old format - JSON input
    $input = json_decode(file_get_contents('php://input'), true);
} else {
    // New format - POST body
    $input = $_POST;
}

if (!$input) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid input data']);
    exit;
}

// Debug logging
error_log("Sync fingerprint request: " . print_r($input, true));

// Handle new format with template_type
if (isset($input['template_type'])) {
    // New format: template_type (e.g., 'zkteco_left', 'futronic_right')
    $learnerId = intval($input['learner_id'] ?? 0);
    $templateType = $input['template_type'];
    $template = $input['template'] ?? '';
    
    if ($learnerId <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid learner_id']);
        exit;
    }
    
    if (empty($template)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid template']);
        exit;
    }
    
    // Map template_type to database column
    $columnMap = [
        'zkteco_left' => 'zkteco_left_template',
        'zkteco_right' => 'zkteco_right_template',
        'futronic_left' => 'futronic_left_template',
        'futronic_right' => 'futronic_right_template'
    ];
    
    if (!isset($columnMap[$templateType])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid template_type: ' . $templateType]);
        exit;
    }
    
    $column = $columnMap[$templateType];
    
} else {
    // Old format: LearnerID + finger
    $learnerId = intval($input['LearnerID'] ?? 0);
    $finger = $input['finger'] ?? '';
    $template = $input['template'] ?? '';
    
    if ($learnerId <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid LearnerID']);
        exit;
    }
    
    if (!in_array($finger, ['left', 'right'], true)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid finger type']);
        exit;
    }
    
    if (empty($template)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid template']);
        exit;
    }
    
    // For old format, assume ZKTeco scanner
    $column = ($finger === 'left') ? 'zkteco_left_template' : 'zkteco_right_template';
}

// ==== VERIFICATION LOGIC ====
if (isset($input['action']) && $input['action'] === 'verify') {
    $sql = "SELECT zkteco_left_template, zkteco_right_template, futronic_left_template, futronic_right_template FROM learnerdetails WHERE LearnerID = ?";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Prepare failed: ' . $conn->error]);
        exit;
    }
    $stmt->bind_param('i', $learnerId);
    $stmt->execute();
    $stmt->bind_result($zktecoLeft, $zktecoRight, $futronicLeft, $futronicRight);
    if ($stmt->fetch()) {
        if ($template === $zktecoLeft || $template === $zktecoRight || 
            $template === $futronicLeft || $template === $futronicRight) {
            echo json_encode(['success' => true, 'message' => 'Fingerprint verified']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Fingerprint does not match']);
        }
    } else {
        echo json_encode(['success' => false, 'message' => 'Learner not found']);
    }
    $stmt->close();
    $conn->close();
    exit;
}

// ==== UPDATE LOGIC ====

// First check if the learner exists
$checkSql = "SELECT LearnerID FROM learnerdetails WHERE LearnerID = ?";
$checkStmt = $conn->prepare($checkSql);
if (!$checkStmt) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Check prepare failed: ' . $conn->error]);
    exit;
}

$checkStmt->bind_param('i', $learnerId);
$checkStmt->execute();
$checkResult = $checkStmt->get_result();

if ($checkResult->num_rows === 0) {
    http_response_code(404);
    echo json_encode(['success' => false, 'message' => 'Learner not found']);
    $checkStmt->close();
    $conn->close();
    exit;
}
$checkStmt->close();

// Update the fingerprint template
$sql = "UPDATE learnerdetails SET `$column` = ?, synced = 1 WHERE LearnerID = ?";
$stmt = $conn->prepare($sql);
if (!$stmt) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Update prepare failed: ' . $conn->error]);
    exit;
}

$stmt->bind_param('si', $template, $learnerId);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        error_log("Successfully updated $column for learner $learnerId");
        echo json_encode(['success' => true, 'message' => "Fingerprint template updated successfully for $column"]);
    } else {
        echo json_encode(['success' => true, 'message' => 'Fingerprint template updated (no changes)']);
    }
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Update failed: ' . $stmt->error]);
}

$stmt->close();
$conn->close();
?>