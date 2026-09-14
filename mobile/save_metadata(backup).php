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
define('UPLOAD_DIR', 'POE/');
define('ALLOWED_EXTENSIONS', ['pdf']);
define('VALID_TYPES', ['Formative', 'Summative', 'LogBook', 'FormativeRemedial', 'SummativeRemedial']);

// Helper function to send JSON response and exit
function sendResponse($status, $message, $data = []) {
    global $conn;
    ob_end_clean();
    echo json_encode(array_merge(['status' => $status, 'message' => $message], $data));
    if (isset($conn)) $conn->close();
    exit;
}

// Helper function to clean up uploaded files
function cleanupFiles($files) {
    foreach ($files as $file) {
        $path = is_array($file) ? $file['path'] : $file;
        if (file_exists($path)) {
            unlink($path);
            error_log("Cleaned up file: $path");
        }
    }
}

// Helper function to get upload error message
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

// Database connection
$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    error_log('Connection failed: ' . $conn->connect_error);
    sendResponse('error', 'Connection failed');
}

// Handle OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse('error', 'Invalid request method');
}

// Extract and validate input
$learnerID = trim($_POST['learnerID'] ?? '');
$type = trim($_POST['type'] ?? '');
$unitStandardName = trim($_POST['unit_standard_name'] ?? ''); // Optional - for backward compatibility
$isUnitStandardUpload = isset($_POST['unit_standard_upload']) && $_POST['unit_standard_upload'] === 'true';
$exercisesJson = $_POST['exercises'] ?? '';
$isBulkUpload = !empty($exercisesJson);

// Basic validation
if (empty($learnerID) || empty($type)) {
    error_log('Missing learnerID or type');
    sendResponse('error', 'Missing required fields: learnerID and type');
}

if (!in_array($type, VALID_TYPES)) {
    error_log("Invalid type: $type");
    sendResponse('error', 'Invalid assessment type');
}

// Parse exercises
if ($isBulkUpload) {
    $exercises = json_decode($exercisesJson, true);
    if (!is_array($exercises) || empty($exercises)) {
        error_log('Invalid exercises data');
        sendResponse('error', 'Invalid exercises data');
    }
} else {
    $exercise = trim($_POST['exercise'] ?? '');
    $logbookText = trim($_POST['logbook_text'] ?? '');
    
    if (empty($exercise)) {
        error_log('Missing exercise field');
        sendResponse('error', 'Missing exercise field');
    }
    
    $exercises = [$exercise];
    $logbookTexts = [$logbookText];
}

error_log("Upload request: learnerID=$learnerID, type=$type, exercises=" . implode(',', $exercises));

// Check for duplicates
$placeholders = implode(',', array_fill(0, count($exercises), '?'));
$checkStmt = $conn->prepare("SELECT exercise FROM poe WHERE learnerID = ? AND type = ? AND exercise IN ($placeholders)");
if (!$checkStmt) {
    error_log('Prepare failed: ' . $conn->error);
    sendResponse('error', 'Database error');
}

$params = array_merge([$learnerID, $type], $exercises);
$types = str_repeat('s', count($params));
$checkStmt->bind_param($types, ...$params);
$checkStmt->execute();
$checkResult = $checkStmt->get_result();

$existingExercises = [];
while ($row = $checkResult->fetch_assoc()) {
    $existingExercises[] = $row['exercise'];
}
$checkStmt->close();

if (!empty($existingExercises)) {
    error_log('Duplicate exercises: ' . implode(',', $existingExercises));
    sendResponse('error', 'Some exercises have already been answered: ' . implode(', ', $existingExercises));
}

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

$totalFiles = count($_FILES['files']['name']);
error_log("Processing $totalFiles files for " . count($exercises) . " exercises");

// Validate file count
if ($totalFiles !== count($exercises)) {
    error_log("File count mismatch: Expected " . count($exercises) . ", got $totalFiles");
    sendResponse('error', "File count mismatch. Expected " . count($exercises) . " files, received $totalFiles");
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

    // Generate unique filename and move
    // CRITICAL FIX: Remove ALL whitespace characters including tabs, newlines, etc.
    // Windows/XAMPP cannot handle tab characters (\t) in file paths
    $sanitizedName = preg_replace('/\s+/', '_', basename($name)); // Replace all whitespace with underscore
    $sanitizedName = preg_replace('/[^a-zA-Z0-9._-]/', '', $sanitizedName); // Remove special chars
    $fileName = uniqid() . '_' . $sanitizedName;
    $destinationPath = UPLOAD_DIR . $fileName;

    if (move_uploaded_file($tmpPath, $destinationPath)) {
        $uploadedFiles[] = [
            'original_name' => $name,
            'saved_name' => $fileName,
            'path' => UPLOAD_DIR . $fileName,
            'size' => $fileSize,
            'exercise_index' => $key
        ];
        error_log("File uploaded: $name -> $destinationPath");
    } else {
        $errors[] = "Failed to save file: $name";
        error_log("Failed to move file: $name");
    }
}

