<?php
/**
 * Bulk Download Documents (Sick Notes & Manual Attendance)
 * Downloads all sick notes and manual attendance documents for filtered learners
 */

// Include database connection
require_once 'connection.php';
require_once 'get_learner_documents.php';

// Enable error logging
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: application/json');

try {
    // Get parameters
    $learnerIds = isset($_POST['learner_ids']) ? json_decode($_POST['learner_ids'], true) : [];
    $startDate = isset($_POST['start_date']) ? $_POST['start_date'] : date('Y-m-01');
    $endDate = isset($_POST['end_date']) ? $_POST['end_date'] : date('Y-m-t');
    $siteName = isset($_POST['site_name']) ? $_POST['site_name'] : 'Site';
    
    if (empty($learnerIds)) {
        throw new Exception('No learner IDs provided');
    }
    
    error_log("Bulk document download requested for " . count($learnerIds) . " learners");
    error_log("Date range: $startDate to $endDate");
    
    // Create temp directory for documents
    $tempDir = __DIR__ . '/temp_documents_' . time();
    if (!mkdir($tempDir, 0777, true)) {
        throw new Exception('Failed to create temporary directory');
    }
    
    $totalDocuments = 0;
    $processedLearners = 0;
    $errors = [];
    
    // Process each learner
    foreach ($learnerIds as $learnerID) {
        try {
            error_log("Processing learner ID: $learnerID");
            
            // Get learner details
            $learnerQuery = "SELECT Name, Surname, IDNumber FROM learnerdetails WHERE LearnerID = ?";
            $stmt = $conn->prepare($learnerQuery);
            $stmt->bind_param('i', $learnerID);
            $stmt->execute();
            $learnerResult = $stmt->get_result();
            $learner = $learnerResult->fetch_assoc();
            $stmt->close();
            
            if (!$learner) {
                $errors[] = "Learner ID $learnerID not found";
                error_log("Learner ID $learnerID not found in database");
                continue;
            }
            
            error_log("Found learner: {$learner['Name']} {$learner['Surname']}");
            
            $learnerName = $learner['Surname'] . '_' . $learner['Name'];
            $learnerName = preg_replace('/[^A-Za-z0-9_-]/', '_', $learnerName);
            
            // Get documents for this learner
            error_log("Fetching documents for learner $learnerID from $startDate to $endDate");
            $documents = getLearnerDocuments($conn, $learnerID, $startDate, $endDate);
            
            error_log("Found " . count($documents['sick_notes']) . " sick notes and " . count($documents['manual_registers']) . " manual registers");
            
            $learnerDocCount = 0;
            
            // Create learner directory
            $learnerDir = $tempDir . '/' . $learnerName . '_' . $learner['IDNumber'];
            if (!is_dir($learnerDir)) {
                mkdir($learnerDir, 0777, true);
            }
            
            // Copy sick notes
            if (!empty($documents['sick_notes'])) {
                $sickNotesDir = $learnerDir . '/Sick_Notes';
                mkdir($sickNotesDir, 0777, true);
                
                foreach ($documents['sick_notes'] as $index => $sickNote) {
                    if ($sickNote['file_exists'] && $sickNote['actual_path']) {
                        $extension = pathinfo($sickNote['actual_path'], PATHINFO_EXTENSION);
                        $dateFrom = date('Y-m-d', strtotime($sickNote['date_from']));
                        $dateTo = date('Y-m-d', strtotime($sickNote['date_to']));
                        $newFileName = "SickNote_{$dateFrom}_to_{$dateTo}.{$extension}";
                        
                        if (copy($sickNote['actual_path'], $sickNotesDir . '/' . $newFileName)) {
                            $learnerDocCount++;
                            $totalDocuments++;
                        }
                    }
                }
            }
            
            // Copy manual registers
            if (!empty($documents['manual_registers'])) {
                $manualRegDir = $learnerDir . '/Manual_Attendance';
                mkdir($manualRegDir, 0777, true);
                
                foreach ($documents['manual_registers'] as $index => $manualReg) {
                    if ($manualReg['file_exists'] && $manualReg['actual_path']) {
                        $extension = pathinfo($manualReg['actual_path'], PATHINFO_EXTENSION);
                        $clockDate = date('Y-m-d', strtotime($manualReg['clock_date']));
                        $newFileName = "ManualAttendance_{$clockDate}.{$extension}";
                        
                        if (copy($manualReg['actual_path'], $manualRegDir . '/' . $newFileName)) {
                            $learnerDocCount++;
                            $totalDocuments++;
                        }
                    }
                }
            }
            
            // If no documents found, create a note file
            if ($learnerDocCount === 0) {
                file_put_contents(
                    $learnerDir . '/NO_DOCUMENTS_FOUND.txt',
                    "No sick notes or manual attendance documents found for this learner in the date range:\n" .
                    "From: $startDate\n" .
                    "To: $endDate\n"
                );
            }
            
            $processedLearners++;
            
        } catch (Exception $e) {
            $errors[] = "Error processing learner ID $learnerID: " . $e->getMessage();
            error_log("Error processing learner ID $learnerID: " . $e->getMessage());
        }
    }
    
    // Create ZIP file
    $zipFileName = 'Documents_' . preg_replace('/[^A-Za-z0-9_-]/', '_', $siteName) . '_' . date('Y-m-d_His') . '.zip';
    $zipPath = __DIR__ . '/temp_reports/' . $zipFileName;
    
    // Ensure temp_reports directory exists
    if (!is_dir(__DIR__ . '/temp_reports')) {
        mkdir(__DIR__ . '/temp_reports', 0777, true);
    }
    
    $zip = new ZipArchive();
    if ($zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== TRUE) {
        throw new Exception('Failed to create ZIP file');
    }
    
    // Add all files from temp directory to ZIP
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
    
    // Add summary file
    $summary = "Bulk Document Download Summary\n";
    $summary .= "================================\n\n";
    $summary .= "Site: $siteName\n";
    $summary .= "Date Range: $startDate to $endDate\n";
    $summary .= "Generated: " . date('Y-m-d H:i:s') . "\n\n";
    $summary .= "Total Learners Processed: $processedLearners\n";
    $summary .= "Total Documents: $totalDocuments\n\n";
    
    if (!empty($errors)) {
        $summary .= "Errors:\n";
        foreach ($errors as $error) {
            $summary .= "- $error\n";
        }
    }
    
    $zip->addFromString('DOWNLOAD_SUMMARY.txt', $summary);
    $zip->close();
    
    // Clean up temp directory
    $files = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($tempDir, RecursiveDirectoryIterator::SKIP_DOTS),
        RecursiveIteratorIterator::CHILD_FIRST
    );
    
    foreach ($files as $fileinfo) {
        $todo = ($fileinfo->isDir() ? 'rmdir' : 'unlink');
        $todo($fileinfo->getRealPath());
    }
    rmdir($tempDir);
    
    // Return success response
    echo json_encode([
        'success' => true,
        'message' => "Successfully processed $processedLearners learners with $totalDocuments documents",
        'download_url' => 'bulk_down_register.php?temp_file=' . urlencode($zipFileName),
        'filename' => $zipFileName,
        'stats' => [
            'learners_processed' => $processedLearners,
            'total_documents' => $totalDocuments,
            'errors' => count($errors)
        ]
    ]);
    
} catch (Exception $e) {
    error_log("Bulk document download error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}
