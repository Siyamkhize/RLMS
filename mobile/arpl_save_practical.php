<?php
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', '/home/username/public_html/logs/php_error_log');
error_reporting(E_ALL);
ob_start();

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

include('connection.php');

// Constants
define('MAX_FILE_SIZE', 15 * 1024 * 1024); // 15MB
define('UPLOAD_DIR', 'ARPL_PRACTICAL/');
define('ALLOWED_EXTENSIONS', ['pdf']);

function sendResponse($status, $message, $data = []) {
    global $conn;
    ob_end_clean();
    $success = ($status === 'success');
    echo json_encode(array_merge(['status' => $status, 'success' => $success, 'message' => $message], $data));
    if (isset($conn)) $conn->close();
    exit;
}

function cleanupFiles($files) {
    foreach ($files as $file) {
        $path = is_array($file) ? $file['path'] : $file;
        if (file_exists($path)) {
            unlink($path);
            error_log("Cleaned up file: $path");
        }
    }
}

function getUploadErrorMessage($errorCode, $filename) {
    return match ($errorCode) {
        UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE => "File $filename exceeds maximum size limit",
        UPLOAD_ERR_PARTIAL => "File $filename was only partially uploaded",
        UPLOAD_ERR_NO_FILE => "No file was uploaded for $filename",
        UPLOAD_ERR_NO_TMP_DIR => "Missing temporary folder",
        UPLOAD_ERR_CANT_WRITE => "Failed to write file to disk",
        UPLOAD_ERR_EXTENSION => "File upload stopped by extension",
        default => "Unknown upload error for $filename",
    };
}

if (!$conn) {
    error_log('Connection failed');
    sendResponse('error', 'Connection failed');
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse('error', 'Invalid request method');
}

// Extract and validate input
$learnerID = trim($_POST['learnerID'] ?? '');
$ofoNumber = trim($_POST['ofo_number'] ?? '');
$paperTitle = trim($_POST['paper_title'] ?? '');
$paperNumber = trim($_POST['paper_number'] ?? '');
$questionCount = trim($_POST['question_count'] ?? 0);

if (empty($learnerID) || empty($paperTitle) || empty($paperNumber)) {
    error_log('Missing required fields');
    sendResponse('error', 'Missing required fields: learnerID, paper_title, paper_number');
}

// Check for duplicates
$checkStmt = $conn->prepare("SELECT id FROM arpl_practical WHERE learnerID = ? AND ofo_number = ? AND paper_number = ?");
if (!$checkStmt) {
    error_log('Prepare failed: ' . $conn->error);
    sendResponse('error', 'Database error');
}
$checkStmt->bind_param('sss', $learnerID, $ofoNumber, $paperNumber);
$checkStmt->execute();
$checkResult = $checkStmt->get_result();
if ($checkResult->num_rows > 0) {
    error_log('Duplicate practical upload found');
    sendResponse('error', 'This practical paper has already been uploaded');
}
$checkStmt->close();

// Ensure upload directory exists
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

// Process file uploads
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
    
    error_log("Processing PRACTICAL file $key: $name, Size: $fileSize bytes");

    if ($errorCode !== UPLOAD_ERR_OK) {
        $errors[] = getUploadErrorMessage($errorCode, $name);
        continue;
    }

    if ($fileSize > MAX_FILE_SIZE) {
        $sizeMB = round($fileSize / (1024 * 1024), 2);
        $errors[] = "File $name exceeds 15MB limit ({$sizeMB}MB)";
        error_log("File $name exceeds limit: {$sizeMB}MB");
        continue;
    }

    $extension = strtolower(pathinfo($name, PATHINFO_EXTENSION));
    if (!in_array($extension, ALLOWED_EXTENSIONS)) {
        $errors[] = "Invalid file type: $name. Only PDF files allowed";
        continue;
    }

    if (!file_exists($tmpPath) || !is_readable($tmpPath)) {
        $errors[] = "Cannot read uploaded file: $name";
        continue;
    }

    if (filesize($tmpPath) === 0) {
        $errors[] = "Empty file uploaded: $name";
        continue;
    }

    // Generate filename: All_Questions_[Paper_Title]_[OFO]_practical.pdf
    $sanitizedPaper = preg_replace('/\s+/', '_', $paperTitle);
    $sanitizedPaper = preg_replace('/[^a-zA-Z0-9._-]/', '', $sanitizedPaper);
    $sanitizedOFO = preg_replace('/\s+/', '_', $ofoNumber);
    $sanitizedOFO = preg_replace('/[^a-zA-Z0-9._-]/', '', $sanitizedOFO);
    
    $fileName = 'All_Questions_' . $sanitizedPaper . '_' . $sanitizedOFO . '_practical.' . $extension;
    $destinationPath = UPLOAD_DIR . $fileName;

    if (move_uploaded_file($tmpPath, $destinationPath)) {
        $uploadedFiles[] = [
            'original_name' => $name,
            'saved_name' => $fileName,
            'path' => UPLOAD_DIR . $fileName,
            'size' => $fileSize
        ];
        error_log("PRACTICAL PDF uploaded: $name -> $destinationPath");
    } else {
        $errors[] = "Failed to save file: $name";
        error_log("Failed to move file: $name");
    }
}

if (!empty($errors)) {
    cleanupFiles($uploadedFiles);
    error_log('File processing errors: ' . implode('; ', $errors));
    sendResponse('error', 'File processing errors: ' . implode('; ', $errors));
}

if (count($uploadedFiles) === 0) {
    sendResponse('error', 'No valid files uploaded');
}

// Begin database transaction
$conn->begin_transaction();

try {
    $filePath = $uploadedFiles[0]['path'];
    $fileName = $uploadedFiles[0]['saved_name'];
    
    // Insert into arpl_practical table (with rating_status = 'pending_rating')
    $stmt = $conn->prepare('INSERT INTO arpl_practical (learnerID, ofo_number, paper_title, paper_number, question_count, combined_pdf_path, file_name, rating_status, upload_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)');
    if (!$stmt) throw new Exception('Database prepare error: ' . $conn->error);
    
    $ratingStatus = 'pending_rating';  // Waiting for assessor to rate
    $uploadStatus = 'uploaded';
    $stmt->bind_param('sssiiisss', $learnerID, $ofoNumber, $paperTitle, $paperNumber, $questionCount, $filePath, $fileName, $ratingStatus, $uploadStatus);
    
    if (!$stmt->execute()) {
        throw new Exception('Failed to insert practical upload: ' . $stmt->error);
    }
    
    $stmt->close();
    $conn->commit();
    
    ob_end_clean();
    
    $response = [
        'status' => 'success',
        'message' => 'Practical PDF uploaded successfully. Awaiting assessor rating.',
        'paper_title' => $paperTitle,
        'paper_number' => $paperNumber,
        'file_name' => $fileName,
        'file_path' => $filePath,
        'section' => 'practical',
        'rating_status' => 'pending_rating'
    ];
    
    echo json_encode($response);
    error_log("ARPL PRACTICAL upload completed for learnerID=$learnerID, paper=$paperNumber, file=$filePath");

} catch (Exception $e) {
    $conn->rollback();
    cleanupFiles($uploadedFiles);
    error_log('Upload failed: ' . $e->getMessage());
    sendResponse('error', 'Upload failed: ' . $e->getMessage());
}

$conn->close();
ob_end_flush();
?>
