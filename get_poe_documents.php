<?php
/**
 * Get POE Documents - Retrieve uploaded POE documents for a learner
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'connection.php';

try {
    $learnerId = isset($_GET['learner_id']) ? $conn->real_escape_string($_GET['learner_id']) : null;
    $classId = isset($_GET['class_id']) ? $conn->real_escape_string($_GET['class_id']) : null;
    $documentType = isset($_GET['document_type']) ? $conn->real_escape_string($_GET['document_type']) : null;
    $status = isset($_GET['status']) ? $conn->real_escape_string($_GET['status']) : 'active';
    
    // Build query
    $sql = "SELECT 
        id,
        learner_id,
        learner_name,
        document_type,
        file_name,
        file_size,
        page_count,
        mime_type,
        uploaded_by,
        upload_date,
        class_id,
        site_name,
        status,
        notes,
        created_at,
        updated_at
    FROM poe_documents
    WHERE status = '$status'";
    
    if ($learnerId) {
        $sql .= " AND learner_id = '$learnerId'";
    }
    
    if ($classId) {
        $sql .= " AND class_id = '$classId'";
    }
    
    if ($documentType) {
        $sql .= " AND document_type = '$documentType'";
    }
    
    $sql .= " ORDER BY upload_date DESC";
    
    $result = $conn->query($sql);
    
    if (!$result) {
        throw new Exception('Query failed: ' . $conn->error);
    }
    
    $documents = [];
    while ($row = $result->fetch_assoc()) {
        // Format file size for display
        $row['file_size_formatted'] = formatFileSize($row['file_size']);
        
        // Add download URL (relative path)
        $row['download_url'] = 'uploads/poe_documents/' . $row['file_name'];
        
        $documents[] = $row;
    }
    
    echo json_encode([
        'success' => true,
        'count' => count($documents),
        'documents' => $documents
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

function formatFileSize($bytes) {
    if ($bytes >= 1073741824) {
        return number_format($bytes / 1073741824, 2) . ' GB';
    } elseif ($bytes >= 1048576) {
        return number_format($bytes / 1048576, 2) . ' MB';
    } elseif ($bytes >= 1024) {
        return number_format($bytes / 1024, 2) . ' KB';
    } else {
        return $bytes . ' bytes';
    }
}

$conn->close();
?>
