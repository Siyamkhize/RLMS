<?php
/**
 * Safe POE Upload - Fixed to handle base64 chunks in POST data
 */

// Prevent any output before headers
ob_start();

// Error handling
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/poe_upload_error.log');

// Catch fatal errors
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR])) {
        ob_clean();
        header('Content-Type: application/json');
        echo json_encode([
            'success' => false,
            'error' => 'Fatal error: ' . $error['message'],
            'file' => basename($error['file']),
            'line' => $error['line']
        ]);
    }
});

// Set limits
set_time_limit(7200);
ini_set('max_execution_time', '7200');
ini_set('memory_limit', '256M');

// Headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$logFile = __DIR__ . '/poe_upload_safe.log';

function logMessage($msg) {
    global $logFile;
    file_put_contents($logFile, date('Y-m-d H:i:s') . ' ' . $msg . "\n", FILE_APPEND);
}

try {
    logMessage("=== Upload started ===");
    logMessage("POST keys: " . implode(', ', array_keys($_POST)));
    logMessage("FILES keys: " . implode(', ', array_keys($_FILES)));
    
    // Check connection file
    if (!file_exists(__DIR__ . '/connection.php')) {
        throw new Exception('connection.php not found');
    }
    
    logMessage("Including connection.php");
    require_once 'connection.php';
    
    if (!isset($conn)) {
        throw new Exception('Database connection not established');
    }
    
    logMessage("Database connected");
    
    // Check if table exists
    $tableCheck = $conn->query("SHOW TABLES LIKE 'poe_documents'");
    if ($tableCheck->num_rows === 0) {
        throw new Exception('Table poe_documents does not exist. Run create_poe_documents_table.sql first.');
    }
    
    logMessage("Table exists");
    
    // Configuration
    $uploadDir = __DIR__ . '/uploads/poe_documents/';
    
    // Create directory
    if (!file_exists($uploadDir)) {
        if (!mkdir($uploadDir, 0777, true)) {
            throw new Exception('Failed to create upload directory');
        }
    }
    
    logMessage("Upload directory ready");
    
    // Check if chunked
    $isChunked = isset($_POST['chunk_index']) && isset($_POST['total_chunks']);
    
    logMessage("Is chunked: " . ($isChunked ? 'yes' : 'no'));
    
    if ($isChunked) {
        $chunkIndex = intval($_POST['chunk_index']);
        $totalChunks = intval($_POST['total_chunks']);
        $fileId = $_POST['file_id'];
        
        logMessage("Chunk $chunkIndex of $totalChunks, ID: $fileId");
        
        // FIXED: Check if chunk is in POST data (base64) or FILES
        $chunkData = null;
        
        if (isset($_POST['chunk']) && !empty($_POST['chunk'])) {
            // Chunk sent as base64 in POST data
            logMessage("Chunk found in POST data (base64)");
            
            $base64Chunk = $_POST['chunk'];
            
            // Remove data URI prefix if present (e.g., "data:application/pdf;base64,")
            if (strpos($base64Chunk, 'base64,') !== false) {
                $base64Chunk = substr($base64Chunk, strpos($base64Chunk, 'base64,') + 7);
            }
            
            $chunkData = base64_decode($base64Chunk);
            
            if ($chunkData === false) {
                throw new Exception('Failed to decode base64 chunk data');
            }
            
            logMessage("Chunk decoded, size: " . strlen($chunkData) . " bytes");
            
        } elseif (isset($_FILES['chunk'])) {
            // Chunk sent as file upload
            logMessage("Chunk found in FILES");
            
            if ($_FILES['chunk']['error'] !== UPLOAD_ERR_OK) {
                $errorCodes = [
                    UPLOAD_ERR_INI_SIZE => 'File exceeds upload_max_filesize (' . ini_get('upload_max_filesize') . ')',
                    UPLOAD_ERR_FORM_SIZE => 'File exceeds MAX_FILE_SIZE',
                    UPLOAD_ERR_PARTIAL => 'File was only partially uploaded',
                    UPLOAD_ERR_NO_FILE => 'No file was uploaded',
                    UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder',
                    UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk',
                    UPLOAD_ERR_EXTENSION => 'PHP extension stopped upload'
                ];
                $errorMsg = $errorCodes[$_FILES['chunk']['error']] ?? 'Unknown error: ' . $_FILES['chunk']['error'];
                throw new Exception('Chunk upload error: ' . $errorMsg);
            }
            
            $chunkData = file_get_contents($_FILES['chunk']['tmp_name']);
            logMessage("Chunk file loaded, size: " . strlen($chunkData) . " bytes");
            
        } else {
            throw new Exception('Chunk data not found in request (checked both POST and FILES)');
        }
        
        // Create temp directory
        $tempDir = $uploadDir . 'temp/';
        if (!file_exists($tempDir)) {
            mkdir($tempDir, 0777, true);
        }
        
        $chunkFile = $tempDir . $fileId . '_chunk_' . $chunkIndex;
        
        // Save chunk
        if (file_put_contents($chunkFile, $chunkData) === false) {
            throw new Exception('Failed to save chunk file');
        }
        
        logMessage("Chunk saved: $chunkFile");
        
        // Check if last chunk
        if ($chunkIndex === $totalChunks - 1) {
            logMessage("Last chunk - merging...");
            
            // Get metadata
            $learnerId = isset($_POST['learner_id']) ? $conn->real_escape_string($_POST['learner_id']) : null;
            $learnerName = isset($_POST['learner_name']) ? $conn->real_escape_string($_POST['learner_name']) : null;
            
            if (!$learnerId || !$learnerName) {
                throw new Exception('Missing required fields: learner_id or learner_name');
            }
            
            $documentType = isset($_POST['document_type']) ? $conn->real_escape_string($_POST['document_type']) : 'POE';
            $pageCount = isset($_POST['page_count']) ? intval($_POST['page_count']) : 0;
            $classId = isset($_POST['class_id']) ? $conn->real_escape_string($_POST['class_id']) : null;
            $siteName = isset($_POST['site_name']) ? $conn->real_escape_string($_POST['site_name']) : null;
            $uploadedBy = isset($_POST['uploaded_by']) ? $conn->real_escape_string($_POST['uploaded_by']) : null;
            $fileExtension = isset($_POST['file_extension']) ? $_POST['file_extension'] : 'pdf';
            
            // Merge chunks
            $timestamp = time();
            $uniqueId = uniqid();
            $fileName = "POE_{$learnerId}_{$timestamp}_{$uniqueId}.{$fileExtension}";
            $finalPath = $uploadDir . $fileName;
            
            logMessage("Merging to: $fileName");
            
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
                
                $chunkContent = file_get_contents($chunkPath);
                fwrite($finalFile, $chunkContent);
                unlink($chunkPath);
            }
            
            fclose($finalFile);
            
            $fileSize = filesize($finalPath);
            logMessage("File merged, size: $fileSize bytes");
            
            // Get MIME type
            $finfo = finfo_open(FILEINFO_MIME_TYPE);
            $mimeType = finfo_file($finfo, $finalPath);
            finfo_close($finfo);
            
            logMessage("MIME type: $mimeType");
            
            // Insert to database
            $sql = "INSERT INTO poe_documents (
                learner_id, learner_name, document_type, file_name, file_path,
                file_size, page_count, mime_type, class_id, site_name,
                uploaded_by, status
            ) VALUES (
                '$learnerId', 
                '$learnerName', 
                '$documentType', 
                '$fileName', 
                '$finalPath',
                $fileSize, 
                $pageCount, 
                '$mimeType', 
                " . ($classId ? "'$classId'" : "NULL") . ", 
                " . ($siteName ? "'$siteName'" : "NULL") . ", 
                " . ($uploadedBy ? "'$uploadedBy'" : "NULL") . ", 
                'active'
            )";
            
            logMessage("Executing SQL insert");
            
            if (!$conn->query($sql)) {
                $sqlError = $conn->error;
                $sqlErrno = $conn->errno;
                logMessage("SQL Error: $sqlError (Code: $sqlErrno)");
                unlink($finalPath);
                throw new Exception("Database error: $sqlError (Code: $sqlErrno)");
            }
            
            $documentId = $conn->insert_id;
            logMessage("Document saved to database, ID: $documentId");
            
            ob_clean();
            echo json_encode([
                'success' => true,
                'message' => 'POE document uploaded successfully',
                'document_id' => $documentId,
                'file_name' => $fileName,
                'file_size' => $fileSize,
                'page_count' => $pageCount,
                'chunks_merged' => $totalChunks
            ]);
            
        } else {
            // More chunks coming
            ob_clean();
            echo json_encode([
                'success' => true,
                'message' => 'Chunk received',
                'chunk_index' => $chunkIndex,
                'total_chunks' => $totalChunks
            ]);
        }
        
    } else {
        throw new Exception('Only chunked uploads are supported');
    }
    
    $conn->close();
    
} catch (Exception $e) {
    logMessage("ERROR: " . $e->getMessage());
    logMessage("Stack: " . $e->getTraceAsString());
    
    ob_clean();
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'type' => 'exception'
    ]);
}

ob_end_flush();
?>