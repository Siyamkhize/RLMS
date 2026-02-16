<?php
/**
 * Minimal POE Upload Endpoint for Debugging 500 Errors
 * Strips down to bare essentials to identify the problem
 */

// Enable error reporting and logging
error_reporting(E_ALL);
ini_set('display_errors', 0); // Don't display errors in response
ini_set('log_errors', 1);

// Create debug log
$debugLog = __DIR__ . '/poe_debug.log';
function debugLog($message) {
    global $debugLog;
    file_put_contents($debugLog, date('Y-m-d H:i:s') . " - $message\n", FILE_APPEND);
}

debugLog("=== POE Upload Debug Start ===");
debugLog("Method: " . $_SERVER['REQUEST_METHOD']);
debugLog("Content-Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));

// Set response headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    debugLog("OPTIONS request - sending 200");
    http_response_code(200);
    exit();
}

try {
    debugLog("Processing POST request");
    
    // Step 1: Basic validation
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Only POST method allowed');
    }
    
    debugLog("POST data keys: " . implode(', ', array_keys($_POST)));
    debugLog("FILES data keys: " . implode(', ', array_keys($_FILES)));
    
    // Step 2: Check for chunked upload
    $isChunked = isset($_POST['chunk_index']) && isset($_POST['total_chunks']);
    debugLog("Is chunked upload: " . ($isChunked ? 'YES' : 'NO'));
    
    if (!$isChunked) {
        throw new Exception('Only chunked uploads supported in debug mode');
    }
    
    // Step 3: Get chunk info
    $chunkIndex = intval($_POST['chunk_index']);
    $totalChunks = intval($_POST['total_chunks']);
    $fileId = $_POST['file_id'] ?? 'unknown';
    
    debugLog("Chunk: $chunkIndex of $totalChunks, File ID: $fileId");
    
    // Step 4: Validate chunk file
    if (!isset($_FILES['chunk'])) {
        throw new Exception('No chunk file in request');
    }
    
    $chunk = $_FILES['chunk'];
    debugLog("Chunk error: " . $chunk['error']);
    debugLog("Chunk size: " . $chunk['size']);
    debugLog("Chunk type: " . $chunk['type']);
    debugLog("Chunk tmp_name: " . $chunk['tmp_name']);
    
    if ($chunk['error'] !== UPLOAD_ERR_OK) {
        $errors = [
            UPLOAD_ERR_INI_SIZE => 'File too large (upload_max_filesize)',
            UPLOAD_ERR_FORM_SIZE => 'File too large (MAX_FILE_SIZE)',
            UPLOAD_ERR_PARTIAL => 'File partially uploaded',
            UPLOAD_ERR_NO_FILE => 'No file uploaded',
            UPLOAD_ERR_NO_TMP_DIR => 'Missing temp directory',
            UPLOAD_ERR_CANT_WRITE => 'Cannot write to disk',
            UPLOAD_ERR_EXTENSION => 'Upload stopped by extension'
        ];
        
        $errorMsg = $errors[$chunk['error']] ?? 'Unknown error ' . $chunk['error'];
        throw new Exception("Chunk upload error: $errorMsg");
    }
    
    // Step 5: Create upload directory
    $uploadDir = __DIR__ . '/uploads/poe_documents/';
    $tempDir = $uploadDir . 'temp/';
    
    debugLog("Upload dir: $uploadDir");
    debugLog("Temp dir: $tempDir");
    
    if (!file_exists($tempDir)) {
        debugLog("Creating temp directory");
        if (!mkdir($tempDir, 0777, true)) {
            throw new Exception('Failed to create temp directory');
        }
    }
    
    // Step 6: Save chunk
    $chunkPath = $tempDir . $fileId . '_chunk_' . $chunkIndex;
    debugLog("Saving chunk to: $chunkPath");
    
    if (!move_uploaded_file($chunk['tmp_name'], $chunkPath)) {
        throw new Exception('Failed to move uploaded chunk');
    }
    
    $savedSize = filesize($chunkPath);
    debugLog("Chunk saved successfully, size: $savedSize bytes");
    
    // Step 7: If last chunk, try database connection
    if ($chunkIndex === $totalChunks - 1) {
        debugLog("Last chunk - testing database connection");
        
        // Try to connect to database
        if (file_exists(__DIR__ . '/connection.php')) {
            debugLog("Including connection.php");
            require_once 'connection.php';
            
            if (isset($conn)) {
                debugLog("Database connection successful");
                
                // Test query
                $result = $conn->query("SELECT 1");
                if ($result) {
                    debugLog("Database query test successful");
                } else {
                    debugLog("Database query failed: " . $conn->error);
                }
            } else {
                debugLog("Database connection variable not set");
            }
        } else {
            debugLog("connection.php not found");
        }
        
        // Clean up test chunks (don't save to database in debug mode)
        for ($i = 0; $i < $totalChunks; $i++) {
            $testChunk = $tempDir . $fileId . '_chunk_' . $i;
            if (file_exists($testChunk)) {
                unlink($testChunk);
                debugLog("Cleaned up chunk $i");
            }
        }
    }
    
    // Success response
    $response = [
        'success' => true,
        'message' => 'Debug chunk processed successfully',
        'chunk_index' => $chunkIndex,
        'total_chunks' => $totalChunks,
        'chunk_size' => $chunk['size'],
        'saved_size' => $savedSize,
        'is_last_chunk' => ($chunkIndex === $totalChunks - 1)
    ];
    
    debugLog("Sending success response");
    echo json_encode($response);
    
} catch (Exception $e) {
    debugLog("ERROR: " . $e->getMessage());
    debugLog("File: " . $e->getFile() . " Line: " . $e->getLine());
    debugLog("Stack trace: " . $e->getTraceAsString());
    
    $response = [
        'success' => false,
        'error' => $e->getMessage(),
        'debug_info' => [
            'file' => basename($e->getFile()),
            'line' => $e->getLine(),
            'php_version' => PHP_VERSION,
            'timestamp' => date('Y-m-d H:i:s')
        ]
    ];
    
    http_response_code(500);
    echo json_encode($response);
}

debugLog("=== POE Upload Debug End ===");
?>