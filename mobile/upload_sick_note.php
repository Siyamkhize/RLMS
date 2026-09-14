<?php
session_start();
include 'connection.php';

// Set headers for JSON response
header('Content-Type: application/json');

// Function to send JSON response
function sendResponse($success, $message) {
    echo json_encode(['success' => $success, 'message' => $message]);
    exit;
}

// Validate request method and required fields
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse(false, 'Invalid request method. Only POST is allowed.');
}

// Check required POST fields
$requiredFields = ['learner_id', 'practice_name', 'medical_practitioner', 'practitioner_name', 'date_from', 'date_to'];
foreach ($requiredFields as $field) {
    if (!isset($_POST[$field]) || empty(trim($_POST[$field]))) {
        sendResponse(false, "Missing or empty field: $field");
    }
}

// Check for file upload
if (!isset($_FILES['sick_note']) || $_FILES['sick_note']['error'] === UPLOAD_ERR_NO_FILE) {
    sendResponse(false, 'No file uploaded.');
}

// Sanitize input fields
$learnerID = filter_var(trim($_POST['learner_id']), FILTER_SANITIZE_STRING);
$practiceName = filter_var(trim($_POST['practice_name']), FILTER_SANITIZE_STRING);
$medicalPractitioner = filter_var(trim($_POST['medical_practitioner']), FILTER_SANITIZE_STRING);
$practitionerName = filter_var(trim($_POST['practitioner_name']), FILTER_SANITIZE_STRING);
$dateFrom = filter_var(trim($_POST['date_from']), FILTER_SANITIZE_STRING);
$dateTo = filter_var(trim($_POST['date_to']), FILTER_SANITIZE_STRING);

// Validate date formats (YYYY-MM-DD)
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $dateFrom) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $dateTo)) {
    sendResponse(false, 'Invalid date format. Use YYYY-MM-DD.');
}

// Validate file
$file = $_FILES['sick_note'];
$allowedTypes = ['application/pdf'];
$maxFileSize = 5 * 1024 * 1024; // 5MB

if (!in_array($file['type'], $allowedTypes) || $file['size'] > $maxFileSize || $file['error'] !== UPLOAD_ERR_OK) {
    sendResponse(false, 'Invalid file. Only PDF files up to 5MB are allowed.');
}

// Sanitize file name
$originalFileName = pathinfo($file['name'], PATHINFO_FILENAME);
$extension = pathinfo($file['name'], PATHINFO_EXTENSION);
$safeFileName = preg_replace('/[^A-Za-z0-9_-]/', '_', $originalFileName);
$fileName = $learnerID . '_' . time() . '_' . $safeFileName . '.' . $extension;

// Set upload directory
$uploadDir = 'sicknotes/';
if (!is_dir($uploadDir) && !mkdir($uploadDir, 0755, true)) {
    sendResponse(false, 'Failed to create upload directory.');
}
$filePath = $uploadDir . $fileName;

// Check for duplicate entries
try {
    $checkSql = "SELECT COUNT(*) as count FROM sick_note WHERE learner_id = ? AND date_from = ? AND date_to = ?";
    $checkStmt = $conn->prepare($checkSql);
    if (!$checkStmt) {
        sendResponse(false, 'Database query preparation failed.');
    }
    $checkStmt->bind_param('sss', $learnerID, $dateFrom, $dateTo);
    $checkStmt->execute();
    $result = $checkStmt->get_result();
    $row = $result->fetch_assoc();
    $checkStmt->close();

    if ($row['count'] > 0) {
        sendResponse(false, 'A sick note for this learner and date range already exists.');
    }
} catch (Exception $e) {
    sendResponse(false, 'Database error: ' . $e->getMessage());
}

// Move uploaded file
if (!move_uploaded_file($file['tmp_name'], $filePath)) {
    sendResponse(false, 'Failed to upload file.');
}

// Insert into database
try {
    $insertSql = "INSERT INTO sick_note 
        (learner_id, document_path, practice_name, medical_practitioner, practitioner_name, date_from, date_to, upload_date, status, rejection_reason) 
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), 'PENDING', NULL)";
    $stmt = $conn->prepare($insertSql);
    if (!$stmt) {
        sendResponse(false, 'Database query preparation failed.');
    }
    $stmt->bind_param('sssssss', $learnerID, $filePath, $practiceName, $medicalPractitioner, $practitionerName, $dateFrom, $dateTo);
    
    if ($stmt->execute()) {
        sendResponse(true, 'Sick note uploaded successfully and is now pending approval.');
    } else {
        sendResponse(false, 'Failed to save sick note to database.');
    }
    $stmt->close();
} catch (Exception $e) {
    sendResponse(false, 'Database error: ' . $e->getMessage());
}

// Close database connection
$conn->close();
?>