<?php
/**
 * Corrected POE Document Upload Endpoint
 * Fixes common HTTP 500 error causes with robust error handling
 */

// Enable comprehensive error reporting but don't display in response
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// Set execution limits for large uploads
set_time_limit(600); // 10 minutes
ini_set('max_execution_time', '600');
ini_set('memory_limit', '512M');

// Set response headers early
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Create comprehensive debug log
$debugLog = __DIR__ . '/poe_upload_debug.log';
function debugLog($message, $level = 'INFO') {
    global $debugLog;
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[$timestamp] [$level] $message\n";
    file_put_contents($debugLog, $logEntry, FILE_APPEND | LOCK_EX);
}

// Start logging
debugLog("=== POE Upload Request Start ===");
debugLog("Method: " . $_SERVER['REQUEST_METHOD']);
debugLog("Content-Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));
debugLog("Content-Length: " . ($_SERVER['CONTENT_LENGTH'] ?? 'not set'));

try {
    // Validate request method
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Only POST method allowed');
    }

    // Log request data
    debugLog("POST keys: " . implode(', ', array_keys($_POST)));
    debugLog("FILES keys: " . implode(', ', array_keys($_FILES)));

    // Check for chunked upload parameters
    if (!isset($_POST['chunk_index']) || !isset($_POST['total_chunks']) || !isset($_POST['file_id'])) {
        throw new Exception('Missing required chunked upload parameters: chunk_index, total_chunks, file_id');
    }

    $chunkIndex = intval($_POST['chunk_index']);
    $totalChunks = intval($_POST['total_chunks']);
    $fileId = preg_replace('/[^a-zA-Z0-9_-]/', '', $_POST['file_id']); // Sanitize file ID

    debugLog("Processing chunk $chunkIndex of $totalChunks (File ID: $fileId)");

    // Validate chunk file upload
    if (!isset($_FILES['chunk'])) {
        throw new Exception('No chunk file found in upload');
    }

    $chunk = $_FILES['chunk'];
    debugLog("Chunk details - Error: {$chunk['error']}, Size: {$chunk['size']}, Type: {$chunk['type']}");

    // Check for upload errors
    if ($chunk['error'] !== UPLOAD_ERR_OK) {
        $uploadErrors = [
            UPLOAD_ERR_INI_SIZE => 'File exceeds upload_max_filesize (' . ini_get('upload_max_filesize') . ')',
            UPLOAD_ERR_FORM_SIZE => 'File exceeds MAX_FILE_SIZE directive',
            UPLOAD_ERR_PARTIAL => 'File was only partially uploaded',
            UPLOAD_ERR_NO_FILE => 'No file was uploaded',
            UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder',
            UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk',
            UPLOAD_ERR_EXTENSION => 'File upload stopped by extension'
        ];
        
        $errorMsg = $uploadErrors[$chunk['error']] ?? 'Unknown upload error: ' . $chunk['error'];
        throw new Exception("Chunk upload failed: $errorMsg");
    }

    // Validate chunk size
    if ($chunk['size'] <= 0) {
        throw new Exception('Chunk file is empty');
    }

    // Create upload directories with proper error handling
    $baseUploadDir = __DIR__ . '/uploads/';
    $poeUploadDir = $baseUploadDir . 'poe_documents/';
    $tempDir = $poeUploadDir . 'temp/';

    debugLog("Creating directories: $tempDir");

    // Create base upload directory
    if (!file_exists($baseUploadDir)) {
        if (!mkdir($baseUploadDir, 0755, true)) {
            throw new Exception('Failed to create base upload directory');
        }
        debugLog("Created base upload directory: $baseUploadDir");
    }

    // Create POE upload directory
    if (!file_exists($poeUploadDir)) {
        if (!mkdir($poeUploadDir, 0755, true)) {
            throw new Exception('Failed to create POE upload directory');
        }
        debugLog("Created POE upload directory: $poeUploadDir");
    }

    // Create temp directory
    if (!file_exists($tempDir)) {
        if (!mkdir($tempDir, 0755, true)) {
            throw new Exception('Failed to create temp directory');
        }
        debugLog("Created temp directory: $tempDir");
    }

    // Verify directory is writable
    if (!is_writable($tempDir)) {
        throw new Exception('Temp directory is not writable: ' . $tempDir);
    }

    // Save chunk with unique filename
    $chunkFilename = $fileId . '_chunk_' . str_pad($chunkIndex, 4, '0', STR_PAD_LEFT);
    $chunkPath = $tempDir . $chunkFilename;

    debugLog("Saving chunk to: $chunkPath");

    if (!move_uploaded_file($chunk['tmp_name'], $chunkPath)) {
        throw new Exception('Failed to save chunk file');
    }

    $savedSize = filesize($chunkPath);
    debugLog("Chunk saved successfully, size: $savedSize bytes");

    // If this is the last chunk, merge all chunks and save to database
    if ($chunkIndex === $totalChunks - 1) {
        debugLog("Last chunk received - starting merge process");

        // Validate required metadata
        $requiredFields = ['learner_id', 'learner_name'];
        foreach ($requiredFields as $field) {
            if (!isset($_POST[$field]) || empty(trim($_POST[$field]))) {
                throw new Exception("Missing required field: $field");
            }
        }

        $learnerId = trim($_POST['learner_id']);
        $learnerName = trim($_POST['learner_name']);
        $documentType = trim($_POST['document_type'] ?? 'POE');
        $pageCount = intval($_POST['page_count'] ?? 0);
        $fileExtension = trim($_POST['file_extension'] ?? 'pdf');
        $classId = trim($_POST['class_id'] ?? '');
        $siteName = trim($_POST['site_name'] ?? '');
        $uploadedBy = trim($_POST['uploaded_by'] ?? '');

        debugLog("Metadata - Learner: $learnerId ($learnerName), Type: $documentType, Pages: $pageCount");

        // Generate final filename
        $timestamp = time();
        $uniqueId = uniqid();
        $finalFilename = "POE_{$learnerId}_{$timestamp}_{$uniqueId}.{$fileExtension}";
        $finalPath = $poeUploadDir . $finalFilename;

        debugLog("Merging chunks into: $finalPath");

        // Open final file for writing
        $finalFile = fopen($finalPath, 'wb');
        if (!$finalFile) {
            throw new Exception('Cannot create final file: ' . $finalPath);
        }

        $totalSize = 0;
        $mergedChunks = 0;

        // Merge all chunks in order
        for ($i = 0; $i < $totalChunks; $i++) {
            $chunkFile = $tempDir . $fileId . '_chunk_' . str_pad($i, 4, '0', STR_PAD_LEFT);
            
            if (!file_exists($chunkFile)) {
                fclose($finalFile);
                unlink($finalPath);
                throw new Exception("Missing chunk file: $i");
            }

            $chunkData = file_get_contents($chunkFile);
            if ($chunkData === false) {
                fclose($finalFile);
                unlink($finalPath);
                throw new Exception("Cannot read chunk file: $i");
            }

            $bytesWritten = fwrite($finalFile, $chunkData);
            if ($bytesWritten === false) {
                fclose($finalFile);
                unlink($finalPath);
                throw new Exception("Cannot write chunk data: $i");
            }

            $totalSize += strlen($chunkData);
            $mergedChunks++;

            // Clean up chunk file
            unlink($chunkFile);
            debugLog("Merged and cleaned chunk $i");
        }

        fclose($finalFile);
        debugLog("File merge complete - Total size: $totalSize bytes, Chunks merged: $mergedChunks");

        // Verify final file
        $finalFileSize = filesize($finalPath);
        if ($finalFileSize !== $totalSize) {
            unlink($finalPath);
            throw new Exception("File size mismatch after merge. Expected: $totalSize, Got: $finalFileSize");
        }

        // Get MIME type
        $mimeType = 'application/pdf'; // Default
        if (function_exists('finfo_open')) {
            $finfo = finfo_open(FILEINFO_MIME_TYPE);
            if ($finfo) {
                $detectedMime = finfo_file($finfo, $finalPath);
                if ($detectedMime) {
                    $mimeType = $detectedMime;
                }
                finfo_close($finfo);
            }
        }

        debugLog("File MIME type: $mimeType");

        // Save to database
        debugLog("Connecting to database");
        
        // Check if connection file exists
        $connectionFile = __DIR__ . '/connection.php';
        if (!file_exists($connectionFile)) {
            unlink($finalPath);
            throw new Exception('Database connection file not found');
        }

        // Include connection with error handling
        ob_start();
        try {
            require_once $connectionFile;
        } catch (Exception $e) {
            ob_end_clean();
            unlink($finalPath);
            throw new Exception('Database connection error: ' . $e->getMessage());
        }
        $connectionOutput = ob_get_clean();

        if ($connectionOutput) {
            debugLog("Connection output: $connectionOutput");
        }

        if (!isset($conn)) {
            unlink($finalPath);
            throw new Exception('Database connection not established');
        }

        debugLog("Database connection successful");

        // Prepare and execute insert statement
        $sql = "INSERT INTO poe_documents (
            learner_id, learner_name, document_type, file_name, file_path,
            file_size, page_count, mime_type, class_id, site_name,
            uploaded_by, status, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', NOW())";

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            unlink($finalPath);
            throw new Exception('Database prepare error: ' . $conn->error);
        }

        $stmt->bind_param(
            'sssssisssss',
            $learnerId,
            $learnerName,
            $documentType,
            $finalFilename,
            $finalPath,
            $finalFileSize,
            $pageCount,
            $mimeType,
            $classId,
            $siteName,
            $uploadedBy
        );

        if (!$stmt->execute()) {
            unlink($finalPath);
            throw new Exception('Database insert error: ' . $stmt->error);
        }

        $documentId = $conn->insert_id;
        $stmt->close();

        debugLog("Database record created with ID: $documentId");

        // Success response for final chunk
        $response = [
            'success' => true,
            'message' => 'POE document uploaded successfully',
            'document_id' => $documentId,
            'file_name' => $finalFilename,
            'file_size' => $finalFileSize,
            'page_count' => $pageCount,
            'chunks_processed' => $totalChunks,
            'upload_time' => date('Y-m-d H:i:s')
        ];

        debugLog("Upload completed successfully - Document ID: $documentId");
        echo json_encode($response);

    } else {
        // Intermediate chunk response
        $response = [
            'success' => true,
            'message' => 'Chunk received successfully',
            'chunk_index' => $chunkIndex,
            'total_chunks' => $totalChunks,
            'chunk_size' => $savedSize
        ];

        debugLog("Chunk $chunkIndex processed successfully");
        echo json_encode($response);
    }

} catch (Exception $e) {
    debugLog("ERROR: " . $e->getMessage(), 'ERROR');
    debugLog("Stack trace: " . $e->getTraceAsString(), 'ERROR');

    // Clean up any partial files on error
    if (isset($tempDir) && isset($fileId)) {
        for ($i = 0; $i < ($totalChunks ?? 1); $i++) {
            $chunkFile = $tempDir . $fileId . '_chunk_' . str_pad($i, 4, '0', STR_PAD_LEFT);
            if (file_exists($chunkFile)) {
                unlink($chunkFile);
            }
        }
    }

    http_response_code(500);
    $errorResponse = [
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s'),
        'debug_info' => [
            'php_version' => PHP_VERSION,
            'upload_max_filesize' => ini_get('upload_max_filesize'),
            'post_max_size' => ini_get('post_max_size'),
            'memory_limit' => ini_get('memory_limit')
        ]
    ];

    echo json_encode($errorResponse);
}

debugLog("=== POE Upload Request End ===");
?>