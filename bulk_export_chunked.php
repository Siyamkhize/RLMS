<?php
/**
 * CHUNKED BULK EXPORT PROCESSOR - TIMEOUT RESISTANT
 * Processes learners in small chunks with progress tracking
 * Can handle 2000+ learners without timing out
 */

// Start output buffering immediately to catch any unwanted output
ob_start();

// Strict error handling
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/bulk_export_errors.log');   

// Set reasonable limits per chunk
set_time_limit(120); // 2 minutes per chunk
ini_set('memory_limit', '512M');

// Include required files
require_once __DIR__ . '/connection.php';
require_once __DIR__ . '/vendor/autoload.php';

// Clean any output from includes
ob_end_clean();

// Verify database connection
if (!isset($conn) || $conn->connect_error) {
    header('Content-Type: application/json');
    die(json_encode(['error' => 'Database connection failed']));
}

/**
 * Generate HTML from original indivisual.php template
 */
function generateHTMLFromTemplate($learnerID, $projectId, $year, $month) {
    // Store original superglobals
    $original_GET = $_GET;
    $original_POST = $_POST;
    $original_REQUEST = $_REQUEST;
    
    try {
        // Set parameters for indivisual.php
        $_GET = [
            'LearnerID' => $learnerID,
            'project_id' => $projectId,
            'year' => $year,
            'month' => $month,
            'bulk_export' => '1'
        ];
        $_POST = [];
        $_REQUEST = $_GET;
        
        // Start output buffering
        ob_start();
        
        // Suppress errors during template include
        $oldErrorReporting = error_reporting(0);
        
        // Check if indivisual.php exists
        if (file_exists(__DIR__ . '/indivisual.php')) {
            include __DIR__ . '/indivisual.php';
            $html = ob_get_clean();
        } else {
            ob_end_clean();
            // Use fallback simple HTML template
            $html = generateFallbackHTML($learnerID, $projectId, $year, $month);
        }
        
        // Restore error reporting
        error_reporting($oldErrorReporting);
        
        return $html;
        
    } catch (Exception $e) {
        // Clean buffer on error
        if (ob_get_level() > 0) {
            ob_end_clean();
        }
        error_log("Error generating HTML from template: " . $e->getMessage());
        // Return fallback HTML
        return generateFallbackHTML($learnerID, $projectId, $year, $month);
    } finally {
        // Restore original superglobals
        $_GET = $original_GET;
        $_POST = $original_POST;
        $_REQUEST = $original_REQUEST;
    }
}

/**
 * Generate fallback HTML when template is not available
 */
function generateFallbackHTML($learnerID, $projectId, $year, $month) {
    global $conn;
    
    // Get learner details
    $stmt = $conn->prepare("SELECT ld.Name, ld.Surname, ld.IDNumber, ld.PhoneNumber,
                           s.siteName, p.Project_name
                           FROM learnerdetails ld
                           LEFT JOIN class c ON ld.classID = c.classID
                           LEFT JOIN sites s ON c.siteID = s.siteID
                           LEFT JOIN project p ON s.project_id = p.project_id
                           WHERE ld.LearnerID = ?");
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        return '<html><body><h1>Learner not found</h1></body></html>';
    }
    
    $learner = $result->fetch_assoc();
    $stmt->close();
    
    $html = '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Attendance Report - ' . htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']) . '</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { text-align: center; margin-bottom: 20px; }
        .info { margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>ATTENDANCE REPORT</h1>
        <h2>' . htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']) . '</h2>
        <p>Period: ' . date('F Y', mktime(0, 0, 0, $month, 1, $year)) . '</p>
    </div>
    <div class="info">
        <p><strong>ID Number:</strong> ' . htmlspecialchars($learner['IDNumber']) . '</p>
        <p><strong>Phone:</strong> ' . htmlspecialchars($learner['PhoneNumber']) . '</p>
        <p><strong>Site:</strong> ' . htmlspecialchars($learner['siteName'] ?? 'N/A') . '</p>
        <p><strong>Project:</strong> ' . htmlspecialchars($learner['Project_name'] ?? 'N/A') . '</p>
    </div>
    <p><em>Note: Using fallback template. Upload indivisual.php for full report.</em></p>
</body>
</html>';
    
    return $html;
}

