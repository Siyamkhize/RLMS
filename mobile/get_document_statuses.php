<?php
// =====================================================
// Enhanced Profile Validation: Get Document Statuses
// =====================================================
// Description: Get all document statuses for a learner with approval info
// Date: August 6, 2026
// Part of: Enhanced Profile Validation & Document Approval System

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Use server database connection
require_once '../connection.php';

try {
    // Get learner ID from request
    $learner_id = null;
    
    if ($_SERVER['REQUEST_METHOD'] == 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        $learner_id = isset($input['learner_id']) ? $input['learner_id'] : null;
        
        // Also support form data
        if (!$learner_id) {
            $learner_id = isset($_POST['learner_id']) ? $_POST['learner_id'] : null;
        }
    } else if ($_SERVER['REQUEST_METHOD'] == 'GET') {
        $learner_id = isset($_GET['learner_id']) ? $_GET['learner_id'] : null;
    }
    
    if (!$learner_id) {
        echo json_encode([
            'success' => false,
            'error' => 'learner_id is required'
        ]);
        exit;
    }
    
    // Get all documents for this learner with status
    $query = "SELECT 
                documentName,
                status,
                rejection_reason,
                upload_date,
                learner_document,
                document_id
              FROM learner_document 
              WHERE learner_id = ? 
              ORDER BY document_id DESC";
    
    $stmt = $conn->prepare($query);
    $stmt->bind_param('s', $learner_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $documents = [];
    $latestDocs = []; // Track latest version of each document
    
    while ($row = $result->fetch_assoc()) {
        $docName = $row['documentName'];
        
        // Keep only the latest upload for each document type
        if (!isset($latestDocs[$docName])) {
            $latestDocs[$docName] = true;
            $documents[$docName] = [
                'status' => $row['status'] ?? 'Pending',
                'rejection_reason' => $row['rejection_reason'],
                'upload_date' => $row['upload_date'],
                'reviewed_date' => $row['reviewed_date'],
                'reviewed_by' => $row['reviewed_by'],
                'file_path' => $row['learner_document'],
                'document_id' => $row['document_id'],
            ];
        }
    }
    
    echo json_encode([
        'success' => true,
        'documents' => $documents,
        'total_documents' => count($documents),
        'learner_id' => $learner_id,
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => 'Database error: ' . $e->getMessage()
    ]);
}
?>
