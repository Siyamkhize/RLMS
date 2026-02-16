<?php
/**
 * Background job processor for large bulk exports
 * Runs independently to avoid gateway timeouts
 */

// Disable output buffering and set unlimited execution time
while (ob_get_level()) {
    ob_end_clean();
}

set_time_limit(0); // No time limit for background processing
ini_set('memory_limit', '1024M');
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/background_job_errors.log');

// Get job ID from command line
$jobId = $argv[1] ?? null;

if (!$jobId) {
    error_log("No job ID provided to background processor");
    exit(1);
}

error_log("Starting background job: $jobId");

try {
    // Load job data
    $jobFile = __DIR__ . '/temp_reports/jobs/' . $jobId . '.json';
    if (!file_exists($jobFile)) {
        throw new Exception("Job file not found: $jobFile");
    }
    
    $jobData = json_decode(file_get_contents($jobFile), true);
    if (!$jobData) {
        throw new Exception("Invalid job data");
    }
    
    // Update job status
    $jobData['status'] = 'processing';
    $jobData['started_at'] = time();
    file_put_contents($jobFile, json_encode($jobData));
    
    // Include required files
    require_once __DIR__ . '/connection.php';
    require_once __DIR__ . '/get_learner_documents.php';
    
    // Verify database connection
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception('Database connection failed: ' . ($conn->connect_error ?? 'Unknown error'));
    }
    
    // Process in batches to manage memory
    $learnerIds = $jobData['learner_ids'];
    $startDate = $jobData['start_date'];
    $endDate = $jobData['end_date'];
    $projectId = $jobData['project_id'];
    
    $batchSize = 25; // Process 25 learners at a time
    $totalLearners = count($learnerIds);
    $processed = 0;
    $failed = 0;
    $allReports = [];
    $totalSickNotes = 0;
    $totalManualRegisters = 0;
    
    // Create main temp directory
    $mainTempDir = __DIR__ . '/temp_reports_' . $jobId;
    if (!mkdir($mainTempDir, 0777, true)) {
        throw new Exception("Failed to create main temp directory");
    }
    
    $reportsDir = $mainTempDir . '/reports';
    $sickNotesDir = $mainTempDir . '/sick_notes';
    $manualRegistersDir = $mainTempDir . '/manual_registers';
    
    mkdir($reportsDir, 0777, true);
    mkdir($sickNotesDir, 0777, true);
    mkdir($manualRegistersDir, 0777, true);
    
    // Process in batches
    for ($i = 0; $i < $totalLearners; $i += $batchSize) {
        $batch = array_slice($learnerIds, $i, $batchSize);
        error_log("Processing batch " . ($i / $batchSize + 1) . " with " . count($batch) . " learners");
        
        foreach ($batch as $learnerID) {
            try {
                // Get learner details
                $stmt = $conn->prepare("SELECT ld.Name, ld.Surname, ld.IDNumber, s.project_id, s.siteName 
                                       FROM learnerdetails ld
                                       LEFT JOIN class c ON ld.classID = c.classID
                                       LEFT JOIN sites s ON c.siteID = s.siteID
                                       WHERE ld.LearnerID = ?");
                $stmt->bind_param('i', $learnerID);
                $stmt->execute();
                $learnerResult = $stmt->get_result();
                
                if ($learnerResult->num_rows === 0) {
                    $failed++;
                    continue;
                }
                
                $learner = $learnerResult->fetch_assoc();
                $stmt->close();
                
                // Get documents
                $documents = getLearnerDocuments($conn, $learnerID, $startDate, $endDate);
                
                // Copy documents
                foreach ($documents['sick_notes'] as $sickNote) {
                    if ($sickNote['file_exists'] && !empty($sickNote['actual_path'])) {
                        $fileName = $learnerID . '_' . basename($sickNote['actual_path']);
                        if (copy($sickNote['actual_path'], $sickNotesDir . '/' . $fileName)) {
                            $totalSickNotes++;
                        }
                    }
                }
                
                foreach ($documents['manual_registers'] as $manualReg) {
                    if ($manualReg['file_exists'] && !empty($manualReg['actual_path'])) {
                        $fileName = $learnerID . '_' . basename($manualReg['actual_path']);
                        if (copy($manualReg['actual_path'], $manualRegistersDir . '/' . $fileName)) {
                            $totalManualRegisters++;
                        }
                    }
                }
                
                // Generate enhanced text report with attendance data
                $reportText = generateEnhancedTextReport($conn, $learner, $learnerID, $documents, $startDate, $endDate, $projectId);
                $reportFile = $reportsDir . '/' . $learnerID . '_report.txt';
                file_put_contents($reportFile, $reportText);
                
                $allReports[] = [
                    'learner_id' => $learnerID,
                    'name' => $learner['Name'] . ' ' . $learner['Surname'],
                    'id_number' => $learner['IDNumber'],
                    'site' => $learner['siteName'] ?? 'N/A',
                    'sick_notes_count' => count($documents['sick_notes']),
                    'manual_registers_count' => count($documents['manual_registers'])
                ];
                
                $processed++;
                
            } catch (Exception $e) {
                $failed++;
                error_log("Error processing learner $learnerID: " . $e->getMessage());
            }
        }
        
        // Update progress
        $progress = round(($processed + $failed) / $totalLearners * 100);
        $jobData['progress'] = $progress;
        $jobData['processed'] = $processed;
        $jobData['failed'] = $failed;
        file_put_contents($jobFile, json_encode($jobData));
        
        // Clear memory
        if (function_exists('gc_collect_cycles')) {
            gc_collect_cycles();
        }
    }
    
    // Create ZIP file
    $zipFileName = 'bulk_reports_' . date('Ymd_His') . '.zip';
    $zipPath = __DIR__ . '/temp_reports/' . $zipFileName;
    
    if (!is_dir(__DIR__ . '/temp_reports')) {
        mkdir(__DIR__ . '/temp_reports', 0777, true);
    }
    
    $zip = new ZipArchive();
    if ($zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) === TRUE) {
        
        // Add all files
        $files = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($mainTempDir),
            RecursiveIteratorIterator::LEAVES_ONLY
        );
        
        foreach ($files as $file) {
            if (!$file->isDir()) {
                $filePath = $file->getRealPath();
                $relativePath = substr($filePath, strlen($mainTempDir) + 1);
                $zip->addFile($filePath, $relativePath);
            }
        }
        
        // Add comprehensive summary
        $summary = "BULK EXPORT SUMMARY\n";
        $summary .= "===================\n\n";
        $summary .= "Export Date: " . date('Y-m-d H:i:s') . "\n";
        $summary .= "Date Range: $startDate to $endDate\n\n";
        $summary .= "STATISTICS:\n";
        $summary .= "- Total Learners: $totalLearners\n";
        $summary .= "- Successfully Processed: $processed\n";
        $summary .= "- Failed: $failed\n";
        $summary .= "- Success Rate: " . round(($processed / $totalLearners) * 100, 1) . "%\n\n";
        $summary .= "DOCUMENTS:\n";
        $summary .= "- Sick Notes Included: $totalSickNotes\n";
        $summary .= "- Manual Registers Included: $totalManualRegisters\n\n";
        $summary .= "FOLDER STRUCTURE:\n";
        $summary .= "- reports/ : Individual learner reports\n";
        $summary .= "- sick_notes/ : Sick note documents\n";
        $summary .= "- manual_registers/ : Manual register documents\n\n";
        $summary .= "Generated by: Background Processing System\n";
        $summary .= "Job ID: $jobId\n";
        
        $zip->addFromString('SUMMARY.txt', $summary);
        $zip->close();
        
        // Update job completion
        $jobData['status'] = 'completed';
        $jobData['completed_at'] = time();
        $jobData['zip_file'] = $zipFileName;
        $jobData['results'] = [
            'success' => true,
            'total_learners' => $totalLearners,
            'processed' => $processed,
            'failed' => $failed,
            'reports' => $allReports,
            'documents_included' => [
                'sick_notes' => $totalSickNotes,
                'manual_registers' => $totalManualRegisters
            ],
            'zip_file' => $zipFileName
        ];
        
        file_put_contents($jobFile, json_encode($jobData));
        
        error_log("Background job completed successfully: $jobId");
        
    } else {
        throw new Exception("Failed to create ZIP file");
    }
    
    // Clean up temp directory
    deleteDirectory($mainTempDir);
    
} catch (Exception $e) {
    error_log("Background job failed: $jobId - " . $e->getMessage());
    
    // Update job with error
    if (isset($jobFile) && file_exists($jobFile)) {
        $jobData = json_decode(file_get_contents($jobFile), true) ?: [];
        $jobData['status'] = 'failed';
        $jobData['error'] = $e->getMessage();
        $jobData['failed_at'] = time();
        file_put_contents($jobFile, json_encode($jobData));
    }
}

