<?php
/**
 * Enhanced Bulk Report Generator with Sick Notes and Manual Registers
 * Based on your original working version that could generate 2000 reports in 13 minutes
 * Enhanced to include sick notes and manual register documents
 */

// DEBUG: Log that this script was called
error_log("SCRIPT_CALLED: generate_bulk_reports.php accessed at " . date('Y-m-d H:i:s'));
$debugFile = __DIR__ . '/temp_reports/debug_generate_' . date('Y-m-d_H-i-s') . '.txt';
@file_put_contents($debugFile, "DEBUG: generate_bulk_reports.php called at " . date('Y-m-d H:i:s') . "\n", FILE_APPEND);

// Detect if called from API wrapper by checking the call stack
$isApiWrapper = false;
$backtrace = debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS);
foreach ($backtrace as $trace) {
    if (isset($trace['file']) && basename($trace['file']) === 'bulk_export_api.php') {
        $isApiWrapper = true;
        break;
    }
}

// Alternative detection method
if (!$isApiWrapper) {
    $isApiWrapper = isset($_SERVER['HTTP_X_API_WRAPPER']) || 
                   (isset($_SERVER['SCRIPT_FILENAME']) && basename($_SERVER['SCRIPT_FILENAME']) === 'bulk_export_api.php');
}

if (!$isApiWrapper) {
    ob_start();
}

// Configure error handling
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error.log');
error_reporting(E_ALL);

// Debug mode: output to browser if requested
$debug_mode = isset($_GET['debug']) || isset($_POST['debug']) || isset($input['debug']);
if ($debug_mode) {
    error_log("=== GENERATE_BULK_REPORTS.PHP DEBUG MODE ===");
    error_log("Started at: " . date('Y-m-d H:i:s'));
    error_log("Called from API wrapper: " . ($isApiWrapper ? 'YES' : 'NO'));
}

// Function to return result (either as return value or JSON output)
function returnResult($data, $statusCode = 200) {
    global $isApiWrapper, $debug_mode;
    
    if ($debug_mode) {
        error_log("RETURN RESULT: API wrapper mode: " . ($isApiWrapper ? 'YES' : 'NO'));
        error_log("RETURN RESULT: Data keys: " . implode(', ', array_keys($data)));
    }
    
    if ($isApiWrapper) {
        // If called from API wrapper, just return the data directly
        if ($debug_mode) {
            error_log("RETURN RESULT: Returning data to API wrapper");
        }
        return $data;
    } else {
        // If called directly, output JSON and exit
        if ($debug_mode) {
            error_log("RETURN RESULT: Outputting JSON directly");
        }
        if (!headers_sent()) {
            header('Content-Type: application/json');
            http_response_code($statusCode);
        }
        // Clean any existing output buffers
        while (ob_get_level() > 0) {
            ob_end_clean();
        }
        echo json_encode($data);
        exit;
    }
}

// Handle test endpoint
if (isset($_GET['test'])) {
    return returnResult([
        'success' => true,
        'message' => 'generate_bulk_reports.php is accessible',
        'timestamp' => time()
    ]);
}

// Load Composer autoloader once
if (!file_exists(__DIR__ . '/vendor/autoload.php')) {
    error_log("Composer autoloader not found");
    return returnResult(['error' => 'Composer autoloader not found. Please run "composer install".'], 500);
}
require_once __DIR__ . '/vendor/autoload.php';
use Mpdf\Mpdf;

// Include database connection once
if (!file_exists(__DIR__ . '/connection.php')) {
    error_log("Database connection file not found");
    return returnResult(['error' => 'Database configuration file missing'], 500);
}
include_once __DIR__ . '/connection.php';

// Include document retrieval functions
if (file_exists(__DIR__ . '/get_learner_documents.php')) {
    include_once __DIR__ . '/get_learner_documents.php';
}