/**
 * Get learner documents within date range
 */
function getLearnerDocumentsQuick($conn, $learnerID, $startDate, $endDate) {
    $documents = ['sick_notes' => [], 'manual_registers' => []];
    
    try {
        // Sick notes
        $stmt = $conn->prepare("SELECT note_id, document_path, date_from, date_to, status 
                               FROM sick_note 
                               WHERE learner_id = ? 
                               AND ((date_from BETWEEN ? AND ?) OR (date_to BETWEEN ? AND ?))
                               ORDER BY date_from DESC");
        $stmt->bind_param('issss', $learnerID, $startDate, $endDate, $startDate, $endDate);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $possiblePaths = [
                __DIR__ . '/mobile/sicknotes/' . $row['document_path'],
                __DIR__ . '/uploads/' . $row['document_path'],
                __DIR__ . '/' . $row['document_path']
            ];
            
            $actualPath = null;
            foreach ($possiblePaths as $path) {
                if (file_exists($path)) {
                    $actualPath = $path;
                    break;
                }
            }
            
            if ($actualPath) {
                $documents['sick_notes'][] = [
                    'id' => $row['note_id'],
                    'path' => $actualPath,
                    'date_from' => $row['date_from'],
                    'date_to' => $row['date_to']
                ];
            }
        }
        $stmt->close();
        
        // Manual registers
        $stmt = $conn->prepare("SELECT manual_id, fdp_document, clock_date, status 
                               FROM manual_clocking 
                               WHERE LearnerID = ? 
                               AND clock_date BETWEEN ? AND ?
                               AND fdp_document IS NOT NULL AND fdp_document != ''
                               ORDER BY clock_date DESC");
        $stmt->bind_param('iss', $learnerID, $startDate, $endDate);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $possiblePaths = [
                __DIR__ . '/uploads/' . $row['fdp_document'],
                __DIR__ . '/mobile/uploads/' . $row['fdp_document'],
                __DIR__ . '/' . $row['fdp_document']
            ];
            
            $actualPath = null;
            foreach ($possiblePaths as $path) {
                if (file_exists($path)) {
                    $actualPath = $path;
                    break;
                }
            }
            
            if ($actualPath) {
                $documents['manual_registers'][] = [
                    'id' => $row['manual_id'],
                    'path' => $actualPath,
                    'clock_date' => $row['clock_date']
                ];
            }
        }
        $stmt->close();
        
    } catch (Exception $e) {
        error_log("Error getting documents for learner $learnerID: " . $e->getMessage());
    }
    
    return $documents;
}

/**
 * Generate HTML report using original indivisual.php template
 */
function generateQuickHTMLReport($conn, $learnerID, $startDate, $endDate) {
    // Get learner details with project_id
    $stmt = $conn->prepare("SELECT ld.Name, ld.Surname, ld.IDNumber, ld.PhoneNumber,
                           s.siteName, s.project_id, p.Project_name
                           FROM learnerdetails ld
                           LEFT JOIN class c ON ld.classID = c.classID
                           LEFT JOIN sites s ON c.siteID = s.siteID
                           LEFT JOIN project p ON s.project_id = p.project_id
                           WHERE ld.LearnerID = ?");
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        return null;
    }
    
    $learner = $result->fetch_assoc();
    $stmt->close();
    
    // Extract year and month from date range
    $year = date('Y', strtotime($startDate));
    $month = date('m', strtotime($startDate));
    
    // Use original indivisual.php template
    return generateHTMLFromTemplate($learnerID, $learner['project_id'], $year, $month);
}

/**
 * Process a chunk of learners
 */
