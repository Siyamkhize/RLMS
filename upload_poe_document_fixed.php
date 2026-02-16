<?php
/**
 * Upload POE Document - Fixed version with better error handling
 * Handles large multi-page PDF uploads with chunked upload support
 */

// CRITICAL: Catch ALL errors before they become 500 errors
error_reporting(E_ALL);
ini_set('display_errors', 0); // Don't display errors (would break JSON)
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/poe_upload_errors.log');

// Set error handler to catch fatal errors
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        header('Content-Type: application/json');
        echo json_encode([
            'success' => false,
            'message' => 'Fatal error: ' . $error['message'],
            'file' => $error['file'],
            'line' => $error['line']
        ]);
    }
});

// Set exception handler
set_exception_handler(function($e) {
    header('Content-Type: application/json');
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Exception: ' . $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ]);
});

// Increase execution time and upload limits
set_time_limit(7200);
ini_set('max_execution_time', '7200');
ini_set('max_input_time', '7200');
ini_set('memory_limit', '256M');

// Set headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Log file for debugging
$logFile = __DIR__ . '/poe_upload.log';

try {
    // Include database connection
    if (!file_exists(__DIR__ . '/connection.php')) {
        throw new Exception('connection.php not found');
    }
    
    require_once 'connection.php';
    
    if (!isset($conn)) {
        throw new Exception('Database connection failed');
    }
    
    // Configuration
    $maxFileSize = 200 * 1024 * 1024; // 200MB
    $uploadDir = __DIR__ . '/uploads/poe_documents/';
    $allowedMimeTypes = ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png'];
    
    // Create upload directory
    if (!file_exists($uploadDir)) {
        if (!mkdir($uploadDir, 0777, true)) {
            throw new Exception('Failed to create upload directory');
        }
    }
    
    // Check if chunked upload
    $isChunked = isset($_POST['chunk_index']) && isset($_POST['total_chunks']);
    
    if ($isChunked) {
        handleChunkedUpload($conn, $uploadDir, $maxFileSize, $logFile);
    } else {
        handleDirectUpload($conn, $uploadDir, $maxFileSize, $allowedMimeTypes, $logFile);
    }
    
} catch (Exception $e) {
    file_put_contents($logFile, date('Y-m-d H:i:s') . " ERROR: " . $e->getMessage() . "\n", FILE_APPEND);
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'error_type' => 'exception'
    ]);
}

/**
 * Handle direct upload
 */
