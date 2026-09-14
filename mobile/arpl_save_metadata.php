<?php
/**
 * ARPL PDF Metadata Upload Handler
 * Unified table approach - stores both theory and practical in arpl_poe table
 * Created: July 7, 2026
 */

ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', '/home/username/public_html/logs/php_error_log');
error_reporting(E_ALL);
ob_start();

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

include_once 'connection.php';

// Constants
define('MAX_FILE_SIZE', 15 * 1024 * 1024); // 15MB
define('UPLOAD_DIR', 'ARPL_POE/');
define('ALLOWED_EXTENSIONS', ['pdf']);

/**
 * Send JSON response and exit
 */
function sendResponse($status, $message, $data = []) {
    global $conn;
    ob_end_clean();
    $success = ($status === 'success');
    echo json_encode(array_merge(
        ['status' => $status, 'success' => $success, 'message' => $message],
        $data
    ));
    if (isset($conn)) {
        $conn->close();
    }
    exit;
}

/**
 * Clean up uploaded files on error
 */
function cleanupFiles($files) {
    foreach ($files as $file) {
        $path = is_array($file) ? $file['path'] : $file;
        if (file_exists($path)) {
            unlink($path);
            error_log("Cleaned up file: $path");
        }
    }
}

/**
 * Get upload error message
 */
function getUploadErrorMessage($errorCode, $filename) {
    switch ($errorCode) {
        case UPLOAD_ERR_INI_SIZE:
        case UPLOAD_ERR_FORM_SIZE:
            return "File $filename exceeds maximum size limit";
        case UPLOAD_ERR_PARTIAL:
            return "File $filename was only partially uploaded";
        case UPLOAD_ERR_NO_FILE:
            return "No file was uploaded for $filename";
        case UPLOAD_ERR_NO_TMP_DIR:
            return "Missing temporary folder";
        case UPLOAD_ERR_CANT_WRITE:
            return "Failed to write file to disk";
        case UPLOAD_ERR_EXTENSION:
            return "File upload stopped by extension";
        default:
            return "Unknown upload error for $filename";
    }
}

// Check database connection
if (!$conn) {
    error_log('Connection failed');
    sendResponse('error', 'Database connection failed');
}

// Handle OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse('error', 'Invalid request method. POST required.');
}

// ============================================
// VALIDATE INPUT PARAMETERS
// ============================================
$learnerID = trim($_POST['learnerID'] ?? '');
$ofoNumber = trim($_POST['ofo_number'] ?? '');
$paperTitle = trim($_POST['paper_title'] ?? '');
$paperNumber = trim($_POST['paper_number'] ?? '');
$sectionType = trim($_POST['section_type'] ?? '');
$questionCount = intval($_POST['question_count'] ?? 0);

// Validate required fields
if (empty($learnerID) || empty($ofoNumber) || empty($paperTitle) || empty($paperNumber) || empty($sectionType)) {
    error_log('Missing required fields: learnerID=' . $learnerID . ', ofo=' . $ofoNumber . ', paperTitle=' . $paperTitle . ', paperNumber=' . $paperNumber . ', sectionType=' . $sectionType);
    sendResponse('error', 'Missing required fields: learnerID, ofo_number, paper_title, paper_number, section_type');
}

// Normalize and validate section_type
$sectionType = strtolower($sectionType);
if (!in_array($sectionType, ['theory', 'practical'])) {
    error_log('Invalid section_type: ' . $sectionType);
    sendResponse('error', 'section_type must be either "theory" or "practical"');
}

