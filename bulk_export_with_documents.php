<?php
/**
 * Enhanced Bulk Export with Sick Notes and Manual Registers
 * This script generates PDF reports and includes supporting documents in a ZIP file
 */

// Strict error handling
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/bulk_export_errors.log');

// Set execution time limit for large batches with PDF generation
set_time_limit(1800); // 30 minutes for PDF generation
ini_set('memory_limit', '1024M'); // Increase memory for PDF processing
ini_set('max_execution_time', '1800');

// Only include files if not already included (when called directly)
if (!defined('BULK_EXPORT_INCLUDED')) {
    define('BULK_EXPORT_INCLUDED', true);
    
    // Include required files
    if (!file_exists(__DIR__ . '/connection.php')) {
        error_log("connection.php not found at: " . __DIR__ . '/connection.php');
        if (php_sapi_name() !== 'cli') {
            header('Content-Type: application/json');
        }
        die(json_encode(['error' => 'connection.php not found']));
    }
    require_once __DIR__ . '/connection.php';

    if (!file_exists(__DIR__ . '/get_learner_documents.php')) {
        error_log("get_learner_documents.php not found at: " . __DIR__ . '/get_learner_documents.php');
        if (php_sapi_name() !== 'cli') {
            header('Content-Type: application/json');
        }
        die(json_encode(['error' => 'get_learner_documents.php not found']));
    }
    require_once __DIR__ . '/get_learner_documents.php';

    // Verify database connection
    if (!isset($conn) || $conn->connect_error) {
        error_log("Database connection failed: " . ($conn->connect_error ?? 'Unknown error'));
        if (php_sapi_name() !== 'cli') {
            header('Content-Type: application/json');
        }
        die(json_encode(['error' => 'Database connection failed', 'details' => ($conn->connect_error ?? 'Unknown error')]));
    }
}

/**
 * Generate attendance report HTML using same logic as indivisual.php (FAST!)
 */