function handleDirectUpload($conn, $uploadDir, $maxFileSize, $allowedMimeTypes, $logFile) {
    file_put_contents($logFile, date('Y-m-d H:i:s') . " Direct upload started\n", FILE_APPEND);
    
    // Validate required fields
    if (!isset($_POST['learner_id']) || !isset($_POST['learner_name'])) {
        throw new Exception('Missing required fields: learner_id or learner_name');
    }
    
    // Check file
    if (!isset($_FILES['poe_document'])) {
        throw new Exception('No file uploaded');
    }
    
    $file = $_FILES['poe_document'];
    
    // Check upload errors
    if ($file['error'] !== UPLOAD_ERR_OK) {
        $errors = [
            UPLOAD_ERR_INI_SIZE => 'File exceeds upload_max_filesize',
            UPLOAD_ERR_FORM_SIZE => 'File exceeds MAX_FILE_SIZE',
            UPLOAD_ERR_PARTIAL => 'File partially uploaded',
            UPLOAD_ERR_NO_FILE => 'No file uploaded',
            UPLOAD_ERR_NO_TMP_DIR => 'Missing temp folder',
            UPLOAD_ERR_CANT_WRITE => 'Failed to write to disk',
            UPLOAD_ERR_EXTENSION => 'Extension stopped upload'
        ];
        throw new Exception($errors[$file['error']] ?? 'Upload error code: ' . $file['error']);
    }
    
    // Validate size
    if ($file['size'] > $maxFileSize) {
        throw new Exception('File too large. Max: ' . ($maxFileSize / 1024 / 1024) . 'MB');
    }
    
    // Validate MIME type
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mimeType = finfo_file($finfo, $file['tmp_name']);
    finfo_close($finfo);
    
    if (!in_array($mimeType, $allowedMimeTypes)) {
        throw new Exception('Invalid file type. Allowed: PDF, JPEG, PNG');
    }
    
    // Generate filename
    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $learnerId = $conn->real_escape_string($_POST['learner_id']);
    $timestamp = time();
    $uniqueId = uniqid();
    $fileName = "POE_{$learnerId}_{$timestamp}_{$uniqueId}.{$extension}";
    $filePath = $uploadDir . $fileName;
    
    // Move file
    if (!move_uploaded_file($file['tmp_name'], $filePath)) {
        throw new Exception('Failed to save file');
    }
    
    // Get metadata
    $learnerName = $conn->real_escape_string($_POST['learner_name']);
    $documentType = isset($_POST['document_type']) ? $conn->real_escape_string($_POST['document_type']) : 'POE';
    $pageCount = isset($_POST['page_count']) ? intval($_POST['page_count']) : 0;
    $classId = isset($_POST['class_id']) ? $conn->real_escape_string($_POST['class_id']) : null;
    $siteName = isset($_POST['site_name']) ? $conn->real_escape_string($_POST['site_name']) : null;
    $uploadedBy = isset($_POST['uploaded_by']) ? $conn->real_escape_string($_POST['uploaded_by']) : null;
    
    // Insert to database
    $sql = "INSERT INTO poe_documents (
        learner_id, learner_name, document_type, file_name, file_path,
        file_size, page_count, mime_type, class_id, site_name,
        uploaded_by, status
    ) VALUES (
        '$learnerId', '$learnerName', '$documentType', '$fileName', '$filePath',
        {$file['size']}, $pageCount, '$mimeType', " . 
        ($classId ? "'$classId'" : "NULL") . ", " .
        ($siteName ? "'$siteName'" : "NULL") . ", " .
        ($uploadedBy ? "'$uploadedBy'" : "NULL") . ", 'active'
    )";
    
    if (!$conn->query($sql)) {
        unlink($filePath);
        throw new Exception('Database error: ' . $conn->error);
    }
    
    $documentId = $conn->insert_id;
    
    file_put_contents($logFile, date('Y-m-d H:i:s') . " Direct upload success: $fileName\n", FILE_APPEND);
    
    echo json_encode([
        'success' => true,
        'message' => 'POE document uploaded successfully',
        'document_id' => $documentId,
        'file_name' => $fileName,
        'file_size' => $file['size'],
        'page_count' => $pageCount
    ]);
}

/**
 * Handle chunked upload
 */
