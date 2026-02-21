<?php
// Security functions
if (!defined('SECURITY_FUNCTIONS_LOADED')) {
    require_once __DIR__ . '/../security_functions.php';
}

/**
 * Upload POE Document - Handles large multi-page PDF uploads
 * Supports chunked uploads to prevent timeout issues
 * Maximum file size: 200MB (configurable)
 */

// Increase execution time and upload limits for large uploads
set_time_limit(7200); // 2 hours (120 minutes)
ini_set('max_execution_time', '7200');
ini_set('max_input_time', '7200');
ini_set('upload_max_filesize', '200M');
ini_set('post_max_size', '200M');
ini_set('memory_limit', '256M');

// Set headers before any output (only if not already sent)
if (!headers_sent()) {
    header('Content-Type: application/json');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'connection.php';

// Configuration
$maxFileSize = 200 * 1024 * 1024; // 200MB
$uploadDir = __DIR__ . '/uploads/poe_documents/';
$allowedMimeTypes = ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png'];

// Create upload directory if it doesn't exist
if (!file_exists($uploadDir)) {
    if (!mkdir($uploadDir, 0777, true)) {
        echo json_encode([
            'success' => false,
            'message' => 'Failed to create upload directory'
        ]);
        exit;
    }
}

try {
    // Check if this is a chunked upload
    $isChunked = isset($_POST['chunk_index']) && isset($_POST['total_chunks']);
    
    if ($isChunked) {
        handleChunkedUpload($conn, $uploadDir, $maxFileSize);
    } else {
        handleDirectUpload($conn, $uploadDir, $maxFileSize, $allowedMimeTypes);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Upload failed: ' . $e->getMessage(),
        'error' => $e->getMessage()
    ]);
}

/**
 * Handle direct (non-chunked) upload
 */
