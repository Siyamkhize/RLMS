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

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    error_log('Connection failed: ' . $conn->connect_error);
    ob_end_clean();
    echo json_encode(['status' => 'error', 'message' => 'Connection failed']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $learnerID = $_POST['learnerID'] ?? '';
    $assessorID = $_POST['assessorID'] ?? '';
    $assessmentDate = $_POST['assessmentDate'] ?? date('Y-m-d');

    if (empty($learnerID)) {
        ob_end_clean();
        echo json_encode(['status' => 'error', 'message' => 'Learner ID is required']);
        exit;
    }
    
    // Convert learnerID to integer (POE table expects INT)
    $learnerID = intval($learnerID);

    // Debug: Log what we received
    error_log('POST data: ' . print_r($_POST, true));
    error_log('FILES data: ' . print_r($_FILES, true));

    // Check if files were uploaded - handle both 'images' and 'images[]' field names
    $filesKey = isset($_FILES['images']) ? 'images' : (isset($_FILES['images_']) ? 'images_' : null);
    
    if ($filesKey === null || empty($_FILES[$filesKey]['name'][0])) {
        ob_end_clean();
        echo json_encode([
            'status' => 'error', 
            'message' => 'No images uploaded',
            'debug' => [
                'files_keys' => array_keys($_FILES),
                'post_data' => $_POST
            ]
        ]);
        exit;
    }

    $uploadDir = 'uploads/pothole_evidence/';
    
    // Create directory if it doesn't exist
    if (!file_exists($uploadDir)) {
        if (!mkdir($uploadDir, 0755, true)) {
            error_log("Failed to create upload directory: $uploadDir");
            ob_end_clean();
            echo json_encode([
                'status' => 'error',
                'message' => 'Failed to create upload directory. Please contact administrator.',
                'debug' => [
                    'directory' => $uploadDir,
                    'parent_exists' => file_exists('uploads/'),
                    'parent_writable' => file_exists('uploads/') ? is_writable('uploads/') : false
                ]
            ]);
            exit;
        }
        error_log("Created upload directory: $uploadDir");
    }
    
    // Verify directory is writable
    if (!is_writable($uploadDir)) {
        error_log("Upload directory is not writable: $uploadDir");
        ob_end_clean();
        echo json_encode([
            'status' => 'error',
            'message' => 'Upload directory is not writable. Please contact administrator.',
            'debug' => [
                'directory' => $uploadDir,
                'exists' => file_exists($uploadDir),
                'writable' => false
            ]
        ]);
        exit;
    }

    $uploadedFiles = [];
    $errors = [];
    $successCount = 0;

    // Process each uploaded file
    $fileCount = is_array($_FILES[$filesKey]['name']) ? count($_FILES[$filesKey]['name']) : 1;
    error_log("Processing $fileCount file(s) from field: $filesKey");
    
    for ($i = 0; $i < $fileCount; $i++) {
        $error = is_array($_FILES[$filesKey]['error']) ? $_FILES[$filesKey]['error'][$i] : $_FILES[$filesKey]['error'];
        
        if ($error === UPLOAD_ERR_OK) {
            $tmpName = is_array($_FILES[$filesKey]['tmp_name']) ? $_FILES[$filesKey]['tmp_name'][$i] : $_FILES[$filesKey]['tmp_name'];
            $originalName = is_array($_FILES[$filesKey]['name']) ? $_FILES[$filesKey]['name'][$i] : $_FILES[$filesKey]['name'];
            $fileSize = is_array($_FILES[$filesKey]['size']) ? $_FILES[$filesKey]['size'][$i] : $_FILES[$filesKey]['size'];
            $fileType = is_array($_FILES[$filesKey]['type']) ? $_FILES[$filesKey]['type'][$i] : $_FILES[$filesKey]['type'];
            
            error_log("Processing file: $originalName, size: $fileSize, type: $fileType");

            // Validate file type (images only) - check both MIME type and extension
            $allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
            $extension = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
            $allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
            
            // Check either MIME type or extension
            if (!in_array($fileType, $allowedTypes) && !in_array($extension, $allowedExtensions)) {
                error_log("File rejected: $originalName, type: $fileType, extension: $extension");
                $errors[] = "File $originalName is not a valid image type";
                continue;
            }
            
            error_log("File accepted: $originalName, type: $fileType, extension: $extension");

            // Validate file size (max 10MB)
            if ($fileSize > 10 * 1024 * 1024) {
                $errors[] = "File $originalName exceeds 10MB limit";
                continue;
            }

            // Generate unique filename
            $extension = pathinfo($originalName, PATHINFO_EXTENSION);
            $timestamp = time();
            $uniqueId = uniqid();
            $newFileName = "pothole_{$learnerID}_{$assessmentDate}_{$timestamp}_{$uniqueId}.{$extension}";
            $filePath = $uploadDir . $newFileName;

            // Move uploaded file
            if (move_uploaded_file($tmpName, $filePath)) {
                // Insert into poe table
                $exercise = "Pothole Patching Evidence - " . date('Y-m-d H:i:s', $timestamp);
                $type = "LogBook";
                $logbookText = "Pothole patching evidence uploaded by assessor $assessorID on $assessmentDate";

                $stmt = $conn->prepare('INSERT INTO poe (learnerID, exercise, type, filePath, logbook_text) VALUES (?, ?, ?, ?, ?)');
                
                if (!$stmt) {
                    $errors[] = "Database error for $originalName: " . $conn->error;
                    error_log("Failed to prepare statement: " . $conn->error);
                    // Delete the uploaded file if database insert fails
                    unlink($filePath);
                    continue;
                }

                // learnerID is INT, others are strings
                $stmt->bind_param('issss', $learnerID, $exercise, $type, $filePath, $logbookText);

                if ($stmt->execute()) {
                    $uploadedFiles[] = [
                        'original_name' => $originalName,
                        'file_path' => $filePath,
                        'poe_id' => $stmt->insert_id
                    ];
                    $successCount++;
                    error_log("Pothole evidence uploaded: learnerID=$learnerID, file=$filePath");
                } else {
                    $errors[] = "Failed to save $originalName to database: " . $stmt->error;
                    // Delete the uploaded file if database insert fails
                    unlink($filePath);
                }

                $stmt->close();
            } else {
                $errorMsg = "Failed to move uploaded file: $originalName";
                error_log($errorMsg);
                $errors[] = $errorMsg;
            }
        } else {
            $errorMsg = "Upload error for file at index $i: " . $error;
            error_log($errorMsg);
            $errors[] = $errorMsg;
        }
    }

    $conn->close();
    ob_end_clean();

    if ($successCount > 0) {
        echo json_encode([
            'status' => 'success',
            'message' => "$successCount image(s) uploaded successfully",
            'uploaded_files' => $uploadedFiles,
            'errors' => $errors,
            'success_count' => $successCount,
            'total_count' => $fileCount
        ]);
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'No images were uploaded successfully',
            'errors' => $errors
        ]);
    }
} else {
    ob_end_clean();
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method']);
}
?>
