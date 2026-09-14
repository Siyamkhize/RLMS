<?php
header('Content-Type: application/json');

// Include database connection
require_once 'connection.php';

// Sanitize input
$learnerID = filter_input(INPUT_POST, 'LearnerID', FILTER_SANITIZE_STRING);
if (empty($learnerID)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'LearnerID is required']);
    exit;
}

// Check database connection
if ($conn->connect_error) {
    error_log("Database connection failed: " . $conn->connect_error);
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database connection failed']);
    exit;
}

// Check for uploaded file
if (!isset($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'No file uploaded or upload error']);
    exit;
}

// Validate file type and size
$allowedTypes = ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'];
$maxSize = 5 * 1024 * 1024; // 5MB
$fileType = $_FILES['file']['type'];
$fileSize = $_FILES['file']['size'];

if (!in_array($fileType, $allowedTypes) || $fileSize > $maxSize) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid file type or size']);
    exit;
}

// Define upload directory
$uploadDir = 'agreement/';
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

// Generate safe file name
$fileName = "Learner_Agreement_$learnerID.docx";
$filePath = $uploadDir . $fileName;

// Move uploaded file
try {
    if (!move_uploaded_file($_FILES['file']['tmp_name'], $filePath)) {
        error_log("Failed to move uploaded file to $filePath");
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Failed to save file']);
        exit;
    }
} catch (Exception $e) {
    error_log("Error moving uploaded file: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Failed to save file']);
    exit;
}

// Save to database
try {
    $query = "INSERT INTO learner_documents (learner_id, title, file_path, status, upload_date) 
              VALUES (?, ?, ?, 'synced', ?)
              ON DUPLICATE KEY UPDATE file_path = ?, status = 'synced', upload_date = ?";
    $stmt = $conn->prepare($query);
    if (!$stmt) {
        error_log("Prepare failed: " . $conn->error);
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Database query error']);
        exit;
    }
    $title = "Learner Agreement";
    $uploadDate = date('Y-m-d');
    $stmt->bind_param('ssssss', $learnerID, $title, $filePath, $uploadDate, $filePath, $uploadDate);
    if (!$stmt->execute()) {
        error_log("Database insert failed: " . $stmt->error);
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Failed to save document to database']);
        exit;
    }
} catch (Exception $e) {
    error_log("Database insert error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Failed to save document to database']);
    exit;
} finally {
    $stmt->close();
    $conn->close();
}

// Return success response
echo json_encode(['success' => true, 'message' => 'Agreement uploaded successfully']);
?>