// Get input data (from API wrapper or direct POST)
if (isset($input)) {
    // Called from API wrapper
    $postData = $input;
} else {
    // Called directly - handle POST request
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        return returnResult([
            'error' => 'Invalid request method',
            'method' => $_SERVER['REQUEST_METHOD'] ?? 'UNKNOWN'
        ], 405);
    }
    
    $postData = $_POST;
    
    // Parse POST data if empty
    if (empty($postData)) {
        $rawInput = file_get_contents('php://input');
        if (strlen($rawInput) > 0) {
            $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
            if (strpos($contentType, 'application/x-www-form-urlencoded') !== false) {
                parse_str($rawInput, $postData);
            }
        }
    }
}

if ($debug_mode) {
    error_log("=== POST DATA PROCESSING ===");
    error_log("Post data keys: " . implode(', ', array_keys($postData)));
}

// Set execution limits
set_time_limit(1800); // 30 minutes
ini_set('memory_limit', '2G');

if (!isset($conn) || $conn->connect_error) {
    error_log("Database connection failed: " . ($conn->connect_error ?? 'Connection not established'));
    return returnResult(['error' => 'Database connection failed'], 500);
}

// Extract and validate learner IDs
$learnerIdsJson = $postData['learner_ids'] ?? '';
if (empty($learnerIdsJson)) {
    error_log("No learner_ids provided");
    return returnResult(['error' => 'No learner IDs provided'], 400);
}

$learnerIDs = json_decode($learnerIdsJson, true);
if (json_last_error() !== JSON_ERROR_NONE || !is_array($learnerIDs)) {
    error_log("Invalid learner_ids JSON: " . json_last_error_msg());
    return returnResult(['error' => 'Invalid learner IDs format'], 400);
}

$total = count($learnerIDs);
if ($total > 1536) {
    return returnResult(['error' => 'Too many learners selected. Maximum is 1536.'], 400);
}

// Extract parameters
$project_id = $postData['project_id'] ?? '';
$year = $postData['year'] ?? date('Y');
$month = $postData['month'] ?? date('m');

// Enhanced: Extract date range for document filtering
$startDate = $postData['start_date'] ?? date('Y-m-01');
$endDate = $postData['end_date'] ?? date('Y-m-t');

if ($debug_mode) {
    error_log("=== PARAMETERS ===");
    error_log("Total learners: $total");
    error_log("Project ID: '$project_id'");
    error_log("Year: '$year'");
    error_log("Month: '$month'");
    error_log("Date range: $startDate to $endDate");
}

// Set up file system
$baseDir = __DIR__ . '/temp_reports';
if (!is_dir($baseDir) && !mkdir($baseDir, 0777, true)) {
    error_log("Failed to create temp_reports directory");
    return returnResult(['error' => 'Cannot create temporary directory'], 500);
}

// Clean old files
foreach (glob("$baseDir/*") as $file) {
    if (is_file($file)) {
        unlink($file);
    }
}

// Create reports directory
$reportsDir = $baseDir . '/reports';
if (!is_dir($reportsDir)) {
    mkdir($reportsDir, 0777, true);
}

// Enhanced: Create directories for documents
$sickNotesDir = $baseDir . '/sick_notes';
$manualRegistersDir = $baseDir . '/manual_registers';
if (!is_dir($sickNotesDir)) {
    mkdir($sickNotesDir, 0777, true);
}
if (!is_dir($manualRegistersDir)) {
    mkdir($manualRegistersDir, 0777, true);
}

