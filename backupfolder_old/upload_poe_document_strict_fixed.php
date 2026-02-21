<?php
// Security functions
if (!defined('SECURITY_FUNCTIONS_LOADED')) {
    require_once __DIR__ . '/../security_functions.php';
}

/**
 * POE Upload with STRICT_TRANS_TABLES Fix
 * Handles the SQL mode issue causing 500 errors
 */

error_reporting(E_ALL);
ini_set("display_errors", 0);
ini_set("log_errors", 1);

set_time_limit(600);
ini_set("memory_limit", "512M");

header("Content-Type: application/json; charset=utf-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
    http_response_code(200);
    exit();
}

$debugLog = __DIR__ . "/poe_strict_mode_debug.log";
function logDebug($message) {
    global $debugLog;
    file_put_contents($debugLog, date("Y-m-d H:i:s") . " - $message\n", FILE_APPEND);
}

try {
    logDebug("=== POE Upload with Strict Mode Fix Start ===");
    
    if ($_SERVER["REQUEST_METHOD"] !== "POST") {
        throw new Exception("Only POST method allowed");
    }
    
    // Validate chunked upload parameters
    if (!isset($_POST["chunk_index"]) || !isset($_POST["total_chunks"]) || !isset($_POST["file_id"])) {
        throw new Exception("Missing chunked upload parameters");
    }
    
    $chunkIndex = intval($_POST["chunk_index"]);
    $totalChunks = intval($_POST["total_chunks"]);
    $fileId = preg_replace("/[^a-zA-Z0-9_-]/", "", $_POST["file_id"]);
    
    logDebug("Chunk $chunkIndex of $totalChunks, File ID: $fileId");
    
    // Validate chunk file
    if (!isset($_FILES["chunk"]) || $_FILES["chunk"]["error"] !== UPLOAD_ERR_OK) {
        throw new Exception("Chunk upload failed: " . ($_FILES["chunk"]["error"] ?? "no file"));
    }
    
    // Create directories
    $uploadDir = __DIR__ . "/uploads/poe_documents/";
    $tempDir = $uploadDir . "temp/";
    
    if (!file_exists($tempDir)) {
        mkdir($tempDir, 0755, true);
    }
    
    // Save chunk
    $chunkPath = $tempDir . $fileId . "_chunk_" . str_pad($chunkIndex, 4, "0", STR_PAD_LEFT);
    if (!$_FILES['chunk'] = $_FILES['chunk'] ?? '';
$safe_path_chunk = sanitize_file_path($_FILES['chunk'], __DIR__);
if ($safe_path_chunk === false) { error_log('Invalid path'); exit('Invalid file path'); }
move_uploaded_file($safe_path_chunk["tmp_name"], $chunkPath)) {
        throw new Exception("Failed to save chunk");
    }
    
    logDebug("Chunk saved: $chunkPath");
    
    // If last chunk, merge and save to database
    if ($chunkIndex === $totalChunks - 1) {
        logDebug("Last chunk - merging and saving to database");
        
        // Validate and sanitize metadata
        $learnerId = trim($_POST["learner_id"] ?? "");
        $learnerName = trim($_POST["learner_name"] ?? "");
        
        if (!$learnerId || !$learnerName) {
            throw new Exception("Missing learner_id or learner_name");
        }
        
        // Sanitize data to prevent issues
        $learnerId = substr($learnerId, 0, 50);  // Limit length
        $learnerName = substr($learnerName, 0, 255);  // Limit length
        $documentType = substr(trim($_POST["document_type"] ?? "POE"), 0, 50);
        $pageCount = max(0, intval($_POST["page_count"] ?? 0));  // Ensure positive
        $classId = substr(trim($_POST["class_id"] ?? ""), 0, 50);
        $siteName = substr(trim($_POST["site_name"] ?? ""), 0, 255);
        $uploadedBy = substr(trim($_POST["uploaded_by"] ?? ""), 0, 100);
        
        // Handle empty strings as NULL for optional fields
        $classId = $classId ?: null;
        $siteName = $siteName ?: null;
        $uploadedBy = $uploadedBy ?: null;
        
        // Ensure document_type is not empty
        if (!$documentType) {
            $documentType = "POE";
        }
        
        logDebug("Sanitized data - Learner: $learnerId ($learnerName), Type: $documentType");
        
        // Merge chunks
        $fileName = "POE_" . $learnerId . "_" . time() . ".pdf";
        $finalPath = $uploadDir . $fileName;
        
        $finalFile = fopen($finalPath, "wb");
        if (!$finalFile) {
            throw new Exception("Cannot create final file");
        }
        
        $totalSize = 0;
        for ($i = 0; $i < $totalChunks; $i++) {
            $chunkFile = $tempDir . $fileId . "_chunk_" . str_pad($i, 4, "0", STR_PAD_LEFT);
            if (!file_exists($chunkFile)) {
                fclose($finalFile);
                unlink($finalPath);
                throw new Exception("Missing chunk $i");
            }
            
            $data = file_get_contents($chunkFile);
            fwrite($finalFile, $data);
            $totalSize += strlen($data);
            unlink($chunkFile);
        }
        fclose($finalFile);
        
        logDebug("File merged: $finalPath ($totalSize bytes)");
        
        // Database insert with STRICT mode handling
        require_once "connection.php";
        
        if (!isset($conn)) {
            unlink($finalPath);
            throw new Exception("Database connection failed");
        }
        
        // CRITICAL: Set permissive SQL mode to prevent STRICT_TRANS_TABLES issues
        $conn->query("SET sql_mode = \"\"");
        logDebug("Set permissive SQL mode");
        
        // Use prepared statement for safety
        $stmt = $conn->prepare("INSERT INTO poe_documents (
            learner_id, learner_name, document_type, file_name, file_path,
            file_size, page_count, mime_type, class_id, site_name,
            uploaded_by, status, upload_date
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, \"active\", NOW())");
        
        if (!$stmt) {
            unlink($finalPath);
            logDebug("Prepare failed: " . $conn->error);
            throw new Exception("Database prepare error: " . $conn->error);
        }
        
        $mimeType = "application/pdf";
        
        $stmt->bind_param(
            "sssssisssss",
            $learnerId,
            $learnerName,
            $documentType,
            $fileName,
            $finalPath,
            $totalSize,
            $pageCount,
            $mimeType,
            $classId,
            $siteName,
            $uploadedBy
        );
        
        if (!$stmt->execute()) {
            unlink($finalPath);
            logDebug("Execute failed: " . $stmt->error . " (Code: " . $stmt->errno . ")");
            throw new Exception("Database insert error: " . $stmt->error);
        }
        
        $documentId = $conn->insert_id;
        $stmt->close();
        
        logDebug("Database record created: ID $documentId");
        
        echo json_encode([
            "success" => true,
            "message" => "POE document uploaded successfully",
            "document_id" => $documentId,
            "file_name" => $fileName,
            "file_size" => $totalSize,
            "chunks_processed" => $totalChunks
        ]);
        
    } else {
        echo json_encode([
            "success" => true,
            "message" => "Chunk received",
            "chunk_index" => $chunkIndex,
            "total_chunks" => $totalChunks
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

logDebug("=== POE Upload with Strict Mode Fix End ===");
?>