function processChunk($conn, $learnerIds, $startDate, $endDate, $sessionId, $chunkIndex) {
    $sessionDir = __DIR__ . '/temp_reports/session_' . $sessionId;
    $reportsDir = $sessionDir . '/reports';
    $sickNotesDir = $sessionDir . '/sick_notes';
    $manualRegistersDir = $sessionDir . '/manual_registers';
    
    // Ensure directories exist
    if (!is_dir($reportsDir)) mkdir($reportsDir, 0777, true);
    if (!is_dir($sickNotesDir)) mkdir($sickNotesDir, 0777, true);
    if (!is_dir($manualRegistersDir)) mkdir($manualRegistersDir, 0777, true);
    
    $results = [
        'processed' => 0,
        'failed' => 0,
        'sick_notes' => 0,
        'manual_registers' => 0,
        'errors' => []
    ];
    
    foreach ($learnerIds as $learnerID) {
        try {
            // Get documents
            $documents = getLearnerDocumentsQuick($conn, $learnerID, $startDate, $endDate);
            
            // Copy sick notes
            foreach ($documents['sick_notes'] as $doc) {
                $fileName = $learnerID . '_sicknote_' . basename($doc['path']);
                if (copy($doc['path'], $sickNotesDir . '/' . $fileName)) {
                    $results['sick_notes']++;
                }
            }
            
            // Copy manual registers
            foreach ($documents['manual_registers'] as $doc) {
                $fileName = $learnerID . '_manual_' . basename($doc['path']);
                if (copy($doc['path'], $manualRegistersDir . '/' . $fileName)) {
                    $results['manual_registers']++;
                }
            }
            
            // Generate HTML report
            $html = generateQuickHTMLReport($conn, $learnerID, $startDate, $endDate);
            
            if ($html) {
                // Convert to PDF using mPDF
                $mpdf = new \Mpdf\Mpdf([
                    'mode' => 'utf-8',
                    'format' => 'A4',
                    'margin_left' => 10,
                    'margin_right' => 10,
                    'margin_top' => 10,
                    'margin_bottom' => 10
                ]);
                
                $mpdf->WriteHTML($html);
                $pdfPath = $reportsDir . '/report_' . $learnerID . '.pdf';
                $mpdf->Output($pdfPath, 'F');
                
                $results['processed']++;
            } else {
                $results['failed']++;
                $results['errors'][] = "No data for learner $learnerID";
            }
            
        } catch (Exception $e) {
            $results['failed']++;
            $results['errors'][] = "Learner $learnerID: " . $e->getMessage();
            error_log("Error processing learner $learnerID: " . $e->getMessage());
        }
    }
    
    return $results;
}

// Handle requests
// Clean any remaining output buffers
while (ob_get_level()) {
    ob_end_clean();
}

// Set JSON header
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-cache, must-revalidate');

$action = $_POST['action'] ?? $_GET['action'] ?? '';