function generateAttendanceReportHTML($conn, $learnerID, $projectId, $year, $month, $learnerData) {
    // Get month boundaries
    $firstDayOfMonth = date('Y-m-01', strtotime("$year-$month-01"));
    $lastDayOfMonth = date('Y-m-t', strtotime("$year-$month-01"));
    
    // Fetch learner and project details (optimized query)
    $sql = "SELECT DISTINCT
                l.Name, l.Surname, l.IDNumber, l.PhoneNumber, l.AddressLine1, l.Gender, l.profile_image,
                sdp.sdp_logo, client.client_logo, p.Project_name, s.Project_pathway, p.Province
            FROM learnerdetails l
            JOIN class c ON l.classID = c.classID
            JOIN sites s ON c.siteID = s.siteID
            JOIN project p ON p.project_id = s.project_id
            JOIN sdp ON p.sdp_name = sdp.sdp_name
            JOIN client ON p.client_name = client.client_name
            WHERE p.project_id = ? AND l.LearnerID = ?";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ii", $projectId, $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if (!$result || $result->num_rows === 0) {
        return null;
    }
    
    $row = $result->fetch_assoc();
    $stmt->close();
    
    $Name = $row['Name'] ?? '';
    $Surname = $row['Surname'] ?? '';
    $FullName = trim($Name . ' ' . $Surname);
    $IDNumber = $row['IDNumber'] ?? 'N/A';
    $PhoneNumber = $row['PhoneNumber'] ?? 'N/A';
    $projectName = $row['Project_name'] ?? 'N/A';
    $projectPathway = $row['Project_pathway'] ?? 'N/A';
    $Province = $row['Province'] ?? 'N/A';
    
    // Get attendance data for the month
    $sql = "SELECT DATE(clock_date) as clock_date, clock_in_time, clock_out_time, contact_time
            FROM learner_clocking
            WHERE LearnerID = ? AND MONTH(clock_date) = ? AND YEAR(clock_date) = ?
            ORDER BY clock_date";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('iii', $learnerID, $month, $year);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $clockingData = [];
    while ($row = $result->fetch_assoc()) {
        $clockingData[$row['clock_date']] = $row;
    }
    $stmt->close();
    
    // Generate HTML (simplified version of indivisual.php)
    $html = '<!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>Attendance Report - ' . htmlspecialchars($FullName) . '</title>
        <style>
            body { font-family: Arial, sans-serif; font-size: 12px; margin: 10px; }
            .header { text-align: center; margin-bottom: 20px; }
            .learner-info { margin-bottom: 20px; }
            .calendar { width: 100%; border-collapse: collapse; }
            .calendar th, .calendar td { border: 1px solid #000; padding: 5px; text-align: center; }
            .calendar th { background: #f0f0f0; }
            .present { background: #d4edda; }
            .absent { background: #f8d7da; }
            .holiday { background: #fff3cd; }
            .weekend { background: #e2e3e5; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>ATTENDANCE REPORT</h1>
            <h2>' . htmlspecialchars($FullName) . '</h2>
            <p>Period: ' . date('F Y', strtotime($firstDayOfMonth)) . '</p>
        </div>
        
        <div class="learner-info">
            <p><strong>ID Number:</strong> ' . htmlspecialchars($IDNumber) . '</p>
            <p><strong>Phone:</strong> ' . htmlspecialchars($PhoneNumber) . '</p>
            <p><strong>Project:</strong> ' . htmlspecialchars($projectName) . '</p>
            <p><strong>Province:</strong> ' . htmlspecialchars($Province) . '</p>
        </div>
        
        <table class="calendar">
            <tr><th>Date</th><th>Status</th><th>Clock In</th><th>Clock Out</th></tr>';
    
    // Generate calendar rows
    $daysInMonth = date('t', strtotime($firstDayOfMonth));
    $presentDays = 0;
    
    for ($day = 1; $day <= $daysInMonth; $day++) {
        $date = sprintf('%04d-%02d-%02d', $year, $month, $day);
        $dayOfWeek = date('w', strtotime($date));
        
        $html .= '<tr>';
        $html .= '<td>' . date('d M', strtotime($date)) . '</td>';
        
        if ($dayOfWeek == 0 || $dayOfWeek == 6) {
            $html .= '<td class="weekend">Weekend</td><td>-</td><td>-</td>';
        } elseif (isset($clockingData[$date])) {
            $record = $clockingData[$date];
            $html .= '<td class="present">Present</td>';
            $html .= '<td>' . substr($record['clock_in_time'] ?? '', 0, 5) . '</td>';
            $html .= '<td>' . substr($record['clock_out_time'] ?? '', 0, 5) . '</td>';
            $presentDays++;
        } else {
            $html .= '<td class="absent">Absent</td><td>-</td><td>-</td>';
        }
        
        $html .= '</tr>';
    }
    
    $html .= '</table>
        
        <div style="margin-top: 20px;">
            <p><strong>Summary:</strong></p>
            <p>Days Present: ' . $presentDays . '</p>
            <p>Working Days: ' . ($daysInMonth - 8) . ' (approx)</p>
            <p>Generated: ' . date('Y-m-d H:i:s') . '</p>
        </div>
    </body>
    </html>';
    
    return $html;
}

/**
 * Generate bulk reports with documents - TIMEOUT RESISTANT VERSION
 * Processes in small batches to avoid gateway timeouts
 */
function generateBulkReportsWithDocuments($conn, $learnerIds, $startDate, $endDate, $projectId = null) {
    error_log("=== BULK EXPORT START (TIMEOUT RESISTANT) ===");
    error_log("generateBulkReportsWithDocuments called with " . count($learnerIds) . " learners");
    error_log("Date range: $startDate to $endDate");
    
    // For large batches, use background processing
    if (count($learnerIds) > 50) {
        return startBackgroundProcessing($learnerIds, $startDate, $endDate, $projectId);
    }
    
    // For small batches, process immediately with optimizations
    return processLearnersBatch($conn, $learnerIds, $startDate, $endDate, $projectId);
}

/**
 * Start background processing for large batches
 */
function startBackgroundProcessing($learnerIds, $startDate, $endDate, $projectId) {
    $jobId = 'job_' . time() . '_' . rand(1000, 9999);
    
    // Create job file
    $jobData = [
        'job_id' => $jobId,
        'learner_ids' => $learnerIds,
        'start_date' => $startDate,
        'end_date' => $endDate,
        'project_id' => $projectId,
        'status' => 'queued',
        'created_at' => time()
    ];
    
    $jobsDir = __DIR__ . '/temp_reports/jobs';
    if (!is_dir($jobsDir)) {
        mkdir($jobsDir, 0777, true);
    }
    
    file_put_contents($jobsDir . '/' . $jobId . '.json', json_encode($jobData));
    
    // Start background process (non-blocking)
    if (function_exists('exec')) {
        $command = "php " . __DIR__ . "/process_background_job.php $jobId > /dev/null 2>&1 &";
        exec($command);
    }
    
    return [
        'success' => true,
        'background_job' => true,
        'job_id' => $jobId,
        'message' => 'Large batch queued for background processing',
        'total_learners' => count($learnerIds),
        'check_status_url' => 'check_job_status.php?job_id=' . $jobId
    ];
}

/**
 * Process learners in optimized batch - FAST VERSION
 */
function processLearnersBatch($conn, $learnerIds, $startDate, $endDate, $projectId = null) {
    $results = [
        'success' => false,
        'total_learners' => count($learnerIds),
        'processed' => 0,
        'failed' => 0,
        'reports' => [],
        'documents_included' => [
            'sick_notes' => 0,
            'manual_registers' => 0
        ],
        'zip_file' => null,
        'errors' => []
    ];
    
    // Create temp directory
    $tempDir = __DIR__ . '/temp_reports_' . time();
    if (!mkdir($tempDir, 0777, true)) {
        $results['errors'][] = "Failed to create temp directory";
        return $results;
    }
    
    $reportsDir = $tempDir . '/reports';
    $sickNotesDir = $tempDir . '/sick_notes';
    $manualRegistersDir = $tempDir . '/manual_registers';
    
    mkdir($reportsDir, 0777, true);
    mkdir($sickNotesDir, 0777, true);
    mkdir($manualRegistersDir, 0777, true);
    
    // Process learners with optimizations
    foreach ($learnerIds as $index => $learnerID) {
        try {
            // Get learner details (optimized query)
            $stmt = $conn->prepare("SELECT ld.Name, ld.Surname, ld.IDNumber, s.project_id, s.siteName 
                                   FROM learnerdetails ld
                                   LEFT JOIN class c ON ld.classID = c.classID
                                   LEFT JOIN sites s ON c.siteID = s.siteID
                                   WHERE ld.LearnerID = ?");
            $stmt->bind_param('i', $learnerID);
            $stmt->execute();
            $learnerResult = $stmt->get_result();
            
            if ($learnerResult->num_rows === 0) {
                $results['failed']++;
                $results['errors'][] = "Learner ID $learnerID not found";
                continue;
            }
            
            $learner = $learnerResult->fetch_assoc();
            $stmt->close();
            
            // Get documents (optimized)
            $documents = getLearnerDocuments($conn, $learnerID, $startDate, $endDate);
            
            // Copy documents quickly
            foreach ($documents['sick_notes'] as $sickNote) {
                if ($sickNote['file_exists'] && !empty($sickNote['actual_path'])) {
                    $fileName = $learnerID . '_' . basename($sickNote['actual_path']);
                    if (copy($sickNote['actual_path'], $sickNotesDir . '/' . $fileName)) {
                        $results['documents_included']['sick_notes']++;
                    }
                }
            }
            
            foreach ($documents['manual_registers'] as $manualReg) {
                if ($manualReg['file_exists'] && !empty($manualReg['actual_path'])) {
                    $fileName = $learnerID . '_' . basename($manualReg['actual_path']);
                    if (copy($manualReg['actual_path'], $manualRegistersDir . '/' . $fileName)) {
                        $results['documents_included']['manual_registers']++;
                    }
                }
            }
            
            // Generate simple text report (FAST - no PDF for small batches to avoid timeout)
            $reportText = generateSimpleTextReport($learner, $learnerID, $documents, $startDate, $endDate);
            $reportFile = $reportsDir . '/' . $learnerID . '_report.txt';
            file_put_contents($reportFile, $reportText);
            
            $results['processed']++;
            $results['reports'][] = [
                'learner_id' => $learnerID,
                'name' => $learner['Name'] . ' ' . $learner['Surname'],
                'id_number' => $learner['IDNumber'],
                'site' => $learner['siteName'] ?? 'N/A',
                'sick_notes_count' => count($documents['sick_notes']),
                'manual_registers_count' => count($documents['manual_registers'])
            ];
            
        } catch (Exception $e) {
            $results['failed']++;
            $results['errors'][] = "Error processing learner $learnerID: " . $e->getMessage();
            error_log("Error processing learner $learnerID: " . $e->getMessage());
        }
    }
    
    // Create ZIP file quickly
    try {
        $zipFileName = 'bulk_reports_' . date('Ymd_His') . '.zip';
        $zipPath = __DIR__ . '/temp_reports/' . $zipFileName;
        
        if (!is_dir(__DIR__ . '/temp_reports')) {
            mkdir(__DIR__ . '/temp_reports', 0777, true);
        }
        
        $zip = new ZipArchive();
        if ($zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) === TRUE) {
            
            // Add files efficiently
            $files = new RecursiveIteratorIterator(
                new RecursiveDirectoryIterator($tempDir),
                RecursiveIteratorIterator::LEAVES_ONLY
            );
            
            foreach ($files as $file) {
                if (!$file->isDir()) {
                    $filePath = $file->getRealPath();
                    $relativePath = substr($filePath, strlen($tempDir) + 1);
                    $zip->addFile($filePath, $relativePath);
                }
            }
            
            // Add summary
            $summary = "Bulk Export Summary\n===================\n\n";
            $summary .= "Date Range: $startDate to $endDate\n";
            $summary .= "Total Learners: " . $results['total_learners'] . "\n";
            $summary .= "Successfully Processed: " . $results['processed'] . "\n";
            $summary .= "Failed: " . $results['failed'] . "\n";
            $summary .= "Sick Notes: " . $results['documents_included']['sick_notes'] . "\n";
            $summary .= "Manual Registers: " . $results['documents_included']['manual_registers'] . "\n";
            $summary .= "\nGenerated: " . date('Y-m-d H:i:s') . "\n";
            
            $zip->addFromString('SUMMARY.txt', $summary);
            $zip->close();
            
            $results['zip_file'] = $zipFileName;
            $results['success'] = true;
        }
        
    } catch (Exception $e) {
        $results['errors'][] = "ZIP creation failed: " . $e->getMessage();
    }
    
    // Clean up
    deleteDirectory($tempDir);
    
    error_log("=== BULK EXPORT END ===");
    return $results;
}

/**
 * Generate simple text report (FAST)
 */
function generateSimpleTextReport($learner, $learnerID, $documents, $startDate, $endDate) {
    $report = "LEARNER ATTENDANCE & DOCUMENT REPORT\n";
    $report .= "====================================\n\n";
    $report .= "Learner ID: " . $learnerID . "\n";
    $report .= "Name: " . $learner['Name'] . " " . $learner['Surname'] . "\n";
    $report .= "ID Number: " . $learner['IDNumber'] . "\n";
    $report .= "Site: " . ($learner['siteName'] ?? 'N/A') . "\n";
    $report .= "\nREPORT PERIOD: " . date('d M Y', strtotime($startDate)) . " to " . date('d M Y', strtotime($endDate)) . "\n\n";
    
    $report .= "DOCUMENTS INCLUDED:\n";
    $report .= "- Sick Notes: " . count($documents['sick_notes']) . "\n";
    $report .= "- Manual Registers: " . count($documents['manual_registers']) . "\n\n";
    
    if (!empty($documents['sick_notes'])) {
        $report .= "SICK NOTES:\n";
        foreach ($documents['sick_notes'] as $note) {
            $report .= "- " . $note['date_submitted'] . ": " . ($note['file_exists'] ? 'Included' : 'File missing') . "\n";
        }
        $report .= "\n";
    }
    
    if (!empty($documents['manual_registers'])) {
        $report .= "MANUAL REGISTERS:\n";
        foreach ($documents['manual_registers'] as $reg) {
            $report .= "- " . $reg['date_submitted'] . ": " . ($reg['file_exists'] ? 'Included' : 'File missing') . "\n";
        }
        $report .= "\n";
    }
    
    $report .= "Generated: " . date('Y-m-d H:i:s') . "\n";
    $report .= "\nNOTE: For detailed attendance calendar, use individual report generation.\n";
    
    return $report;
}

/**
 * Recursively delete a directory
 */
function deleteDirectory($dir) {
    if (!is_dir($dir)) {
        return;
    }
    
    $files = array_diff(scandir($dir), ['.', '..']);
    foreach ($files as $file) {
        $path = $dir . '/' . $file;
        is_dir($path) ? deleteDirectory($path) : unlink($path);
    }
    
    rmdir($dir);
}

// Handle POST request
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    header('Content-Type: application/json');
    
    // Get parameters
    $learnerIds = isset($_POST['learner_ids']) ? json_decode($_POST['learner_ids'], true) : [];
    $startDate = isset($_POST['start_date']) ? $_POST['start_date'] : date('Y-m-01');
    $endDate = isset($_POST['end_date']) ? $_POST['end_date'] : date('Y-m-t');
    $projectId = isset($_POST['project_id']) ? $_POST['project_id'] : null;
    
    // Validate inputs
    if (empty($learnerIds) || !is_array($learnerIds)) {
        echo json_encode([
            'success' => false,
            'error' => 'Invalid or missing learner_ids parameter'
        ]);
        exit;
    }
    
    // Generate reports
    $results = generateBulkReportsWithDocuments($conn, $learnerIds, $startDate, $endDate, $projectId);
    
    echo json_encode($results, JSON_PRETTY_PRINT);
    exit;
}

// Handle GET request (for testing)
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['test'])) {
    header('Content-Type: text/html');
    echo "<h1>Bulk Export with Documents - Test Mode</h1>";
    echo "<p>This endpoint is ready to process bulk exports with sick notes and manual registers.</p>";
    echo "<h3>Usage:</h3>";
    echo "<pre>";
    echo "POST Parameters:\n";
    echo "  - learner_ids: JSON array of learner IDs\n";
    echo "  - start_date: Start date (Y-m-d format)\n";
    echo "  - end_date: End date (Y-m-d format)\n";
    echo "  - project_id: (optional) Project ID\n";
    echo "</pre>";
    exit;
}