// ============================================
// CHECK FOR DUPLICATE UPLOADS
// ============================================
$checkStmt = $conn->prepare("
    SELECT id FROM arpl_poe 
    WHERE learnerID = ? AND ofo_number = ? AND paper_number = ? AND section_type = ?
");

if (!$checkStmt) {
    error_log('Prepare failed: ' . $conn->error);
    sendResponse('error', 'Database error: cannot check for duplicates');
}

$checkStmt->bind_param('isss', $learnerID, $paperNumber, $sectionType, $ofoNumber);
$checkStmt->execute();
$checkResult = $checkStmt->get_result();

if ($checkResult->num_rows > 0) {
    $checkStmt->close();
    error_log('Duplicate upload: learnerID=' . $learnerID . ', ofo=' . $ofoNumber . ', paper=' . $paperNumber . ', section=' . $sectionType);
    sendResponse('error', ucfirst($sectionType) . ' paper #' . $paperNumber . ' has already been uploaded');
}
$checkStmt->close();

// ============================================
// ENSURE UPLOAD DIRECTORY EXISTS
// ============================================
if (!is_dir(UPLOAD_DIR)) {
    if (!mkdir(UPLOAD_DIR, 0777, true)) {
        error_log('Failed to create directory: ' . UPLOAD_DIR);
        sendResponse('error', 'Failed to create upload directory');
    }
}

if (!is_writable(UPLOAD_DIR)) {
    error_log('Upload directory not writable: ' . UPLOAD_DIR);
    sendResponse('error', 'Upload directory is not writable');
}

// ============================================
// PROCESS FILE UPLOADS
// ============================================
if (!isset($_FILES['files']) || !is_array($_FILES['files']['name'])) {
    error_log('No files uploaded');
    sendResponse('error', 'No files uploaded');
}

$uploadedFiles = [];
$errors = [];

foreach ($_FILES['files']['name'] as $key => $name) {
    $errorCode = $_FILES['files']['error'][$key];
    $tmpPath = $_FILES['files']['tmp_name'][$key];
    $fileSize = $_FILES['files']['size'][$key];

    error_log("Processing file $key: $name, Size: $fileSize bytes");

    // Check upload errors
    if ($errorCode !== UPLOAD_ERR_OK) {
        $errors[] = getUploadErrorMessage($errorCode, $name);
        continue;
    }

    // Validate file size
    if ($fileSize > MAX_FILE_SIZE) {
        $sizeMB = round($fileSize / (1024 * 1024), 2);
        $errors[] = "File $name exceeds 15MB limit ({$sizeMB}MB)";
        error_log("File $name exceeds limit: {$sizeMB}MB");
        continue;
    }

    // Validate file extension
    $extension = strtolower(pathinfo($name, PATHINFO_EXTENSION));
    if (!in_array($extension, ALLOWED_EXTENSIONS)) {
        $errors[] = "Invalid file type: $name. Only PDF files allowed";
        continue;
    }

    // Validate file exists and is readable
    if (!file_exists($tmpPath) || !is_readable($tmpPath)) {
        $errors[] = "Cannot read uploaded file: $name";
        continue;
    }

    // Validate file is not empty
    if (filesize($tmpPath) === 0) {
        $errors[] = "Empty file uploaded: $name";
        continue;
    }

    // ============================================
    // GENERATE FILENAME
    // Format: All_Questions_[Paper_Title]_[OFO]_[theory|practical].pdf
    // Example: All_Questions_Apply_health_and_safety_to_comply_with_OHSA_9964_theory.pdf
    // ============================================
    $sanitizedPaper = preg_replace('/\s+/', '_', $paperTitle);
    $sanitizedPaper = preg_replace('/[^a-zA-Z0-9._-]/', '', $sanitizedPaper);
    $sanitizedOFO = preg_replace('/[^a-zA-Z0-9._-]/', '', $ofoNumber);

    $fileName = 'All_Questions_' . $sanitizedPaper . '_' . $sanitizedOFO . '_' . $sectionType . '.' . $extension;
    $destinationPath = UPLOAD_DIR . $fileName;

    // Move uploaded file to destination
    if (move_uploaded_file($tmpPath, $destinationPath)) {
        $uploadedFiles[] = [
            'original_name' => $name,
            'saved_name' => $fileName,
            'path' => $destinationPath,
            'size' => $fileSize
        ];
        error_log("File uploaded successfully: $fileName");
    } else {
        $errors[] = "Failed to save file: $name";
        error_log("Failed to move file: $name to $destinationPath");
    }
}

// Check for file processing errors
if (!empty($errors)) {
    cleanupFiles($uploadedFiles);
    error_log('File processing errors: ' . implode('; ', $errors));
    sendResponse('error', 'File processing errors: ' . implode('; ', $errors));
}

// Verify we have at least one file
if (empty($uploadedFiles)) {
    sendResponse('error', 'No valid files uploaded');
}

// ============================================
// INSERT INTO UNIFIED arpl_poe TABLE
// ============================================
$conn->begin_transaction();

try {
    $filePath = $uploadedFiles[0]['path'];
    $fileName = $uploadedFiles[0]['saved_name'];
    $uploadStatus = 'uploaded';

    // For practical papers: set rating_status to 'pending_rating' (awaiting assessor)
    // For theory papers: rating_status stays NULL (not applicable)
    $ratingStatus = ($sectionType === 'practical') ? 'pending_rating' : NULL;

    $stmt = $conn->prepare('
        INSERT INTO arpl_poe (
            learnerID, ofo_number, paper_title, paper_number, section_type,
            question_count, combined_pdf_path, file_name, upload_status, rating_status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ');

    if (!$stmt) {
        throw new Exception('Database prepare error: ' . $conn->error);
    }

    $stmt->bind_param(
        'issssiisss',
        $learnerID,
        $ofoNumber,
        $paperTitle,
        $paperNumber,
        $sectionType,
        $questionCount,
        $filePath,
        $fileName,
        $uploadStatus,
        $ratingStatus
    );

    if (!$stmt->execute()) {
        throw new Exception('Failed to insert record: ' . $stmt->error);
    }

    $recordId = $stmt->insert_id;
    $stmt->close();

    // Commit transaction
    $conn->commit();

    // ============================================
    // SUCCESS RESPONSE
    // ============================================
    ob_end_clean();

    $response = [
        'status' => 'success',
        'message' => ucfirst($sectionType) . ' paper uploaded successfully',
        'data' => [
            'record_id' => $recordId,
            'learnerID' => $learnerID,
            'ofo_number' => $ofoNumber,
            'paper_title' => $paperTitle,
            'paper_number' => $paperNumber,
            'section_type' => $sectionType,
            'question_count' => $questionCount,
            'file_name' => $fileName,
            'file_path' => $filePath,
            'upload_status' => $uploadStatus,
            'rating_status' => $ratingStatus,
            'file_size' => $uploadedFiles[0]['size'],
            'uploaded_at' => date('Y-m-d H:i:s')
        ]
    ];

    echo json_encode($response);
    error_log("ARPL upload success: learnerID=$learnerID, ofo=$ofoNumber, paper=$paperNumber, section=$sectionType, recordId=$recordId");

} catch (Exception $e) {
    $conn->rollback();
    cleanupFiles($uploadedFiles);
    error_log('Upload failed: ' . $e->getMessage());
    sendResponse('error', 'Upload failed: ' . $e->getMessage());
}

$conn->close();
ob_end_flush();

