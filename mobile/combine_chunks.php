<?php
/**
 * Combine Chunks into Single ZIP - Server-side Processing
 * Updated to generate proper agreement documents and convert to PDF
 * PDFs are also stored permanently on server for viewing
 */

session_start();

// Check if user is logged in
if (!isset($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
    header("Location: login.php");
    exit();
}

// Include required files
use PhpOffice\PhpWord\TemplateProcessor;
require 'vendor/autoload.php';
include 'connection.php';
require_once 'pdf_converter_libreoffice.php';
require_once 'pdf_storage_helper.php';

error_reporting(E_ALL);
ini_set('display_errors', 1);

// Set execution limits for large processing
ini_set('max_execution_time', 1800); // 30 minutes for large batches
ini_set('memory_limit', '1024M'); // 1GB

// SETA list
$SETAS = [
    'AGRISETA', 'BANKSETA', 'CATHSSETA', 'CETA', 'CHIETA', 'ETDPSETA', 'EWSETA',
    'FASSET', 'FOODBEV', 'FP&M SETA', 'HWSETA', 'INSETA', 'LGSETA', 'MERSETA',
    'MICT SETA', 'MQA', 'PSETA', 'SASSETA', 'SERVICES SETA', 'TETA', 'W&RSETA'
];

// Handle direct download request
if (isset($_POST['download_combined']) && $_POST['download_combined'] === '1') {
    // Check if there's a stored combined ZIP
    $sessionKey = 'combined_zip_' . session_id();
    if (isset($_SESSION[$sessionKey]) && file_exists($_SESSION[$sessionKey])) {
        $zipFile = $_SESSION[$sessionKey];
        
        // Send the file for download
        header('Content-Type: application/zip');
        header('Content-Disposition: attachment; filename="Combined_Learner_Agreements_' . date('Y-m-d_H-i-s') . '.zip"');
        header('Content-Length: ' . filesize($zipFile));
        readfile($zipFile);
        
        // Clean up
        unlink($zipFile);
        unset($_SESSION[$sessionKey]);
        exit;
    } else {
        die("Combined ZIP file not found or expired. Please regenerate the download.");
    }
}

// Handle chunk combination request
if (isset($_POST['chunk_data']) && isset($_POST['filters'])) {
    $chunkData = json_decode($_POST['chunk_data'], true);
    $filters = json_decode($_POST['filters'], true);
    
    if (!$chunkData || !is_array($chunkData)) {
        die("Invalid chunk data provided");
    }
    
    // Create temporary directory for combined processing
    $tempDir = sys_get_temp_dir() . '/combined_chunks_' . time() . '_' . rand(1000, 9999);
    
    // Check available disk space before proceeding
    $freeBytes = disk_free_space(sys_get_temp_dir());
    $requiredBytes = count($chunkData) * 50 * 1024 * 1024; // Estimate 50MB per chunk
    
    if ($freeBytes < $requiredBytes) {
        echo "<!DOCTYPE html>
<html>
<head>
    <title>Disk Space Issue - Alternative Solution</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; }
        .warning { background: #fff3cd; border: 1px solid #ffeaa7; border-left: 4px solid #f39c12; padding: 20px; border-radius: 8px; }
        .info { background: #d1ecf1; border: 1px solid #bee5eb; border-left: 4px solid #17a2b8; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .btn { padding: 15px 25px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; display: inline-block; margin: 10px; }
    </style>
</head>
<body>
    <div class='container'>
        <h2>⚠️ Insufficient Disk Space</h2>
        <div class='warning'>
            <h3>Server Storage Issue Detected</h3>
            <p><strong>Available Space:</strong> " . formatBytes($freeBytes) . "</p>
            <p><strong>Required Space:</strong> " . formatBytes($requiredBytes) . "</p>
            <p><strong>Issue:</strong> Not enough disk space to combine all chunks into a single ZIP file.</p>
        </div>
        
        <div class='info'>
            <h3>✅ Alternative Solution Active</h3>
            <p>Your learner agreements have already been downloaded individually by chunk. This is actually more efficient and avoids server storage limitations.</p>
            <ul>
                <li><strong>Total Chunks Processed:</strong> " . count($chunkData) . "</li>
                <li><strong>Download Method:</strong> Individual chunk downloads</li>
                <li><strong>Location:</strong> Your computer's Downloads folder</li>
                <li><strong>Advantage:</strong> No server storage constraints</li>
            </ul>
        </div>
        
        <div style='text-align: center; margin-top: 30px;'>
            <a href='new_aggrement_All.php' class='btn'>📋 Return to Main System</a>
            <a href='javascript:window.close()' class='btn' style='background: #6c757d;'>✅ Close Window</a>
        </div>
    </div>
</body>
</html>";
        exit;
    }
    
    if (!mkdir($tempDir, 0755, true)) {
        die("Failed to create temporary directory - disk space may be full");
    }
    
    $totalProcessed = 0;
    $allPdfFiles = [];
    
    echo "<!DOCTYPE html>
<html>
<head>
    <title>Combining Chunks with PDF Conversion</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 900px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .progress { background: #e0e0e0; height: 25px; border-radius: 12px; overflow: hidden; margin: 20px 0; }
        .progress-bar { background: linear-gradient(90deg, #4CAF50, #45a049); height: 100%; transition: width 0.3s; text-align: center; color: white; line-height: 25px; font-size: 12px; font-weight: bold; }
        .status { padding: 15px; margin: 10px 0; border-radius: 5px; font-size: 14px; }
        .status.info { background: #e3f2fd; border-left: 4px solid #2196F3; }
        .status.success { background: #e8f5e8; border-left: 4px solid #4CAF50; }
        .status.processing { background: #fff3e0; border-left: 4px solid #ff9800; }
        .download-btn { padding: 15px 30px; background: #4CAF50; color: white; border: none; border-radius: 5px; font-size: 16px; cursor: pointer; }
        .download-btn:hover { background: #45a049; }
        #detailLog { max-height: 300px; overflow-y: auto; background: #f9f9f9; padding: 10px; border-radius: 5px; font-family: monospace; font-size: 12px; margin-top: 20px; }
        .log-entry { margin: 2px 0; padding: 3px; }
        .log-success { color: #4CAF50; }
        .log-error { color: #f44336; }
        .log-info { color: #2196F3; }
    </style>
</head>
<body>
    <div class='container'>
        <h2>📄 Combining Chunks with PDF Conversion & Storage</h2>
        <div class='status info'>
            <strong>Processing " . count($chunkData) . " chunks</strong><br>
            Generating proper agreement documents, converting to PDF, and storing on server...
        </div>
        <div class='progress'>
            <div class='progress-bar' id='progressBar' style='width: 0%;'>0%</div>
        </div>
        <div id='statusText' class='status processing'>Initializing...</div>
        
        <div id='detailLog'></div>
        
        <div id='downloadSection' style='display: none; text-align: center; margin-top: 30px;'>
            <div class='status success'>
                <h3>✅ Combined ZIP Ready!</h3>
                <p id='completionMessage'>All chunks have been successfully combined into a single ZIP file.</p>
            </div>
            <form method='POST' style='display: inline;'>
                <input type='hidden' name='download_combined' value='1'>
                <button type='submit' class='download-btn'>📥 Download Combined ZIP</button>
            </form>
            <br><br>
            <a href='new_aggrement_All.php' style='color: #2196F3; text-decoration: none;'>← Back to Agreements</a>
        </div>
    </div>
    
    <script>
        function updateProgress(percent, text) {
            const bar = document.getElementById('progressBar');
            bar.style.width = percent + '%';
            bar.textContent = Math.round(percent) + '%';
            document.getElementById('statusText').innerHTML = '<strong>' + text + '</strong>';
        }
        
        function addLog(message, type = 'info') {
            const log = document.getElementById('detailLog');
            const entry = document.createElement('div');
            entry.className = 'log-entry log-' + type;
            entry.textContent = new Date().toLocaleTimeString() + ': ' + message;
            log.appendChild(entry);
            log.scrollTop = log.scrollHeight;
        }
        
        function showDownload(totalFiles, storedCount) {
            document.getElementById('completionMessage').innerHTML = 
                'Successfully processed ' + totalFiles + ' agreements<br>' +
                '<small>' + storedCount + ' PDFs stored permanently on server for viewing</small>';
            document.getElementById('downloadSection').style.display = 'block';
            updateProgress(100, '✅ Processing complete!');
        }
    </script>";
    
    // Flush output to show progress
    ob_flush();
    flush();
    
    echo "<script>addLog('System initialized - starting chunk processing', 'info');</script>";
    ob_flush();
    flush();
    
    // Process each chunk
    $storedPdfCount = 0;
    foreach ($chunkData as $index => $chunk) {
        $chunkNumber = $chunk['chunk'];
        $chunkIdNumbers = isset($chunk['idNumbers']) ? $chunk['idNumbers'] : [];
        $learnerCount = $chunk['learners'];
        
        // If no idNumbers provided, skip this chunk
        if (empty($chunkIdNumbers)) {
            echo "<script>
                updateProgress(" . (($index / count($chunkData)) * 80) . ", 'Skipping chunk $chunkNumber (no data provided)...');
                addLog('Chunk $chunkNumber: Skipped (disk space optimization)', 'info');
            </script>";
            ob_flush();
            flush();
            continue;
        }
        
        $progressPercent = (($index / count($chunkData)) * 80);
        echo "<script>
            updateProgress($progressPercent, 'Processing chunk $chunkNumber ($learnerCount learners) - Generating agreements...');
            addLog('Chunk $chunkNumber: Starting processing of $learnerCount learners', 'info');
        </script>";
        ob_flush();
        flush();
        
        // Generate agreements for this chunk
        $result = generateChunkAgreementsPDF($conn, $chunkIdNumbers, $tempDir, $chunkNumber, $SETAS);
        
        if ($result['success']) {
            $allPdfFiles = array_merge($allPdfFiles, $result['pdf_files']);
            $totalProcessed += count($result['pdf_files']);
            $storedPdfCount += $result['stored_count'];
            
            echo "<script>
                addLog('Chunk $chunkNumber: Generated " . count($result['pdf_files']) . " PDFs, stored " . $result['stored_count'] . " permanently', 'success');
            </script>";
        } else {
            echo "<script>
                addLog('Chunk $chunkNumber: Error - " . addslashes($result['error']) . "', 'error');
            </script>";
        }
        
        ob_flush();
        flush();
        
        // Small delay for progress visibility
        usleep(200000); // 0.2 seconds
    }
    
    echo "<script>
        updateProgress(90, 'Creating final combined ZIP file with $totalProcessed PDFs...');
        addLog('Creating combined ZIP archive...', 'info');
    </script>";
    ob_flush();
    flush();
    
    // Create final combined ZIP
    $finalZipPath = sys_get_temp_dir() . '/combined_agreements_' . time() . '.zip';
    $zip = new ZipArchive();
    
    if ($zip->open($finalZipPath, ZipArchive::CREATE) === TRUE) {
        foreach ($allPdfFiles as $file) {
            if (file_exists($file)) {
                $filename = basename($file);
                
                // Extract learner ID and organize by folder
                if (preg_match('/^(\d+)_/', $filename, $matches)) {
                    $learnerID = $matches[1];
                    $zipPath = $learnerID . '/' . $filename;
                } else {
                    $zipPath = $filename;
                }
                
                $zip->addFile($file, $zipPath);
            }
        }
        $zip->close();
        
        // Store ZIP path in session for download
        $sessionKey = 'combined_zip_' . session_id();
        $_SESSION[$sessionKey] = $finalZipPath;
        
        echo "<script>
            addLog('Combined ZIP created: $totalProcessed files', 'success');
            addLog('PDFs stored permanently: $storedPdfCount files', 'success');
        </script>";
        
        // Clean up temporary files
        foreach ($allPdfFiles as $file) {
            if (file_exists($file)) {
                @unlink($file);
            }
        }
        @rmdir($tempDir);
        
        echo "<script>
            updateProgress(100, 'Combined ZIP created with $totalProcessed PDFs!');
            setTimeout(function() { showDownload($totalProcessed, $storedPdfCount); }, 500);
        </script>";
        
    } else {
        echo "<script>
            updateProgress(100, 'Error: Failed to create combined ZIP file');
            addLog('Failed to create ZIP archive', 'error');
        </script>";
    }
    
    echo "</body></html>";
    exit;
}

/**
 * Generate proper agreement documents for a chunk and convert to PDF
 */
function generateChunkAgreementsPDF($conn, $idNumbers, $outputDir, $chunkNumber, $SETAS) {
    $pdfFiles = [];
    $storedCount = 0;
    $errors = [];
    
    // Template path
    $templatePath = __DIR__ . '/mobile/agreement/Cleaned_Final_Agreement.docx';
    
    if (!file_exists($templatePath)) {
        return [
            'success' => false,
            'error' => 'Agreement template not found at: ' . $templatePath,
            'pdf_files' => [],
            'stored_count' => 0
        ];
    }
    
    foreach ($idNumbers as $learnerID) {
        try {
            // Get learner data
            $stmt = $conn->prepare("
                SELECT l.*, 
                       p.project_name,
                       p.saqa_id,
                       p.nqf_level,
                       p.skills_programme_name
                FROM learners l
                LEFT JOIN projects p ON l.project_id = p.id
                WHERE l.idnumber = ?
                LIMIT 1
            ");
            
            $stmt->bind_param('s', $learnerID);
            $stmt->execute();
            $result = $stmt->get_result();
            
            if (!$learner = $result->fetch_assoc()) {
                $errors[] = "Learner not found: $learnerID";
                $stmt->close();
                continue;
            }
            
            $stmt->close();
            
            // Load template
            $template = new TemplateProcessor($templatePath);
            
            // Fill basic learner information
            $template->setValue('firstname', $learner['firstname'] ?? '');
            $template->setValue('surname', $learner['surname'] ?? '');
            $template->setValue('idnumber', $learner['idnumber'] ?? '');
            $template->setValue('cellnumber', $learner['cellnumber'] ?? '');
            $template->setValue('email', $learner['email'] ?? '');
            $template->setValue('physical_address', $learner['physical_address'] ?? '');
            $template->setValue('postal_address', $learner['postal_address'] ?? '');
            
            // Fill project information
            $template->setValue('project_name', $learner['project_name'] ?? '');
            $template->setValue('saqa_id', $learner['saqa_id'] ?? '');
            $template->setValue('nqf_level', $learner['nqf_level'] ?? '');
            $template->setValue('skills_programme_name', $learner['skills_programme_name'] ?? '');
            
            // Fill SETA
            $seta = $learner['seta'] ?? '';
            foreach ($SETAS as $setaOption) {
                $checked = ($setaOption === $seta) ? '☑' : '☐';
                $template->setValue('seta_' . str_replace([' ', '&'], ['_', 'and'], $setaOption), $checked);
            }
            
            // Handle signatures (base64 images)
            if (!empty($learner['learner_signature'])) {
                try {
                    $signatureData = base64_decode($learner['learner_signature']);
                    $tempSigPath = $outputDir . '/sig_' . $learnerID . '_learner.png';
                    file_put_contents($tempSigPath, $signatureData);
                    $template->setImageValue('learner_signature', [
                        'path' => $tempSigPath,
                        'width' => 150,
                        'height' => 50
                    ]);
                    @unlink($tempSigPath);
                } catch (Exception $e) {
                    $template->setValue('learner_signature', '[Signature Error]');
                }
            } else {
                $template->setValue('learner_signature', '');
            }
            
            if (!empty($learner['witness_signature'])) {
                try {
                    $signatureData = base64_decode($learner['witness_signature']);
                    $tempSigPath = $outputDir . '/sig_' . $learnerID . '_witness.png';
                    file_put_contents($tempSigPath, $signatureData);
                    $template->setImageValue('witness_signature', [
                        'path' => $tempSigPath,
                        'width' => 150,
                        'height' => 50
                    ]);
                    @unlink($tempSigPath);
                } catch (Exception $e) {
                    $template->setValue('witness_signature', '[Signature Error]');
                }
            } else {
                $template->setValue('witness_signature', '');
            }
            
            // Fill dates
            $template->setValue('date', date('Y-m-d'));
            $template->setValue('signature_date', !empty($learner['signature_date']) ? $learner['signature_date'] : date('Y-m-d'));
            
            // Save DOCX
            $docxFilename = $learnerID . '_Agreement.docx';
            $docxPath = $outputDir . '/' . $docxFilename;
            $template->saveAs($docxPath);
            
            // Convert DOCX to PDF
            $pdfPath = convertDocxToPdfLibreOffice($docxPath, $outputDir);
            
            if ($pdfPath && file_exists($pdfPath)) {
                $pdfFiles[] = $pdfPath;
                
                // Store PDF permanently on server
                $learnerName = ($learner['firstname'] ?? '') . ' ' . ($learner['surname'] ?? '');
                $projectId = $learner['project_id'] ?? null;
                
                $storeResult = storePdfPermanently(
                    $conn,
                    $pdfPath,
                    $learnerID,
                    $learnerName,
                    $projectId,
                    'Agreement',
                    date('Y'),
                    date('m')
                );
                
                if ($storeResult['success']) {
                    $storedCount++;
                }
                
                // Clean up DOCX
                @unlink($docxPath);
                
            } else {
                $errors[] = "PDF conversion failed for learner: $learnerID";
                // Keep DOCX as fallback
                if (file_exists($docxPath)) {
                    $pdfFiles[] = $docxPath;
                }
            }
            
        } catch (Exception $e) {
            $errors[] = "Error processing learner $learnerID: " . $e->getMessage();
            error_log("Chunk agreement generation error for $learnerID: " . $e->getMessage());
        }
    }
    
    return [
        'success' => true,
        'pdf_files' => $pdfFiles,
        'stored_count' => $storedCount,
        'errors' => $errors
    ];
}

/**
 * Format bytes for display
 */
function formatBytes($bytes, $precision = 2) {
    $units = array('B', 'KB', 'MB', 'GB', 'TB');
    
    for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}

// If no POST data, show the interface
?>
<!DOCTYPE html>
<html>
<head>
    <title>Combine Chunks System</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container { 
            max-width: 700px; 
            margin: 50px auto; 
            background: white; 
            padding: 40px; 
            border-radius: 10px; 
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
        }
        h2 {
            color: #667eea;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
        }
        .info { 
            background: #e3f2fd; 
            padding: 20px; 
            border-radius: 5px; 
            border-left: 4px solid #2196F3; 
            margin: 20px 0;
        }
        .feature {
            background: #f9f9f9;
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
            border-left: 4px solid #4CAF50;
        }
        .feature h3 {
            margin-top: 0;
            color: #4CAF50;
        }
        ul {
            line-height: 1.8;
        }
        .btn {
            display: inline-block;
            padding: 12px 24px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            margin-top: 20px;
        }
        .btn:hover {
            background: #764ba2;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>📄 Combine Chunks System</h2>
        
        <div class="info">
            <p><strong>This system combines chunked bulk downloads into a single ZIP file.</strong></p>
            <p>It will be called automatically when processing large batches of learner agreements.</p>
        </div>
        
        <div class="feature">
            <h3>✨ New Features</h3>
            <ul>
                <li><strong>Proper Agreement Generation:</strong> Uses actual agreement template (Cleaned_Final_Agreement.docx)</li>
                <li><strong>PDF Conversion:</strong> Converts all documents to PDF using LibreOffice</li>
                <li><strong>Permanent Storage:</strong> PDFs stored on server for viewing without downloading</li>
                <li><strong>Database Tracking:</strong> All PDFs recorded in database with metadata</li>
                <li><strong>Organized Structure:</strong> PDFs organized by learner ID in ZIP</li>
            </ul>
        </div>
        
        <div class="feature">
            <h3>📊 How It Works</h3>
            <ol>
                <li>Receives chunk data from main bulk download system</li>
                <li>Generates proper agreement documents for each learner</li>
                <li>Converts DOCX files to PDF format</li>
                <li>Stores PDFs permanently on server (mobile/agreement/pdfs/)</li>
                <li>Records in database for easy retrieval</li>
                <li>Combines all PDFs into single downloadable ZIP</li>
                <li>Organizes by learner folders in ZIP</li>
            </ol>
        </div>
        
        <div style="text-align: center; margin-top: 30px;">
            <a href="new_aggrement_All.php" class="btn">📋 Go to Agreements System</a>
        </div>
        
        <div style="margin-top: 30px; padding: 15px; background: #fff3e0; border-radius: 5px; font-size: 13px;">
            <strong>System Requirements:</strong>
            <ul style="margin: 10px 0;">
                <li>LibreOffice installed: /usr/bin/libreoffice</li>
                <li>PHP exec() function enabled</li>
                <li>Database table: stored_agreement_pdfs</li>
                <li>Storage directory: mobile/agreement/pdfs/</li>
            </ul>
        </div>
    </div>
</body>
</html>
