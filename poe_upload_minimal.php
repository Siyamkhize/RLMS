<?php
// Absolute minimal POE upload - no dependencies, pure PHP
@ini_set('display_errors', 0);
@error_reporting(0);

// Force JSON header before anything else
@header('Content-Type: application/json');
@header('Access-Control-Allow-Origin: *');

// Log everything to a file we can check
$log = __DIR__ . '/poe_minimal.log';
@file_put_contents($log, "\n=== " . date('Y-m-d H:i:s') . " ===\n", FILE_APPEND);
@file_put_contents($log, "Script started\n", FILE_APPEND);

try {
    // Step 1: Basic info
    @file_put_contents($log, "PHP Version: " . phpversion() . "\n", FILE_APPEND);
    @file_put_contents($log, "Method: " . $_SERVER['REQUEST_METHOD'] . "\n", FILE_APPEND);
    
    // Step 2: Check POST data
    $postKeys = @array_keys($_POST);
    $filesKeys = @array_keys($_FILES);
    @file_put_contents($log, "POST keys: " . implode(',', $postKeys) . "\n", FILE_APPEND);
    @file_put_contents($log, "FILES keys: " . implode(',', $filesKeys) . "\n", FILE_APPEND);
    
    // Step 3: Check if chunked
    $isChunked = isset($_POST['chunk_index']) && isset($_POST['total_chunks']);
    @file_put_contents($log, "Is chunked: " . ($isChunked ? 'yes' : 'no') . "\n", FILE_APPEND);
    
    if ($isChunked) {
        $chunkIndex = (int)$_POST['chunk_index'];
        $totalChunks = (int)$_POST['total_chunks'];
        $fileId = $_POST['file_id'];
        
        @file_put_contents($log, "Chunk $chunkIndex of $totalChunks, ID: $fileId\n", FILE_APPEND);
        
        // Check chunk file
        if (!isset($_FILES['chunk'])) {
            throw new Exception('No chunk file');
        }
        
        $error = $_FILES['chunk']['error'];
        $size = $_FILES['chunk']['size'];
        $tmpName = $_FILES['chunk']['tmp_name'];
        
        @file_put_contents($log, "Chunk error: $error, size: $size\n", FILE_APPEND);
        
        if ($error !== 0) {
            throw new Exception("Chunk upload error code: $error");
        }
        
        // Create directory
        $dir = __DIR__ . '/uploads/poe_documents/temp/';
        if (!@file_exists($dir)) {
            @mkdir($dir, 0777, true);
        }
        
        // Save chunk
        $chunkPath = $dir . $fileId . '_chunk_' . $chunkIndex;
        @file_put_contents($log, "Saving to: $chunkPath\n", FILE_APPEND);
        
        if (!@move_uploaded_file($tmpName, $chunkPath)) {
            throw new Exception('Failed to save chunk');
        }
        
        @file_put_contents($log, "Chunk saved OK\n", FILE_APPEND);
        
        // Return success
        echo json_encode([
            'success' => true,
            'message' => 'Chunk received',
            'chunk_index' => $chunkIndex,
            'total_chunks' => $totalChunks
        ]);
        
    } else {
        @file_put_contents($log, "Not a chunked upload\n", FILE_APPEND);
        echo json_encode([
            'success' => true,
            'message' => 'Endpoint working',
            'method' => $_SERVER['REQUEST_METHOD']
        ]);
    }
    
} catch (Exception $e) {
    @file_put_contents($log, "ERROR: " . $e->getMessage() . "\n", FILE_APPEND);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

@file_put_contents($log, "Script completed\n", FILE_APPEND);
?>
