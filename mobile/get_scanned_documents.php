<?php
/**
 * Get Scanned Documents API
 * Retrieves scanned documents for a specific learner or all learners
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Only allow GET requests
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode([
        'status' => 'error',
        'message' => 'Only GET method allowed'
    ]);
    exit();
}

// Include database configuration
require_once 'config.php';

try {
    // Get query parameters
    $learnerID = isset($_GET['learnerID']) ? intval($_GET['learnerID']) : null;
    $documentType = isset($_GET['type']) ? trim($_GET['type']) : null;
    $exercise = isset($_GET['exercise']) ? trim($_GET['exercise']) : null;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 100;
    $offset = isset($_GET['offset']) ? intval($_GET['offset']) : 0;
    
    // Validate limit
    if ($limit > 1000) {
        $limit = 1000;
    }
    
    // Build query
    $whereConditions = [];
    $params = [];
    $types = '';
    
    if ($learnerID !== null) {
        $whereConditions[] = 'learnerID = ?';
        $params[] = $learnerID;
        $types .= 'i';
    }
    
    if ($documentType !== null) {
        $whereConditions[] = 'document_type = ?';
        $params[] = $documentType;
        $types .= 's';
    }
    
    if ($exercise !== null) {
        $whereConditions[] = 'exercise = ?';
        $params[] = $exercise;
        $types .= 's';
    }
    
    $whereClause = '';
    if (!empty($whereConditions)) {
        $whereClause = 'WHERE ' . implode(' AND ', $whereConditions);
    }
    
    // Get total count
    $countQuery = "SELECT COUNT(*) as total FROM scanned_documents $whereClause";
    $countStmt = $conn->prepare($countQuery);
    
    if (!empty($params)) {
        $countStmt->bind_param($types, ...$params);
    }
    
    $countStmt->execute();
    $countResult = $countStmt->get_result();
    $totalCount = $countResult->fetch_assoc()['total'];
    
    // Get documents
    $query = "
        SELECT 
            id,
            learnerID,
            learner_name,
            document_type,
            exercise,
            file_path,
            original_filename,
            file_size,
            mime_type,
            logbook_text,
            scanned_by,
            uploaded_at,
            synced,
            created_at
        FROM scanned_documents 
        $whereClause 
        ORDER BY uploaded_at DESC 
        LIMIT ? OFFSET ?
    ";
    
    $stmt = $conn->prepare($query);
    
    // Add limit and offset to parameters
    $params[] = $limit;
    $params[] = $offset;
    $types .= 'ii';
    
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    $documents = [];
    while ($row = $result->fetch_assoc()) {
        // Check if file exists
        $fileExists = file_exists($row['file_path']);
        
        $documents[] = [
            'id' => intval($row['id']),
            'learnerID' => intval($row['learnerID']),
            'learner_name' => $row['learner_name'],
            'document_type' => $row['document_type'],
            'exercise' => $row['exercise'],
            'file_path' => $row['file_path'],
            'original_filename' => $row['original_filename'],
            'file_size' => intval($row['file_size']),
            'file_size_mb' => round($row['file_size'] / (1024 * 1024), 2),
            'mime_type' => $row['mime_type'],
            'logbook_text' => $row['logbook_text'],
            'scanned_by' => $row['scanned_by'],
            'uploaded_at' => $row['uploaded_at'],
            'synced' => intval($row['synced']),
            'created_at' => $row['created_at'],
            'file_exists' => $fileExists,
            'download_url' => $fileExists ? 'download_scanned_document.php?id=' . $row['id'] : null
        ];
    }
    
    // Return response
    echo json_encode([
        'status' => 'success',
        'message' => 'Documents retrieved successfully',
        'data' => [
            'total_count' => intval($totalCount),
            'returned_count' => count($documents),
            'limit' => $limit,
            'offset' => $offset,
            'has_more' => ($offset + $limit) < $totalCount,
            'documents' => $documents
        ],
        'filters' => [
            'learnerID' => $learnerID,
            'document_type' => $documentType,
            'exercise' => $exercise
        ],
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    
} catch (Exception $e) {
    error_log('Get Scanned Documents Error: ' . $e->getMessage());
    
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Failed to retrieve documents: ' . $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}

// Close database connection
if (isset($conn)) {
    $conn->close();
}
?>