<?php
// Direct PDF content merger - uses FPDI for proper PDF merging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Start output buffering
ob_start();

// Start session
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include('connection.php');

// Load FPDI library
// Note: If you get a platform check error, run fix_composer_platform_check.php first
require_once 'vendor/autoload.php';
use setasign\Fpdi\Fpdi;

// Check authorization
$is_authorized = false;
$user_name = 'User';

if (isset($_SESSION['sdp_id']) && isset($_SESSION['sdp_name'])) {
    $is_authorized = true;
    $user_name = $_SESSION['sdp_name'];
} elseif (isset($_SESSION['admin_id'])) {
    $is_authorized = true;
    $user_name = $_SESSION['admin_name'] ?? 'Admin';
} elseif (isset($_SESSION['facilitator_id'])) {
    $is_authorized = true;
    $user_name = $_SESSION['facilitator_name'] ?? 'Facilitator';
}

if (!$is_authorized) {
    ob_clean();
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Not authorized']);
    exit;
}

// Get parameters
$learner_id = $_GET['learner_id'] ?? $_POST['learner_id'] ?? null;
$action = $_GET['action'] ?? 'merge_single';

// ADD DETAILED LOGGING
error_log("=== POE MERGE DEBUG START ===");
error_log("Learner ID received: " . ($learner_id ?? 'NONE'));
error_log("Action: " . $action);

if (!$learner_id && $action === 'merge_single') {
    error_log("ERROR: No learner_id provided");
    ob_clean();
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Learner ID is required']);
    exit;
}

try {
    if ($action === 'merge_single') {
        $result = mergeLearnerDocuments($conn, $learner_id);
    } else {
        $result = mergeAllLearnerDocuments($conn);
    }
    
    if ($result['success']) {
        ob_clean();
        
        header('Content-Type: application/pdf');
        header('Content-Disposition: attachment; filename="' . $result['filename'] . '"');
        header('Content-Length: ' . $result['size']);
        header('Cache-Control: no-cache, must-revalidate');
        header('Pragma: no-cache');
        echo $result['content'];
        exit;
    } else {
        ob_clean();
        http_response_code(500);
        header('Content-Type: application/json');
        echo json_encode($result);
    }
    
} catch (Exception $e) {
    error_log("POE Merge Error: " . $e->getMessage());
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Error: ' . $e->getMessage()]);
}

