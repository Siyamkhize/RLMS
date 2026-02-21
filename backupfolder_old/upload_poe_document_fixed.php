<?php
// Security functions
if (!defined('SECURITY_FUNCTIONS_LOADED')) {
    require_once __DIR__ . '/../security_functions.php';
}

/**
 * Fixed POE Document Upload Endpoint
 * Addresses common 500 error causes
 */

// Error handling
error_reporting(E_ALL);
ini_set("display_errors", 0);
ini_set("log_errors", 1);

// Increase limits
set_time_limit(300);
ini_set("max_execution_time", "300");
ini_set("memory_limit", "256M");

// Headers
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
    http_response_code(200);
    exit();
}

// Debug logging
$debugLog = __DIR__ . "/poe_upload.log";
function logDebug($message) {
    global $debugLog;
    file_put_contents($debugLog, date("Y-m-d H:i:s") . " - $message\n", FILE_APPEND);
}

try {
    logDebug("=== Upload Start ===");
    
    // Check method
    if ($_SERVER["REQUEST_METHOD"] !== "POST") {
        throw new Exception("Only POST method allowed");
    }
    
    // Check for chunked upload
    if (!isset($_POST["chunk_index"]) || !isset($_POST["total_chunks"])) {
        throw new Exception("Missing chunk parameters");
    }
    
    $chunkIndex = intval($_POST["chunk_index"]);
    $totalChunks = intval($_POST["total_chunks"]);
    $fileId = $_POST["file_id"] ?? "unknown";
    
    logDebug("Chunk $chunkIndex of $totalChunks, ID: $fileId");
    
    // Check chunk file
    if (!isset($_FILES["chunk"])) {
        throw new Exception("No chunk file uploaded");
    }
    
    if ($_FILES["chunk"]["error"] !== UPLOAD_ERR_OK) {
        throw new Exception("Chunk upload error: " . $_FILES["chunk"]["error"]);
    }
    
    // Create directories
    $uploadDir = __DIR__ . "/uploads/poe_documents/";
    $tempDir = $uploadDir . "temp/";
    
    if (!file_exists($tempDir)) {
        mkdir($tempDir, 0777, true);
    }
    
    // Save chunk
    $chunkPath = $tempDir . $fileId . "_chunk_" . $chunkIndex;
    if (!$_FILES['chunk'] = $_FILES['chunk'] ?? '';
$safe_path_chunk = sanitize_file_path($_FILES['chunk'], __DIR__);
if ($safe_path_chunk === false) { error_log('Invalid path'); exit('Invalid file path'); }
move_uploaded_file($safe_path_chunk["tmp_name"], $chunkPath)) {
        throw new Exception("Failed to save chunk");
    }
    
    logDebug("Chunk saved: $chunkPath");
    
    // If last chunk, merge and save to database
    if ($chunkIndex === $totalChunks - 1) {
        logDebug("Last chunk - merging");
        
        // Get metadata
        $learnerId = $_POST["learner_id"] ?? "";
        $learnerName = $_POST["learner_name"] ?? "";
        
        if (!$learnerId || !$learnerName) {
            throw new Exception("Missing learner_id or learner_name");
        }
        
        // Merge chunks
        $fileName = "POE_" . $learnerId . "_" . time() . ".pdf";
        $finalPath = $uploadDir . $fileName;
        
        $finalFile = fopen($finalPath, "wb");
        if (!$finalFile) {
            throw new Exception("Cannot create final file");
        }
        
        for ($i = 0; $i < $totalChunks; $i++) {
            $chunkFile = $tempDir . $fileId . "_chunk_" . $i;
            if (!file_exists($chunkFile)) {
                fclose($finalFile);
                throw new Exception("Missing chunk $i");
            }
            
            $data = file_get_contents($chunkFile);
            fwrite($finalFile, $data);
            unlink($chunkFile);
        }
        
        fclose($finalFile);
        $fileSize = filesize($finalPath);
        
        logDebug("File merged: $finalPath ($fileSize bytes)");
        
        // Save to database
        require_once "connection.php";
        
        $stmt = $conn->prepare("INSERT INTO poe_documents (learner_id, learner_name, file_name, file_path, file_size, status) VALUES (?, ?, ?, ?, ?, ?)");
        $status = "active";
        $stmt->bind_param("ssssds", $learnerId, $learnerName, $fileName, $finalPath, $fileSize, $status);
        
        if (!$stmt->execute()) {
            unlink($finalPath);
            throw new Exception("Database error: " . $stmt->error);
        }
        
        $documentId = $conn->insert_id;
        
        echo json_encode([
            "success" => true,
            "message" => "Upload completed",
            "document_id" => $documentId,
            "file_name" => $fileName,
            "file_size" => $fileSize
        ]);
    } else {
        echo json_encode([
            "success" => true,
            "message" => "Chunk received",
            "chunk_index" => $chunkIndex
        ]);
    }
    
} catch (Exception $e) {
    logDebug("ERROR: " . $e->getMessage());
    
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => $e->getMessage()
    ]);
}
?>