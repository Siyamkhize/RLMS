<?php
// =====================================================
// Document Sync Endpoint - Validate & Auto-Upload Missing Files
// =====================================================
// Description: Checks if local documents exist on server, re-uploads if missing
// Date: August 7, 2026

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

include 'connection.php';

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database connection failed'
    ]);
    exit;
}

try {
    // Get learner_id and local documents from POST
    if (!isset($_POST['learner_id'])) {
        throw new Exception('learner_id is required');
    }
    
    $learnerId = $conn->real_escape_string($_POST['learner_id']);
    
    // Get documents data (JSON array from client)
    $localDocuments = [];
    if (isset($_POST['documents'])) {
        $localDocuments = json_decode($_POST['documents'], true);
    }
    
    // Query server database for this learner's documents
    $query = "SELECT document_id, documentName, document_type, learner_document, status, 
                     rejection_reason, upload_date 
              FROM learner_document 
              WHERE learner_id = ? 
              ORDER BY document_id DESC";
    
    $stmt = $conn->prepare($query);
    $stmt->bind_param('s', $learnerId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $serverDocuments = [];
    $latestDocs = []; // Track latest version of each document type
    
    while ($row = $result->fetch_assoc()) {
        $docName = $row['documentName'];
        
        // Keep only the latest upload for each document type
        if (!isset($latestDocs[$docName])) {
            $latestDocs[$docName] = true;
            
            // Check if physical file exists on server
            $filePath = $row['learner_document'];
            $fileExists = !empty($filePath) && file_exists($filePath);
            
            $serverDocuments[$docName] = [
                'document_id' => $row['document_id'],
                'documentName' => $row['documentName'],
                'document_type' => $row['document_type'],
                'learner_document' => $row['learner_document'],
                'status' => $row['status'],
                'rejection_reason' => $row['rejection_reason'],
                'upload_date' => $row['upload_date'],
                'file_exists' => $fileExists, // CRITICAL: Check if file actually exists
            ];
        }
    }
    
    // Compare local vs server documents
    $missingOnServer = []; // Documents that exist locally but not on server
    $fileMissingOnServer = []; // Documents in DB but file is missing
    $needsReUpload = []; // Documents that need re-upload
    
    foreach ($localDocuments as $localDoc) {
        $docName = $localDoc['documentName'];
        
        if (!isset($serverDocuments[$docName])) {
            // Document doesn't exist on server AT ALL
            $missingOnServer[] = $docName;
            $needsReUpload[] = [
                'documentName' => $docName,
                'reason' => 'not_in_database',
                'local_path' => $localDoc['learner_document'] ?? null,
            ];
        } else {
            // Document exists in server DB, but check if FILE exists
            $serverDoc = $serverDocuments[$docName];
            
            if (!$serverDoc['file_exists']) {
                // File is missing from server storage!
                $fileMissingOnServer[] = $docName;
                $needsReUpload[] = [
                    'documentName' => $docName,
                    'document_id' => $serverDoc['document_id'],
                    'reason' => 'file_missing_on_server',
                    'local_path' => $localDoc['learner_document'] ?? null,
                    'server_path' => $serverDoc['learner_document'],
                ];
            }
        }
    }
    
    // Return sync status
    echo json_encode([
        'success' => true,
        'learner_id' => $learnerId,
        'server_documents' => $serverDocuments,
        'missing_on_server' => $missingOnServer,
        'file_missing_on_server' => $fileMissingOnServer,
        'needs_reupload' => $needsReUpload,
        'sync_required' => count($needsReUpload) > 0,
        'timestamp' => date('Y-m-d H:i:s'),
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
} finally {
    if (isset($stmt)) {
        $stmt->close();
    }
    $conn->close();
}
