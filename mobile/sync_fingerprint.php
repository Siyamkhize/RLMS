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

// ==== CONFIGURATION ====
define('API_KEY', 'rlmss_2025_8e7d2f6e-3c4b-4c8f-b1e6-4a01a1b2e9f7');

// ==== AUTHENTICATION ====
$headers = getallheaders();
$authHeader = $headers['Authorization'] ?? '';
error_log("Auth header received: " . $authHeader);
error_log("Expected: Bearer " . API_KEY);

// Make authentication optional for debugging - remove this in production
$skipAuth = true; // Set to false for production

if (!$skipAuth) {
    if (!isset($headers['Authorization']) || $headers['Authorization'] !== 'Bearer ' . API_KEY) {
        error_log("Authentication failed - header: " . ($headers['Authorization'] ?? 'MISSING'));
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Unauthorized - invalid or missing API key']);
        exit;
    }
} else {
    error_log("Authentication skipped for debugging");
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
error_log("Request method: " . $_SERVER['REQUEST_METHOD']);
error_log("Content type: " . ($_SERVER['CONTENT_TYPE'] ?? 'MISSING'));
error_log("POST data: " . print_r($_POST, true));
error_log("Raw input: " . file_get_contents('php://input'));

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
        echo json_encode(['success' => false, 'message' => 'Template is empty or null']);
        error_log("Template validation failed: empty template for learner $learnerId, type $templateType");
        exit;
    }
    
    if (!is_string($template)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Template must be a string, received: ' . gettype($template)]);
        error_log("Template validation failed: not a string for learner $learnerId, type $templateType");
        exit;
    }
    
    if (trim($template) === '') {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Template is whitespace only']);
        error_log("Template validation failed: whitespace only for learner $learnerId, type $templateType");
        exit;
    }
    
    if (strlen($template) < 10) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Template too short (minimum 10 characters), received: ' . strlen($template) . ' characters']);
        error_log("Template validation failed: too short (" . strlen($template) . " chars) for learner $learnerId, type $templateType");
        exit;
    }
    
    // Log successful validation
    error_log("Template validation passed: learner $learnerId, type $templateType, length " . strlen($template));
    
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
        echo json_encode(['success' => false, 'message' => 'Template is empty or null (old format)']);
        error_log("Template validation failed: empty template for learner $learnerId, finger $finger");
        exit;
    }
    
    if (!is_string($template)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Template must be a string (old format), received: ' . gettype($template)]);
        error_log("Template validation failed: not a string for learner $learnerId, finger $finger");
        exit;
    }
    
    if (trim($template) === '') {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Template is whitespace only (old format)']);
        error_log("Template validation failed: whitespace only for learner $learnerId, finger $finger");
        exit;
    }
    
    if (strlen($template) < 10) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Template too short (old format, minimum 10 characters), received: ' . strlen($template) . ' characters']);
        error_log("Template validation failed: too short (" . strlen($template) . " chars) for learner $learnerId, finger $finger");
        exit;
    }
    
    // Log successful validation
    error_log("Template validation passed (old format): learner $learnerId, finger $finger, length " . strlen($template));
    
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