/**
 * Generate enhanced text report with attendance data
 */
function generateEnhancedTextReport($conn, $learner, $learnerID, $documents, $startDate, $endDate, $projectId) {
    $report = "LEARNER ATTENDANCE & DOCUMENT REPORT\n";
    $report .= "====================================\n\n";
    $report .= "Learner ID: " . $learnerID . "\n";
    $report .= "Name: " . $learner['Name'] . " " . $learner['Surname'] . "\n";
    $report .= "ID Number: " . $learner['IDNumber'] . "\n";
    $report .= "Site: " . ($learner['siteName'] ?? 'N/A') . "\n";
    $report .= "Report Period: " . date('d M Y', strtotime($startDate)) . " to " . date('d M Y', strtotime($endDate)) . "\n\n";
    
    // Get attendance summary
    try {
        $stmt = $conn->prepare("SELECT 
                                COUNT(DISTINCT DATE(clock_date)) as days_present,
                                MIN(clock_date) as first_attendance,
                                MAX(clock_date) as last_attendance
                               FROM learner_clocking 
                               WHERE LearnerID = ? AND clock_date BETWEEN ? AND ?");
        $stmt->bind_param('iss', $learnerID, $startDate, $endDate);
        $stmt->execute();
        $attendanceResult = $stmt->get_result();
        $attendance = $attendanceResult->fetch_assoc();
        $stmt->close();
        
        $report .= "ATTENDANCE SUMMARY:\n";
        $report .= "- Days Present: " . ($attendance['days_present'] ?? 0) . "\n";
        $report .= "- First Attendance: " . ($attendance['first_attendance'] ? date('d M Y', strtotime($attendance['first_attendance'])) : 'None') . "\n";
        $report .= "- Last Attendance: " . ($attendance['last_attendance'] ? date('d M Y', strtotime($attendance['last_attendance'])) : 'None') . "\n\n";
        
    } catch (Exception $e) {
        $report .= "ATTENDANCE SUMMARY: Unable to retrieve data\n\n";
    }
    
    $report .= "DOCUMENTS INCLUDED:\n";
    $report .= "- Sick Notes: " . count($documents['sick_notes']) . "\n";
    $report .= "- Manual Registers: " . count($documents['manual_registers']) . "\n\n";
    
    if (!empty($documents['sick_notes'])) {
        $report .= "SICK NOTES DETAILS:\n";
        foreach ($documents['sick_notes'] as $note) {
            $report .= "- " . $note['date_submitted'] . ": " . ($note['file_exists'] ? 'Included' : 'File missing') . "\n";
        }
        $report .= "\n";
    }
    
    if (!empty($documents['manual_registers'])) {
        $report .= "MANUAL REGISTERS DETAILS:\n";
        foreach ($documents['manual_registers'] as $reg) {
            $report .= "- " . $reg['date_submitted'] . ": " . ($reg['file_exists'] ? 'Included' : 'File missing') . "\n";
        }
        $report .= "\n";
    }
    
    $report .= "Generated: " . date('Y-m-d H:i:s') . "\n";
    $report .= "Processing Method: Background Job Processing\n";
    
    return $report;
}

/**
 * Recursively delete directory
 */
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