// Check for errors
if (!empty($errors)) {
    cleanupFiles($uploadedFiles);
    error_log('File processing errors: ' . implode('; ', $errors));
    sendResponse('error', 'File processing errors: ' . implode('; ', $errors));
}

// Verify sufficient files
if (count($uploadedFiles) < count($exercises)) {
    cleanupFiles($uploadedFiles);
    sendResponse('error', 'Not enough files uploaded. Expected: ' . count($exercises) . ', Received: ' . count($uploadedFiles));
}

// Begin database transaction
$conn->begin_transaction();

try {
    if ($isUnitStandardUpload) {
        // Unit standard upload - single entry for all exercises
        $unitStandardExercise = "All $type Questions";
        $filePath = $uploadedFiles[0]['path'];
        
        // Check if unitStandard column exists before using it
        $checkColumnQuery = "SHOW COLUMNS FROM poe LIKE 'unitStandard'";
        $columnResult = $conn->query($checkColumnQuery);
        
        if ($columnResult && $columnResult->num_rows > 0) {
            // Column exists, use it
            $stmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, unitStandard, filePath, logbook_text) VALUES (?, ?, ?, ?, ?, ?)');
            if (!$stmt) throw new Exception('Database prepare error: ' . $conn->error);
            
            $emptyText = '';
            $stmt->bind_param('ssssss', $learnerID, $unitStandardExercise, $type, $unitStandardName, $filePath, $emptyText);
        } else {
            // Column doesn't exist, use original format
            $stmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, filePath, logbook_text) VALUES (?, ?, ?, ?, ?)');
            if (!$stmt) throw new Exception('Database prepare error: ' . $conn->error);
            
            $emptyText = '';
            $stmt->bind_param('sssss', $learnerID, $unitStandardExercise, $type, $filePath, $emptyText);
        }
        
        if (!$stmt->execute()) {
            throw new Exception('Failed to insert unit standard upload: ' . $stmt->error);
        }
        
        $stmt->close();
        $successCount = 1;
        $insertedExercises = [$unitStandardExercise];
        $insertedFiles = [$filePath];
        
        error_log("Unit standard upload successful: $unitStandardExercise");
        
    } else {
        // Regular upload - insert each exercise
        // Check if unitStandard column exists before using it
        $checkColumnQuery = "SHOW COLUMNS FROM poe LIKE 'unitStandard'";
        $columnResult = $conn->query($checkColumnQuery);
        
        if ($columnResult && $columnResult->num_rows > 0) {
            // Column exists, use it
            $stmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, unitStandard, filePath, logbook_text) VALUES (?, ?, ?, ?, ?, ?)');
            if (!$stmt) throw new Exception('Database prepare error: ' . $conn->error);
        } else {
            // Column doesn't exist, use original format
            $stmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, filePath, logbook_text) VALUES (?, ?, ?, ?, ?)');
            if (!$stmt) throw new Exception('Database prepare error: ' . $conn->error);
        }

        $successCount = 0;
        $insertedExercises = [];
        $insertedFiles = [];

        foreach ($exercises as $i => $exercise) {
            $filePath = $uploadedFiles[$i]['path'];
            $logbookText = $isBulkUpload ? '' : ($logbookTexts[$i] ?? '');
            
            if ($columnResult && $columnResult->num_rows > 0) {
                // Column exists
                $stmt->bind_param('ssssss', $learnerID, $exercise, $type, $unitStandardName, $filePath, $logbookText);
            } else {
                // Column doesn't exist
                $stmt->bind_param('sssss', $learnerID, $exercise, $type, $filePath, $logbookText);
            }
            
            if ($stmt->execute()) {
                $successCount++;
                $insertedExercises[] = $exercise;
                $insertedFiles[] = $filePath;
                error_log("Inserted: exercise=$exercise, file=$filePath");
            } else {
                throw new Exception("Failed to insert exercise: $exercise - " . $stmt->error);
            }
        }

        $stmt->close();
    }

    // Commit transaction
    $conn->commit();
    
    ob_end_clean();
    
    $response = [
        'status' => 'success',
        'message' => $isBulkUpload ? "Bulk upload successful. $successCount exercises uploaded." : 'Upload successful',
        'exercises' => $insertedExercises,
        'files' => $insertedFiles,
        'upload_details' => [
            'total_files' => count($uploadedFiles),
            'total_exercises' => count($exercises),
            'successful_uploads' => $successCount
        ]
    ];
    
    if (!$isBulkUpload) {
        $response['logbook_text'] = $logbookTexts[0] ?? '';
    }
    
    echo json_encode($response);
    error_log("Upload completed: $successCount exercises for learnerID=$learnerID, type=$type");

} catch (Exception $e) {
    $conn->rollback();
    cleanupFiles($uploadedFiles);
    error_log('Upload failed: ' . $e->getMessage());
    sendResponse('error', 'Upload failed: ' . $e->getMessage());
}

$conn->close();
ob_end_flush();
?>