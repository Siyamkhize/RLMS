<?php
/**
 * Download Scanned Document
 * Allows downloading of scanned documents by ID
 */

// Include database configuration
require_once 'config.php';

try {
    // Validate document ID
    if (!isset($_GET['id']) || empty($_GET['id'])) {
        throw new Exception('Document ID is required');
    }
    
    $documentId = intval($_GET['id']);
    
    // Get document details from database
    $stmt = $conn->prepare("
        SELECT 
            id,
            learnerID,
            learner_name,
            file_path,
            original_filename,
            mime_type,
            file_size
        FROM scanned_documents 
        WHERE id = ?
    ");
    
    $stmt->bind_param("i", $documentId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        throw new Exception('Document not found');
    }
    
    $document = $result->fetch_assoc();
    $filePath = $document['file_path'];
    
    // Check if file exists
    if (!file_exists($filePath)) {
        throw new Exception('File not found on server');
    }
    
    // Get file info
    $fileSize = filesize($filePath);
    $mimeType = $document['mime_type'];
    $originalFilename = $document['original_filename'];
    
    // Set headers for download
    header('Content-Type: ' . $mimeType);
    header('Content-Disposition: attachment; filename="' . $originalFilename . '"');
    header('Content-Length: ' . $fileSize);
    header('Cache-Control: no-cache, must-revalidate');
    header('Pragma: public');
    header('Expires: 0');
    
    // Clear output buffer
    if (ob_get_level()) {
        ob_end_clean();
    }
    
    // Read and output file
    readfile($filePath);
    
    exit();
    
} catch (Exception $e) {
    error_log('Download Scanned Document Error: ' . $e->getMessage());
    
    http_response_code(404);
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}

// Close database connection
if (isset($conn)) {
    $conn->close();
}
?>