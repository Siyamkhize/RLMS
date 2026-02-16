<?php
/**
 * Delete POE Document - Soft delete or permanent delete
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'connection.php';

try {
    $documentId = isset($_POST['document_id']) ? intval($_POST['document_id']) : null;
    $permanent = isset($_POST['permanent']) && $_POST['permanent'] === 'true';
    
    if (!$documentId) {
        throw new Exception('Document ID is required');
    }
    
    // Get document info
    $sql = "SELECT file_path FROM poe_documents WHERE id = $documentId";
    $result = $conn->query($sql);
    
    if ($result->num_rows === 0) {
        throw new Exception('Document not found');
    }
    
    $document = $result->fetch_assoc();
    
    if ($permanent) {
        // Permanent delete - remove file and database record
        if (file_exists($document['file_path'])) {
            unlink($document['file_path']);
        }
        
        $sql = "DELETE FROM poe_documents WHERE id = $documentId";
        $message = 'Document permanently deleted';
    } else {
        // Soft delete - mark as deleted
        $sql = "UPDATE poe_documents SET status = 'deleted' WHERE id = $documentId";
        $message = 'Document marked as deleted';
    }
    
    if (!$conn->query($sql)) {
        throw new Exception('Database error: ' . $conn->error);
    }
    
    echo json_encode([
        'success' => true,
        'message' => $message,
        'document_id' => $documentId
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
