<?php
// Strict output control
if(!headers_sent()) ob_start(null, 1);
// Enable strict error reporting for development
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/bulk_export_errors.log');

// Start output buffering with callback to catch any output
ob_start(function($buffer) {
    // If we get here, it means something tried to output before JSON
    error_log('Unexpected output before JSON: ' . substr($buffer, 0, 1000));
    return ''; // Discard the output
}, 1);

// Set headers to ensure JSON response
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-cache, must-revalidate');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit(0);
}

/**
 * Send JSON response and exit
 */
function sendJsonResponse($data, $statusCode = 200) {
    http_response_code($statusCode);
    $output = json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        // If we can't encode to JSON, send a basic error
        $output = json_encode([
            'error' => 'Failed to encode response',
            'details' => json_last_error_msg()
        ]);
        http_response_code(500);
    }
    
    // Clear any previous output
    while (ob_get_level() > 0) {
        ob_end_clean();
    }
    
    echo $output;
    exit;
}

/**
 * Handle errors and exceptions
 */
set_error_handler(function($errno, $errstr, $errfile, $errline) {
    error_log("PHP Error [$errno] $errstr in $errfile on line $errline");
    sendJsonResponse([
        'error' => 'Server error occurred',
        'code' => $errno,
        'message' => $errstr,
        'file' => $errfile,
        'line' => $errline
    ], 500);
}, E_ALL);

set_exception_handler(function($e) {
    error_log("Uncaught Exception: " . $e->getMessage() . " in " . $e->getFile() . ":" . $e->getLine());
    sendJsonResponse([
        'error' => 'Unhandled exception',
        'message' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine(),
        'trace' => (defined('DEBUG_MODE') && constant('DEBUG_MODE')) ? $e->getTrace() : null
    ], 500);
});

// Handle different request methods
switch ($_SERVER['REQUEST_METHOD']) {
    case 'GET':
        // Test endpoint
        sendJsonResponse([
            'success' => true,
            'message' => 'Bulk Export API is running',
            'endpoints' => [
                'POST /' => 'Generate bulk reports with learner data',
                'GET /' => 'API status'
            ],
            'timestamp' => time()
        ]);
        break;

    case 'POST':
        try {
            // Get JSON input if Content-Type is application/json
            $input = [];
            $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
            
            if (strpos($contentType, 'application/json') !== false) {
                $json = file_get_contents('php://input');
                $input = json_decode($json, true) ?: [];
            } else {
                $input = $_POST;
            }

            // Merge JSON body with POST data (for backward compatibility)
            $input = array_merge($input, $_POST);

            // Basic validation
            if (empty($input['learner_ids'])) {
                throw new Exception('Missing required parameter: learner_ids');
            }

            // Decode learner_ids if it's a JSON string
            $learnerIds = $input['learner_ids'];
            if (is_string($learnerIds)) {
                $learnerIds = json_decode($learnerIds, true);
            }
            
            if (!is_array($learnerIds)) {
                throw new Exception('learner_ids must be an array');
            }

            // Get date range parameters
            $startDate = $input['start_date'] ?? date('Y-m-01');
            $endDate = $input['end_date'] ?? date('Y-m-t');
            $projectId = $input['project_id'] ?? null;

            // Log the request for debugging
            error_log("Bulk export request: " . count($learnerIds) . " learners, dates: $startDate to $endDate");

            // Include the bulk report generator (ORIGINAL WORKING APPROACH)
            ob_start();
            try {
                $result = include __DIR__ . '/generate_bulk_reports.php';
            } finally {
                $output = ob_get_clean();
            }

            // Log the output for debugging
            error_log("Full output from generate_bulk_reports.php: " . $output);

            // If generate_bulk_reports.php didn't exit, handle its output
            if (!empty($output)) {
                // Try to decode the output as JSON
                $jsonOutput = json_decode($output, true);
                if (json_last_error() !== JSON_ERROR_NONE) {
                    error_log("JSON decoding error: " . json_last_error_msg() . " for output: " . $output);
                }

                if (json_last_error() === JSON_ERROR_NONE) {
                    sendJsonResponse($jsonOutput);
                } else {
                    // If output is not JSON, include it in the response
                    sendJsonResponse([
                        'success' => false,
                        'message' => 'Unexpected output from report generator',
                        'output' => $output
                    ], 500);
                }
            } else if ($result === false) {
                throw new Exception('Failed to include generate_bulk_reports.php');
            }

        } catch (Exception $e) {
            sendJsonResponse([
                'error' => 'Failed to generate reports',
                'message' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine()
            ], 500);
        }
        break;

    default:
        sendJsonResponse([
            'error' => 'Method not allowed',
            'allowed_methods' => ['GET', 'POST']
        ], 405);
}

// If we get here, something went wrong with the response
header_remove();
http_response_code(500);
die(json_encode(['error' => 'Critical server failure']));