// Initialize ZIP file (in web root for direct access)
$zipFile = __DIR__ . '/attendance_reports_' . time() . '.zip';
$zip = new ZipArchive();
if ($zip->open($zipFile, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
    error_log("Failed to create ZIP file: $zipFile");
    return returnResult(['error' => 'Failed to create ZIP file'], 500);
}

// Create progress file
$progressFile = $baseDir . '/progress.json';
file_put_contents($progressFile, json_encode([
    'total' => $total,
    'current' => 0,
    'status' => 'Initializing...',
    'done' => false
]));

if ($debug_mode) {
    error_log("=== STARTING PDF GENERATION LOOP ===");
}

// Enhanced function to capture HTML with proper isolation
function captureHTMLSafely($learnerID, $project_id, $year, $month, $debug_mode = false) {
    // Store original superglobals
    $original_GET = $_GET;
    $original_POST = $_POST;
    $original_REQUEST = $_REQUEST;
    
    try {
        // Set new parameters
        $_GET = [
            'learner_id' => $learnerID,
            'LearnerID' => $learnerID,
            'project_id' => $project_id,
            'year' => $year,
            'month' => $month,
            'bulk_processing' => '1'
        ];
        $_POST = [
            'learner_id' => $learnerID,
            'LearnerID' => $learnerID
        ];
        $_REQUEST = array_merge($_GET, $_POST);
        
        if ($debug_mode) {
            error_log("CAPTURE: Set parameters for learner_id=$learnerID, project_id=$project_id");
        }
        
        // CRITICAL: Clean ALL existing output buffers except the main one
        $initial_level = ob_get_level();
        while (ob_get_level() > 1) {
            ob_end_clean();
        }
        
        // Start fresh output buffering
        ob_start();
        
        // Check if bulk_indivisual.php exists
        $bulkFile = __DIR__ . '/bulk_indivisual.php';
        if (!file_exists($bulkFile)) {
            throw new Exception("bulk_indivisual.php not found at: $bulkFile");
        }
        
        if ($debug_mode) {
            error_log("CAPTURE: Including $bulkFile");
        }
        
        // Suppress any PHP errors during include
        $old_error_reporting = error_reporting();
        error_reporting(0);
        
        // Include the file
        include $bulkFile;
        
        // Restore error reporting
        error_reporting($old_error_reporting);
        
        // Get content
        $content = ob_get_clean();
        
        if ($debug_mode) {
            error_log("CAPTURE: Content length: " . strlen($content));
            error_log("CAPTURE: Content preview: " . substr($content, 0, 200) . "...");
        }
        
        // Validate content
        if (empty($content)) {
            throw new Exception("No HTML content captured from bulk_indivisual.php");
        }
        
        if (strlen($content) < 100) {
            throw new Exception("HTML content too short: " . strlen($content) . " characters. Content: " . substr($content, 0, 200));
        }
        
        return $content;
        
    } catch (Exception $e) {
        // Clean up on error
        while (ob_get_level() > $initial_level) {
            ob_end_clean();
        }
        throw $e;
    } finally {
        // Always restore original superglobals
        $_GET = $original_GET;
        $_POST = $original_POST;
        $_REQUEST = $original_REQUEST;
    }
}

// Enhanced: Function to get learner documents
function getLearnerDocumentsEnhanced($conn, $learnerID, $startDate, $endDate) {
    $documents = [
        'sick_notes' => [],
        'manual_registers' => []
    ];
    
    try {
        // Get sick notes within date range
        $stmt = $conn->prepare("SELECT * FROM sick_note 
                               WHERE learner_id = ? 
                               AND date_submitted BETWEEN ? AND ? 
                               ORDER BY date_submitted DESC");
        $stmt->bind_param('iss', $learnerID, $startDate, $endDate);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $filePath = null;
            $fileExists = false;
            
            // Check multiple possible paths
            $possiblePaths = [
                __DIR__ . '/mobile/sicknotes/' . $row['file_path'],
                __DIR__ . '/uploads/' . $row['file_path'],
                __DIR__ . '/' . $row['file_path']
            ];
            
            foreach ($possiblePaths as $path) {
                if (file_exists($path)) {
                    $filePath = $path;
                    $fileExists = true;
                    break;
                }
            }
            
            $documents['sick_notes'][] = [
                'id' => $row['id'],
                'date_submitted' => $row['date_submitted'],
                'file_path' => $row['file_path'],
                'actual_path' => $filePath,
                'file_exists' => $fileExists
            ];
        }
        $stmt->close();
        
        // Get manual registers within date range
        $stmt = $conn->prepare("SELECT * FROM manual_clocking 
                               WHERE learner_id = ? 
                               AND date_submitted BETWEEN ? AND ? 
                               ORDER BY date_submitted DESC");
        $stmt->bind_param('iss', $learnerID, $startDate, $endDate);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $filePath = null;
            $fileExists = false;
            
            // Check multiple possible paths
            $possiblePaths = [
                __DIR__ . '/uploads/' . $row['file_path'],
                __DIR__ . '/mobile/manual_registers/' . $row['file_path'],
                __DIR__ . '/' . $row['file_path']
            ];
            
            foreach ($possiblePaths as $path) {
                if (file_exists($path)) {
                    $filePath = $path;
                    $fileExists = true;
                    break;
                }
            }
            
            $documents['manual_registers'][] = [
                'id' => $row['id'],
                'date_submitted' => $row['date_submitted'],
                'file_path' => $row['file_path'],
                'actual_path' => $filePath,
                'file_exists' => $fileExists
            ];
        }
        $stmt->close();
        
    } catch (Exception $e) {
        error_log("Error getting documents for learner $learnerID: " . $e->getMessage());
    }
    
    return $documents;
}

// Process each learner
$successCount = 0;
$errorCount = 0;
$documentsIncluded = [
    'sick_notes' => 0,
    'manual_registers' => 0
];

foreach ($learnerIDs as $index => $learnerID) {
    $currentLearner = $index + 1;
    
    if ($debug_mode) {
        error_log("--- PROCESSING LEARNER $currentLearner/$total: $learnerID ---");
    }
    
    // Update progress
    $progress = [
        'total' => $total,
        'current' => $currentLearner - 1,
        'status' => "Processing learner $learnerID ($currentLearner/$total)",
        'done' => false
    ];
    file_put_contents($progressFile, json_encode($progress));
    
    // Enhanced: Get documents for this learner
    $documents = getLearnerDocumentsEnhanced($conn, $learnerID, $startDate, $endDate);
    
    // Enhanced: Copy sick notes to ZIP
    foreach ($documents['sick_notes'] as $sickNote) {
        if ($sickNote['file_exists'] && !empty($sickNote['actual_path'])) {
            $fileName = $learnerID . '_' . basename($sickNote['actual_path']);
            $destPath = $sickNotesDir . '/' . $fileName;
            
            if (copy($sickNote['actual_path'], $destPath)) {
                $zip->addFile($destPath, 'sick_notes/' . $fileName);
                $documentsIncluded['sick_notes']++;
            }
        }
    }
    
    // Enhanced: Copy manual registers to ZIP
    foreach ($documents['manual_registers'] as $manualReg) {
        if ($manualReg['file_exists'] && !empty($manualReg['actual_path'])) {
            $fileName = $learnerID . '_' . basename($manualReg['actual_path']);
            $destPath = $manualRegistersDir . '/' . $fileName;
            
            if (copy($manualReg['actual_path'], $destPath)) {
                $zip->addFile($destPath, 'manual_registers/' . $fileName);
                $documentsIncluded['manual_registers']++;
            }
        }
    }
    
    // Capture HTML output
    try {
        $htmlContent = captureHTMLSafely($learnerID, $project_id, $year, $month, $debug_mode);
        
        if ($debug_mode) {
            error_log("✅ HTML captured successfully for learner $learnerID");
        }
    } catch (Exception $e) {
        error_log("Error generating HTML for learner $learnerID: " . $e->getMessage());
        if ($debug_mode) {
            error_log("❌ HTML capture failed: " . $e->getMessage());
        }
        $errorCount++;
        continue;
    }
    
    // Generate PDF
    try {
        $mpdf = new Mpdf([
            'mode' => 'utf-8',
            'format' => 'A4-L',
            'margin_left' => 5,
            'margin_right' => 5,
            'margin_top' => 5,
            'margin_bottom' => 5,
            'orientation' => 'L'
        ]);
        
        // Clean HTML for PDF
        $htmlContent = preg_replace('/<script[^>]*>.*?<\/script>/is', '', $htmlContent);
        $htmlContent = preg_replace('/<style[^>]*>.*?<\/style>/is', '', $htmlContent);
        
        $mpdf->WriteHTML($htmlContent);
        
        $pdfFile = $reportsDir . '/attendance_' . $learnerID . '.pdf';
        $mpdf->Output($pdfFile, 'F');
        
        // Add to ZIP
        $zip->addFile($pdfFile, 'reports/attendance_' . $learnerID . '.pdf');
        
        $successCount++;
        
        if ($debug_mode) {
            error_log("✅ Successfully generated PDF for learner $learnerID");
        }
        
        // Memory cleanup
        if ($currentLearner % 50 === 0) {
            if (function_exists('gc_collect_cycles')) {
                gc_collect_cycles();
            }
        }
        
    } catch (Exception $e) {
        error_log("Error generating PDF for learner $learnerID: " . $e->getMessage());
        if ($debug_mode) {
            error_log("❌ PDF generation failed: " . $e->getMessage());
        }
        $errorCount++;
    }
}

// Enhanced: Add summary file to ZIP
$summary = "BULK EXPORT SUMMARY\n";
$summary .= "===================\n\n";
$summary .= "Export Date: " . date('Y-m-d H:i:s') . "\n";
$summary .= "Date Range: $startDate to $endDate\n\n";
$summary .= "STATISTICS:\n";
$summary .= "- Total Learners: $total\n";
$summary .= "- Successfully Processed: $successCount\n";
$summary .= "- Failed: $errorCount\n";
$summary .= "- Success Rate: " . round(($successCount / $total) * 100, 1) . "%\n\n";
$summary .= "DOCUMENTS:\n";
$summary .= "- Sick Notes Included: " . $documentsIncluded['sick_notes'] . "\n";
$summary .= "- Manual Registers Included: " . $documentsIncluded['manual_registers'] . "\n\n";
$summary .= "FOLDER STRUCTURE:\n";
$summary .= "- reports/ : Individual learner attendance reports (PDF)\n";
$summary .= "- sick_notes/ : Sick note documents\n";
$summary .= "- manual_registers/ : Manual register documents\n\n";
$summary .= "Generated by: Enhanced Bulk Export System\n";

$zip->addFromString('SUMMARY.txt', $summary);

// Close ZIP file
$zip->close();

// Final progress update
$finalProgress = [
    'total' => $total,
    'current' => $total,
    'status' => 'Processing complete',
    'done' => true,
    'zip' => basename($zipFile),
    'success_count' => $successCount,
    'error_count' => $errorCount
];
file_put_contents($progressFile, json_encode($finalProgress));

if ($debug_mode) {
    error_log("=== PROCESSING COMPLETE ===");
    error_log("Total processed: $successCount successful, $errorCount failed");
    error_log("Documents included: " . $documentsIncluded['sick_notes'] . " sick notes, " . $documentsIncluded['manual_registers'] . " manual registers");
    error_log("ZIP file created: " . basename($zipFile));
}

// Enhanced: RETURN RESULT with document information
$result = [
    'success' => true,
    'zip_file' => basename($zipFile),
    'total_processed' => $successCount,
    'total_failed' => $errorCount,
    'documents_included' => $documentsIncluded,
    'message' => "Successfully generated $successCount reports with " . 
                ($documentsIncluded['sick_notes'] + $documentsIncluded['manual_registers']) . " documents"
];

if ($debug_mode) {
    error_log("FINAL RESULT: Preparing to return result");
    error_log("FINAL RESULT: API wrapper mode: " . ($isApiWrapper ? 'YES' : 'NO'));
    error_log("FINAL RESULT: Result data: " . json_encode($result));
}

// Check if we're being called from the API wrapper
if ($isApiWrapper) {
    // Called from API wrapper - return the data directly
    if ($debug_mode) {
        error_log("FINAL RESULT: Returning data to API wrapper");
    }
    return $result;
} else {
    // Called directly - output JSON and exit
    if ($debug_mode) {
        error_log("FINAL RESULT: Outputting JSON directly and exiting");
    }
    if (!headers_sent()) {
        header('Content-Type: application/json');
    }
    // Clean any existing output buffers
    while (ob_get_level() > 0) {
        ob_end_clean();
    }
    echo json_encode($result);
    exit;
}
?>