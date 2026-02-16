<?php
/**
 * Simplified Bulk Export API - Without complex error handling
 * This version removes the output buffering and error handlers that may be causing timeouts
 */

// Simple error reporting
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/bulk_export_errors.log');

// Set execution limits
set_time_limit(300); // 5 minutes
ini_set('memory_limit', '512M');

// Set JSON header
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-cache, must-revalidate');

// Simple JSON response function
function sendJson($data, $code = 200) {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

// Handle different request methods
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Test endpoint
    sendJson([
        'success' => true,
        'message' => 'Bulk Export API (Simple) is running',
        'timestamp' => time(),
        'version' => 'simple_v1'
    ]);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        // Get input
        $input = $_POST;
        
        // Validate
        if (empty($input['learner_ids'])) {
            sendJson(['error' => 'Missing learner_ids'], 400);
        }
        
        // Decode learner_ids
        $learnerIds = $input['learner_ids'];
        if (is_string($learnerIds)) {
            $learnerIds = json_decode($learnerIds, true);
        }
        
        if (!is_array($learnerIds)) {
            sendJson(['error' => 'learner_ids must be an array'], 400);
        }
        
        // Get parameters
        $startDate = $input['start_date'] ?? date('Y-m-01');
        $endDate = $input['end_date'] ?? date('Y-m-t');
        $projectId = $input['project_id'] ?? null;
        
        // Log the request
        error_log("=== SIMPLE API REQUEST ===");
        error_log("Learners: " . count($learnerIds));
        error_log("Date range: $startDate to $endDate");
        
        // Check required files
        if (!file_exists(__DIR__ . '/connection.php')) {
            sendJson(['error' => 'connection.php not found'], 500);
        }
        
        if (!file_exists(__DIR__ . '/bulk_export_with_documents.php')) {
            sendJson(['error' => 'bulk_export_with_documents.php not found'], 500);
        }
        
        // Include files
        require_once __DIR__ . '/connection.php';
        require_once __DIR__ . '/bulk_export_with_documents.php';
        
        // Check database connection
        if (!isset($conn) || $conn->connect_error) {
            sendJson(['error' => 'Database connection failed'], 500);
        }
        
        // Check function exists
        if (!function_exists('generateBulkReportsWithDocuments')) {
            sendJson(['error' => 'generateBulkReportsWithDocuments function not found'], 500);
        }
        
        // Generate reports
        error_log("Starting report generation...");
        $results = generateBulkReportsWithDocuments($conn, $learnerIds, $startDate, $endDate, $projectId);
        error_log("Report generation completed");
        
        // Send response
        sendJson($results);
        
    } catch (Exception $e) {
        error_log("ERROR: " . $e->getMessage());
        sendJson([
            'error' => 'Exception occurred',
            'message' => $e->getMessage(),
            'file' => $e->getFile(),
            'line' => $e->getLine()
        ], 500);
    }
}

// Method not allowed
sendJson(['error' => 'Method not allowed'], 405);