function handleChunkedUpload($conn, $uploadDir, $maxFileSize, $logFile) {
    $chunkIndex = intval($_POST['chunk_index']);
    $totalChunks = intval($_POST['total_chunks']);
    $fileId = $_POST['file_id'];
    
    file_put_contents($logFile, date('Y-m-d H:i:s') . " Chunk $chunkIndex of $totalChunks (ID: $fileId)\n", FILE_APPEND);
    
    // Get metadata
    $learnerId = isset($_POST['learner_id']) ? $conn->real_escape_string($_POST['learner_id']) : null;
    $learnerName = isset($_POST['learner_name']) ? $conn->real_escape_string($_POST['learner_name']) : null;
    $documentType = isset($_POST['document_type']) ? $conn->real_escape_string($_POST['document_type']) : 'POE';
    $pageCount = isset($_POST['page_count']) ? intval($_POST['page_count']) : 0;
    $classId = isset($_POST['class_id']) ? $conn->real_escape_string($_POST['class_id']) : null;
    $siteName = isset($_POST['site_name']) ? $conn->real_escape_string($_POST['site_name']) : null;
    $uploadedBy = isset($_POST['uploaded_by']) ? $conn->real_escape_string($_POST['uploaded_by']) : null;
    $fileExtension = isset($_POST['file_extension']) ? $_POST['file_extension'] : 'pdf';
    
    // Validate chunk
    if (!isset($_FILES['chunk'])) {
        throw new Exception('Chunk file not found');
    }
    
    if ($_FILES['chunk']['error'] !== UPLOAD_ERR_OK) {
        $errors = [
            UPLOAD_ERR_INI_SIZE => 'Chunk exceeds upload_max_filesize',
            UPLOAD_ERR_FORM_SIZE => 'Chunk exceeds MAX_FILE_SIZE',
            UPLOAD_ERR_PARTIAL => 'Chunk partially uploaded',
            UPLOAD_ERR_NO_FILE => 'No chunk file',
            UPLOAD_ERR_NO_TMP_DIR => 'Missing temp folder',
            UPLOAD_ERR_CANT_WRITE => 'Failed to write chunk',
            UPLOAD_ERR_EXTENSION => 'Extension stopped chunk'
        ];
        throw new Exception($errors[$_FILES['chunk']['error']] ?? 'Chunk error: ' . $_FILES['chunk']['error']);
    }
    
    // Create temp directory
    $tempDir = $uploadDir . 'temp/';
    if (!file_exists($tempDir)) {
        if (!mkdir($tempDir, 0777, true)) {
            throw new Exception('Failed to create temp directory');
        }
    }
    
    $chunkFile = $tempDir . $fileId . '_chunk_' . $chunkIndex;
    
    // Save chunk
    if (!move_uploaded_file($_FILES['chunk']['tmp_name'], $chunkFile)) {
        throw new Exception('Failed to save chunk');
    }
    
    file_put_contents($logFile, date('Y-m-d H:i:s') . " Chunk $chunkIndex saved\n", FILE_APPEND);
    
    // Check if last chunk
    if ($chunkIndex === $totalChunks - 1) {
        file_put_contents($logFile, date('Y-m-d H:i:s') . " Last chunk - merging...\n", FILE_APPEND);
        
        // Validate required fields
        if (!$learnerId || !$learnerName) {
            throw new Exception('Missing learner_id or learner_name');
        }
        
        // Merge chunks
        $timestamp = time();
        $uniqueId = uniqid();
        $fileName = "POE_{$learnerId}_{$timestamp}_{$uniqueId}.{$fileExtension}";
        $finalPath = $uploadDir . $fileName;
        
        $finalFile = fopen($finalPath, 'wb');
        if (!$finalFile) {
            throw new Exception('Failed to create final file');
        }
        
        for ($i = 0; $i < $totalChunks; $i++) {
            $chunkPath = $tempDir . $fileId . '_chunk_' . $i;
            if (!file_exists($chunkPath)) {
                fclose($finalFile);
                throw new Exception("Missing chunk: $i");
            }
            
            $chunkData = file_get_contents($chunkPath);
            fwrite($finalFile, $chunkData);
            unlink($chunkPath);
        }
        
        fclose($finalFile);
        
        // Get file info
        $fileSize = filesize($finalPath);
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $finalPath);
        finfo_close($finfo);
        
        // Insert to database
        $sql = "INSERT INTO poe_documents (
            learner_id, learner_name, document_type, file_name, file_path,
            file_size, page_count, mime_type, class_id, site_name,
            uploaded_by, status
        ) VALUES (
            '$learnerId', '$learnerName', '$documentType', '$fileName', '$finalPath',
            $fileSize, $pageCount, '$mimeType', " . 
            ($classId ? "'$classId'" : "NULL") . ", " .
            ($siteName ? "'$siteName'" : "NULL") . ", " .
            ($uploadedBy ? "'$uploadedBy'" : "NULL") . ", 'active'
        )";
        
        if (!$conn->query($sql)) {
            unlink($finalPath);
            throw new Exception('Database error: ' . $conn->error);
        }
        
        $documentId = $conn->insert_id;
        
        file_put_contents($logFile, date('Y-m-d H:i:s') . " Chunked upload complete: $fileName\n", FILE_APPEND);
        
        echo json_encode([
            'success' => true,
            'message' => 'POE document uploaded successfully (chunked)',
            'document_id' => $documentId,
            'file_name' => $fileName,
            'file_size' => $fileSize,
            'page_count' => $pageCount,
            'chunks_merged' => $totalChunks
        ]);
    } else {
        // More chunks coming
        echo json_encode([
            'success' => true,
            'message' => 'Chunk received',
            'chunk_index' => $chunkIndex,
            'total_chunks' => $totalChunks
        ]);
    }
}

$conn->close();
?>