switch ($action) {
    case 'start':
        // Start a new chunked export session
        $learnerIds = json_decode($_POST['learner_ids'] ?? '[]', true);
        $startDate = $_POST['start_date'] ?? date('Y-m-01');
        $endDate = $_POST['end_date'] ?? date('Y-m-t');
        $chunkSize = intval($_POST['chunk_size'] ?? 10); // Process 10 learners at a time
        
        if (empty($learnerIds)) {
            echo json_encode(['error' => 'No learner IDs provided']);
            exit;
        }
        
        // Create session
        $sessionId = 'session_' . time() . '_' . rand(1000, 9999);
        $sessionDir = __DIR__ . '/temp_reports/session_' . $sessionId;
        mkdir($sessionDir, 0777, true);
        
        // Split learners into chunks
        $chunks = array_chunk($learnerIds, $chunkSize);
        
        // Save session data
        $sessionData = [
            'session_id' => $sessionId,
            'total_learners' => count($learnerIds),
            'total_chunks' => count($chunks),
            'chunk_size' => $chunkSize,
            'start_date' => $startDate,
            'end_date' => $endDate,
            'chunks' => $chunks,
            'processed_chunks' => 0,
            'status' => 'ready',
            'created_at' => time()
        ];
        
        file_put_contents($sessionDir . '/session.json', json_encode($sessionData));
        
        echo json_encode([
            'success' => true,
            'session_id' => $sessionId,
            'total_learners' => count($learnerIds),
            'total_chunks' => count($chunks),
            'chunk_size' => $chunkSize
        ]);
        break;
        
    case 'process_chunk':
        // Process next chunk
        $sessionId = $_POST['session_id'] ?? '';
        $chunkIndex = intval($_POST['chunk_index'] ?? 0);
        
        if (empty($sessionId)) {
            echo json_encode(['error' => 'No session ID provided']);
            exit;
        }
        
        $sessionDir = __DIR__ . '/temp_reports/session_' . $sessionId;
        $sessionFile = $sessionDir . '/session.json';
        
        if (!file_exists($sessionFile)) {
            echo json_encode(['error' => 'Session not found']);
            exit;
        }
        
        $sessionData = json_decode(file_get_contents($sessionFile), true);
        
        if ($chunkIndex >= $sessionData['total_chunks']) {
            echo json_encode(['error' => 'Invalid chunk index']);
            exit;
        }
        
        // Process this chunk
        $chunkLearners = $sessionData['chunks'][$chunkIndex];
        $results = processChunk($conn, $chunkLearners, $sessionData['start_date'], $sessionData['end_date'], $sessionId, $chunkIndex);
        
        // Update session
        $sessionData['processed_chunks']++;
        $sessionData['status'] = $sessionData['processed_chunks'] >= $sessionData['total_chunks'] ? 'completed' : 'processing';
        file_put_contents($sessionFile, json_encode($sessionData));
        
        echo json_encode([
            'success' => true,
            'chunk_index' => $chunkIndex,
            'chunk_results' => $results,
            'processed_chunks' => $sessionData['processed_chunks'],
            'total_chunks' => $sessionData['total_chunks'],
            'progress_percent' => round(($sessionData['processed_chunks'] / $sessionData['total_chunks']) * 100, 1),
            'completed' => $sessionData['status'] === 'completed'
        ]);
        break;
        
    case 'finalize':
        // Create final ZIP file
        $sessionId = $_POST['session_id'] ?? '';
        
        if (empty($sessionId)) {
            echo json_encode(['error' => 'No session ID provided']);
            exit;
        }
        
        $sessionDir = __DIR__ . '/temp_reports/session_' . $sessionId;
        $sessionFile = $sessionDir . '/session.json';
        
        if (!file_exists($sessionFile)) {
            echo json_encode(['error' => 'Session not found']);
            exit;
        }
        
        $sessionData = json_decode(file_get_contents($sessionFile), true);
        
        // Create ZIP
        $zipFileName = 'bulk_reports_' . date('Ymd_His') . '.zip';
        $zipPath = __DIR__ . '/temp_reports/' . $zipFileName;
        
        $zip = new ZipArchive();
        if ($zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== TRUE) {
            echo json_encode(['error' => 'Failed to create ZIP file']);
            exit;
        }
        
        // Add all files from session directory
        $files = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($sessionDir),
            RecursiveIteratorIterator::LEAVES_ONLY
        );
        
        foreach ($files as $file) {
            if (!$file->isDir() && $file->getFilename() !== 'session.json') {
                $filePath = $file->getRealPath();
                $relativePath = substr($filePath, strlen($sessionDir) + 1);
                $zip->addFile($filePath, $relativePath);
            }
        }
        
        // Add summary
        $summary = "BULK EXPORT SUMMARY\n";
        $summary .= "===================\n\n";
        $summary .= "Export Date: " . date('Y-m-d H:i:s') . "\n";
        $summary .= "Date Range: " . $sessionData['start_date'] . " to " . $sessionData['end_date'] . "\n";
        $summary .= "Total Learners: " . $sessionData['total_learners'] . "\n";
        $summary .= "Processed in " . $sessionData['total_chunks'] . " chunks\n\n";
        $summary .= "FOLDER STRUCTURE:\n";
        $summary .= "- reports/ : Individual learner attendance reports (PDF)\n";
        $summary .= "- sick_notes/ : Sick note documents\n";
        $summary .= "- manual_registers/ : Manual register documents\n";
        
        $zip->addFromString('SUMMARY.txt', $summary);
        $zip->close();
        
        // Clean up session directory
        deleteDirectory($sessionDir);
        
        echo json_encode([
            'success' => true,
            'zip_file' => $zipFileName,
            'download_url' => 'bulk_down_register.php?temp_file=' . $zipFileName
        ]);
        break;
        
    default:
        echo json_encode(['error' => 'Invalid action']);
}

function deleteDirectory($dir) {
    if (!is_dir($dir)) return;
    $files = array_diff(scandir($dir), ['.', '..']);
    foreach ($files as $file) {
        $path = $dir . '/' . $file;
        is_dir($path) ? deleteDirectory($path) : unlink($path);
    }
    rmdir($dir);
}
?>