function mergeLearnerDocuments($conn, $learner_id) {
    try {
        // ADD LOGGING
        error_log("mergeLearnerDocuments called with learner_id: " . $learner_id);
        
        // Get all POE documents for the learner - THIS QUERY IS CORRECT
        $sql = "SELECT * FROM poe_documents 
                WHERE learner_id = ? AND status = 'active' 
                ORDER BY upload_date ASC";
        $stmt = $conn->prepare($sql);
        
        if (!$stmt) {
            error_log("ERROR: Failed to prepare statement: " . $conn->error);
            return ['success' => false, 'message' => 'Database error'];
        }
        
        $stmt->bind_param('s', $learner_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $documents = $result->fetch_all(MYSQLI_ASSOC);
        
        // LOG ALL DOCUMENTS FOUND
        error_log("Documents found: " . count($documents));
        foreach ($documents as $doc) {
            error_log("  - Doc ID: " . $doc['id'] . ", Learner: " . $doc['learner_id'] . ", Name: " . $doc['document_name']);
        }
        
        if (empty($documents)) {
            error_log("ERROR: No documents found for learner_id: " . $learner_id);
            return ['success' => false, 'message' => 'No POE documents found for this learner'];
        }
        
        $learner_name = $documents[0]['learner_name'];
        
        // FIX: Use file_path from database, not reconstructed path
        // Remove this line: $base_path = 'mobile/uploads/poe_documents/';
        
        // Collect all valid PDF files
        $pdf_files = [];
        
        foreach ($documents as $doc) {
            // FIX: Use the file_path column directly from database
            $file_path = $doc['file_path'];
            
            error_log("Checking file: " . $file_path);
            
            if (file_exists($file_path)) {
                // Verify it's a valid PDF
                $file_content = file_get_contents($file_path, false, null, 0, 10);
                if ($file_content !== false && strpos($file_content, '%PDF') === 0) {
                    $pdf_files[] = [
                        'path' => $file_path,
                        'name' => $doc['document_name'], // Changed from file_name to document_name
                        'size' => filesize($file_path),
                        'upload_date' => $doc['upload_date'],
                        'document_type' => $doc['document_type'] ?? 'POE Document'
                    ];
                    error_log("  ✓ Valid PDF added: " . $file_path);
                } else {
                    error_log("  ✗ Invalid PDF format: " . $file_path);
                }
            } else {
                error_log("  ✗ File not found: " . $file_path);
            }
        }
        
        error_log("Valid PDF files collected: " . count($pdf_files));
        
        if (empty($pdf_files)) {
            return ['success' => false, 'message' => 'No valid PDF files found'];
        }
        
        // If only one file, return it as-is
        if (count($pdf_files) === 1) {
            $content = file_get_contents($pdf_files[0]['path']);
            $filename = "POE_" . preg_replace('/[^a-zA-Z0-9_-]/', '_', $learner_name) . "_" . $learner_id . "_" . date('Y-m-d_H-i-s') . ".pdf";
            
            error_log("Returning single PDF: " . $filename);
            
            return [
                'success' => true,
                'content' => $content,
                'filename' => $filename,
                'size' => strlen($content)
            ];
        }
        
        // Try direct PDF concatenation
        error_log("Attempting to merge " . count($pdf_files) . " PDFs");
        $merged_content = attemptDirectPDFMerge($pdf_files, $learner_name, $learner_id);
        
        if ($merged_content) {
            $filename = "POE_Merged_" . preg_replace('/[^a-zA-Z0-9_-]/', '_', $learner_name) . "_" . $learner_id . "_" . date('Y-m-d_H-i-s') . ".pdf";
            
            error_log("Merge successful: " . $filename);
            
            return [
                'success' => true,
                'content' => $merged_content,
                'filename' => $filename,
                'size' => strlen($merged_content)
            ];
        } else {
            error_log("ERROR: PDF merge failed");
            return ['success' => false, 'message' => 'Failed to merge PDF files directly'];
        }
        
    } catch (Exception $e) {
        error_log("EXCEPTION in mergeLearnerDocuments: " . $e->getMessage());
        return ['success' => false, 'message' => 'Error: ' . $e->getMessage()];
    }
}

// Rest of your functions remain the same...
function mergeAllLearnerDocuments($conn) {
    return ['success' => false, 'message' => 'Bulk merge not implemented'];
}

function attemptDirectPDFMerge($pdf_files, $learner_name, $learner_id) {
    try {
        // Use FPDI for proper PDF merging
        error_log("Starting FPDI merge for " . count($pdf_files) . " files");
        
        $pdf = new Fpdi();
        
        // CRITICAL FIX #1: Disable auto page break to prevent blank pages
        $pdf->SetAutoPageBreak(false);
        
        $mergedPages = 0;
        
        foreach ($pdf_files as $index => $file) {
            $filePath = $file['path'];
            error_log("Processing file " . ($index + 1) . ": " . basename($filePath));
            
            try {
                // Set source file
                $pageCount = $pdf->setSourceFile($filePath);
                error_log("  - Found $pageCount pages in " . basename($filePath));
                
                // Import each page
                for ($pageNo = 1; $pageNo <= $pageCount; $pageNo++) {
                    try {
                        // Import the page
                        $templateId = $pdf->importPage($pageNo);
                        $size = $pdf->getTemplateSize($templateId);
                        
                        // CRITICAL FIX #2: Calculate proper orientation
                        $orientation = $size['width'] > $size['height'] ? 'L' : 'P';
                        
                        // Add a new page with the same size and orientation
                        $pdf->AddPage($orientation, [$size['width'], $size['height']]);
                        
                        // CRITICAL FIX #3: Use complete useTemplate call with all parameters
                        $pdf->useTemplate($templateId, 0, 0, $size['width'], $size['height']);
                        
                        $mergedPages++;
                        
                    } catch (Exception $e) {
                        error_log("  ✗ Error on page $pageNo: " . $e->getMessage());
                    }
                }
                
                error_log("  ✓ Successfully processed " . basename($filePath));
                
            } catch (Exception $e) {
                error_log("  ✗ Failed to process file: " . $e->getMessage());
            }
        }
        
        error_log("✓ Merge complete: $mergedPages pages merged");
        
        if ($mergedPages === 0) {
            error_log("ERROR: No pages were merged");
            return false;
        }
        
        // Output PDF as string
        return $pdf->Output('S');
        
    } catch (Exception $e) {
        error_log("FPDI merge failed: " . $e->getMessage());
        error_log("Stack trace: " . $e->getTraceAsString());
        return false;
    }
}

$conn->close();
?>