function handleDirectUpload($conn, $uploadDir, $maxFileSize, $allowedMimeTypes) {
    // Validate required fields
    $requiredFields = ['learner_id', 'learner_name'];
    foreach ($requiredFields as $field) {
        if (!isset($_POST[$field]) || empty($_POST[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    // Check if file was uploaded
    if (!isset($_FILES['poe_document'])) {
        throw new Exception('No file uploaded - poe_document field missing');
    }
    
    $file = $_FILES['poe_document'];
    
    // Check for upload errors with detailed messages
    if ($file['error'] !== UPLOAD_ERR_OK) {
        $errorMessages = [
            UPLOAD_ERR_INI_SIZE => 'File exceeds PHP upload_max_filesize limit. Please contact administrator to increase limit.',
            UPLOAD_ERR_FORM_SIZE => 'File exceeds form MAX_FILE_SIZE limit',
            UPLOAD_ERR_PARTIAL => 'File was only partially uploaded. Please try again.',
            UPLOAD_ERR_NO_FILE => 'No file was uploaded',
            UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder on server',
            UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk',
            UPLOAD_ERR_EXTENSION => 'A PHP extension stopped the file upload',
        ];
        
        $errorMsg = isset($errorMessages[$file['error']]) ? 
            $errorMessages[$file['error']] : 
            'Unknown upload error code: ' . $file['error'];
            
        throw new Exception($errorMsg);
    }
    
    // Validate file size
    if ($file['size'] > $maxFileSize) {
        throw new Exception('File too large. Maximum size: ' . ($maxFileSize / 1024 / 1024) . 'MB');
    }
    
    // Validate MIME type
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mimeType = finfo_file($finfo, $file['tmp_name']);
    finfo_close($finfo);
    
    if (!in_array($mimeType, $allowedMimeTypes)) {
        throw new Exception('Invalid file type. Allowed: PDF, JPEG, PNG');
    }
    
    // Generate unique filename
    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $learnerId = trim($_POST['learner_id'] ?? '');
    if (empty($learnerId)) {
        throw new Exception('learner_id is required');
    }
    $timestamp = time();
    $uniqueId = uniqid();
    $fileName = "POE_{$learnerId}_{$timestamp}_{$uniqueId}.{$extension}";
    $filePath = $uploadDir . $fileName;
    
    // Move uploaded file
    if (!move_uploaded_file(sanitize_file_path($file, __DIR__)['tmp_name'], $filePath)) {
        throw new Exception('Failed to save uploaded file');
    }
    
    // Get additional data and sanitize
    $learnerName = trim($_POST['learner_name'] ?? '');
    $documentType = !empty($_POST['document_type']) ? trim($_POST['document_type']) : 'POE';
    $pageCount = isset($_POST['page_count']) ? intval($_POST['page_count']) : 0;
    $classId = !empty($_POST['class_id']) ? trim($_POST['class_id']) : null;
    $siteName = !empty($_POST['site_name']) ? trim($_POST['site_name']) : null;
    $uploadedBy = !empty($_POST['uploaded_by']) ? trim($_POST['uploaded_by']) : null;
    $notes = !empty($_POST['notes']) ? trim($_POST['notes']) : null;
    
    // Validate required fields
    if (empty($learnerName)) {
        unlink(sanitize_file_path($filePath, __DIR__));
        throw new Exception('learner_name is required');
    }
    
    // Use prepared statement to prevent SQL injection
    $stmt = $conn->prepare("INSERT INTO poe_documents (
        learner_id, learner_name, document_type, file_name, file_path,
        file_size, page_count, mime_type, class_id, site_name,
        uploaded_by, notes, status
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')");
    
    if (!$stmt) {
        unlink(sanitize_file_path($filePath, __DIR__));
        throw new Exception('Database prepare error: ' . $conn->error);
    }
    
    $stmt->bind_param(
        'sssssissssss',
        $learnerId,
        $learnerName,
        $documentType,
        $fileName,
        $filePath,
        $file['size'],
        $pageCount,
        $mimeType,
        $classId,
        $siteName,
        $uploadedBy,
        $notes
    );
    
    if (!$stmt->execute()) {
        $stmt->close();
        unlink(sanitize_file_path($filePath, __DIR__));
        throw new Exception('Database error: ' . $stmt->error);
    }
    
    $documentId = $conn->insert_id;
    $stmt->close();
    
    echo json_encode([
        'success' => true,
        'message' => 'POE document uploaded successfully',
        'document_id' => $documentId,
        'file_name' => $fileName,
        'file_size' => $file['size'],
        'page_count' => $pageCount,
        'upload_date' => date('Y-m-d H:i:s')
    ]);
}

/**
 * Handle chunked upload for very large files
 */
function handleChunkedUpload($conn, $uploadDir, $maxFileSize) {
    error_log("=== POE Chunked Upload Start ===");
    error_log("POST data: " . print_r($_POST, true));
    error_log("FILES data: " . print_r($_FILES, true));
    
    $chunkIndex = intval($_POST['chunk_index']);
    $totalChunks = intval($_POST['total_chunks']);
    $fileId = $_POST['file_id']; // Unique identifier for this upload session
    
    error_log("Chunk $chunkIndex of $totalChunks, File ID: $fileId");
    
    // Get metadata (sent with every chunk now) and sanitize
    $learnerId = !empty($_POST['learner_id']) ? trim($_POST['learner_id']) : null;
    $learnerName = !empty($_POST['learner_name']) ? trim($_POST['learner_name']) : null;
    $documentType = !empty($_POST['document_type']) ? trim($_POST['document_type']) : 'POE';
    $pageCount = isset($_POST['page_count']) ? intval($_POST['page_count']) : 0;
    $classId = !empty($_POST['class_id']) ? trim($_POST['class_id']) : null;
    $siteName = !empty($_POST['site_name']) ? trim($_POST['site_name']) : null;
    $uploadedBy = !empty($_POST['uploaded_by']) ? trim($_POST['uploaded_by']) : null;
    $fileExtension = !empty($_POST['file_extension']) ? trim($_POST['file_extension']) : 'pdf';
    
    error_log("Learner ID: $learnerId, Name: $learnerName, Type: $documentType");
    
    // Validate chunk data
    if (!isset($_FILES['chunk'])) {
        error_log("POE Upload Error: chunk file not in request");
        throw new Exception('Chunk file not found in request');
    }
    
    if ($_FILES['chunk']['error'] !== UPLOAD_ERR_OK) {
        $errorCode = $_FILES['chunk']['error'];
        $errorMessages = [
            UPLOAD_ERR_INI_SIZE => 'Chunk exceeds upload_max_filesize (' . ini_get('upload_max_filesize') . ')',
            UPLOAD_ERR_FORM_SIZE => 'Chunk exceeds form MAX_FILE_SIZE',
            UPLOAD_ERR_PARTIAL => 'Chunk was only partially uploaded',
            UPLOAD_ERR_NO_FILE => 'No chunk file uploaded',
            UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder',
            UPLOAD_ERR_CANT_WRITE => 'Failed to write chunk to disk',
            UPLOAD_ERR_EXTENSION => 'PHP extension stopped chunk upload',
        ];
        
        $errorMsg = isset($errorMessages[$errorCode]) ? 
            $errorMessages[$errorCode] : 
            'Unknown upload error code: ' . $errorCode;
            
        error_log("POE Upload Error: Chunk $chunkIndex failed - $errorMsg");
        throw new Exception('Chunk upload failed: ' . $errorMsg);
    }
    
    // Create temp directory for chunks
    $tempDir = $uploadDir . 'temp/';
    if (!file_exists($tempDir)) {
        mkdir($tempDir, 0777, true);
    }
    
    $chunkFile = $tempDir . $fileId . '_chunk_' . $chunkIndex;
    
    // Save chunk
    if (!$_FILES['chunk'] = $_FILES['chunk'] ?? '';
$safe_path_chunk = sanitize_file_path($_FILES['chunk'], __DIR__);
if ($safe_path_chunk === false) { error_log('Invalid path'); exit('Invalid file path'); }
move_uploaded_file($safe_path_chunk['tmp_name'], $chunkFile)) {
        throw new Exception('Failed to save chunk');
    }
    
    // Check if this is the last chunk
    if ($chunkIndex === $totalChunks - 1) {
        // Validate required fields for final merge
        if (!$learnerId || !$learnerName) {
            throw new Exception('Missing required fields: learner_id or learner_name');
        }
        
        // Merge all chunks
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
            unlink($chunkPath); // Delete chunk after merging
        }
        
        fclose($finalFile);
        
        // Get file info
        $fileSize = filesize($finalPath);
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $finalPath);
        finfo_close($finfo);
        
        // Insert into database using prepared statement
        $stmt = $conn->prepare("INSERT INTO poe_documents (
            learner_id, learner_name, document_type, file_name, file_path,
            file_size, page_count, mime_type, class_id, site_name,
            uploaded_by, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')");
        
        if (!$stmt) {
            unlink($finalPath);
            throw new Exception('Database prepare error: ' . $conn->error);
        }
        
        $stmt->bind_param(
            'sssssisssss',
            $learnerId,
            $learnerName,
            $documentType,
            $fileName,
            $finalPath,
            $fileSize,
            $pageCount,
            $mimeType,
            $classId,
            $siteName,
            $uploadedBy
        );
        
        if (!$stmt->execute()) {
            $stmt->close();
            unlink($finalPath);
            throw new Exception('Database error: ' . $stmt->error);
        }
        
        $documentId = $conn->insert_id;
        $stmt->close();
        
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
        // Chunk saved, waiting for more
        echo json_encode([
            'success' => true,
            'message' => 'Chunk received',
            'chunk_index' => $chunkIndex,
            'total_chunks' => $totalChunks
        ]);
    }
}

// Only close connection if not included from another script
if (!isset($GLOBALS['keep_connection_open'])) {
    $conn->close();
}
?>
