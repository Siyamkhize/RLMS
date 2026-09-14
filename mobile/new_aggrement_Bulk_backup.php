<?php
use PhpOffice\PhpWord\TemplateProcessor;
use PhpOffice\PhpWord\IOFactory;
use PhpOffice\PhpWord\Settings;
require 'vendor/autoload.php';

// PDF Configuration
$ENABLE_PDF_CONVERSION = false; // Set to false to disable PDF conversion - DOCX ONLY
$FORCE_PDF_ONLY = false; // Set to true to only generate PDFs (no DOCX)
$FORCE_SIMPLE_PDF = true; // Set to true to use simple FPDF method (guaranteed to work)

// Set PDF renderer (only if PDF conversion is enabled)
if ($ENABLE_PDF_CONVERSION) {
    Settings::setPdfRendererName(Settings::PDF_RENDERER_DOMPDF);
    Settings::setPdfRendererPath('vendor/dompdf/dompdf');
}

ini_set('memory_limit', '512M');
set_time_limit(300);

include('connection.php');

// Check if ZIP extension is loaded
if (!extension_loaded('zip')) {
    log_message("PHP ZIP extension is not loaded.");
    sendErrorResponse("PHP ZIP extension is required but not loaded.", 500);
}

// SETA list
$SETAS = [
    'AGRISETA', 'BANKSETA', 'CATHSSETA', 'CETA', 'CHIETA', 'ETDPSETA', 'EWSETA',
    'FASSET', 'FOODBEV', 'FP&M SETA', 'HWSETA', 'INSETA', 'LGSETA', 'MERSETA',
    'MICT SETA', 'MQA', 'PSETA', 'SASSETA', 'SERVICES SETA', 'TETA', 'W&RSETA'
];

// Ensure the log directory exists
if (!is_dir('agreement/today')) {
    mkdir('agreement/today', 0755, true);
}

$log_file = 'agreement/today/bulk_log_' . date('Ymd_His') . '.log';
ini_set('log_errors', 1);
ini_set('error_log', $log_file);

// Temporary fix for testing - force LearnerID if not provided
if (empty($_GET['LearnerID']) && !empty($_SERVER['QUERY_STRING']) && strpos($_SERVER['QUERY_STRING'], 'LearnerID=') !== false) {
    parse_str($_SERVER['QUERY_STRING'], $_GET);
}

// Check if URL is too long and redirect to POST-based processing
if ($_SERVER['REQUEST_METHOD'] === 'GET' && !empty($_GET['IDNumbers'])) {
    $currentUrl = $_SERVER['REQUEST_URI'];
    if (strlen($currentUrl) > 4000) { // Conservative limit to avoid Apache limits
        // Redirect to POST-based processing
        header('Content-Type: text/html; charset=utf-8');
        $idNumbers = $_GET['IDNumbers'];
        $otherParams = array_diff_key($_GET, ['IDNumbers' => '']);
        
        echo '<!DOCTYPE html>
<html>
<head>
    <title>Processing Bulk Request...</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 500px; margin: 0 auto; }
        .loading { color: #666; }
        .spinner { border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; width: 40px; height: 40px; animation: spin 2s linear infinite; margin: 20px auto; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <div class="container">
        <h2>Processing Bulk Request</h2>
        <div class="spinner"></div>
        <p class="loading">Converting to POST request to avoid URL length limits...</p>
        <p style="font-size: 12px; color: #999;">This happens automatically for large datasets (2000+ records)</p>
    </div>
    
    <form id="redirectForm" action="../bulk-export-api.php" method="POST" style="display: none;">
        <input type="hidden" name="IDNumbers" value="' . htmlspecialchars($idNumbers) . '">';
        
        // Add other parameters as hidden fields
        foreach ($otherParams as $key => $value) {
            if (!empty($value)) {
                echo '<input type="hidden" name="' . htmlspecialchars($key) . '" value="' . htmlspecialchars($value) . '">';
            }
        }
        
        echo '</form>
    
    <script>
        // Auto-submit the form after a short delay
        setTimeout(function() {
            document.getElementById("redirectForm").submit();
        }, 1000);
    </script>
</body>
</html>';
        exit;
    }
}

// Add initial debug log
error_log("Script started - LearnerID: " . ($_GET['LearnerID'] ?? 'not provided'));
error_log("All GET parameters: " . print_r($_GET, true));
error_log("All POST parameters: " . print_r($_POST, true));
error_log("Request method: " . ($_SERVER['REQUEST_METHOD'] ?? 'CLI'));
error_log("Query string: " . ($_SERVER['QUERY_STRING'] ?? 'none'));

// Debug output removed

// Test database connection
try {
    if (!$conn) {
        throw new Exception("Database connection failed");
    }
    error_log("Database connection successful");
} catch (Exception $e) {
    error_log("Database connection error: " . $e->getMessage());
    sendErrorResponse("Database connection failed: " . $e->getMessage(), 500);
}

error_log("Script continuing after database check");

// Set response headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

function log_message($message) {
    global $log_file;
    file_put_contents($log_file, date('Y-m-d H:i:s') . " - $message\n", FILE_APPEND);
}

// Helper function to send error responses
function sendErrorResponse($message, $statusCode = 500) {
    http_response_code($statusCode);
    echo json_encode(['error' => $message]);
    exit;
}


// Signature path finder
$signature_base_paths = [
    '/home/ezxcmacd/public_html/tesing.mtltechnical.co.za/signatures/',
    '/home/ezxcmacd/public_html/tesing.mtltechnical.co.za/mobile/signatures/',
    '/home/ezxcmacd/public_html/tesing.mtltechnical.co.za/',
    '/home/ezxcmacd/public_html/tesing.mtltechnical.co.za/mobile/'
];
$default_signature_path = '/home/ezxcmacd/public_html/tesing.mtltechnical.co.za/mobile/agreement/signature_11_1728641462.png';

function find_signature_path($signature, $base_paths) {
    if (empty($signature)) return false;
    foreach ($base_paths as $path) {
        $full_path = $path . $signature;
        if (file_exists($full_path) && getimagesize($full_path)) {
            return $full_path;
        }
    }
    return false;
}

// Function to test available PDF conversion methods
function testPdfConversionMethods() {
    log_message("=== Testing PDF Conversion Methods ===");
    
    // Test LibreOffice
    $sofficeExe = 'soffice';
    $commonPaths = [
        'C:\\Program Files\\LibreOffice\\program\\soffice.exe',
        'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe',
        'C:\\LibreOffice\\program\\soffice.exe'
    ];
    
    $libreOfficeFound = false;
    foreach ($commonPaths as $path) {
        if (file_exists($path)) {
            $sofficeExe = "\"$path\"";
            $libreOfficeFound = true;
            log_message("LibreOffice found at: $path");
            break;
        }
    }
    
    if (!$libreOfficeFound) {
        exec('soffice --version 2>&1', $output, $returnCode);
        if ($returnCode === 0) {
            log_message("LibreOffice found in PATH: " . implode(' ', $output));
            $libreOfficeFound = true;
        } else {
            log_message("LibreOffice not found in PATH or common locations");
        }
    }
    
    // Test COM
    $comAvailable = class_exists('COM');
    log_message("COM extension available: " . ($comAvailable ? 'yes' : 'no'));
    
    // Test Pandoc
    exec('pandoc --version 2>&1', $pandocOutput, $pandocReturn);
    $pandocAvailable = ($pandocReturn === 0);
    log_message("Pandoc available: " . ($pandocAvailable ? 'yes' : 'no'));
    
    // Test PhpWord PDF
    $phpWordPdfAvailable = class_exists('PhpOffice\\PhpWord\\IOFactory');
    log_message("PhpWord PDF available: " . ($phpWordPdfAvailable ? 'yes' : 'no'));
    
    log_message("=== End PDF Conversion Methods Test ===");
    
    return [
        'libreoffice' => $libreOfficeFound,
        'com' => $comAvailable,
        'pandoc' => $pandocAvailable,
        'phpword' => $phpWordPdfAvailable
    ];
}

// Function to convert DOCX to PDF - Simple and guaranteed to work
function convertDocxToPdf($docxPath, $pdfPath) {
    global $FORCE_SIMPLE_PDF;
    
    try {
        log_message("Converting DOCX to PDF: $docxPath -> $pdfPath");
        
        if (!file_exists($docxPath)) {
            log_message("PDF conversion error: DOCX file not found: $docxPath");
            return false;
        }
        
        // If forced to use simple PDF, skip other methods
        if ($FORCE_SIMPLE_PDF) {
            log_message("Using forced simple PDF method");
            // Try to get learner data from global scope
            global $current_learner_data;
            return createSimplePdfFromDocx($docxPath, $pdfPath, $current_learner_data ?? null);
        }
        
        // Method 1: Try DomPDF with HTML conversion (most reliable)
        if (createPdfWithDomPdf($docxPath, $pdfPath)) {
            return true;
        }
        
        // Method 2: Try FPDF with text extraction (always works)
        global $current_learner_data;
        if (createSimplePdfFromDocx($docxPath, $pdfPath, $current_learner_data ?? null)) {
            return true;
        }
        
        log_message("All PDF conversion methods failed");
        return false;
        
    } catch (Exception $e) {
        log_message("PDF conversion error: " . $e->getMessage());
        return false;
    }
}

// Create PDF using DomPDF - converts DOCX content to HTML then PDF
function createPdfWithDomPdf($docxPath, $pdfPath) {
    try {
        log_message("Trying DomPDF conversion");
        
        // Extract text and basic structure from DOCX
        $content = extractStructuredContentFromDocx($docxPath);
        
        if (empty($content)) {
            log_message("No content extracted for DomPDF");
            return false;
        }
        
        // Create HTML from extracted content
        $html = '
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: Arial, sans-serif; font-size: 12pt; line-height: 1.4; }
                h1 { text-align: center; font-size: 18pt; margin-bottom: 20pt; }
                .field { margin-bottom: 10pt; }
                .label { font-weight: bold; }
                .signature-section { margin-top: 30pt; border-top: 1px solid #ccc; padding-top: 20pt; }
                .signature-box { display: inline-block; width: 200pt; border-bottom: 1px solid #000; margin-right: 50pt; }
            </style>
        </head>
        <body>
            <h1>LEARNER AGREEMENT</h1>
            ' . $content . '
            
            <div class="signature-section">
                <div class="field">
                    <div class="signature-box"></div>
                    <div>Learner Signature</div>
                </div>
                <br><br>
                <div class="field">
                    <div class="signature-box"></div>
                    <div>Training Provider Signature</div>
                </div>
                <br><br>
                <div class="field">
                    <div class="signature-box"></div>
                    <div>Date</div>
                </div>
            </div>
        </body>
        </html>';
        
        // Create PDF with DomPDF
        $dompdf = new \Dompdf\Dompdf([
            'enable_font_subsetting' => false,
            'pdf_backend' => 'CPDF',
        ]);
        
        $dompdf->loadHtml($html);
        $dompdf->setPaper('A4', 'portrait');
        $dompdf->render();
        
        // Save PDF
        $pdfContent = $dompdf->output();
        file_put_contents($pdfPath, $pdfContent);
        
        if (file_exists($pdfPath) && filesize($pdfPath) > 0) {
            log_message("DomPDF conversion successful: $pdfPath");
            return true;
        }
        
        return false;
        
    } catch (Exception $e) {
        log_message("DomPDF conversion error: " . $e->getMessage());
        return false;
    }
}

// Extract structured content from DOCX
function extractStructuredContentFromDocx($docxPath) {
    try {
        $zip = new ZipArchive();
        if ($zip->open($docxPath) !== TRUE) {
            return '';
        }
        
        $content = $zip->getFromName('word/document.xml');
        $zip->close();
        
        if ($content === false) {
            return '';
        }
        
        // Parse XML and extract text with some structure
        $dom = new DOMDocument();
        @$dom->loadXML($content);
        
        $xpath = new DOMXPath($dom);
        $xpath->registerNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        
        $html = '';
        
        // Get all paragraphs
        $paragraphs = $xpath->query('//w:p');
        foreach ($paragraphs as $p) {
            $text = '';
            $runs = $xpath->query('.//w:t', $p);
            foreach ($runs as $run) {
                $text .= $run->textContent;
            }
            
            $text = trim($text);
            if (!empty($text)) {
                // Check if it looks like a field (contains colon)
                if (strpos($text, ':') !== false) {
                    $html .= '<div class="field">' . htmlspecialchars($text) . '</div>';
                } else {
                    $html .= '<p>' . htmlspecialchars($text) . '</p>';
                }
            }
        }
        
        return $html;
        
    } catch (Exception $e) {
        log_message("Error extracting structured content: " . $e->getMessage());
        return extractTextFromDocx($docxPath); // Fallback to simple text
    }
}

// Fallback function using COM (Windows Word)
function convertDocxToPdfWithCOM($docxPath, $pdfPath) {
    try {
        log_message("Attempting COM Word conversion");
        
        if (!class_exists('COM')) {
            log_message("COM extension not available - need to enable COM in PHP");
            return false;
        }
        
        if (!file_exists($docxPath)) {
            log_message("COM: Source DOCX file not found: $docxPath");
            return false;
        }
        
        log_message("COM: Creating Word application");
        $word = new COM("Word.Application");
        $word->Visible = false;
        $word->DisplayAlerts = false;
        
        log_message("COM: Opening document: $docxPath");
        $doc = $word->Documents->Open(realpath($docxPath));
        
        $pdfFullPath = realpath(dirname($pdfPath)) . '\\' . basename($pdfPath);
        log_message("COM: Saving as PDF: $pdfFullPath");
        
        $doc->SaveAs2($pdfFullPath, 17); // 17 = PDF format
        $doc->Close();
        $word->Quit();
        
        // Release COM objects
        $doc = null;
        $word = null;
        
        if (file_exists($pdfPath)) {
            log_message("COM PDF conversion successful: $pdfPath");
            return true;
        } else {
            log_message("COM: PDF file was not created");
            return false;
        }
        
    } catch (Exception $e) {
        log_message("COM PDF conversion error: " . $e->getMessage());
        // Try to clean up COM objects
        try {
            if (isset($doc)) $doc->Close();
            if (isset($word)) $word->Quit();
        } catch (Exception $cleanup) {
            log_message("COM cleanup error: " . $cleanup->getMessage());
        }
        return false;
    }
}

// Fallback function using PhpWord with better PDF settings
function convertDocxToPdfWithPhpWord($docxPath, $pdfPath) {
    try {
        log_message("Using PhpWord PDF conversion with improved settings");
        
        // Load the DOCX file
        $phpWord = IOFactory::load($docxPath);
        
        // Try different PDF renderers in order of preference
        $pdfRenderers = [
            ['name' => Settings::PDF_RENDERER_TCPDF, 'path' => 'vendor/tecnickcom/tcpdf'],
            ['name' => Settings::PDF_RENDERER_MPDF, 'path' => 'vendor/mpdf/mpdf'],
            ['name' => Settings::PDF_RENDERER_DOMPDF, 'path' => 'vendor/dompdf/dompdf']
        ];
        
        $pdfGenerated = false;
        
        foreach ($pdfRenderers as $renderer) {
            try {
                log_message("Trying PDF renderer: " . $renderer['name']);
                
                // Set the PDF renderer
                Settings::setPdfRendererName($renderer['name']);
                Settings::setPdfRendererPath($renderer['path']);
                
                // Create PDF writer
                $writer = IOFactory::createWriter($phpWord, 'PDF');
                
                // Try to save
                $writer->save($pdfPath);
                
                if (file_exists($pdfPath) && filesize($pdfPath) > 0) {
                    log_message("PDF conversion successful using " . $renderer['name'] . ": $pdfPath");
                    $pdfGenerated = true;
                    break;
                }
            } catch (Exception $e) {
                log_message("PDF renderer " . $renderer['name'] . " failed: " . $e->getMessage());
                continue;
            }
        }
        
        if (!$pdfGenerated) {
            // Final fallback - create a simple PDF using FPDF
            log_message("All PhpWord PDF renderers failed, trying FPDF fallback");
            return createSimplePdfFromDocx($docxPath, $pdfPath);
        }
        
        return true;
        
    } catch (Exception $e) {
        log_message("PhpWord PDF conversion error: " . $e->getMessage());
        // Try FPDF fallback
        return createSimplePdfFromDocx($docxPath, $pdfPath);
    }
}

// Create PDF using the same data that filled the Word template
function createSimplePdfFromDocx($docxPath, $pdfPath, $learnerData = null) {
    try {
        log_message("Creating PDF with template data structure");
        
        require_once 'vendor/setasign/fpdf/fpdf.php';
        
        // Create PDF
        $pdf = new FPDF();
        $pdf->AddPage();
        $pdf->SetFont('Arial', '', 12);
        
        // Add title
        $pdf->SetFont('Arial', 'B', 18);
        $pdf->Cell(0, 15, 'LEARNER AGREEMENT', 0, 1, 'C');
        $pdf->Ln(10);
        
        // If we have learner data, use it to create structured PDF
        if ($learnerData && is_array($learnerData)) {
            createStructuredPdf($pdf, $learnerData);
        } else {
            // Fallback to extracting from DOCX
            $docxContent = extractTextFromDocx($docxPath);
            if (!empty($docxContent)) {
                createSimpleTextPdf($pdf, $docxContent);
            } else {
                log_message("No content available for PDF");
                return false;
            }
        }
        
        // Save PDF
        $pdf->Output('F', $pdfPath);
        
        if (file_exists($pdfPath)) {
            log_message("PDF created successfully: $pdfPath");
            return true;
        }
        
        return false;
        
    } catch (Exception $e) {
        log_message("PDF creation error: " . $e->getMessage());
        return false;
    }
}

// Create structured PDF using learner data (matches Word template exactly)
function createStructuredPdf($pdf, $data) {
    // Title - LEARNER AGREEMENT
    $pdf->SetFont('Arial', 'B', 18);
    $pdf->Cell(0, 12, 'LEARNER AGREEMENT', 0, 1, 'C');
    $pdf->Ln(8);
    
    // Personal details section (matches template format)
    $pdf->SetFont('Arial', 'B', 11);
    $pdf->Cell(0, 8, 'LEARNER NAME AND SURNAME:  ' . ($data['Name'] ?? 'N/A') . '    ' . ($data['Surname'] ?? 'N/A'), 0, 1);
    $pdf->Ln(3);
    
    $pdf->Cell(50, 6, 'ID NUMBER: ' . ($data['IDNumber'] ?? 'N/A'), 0, 0);
    $pdf->Cell(0, 6, 'CONTACT NUMBER: ' . ($data['PhoneNumber'] ?? 'N/A'), 0, 1);
    $pdf->Ln(3);
    
    $pdf->Cell(0, 6, 'QUALIFICATION TITLE: NATIONAL CERTIFICATE:  ' . ($data['qualification_name'] ?? 'N/A'), 0, 1);
    $pdf->Ln(3);
    
    $pdf->Cell(0, 6, 'QUALIFICATION ID: ' . ($data['qualification_id'] ?? 'N/A'), 0, 1);
    $pdf->Ln(3);
    
    $pdf->Cell(0, 6, 'LEARNING PATHWAY: ' . ($data['pathway_name'] ?? 'N/A'), 0, 1);
    $pdf->Ln(10);
    
    // Table of Contents
    $pdf->SetFont('Arial', 'B', 14);
    $pdf->Cell(0, 8, 'Table of Content', 0, 1);
    $pdf->Ln(3);
    
    $pdf->SetFont('Arial', '', 10);
    $pdf->Cell(0, 6, 'Learner Agreement', 0, 1);
    $pdf->Cell(0, 6, 'Annexure B (POPI)', 0, 1);
    $pdf->Ln(8);
    
    // Declaration section
    $pdf->SetFont('Arial', 'B', 12);
    $pdf->Cell(0, 8, 'Declaration of the parties', 0, 1);
    $pdf->Ln(3);
    
    $pdf->SetFont('Arial', '', 10);
    $pdf->Cell(0, 6, 'We understand that this Agreement is legally binding.', 0, 1);
    $pdf->Ln(3);
    
    // Programme dates
    $pdf->Cell(0, 6, 'Start Date:  ' . ($data['selected_pathway_start_date'] ?? ($data['pathway_start_date'] ?? 'TBD')), 0, 1);
    $pdf->Cell(0, 6, 'End Date:  ' . ($data['selected_pathway_end_date'] ?? ($data['pathway_end_date'] ?? 'TBD')), 0, 1);
    $pdf->Ln(5);
    
    // Rights and duties section
    $pdf->SetFont('Arial', 'B', 11);
    $pdf->Cell(0, 8, 'Rights and duties of learners and training providers', 0, 1);
    $pdf->Ln(3);
    
    // Rights of the Learner (expanded)
    $pdf->SetFont('Arial', 'B', 10);
    $pdf->Cell(0, 6, 'Rights of the Learner', 0, 1);
    $pdf->Ln(2);
    
    $pdf->SetFont('Arial', '', 9);
    $learnerRights = [
        'Receive an induction to the Programme.',
        'Be educated and trained under the Programme.',
        'Access to the required resources for the achievement of the specified outcomes.',
        'Be provided with the workplace experience activities of the Programme.',
        'Be assessed fairly and consistently according to the assessment policy and procedures.',
        'Receive feedback on assessment results.',
        'Appeal assessment decisions through the appropriate channels.',
        'Be treated with respect and dignity.',
        'Have access to learner support services.',
        'Receive recognition for prior learning where applicable.'
    ];
    
    foreach ($learnerRights as $right) {
        $pdf->Cell(5, 5, chr(149), 0, 0);
        $pdf->MultiCell(0, 5, $right);
        $pdf->Ln(1);
    }
    $pdf->Ln(5);
    
    // Qualification details
    $pdf->SetFont('Arial', 'B', 10);
    $pdf->Cell(0, 6, 'Name of the qualification: National Certificate : ' . ($data['qualification_name'] ?? 'N/A'), 0, 1);
    $pdf->Cell(0, 6, 'SAQA Qualification ID number:  ' . ($data['qualification_id'] ?? 'N/A'), 0, 1);
    $pdf->Ln(5);
    
    // Training Provider details (from template)
    $pdf->SetFont('Arial', 'B', 11);
    $pdf->Cell(0, 8, 'Training Provider details', 0, 1);
    $pdf->Ln(2);
    
    $pdf->SetFont('Arial', '', 9);
    $pdf->Cell(5, 5, chr(149), 0, 0);
    $pdf->Cell(0, 5, 'Legal name of Training Provider: ' . ($data['sdp_name'] ?? 'N/A'), 0, 1);
    $pdf->Ln(2);
    
    $pdf->Cell(5, 5, chr(149), 0, 0);
    $pdf->Cell(0, 5, 'Business address: 6th Floor, MTL House Pinetown 3610', 0, 1);
    $pdf->Ln(2);
    
    $pdf->Cell(5, 5, chr(149), 0, 0);
    $pdf->Cell(0, 5, 'Postal address (if different from 11.8): P O Box 2061 Pinetown 3600', 0, 1);
    $pdf->Ln(2);
    
    $pdf->Cell(5, 5, chr(149), 0, 0);
    $pdf->Cell(0, 5, 'Name of contact person: Nompumelelo Mzimela', 0, 1);
    $pdf->Ln(2);
    
    $pdf->Cell(5, 5, chr(149), 0, 0);
    $pdf->Cell(0, 5, 'Telephone number: 0871887960', 0, 1);
    $pdf->Ln(2);
    
    $pdf->Cell(5, 5, chr(149), 0, 0);
    $pdf->Cell(0, 5, 'Fax number: 086 656 2578', 0, 1);
    $pdf->Ln(2);
    
    $pdf->Cell(5, 5, chr(149), 0, 0);
    $pdf->Cell(0, 5, 'E-mail address:', 0, 1);
    $pdf->Ln(8);
    
    // Add new page for additional content
    $pdf->AddPage();
    
    // Duties of the Learner
    $pdf->SetFont('Arial', 'B', 11);
    $pdf->Cell(0, 8, 'Duties of the Learner', 0, 1);
    $pdf->Ln(3);
    
    $pdf->SetFont('Arial', '', 9);
    $learnerDuties = [
        'Attend all scheduled learning sessions and activities.',
        'Complete all required assessments and assignments.',
        'Participate actively in the learning process.',
        'Comply with the workplace health and safety requirements.',
        'Maintain confidentiality of workplace information.',
        'Report any problems or concerns to the training provider.',
        'Complete the programme within the specified timeframe.',
        'Provide feedback on the quality of training received.',
        'Notify the training provider of any changes in personal circumstances.',
        'Comply with the code of conduct and disciplinary procedures.'
    ];
    
    foreach ($learnerDuties as $duty) {
        $pdf->Cell(5, 5, chr(149), 0, 0);
        $pdf->MultiCell(0, 5, $duty);
        $pdf->Ln(1);
    }
    $pdf->Ln(5);
    
    // Duties of the Training Provider
    $pdf->SetFont('Arial', 'B', 11);
    $pdf->Cell(0, 8, 'Duties of the Training Provider', 0, 1);
    $pdf->Ln(3);
    
    $pdf->SetFont('Arial', '', 9);
    $providerDuties = [
        'Provide quality education and training as per the qualification requirements.',
        'Ensure all learning materials and resources are available.',
        'Conduct fair and valid assessments.',
        'Provide timely feedback on learner progress.',
        'Maintain accurate records of learner achievements.',
        'Ensure compliance with health and safety regulations.',
        'Provide learner support services as required.',
        'Issue certificates upon successful completion.',
        'Maintain confidentiality of learner information.',
        'Comply with all regulatory and accreditation requirements.'
    ];
    
    foreach ($providerDuties as $duty) {
        $pdf->Cell(5, 5, chr(149), 0, 0);
        $pdf->MultiCell(0, 5, $duty);
        $pdf->Ln(1);
    }
    $pdf->Ln(8);
    
    // Assessment Information
    $pdf->SetFont('Arial', 'B', 11);
    $pdf->Cell(0, 8, 'Assessment and Certification', 0, 1);
    $pdf->Ln(3);
    
    $pdf->SetFont('Arial', '', 9);
    $pdf->MultiCell(0, 5, 'Assessment will be conducted in accordance with the assessment policy and procedures of the training provider and the requirements of the qualification. Learners will be assessed through a combination of formative and summative assessments including practical demonstrations, written tests, and workplace observations.');
    $pdf->Ln(3);
    
    $pdf->MultiCell(0, 5, 'Upon successful completion of all assessment requirements, learners will receive a Statement of Results and may apply for certification through the relevant professional body or SAQA.');
    $pdf->Ln(8);
    
    // Workplace Learning
    $pdf->SetFont('Arial', 'B', 11);
    $pdf->Cell(0, 8, 'Workplace Learning Component', 0, 1);
    $pdf->Ln(3);
    
    $pdf->SetFont('Arial', '', 9);
    $pdf->MultiCell(0, 5, 'This qualification includes a workplace learning component where learners will gain practical experience in a real work environment. The workplace learning will be supervised and assessed to ensure competency development.');
    $pdf->Ln(3);
    
    $pdf->MultiCell(0, 5, 'Learners are required to complete a minimum number of hours of workplace learning as specified in the qualification requirements. A workplace mentor will be assigned to guide and support the learner during this period.');
    $pdf->Ln(8);
    
    // Agreement Terms
    $pdf->SetFont('Arial', 'B', 11);
    $pdf->Cell(0, 8, 'Agreement Terms and Conditions', 0, 1);
    $pdf->Ln(3);
    
    $pdf->SetFont('Arial', '', 9);
    $agreementTerms = [
        'This agreement is valid for the duration of the learning programme.',
        'Any changes to this agreement must be made in writing and signed by both parties.',
        'Either party may terminate this agreement with written notice.',
        'The training provider reserves the right to suspend or exclude learners for misconduct.',
        'Learners who do not meet attendance requirements may be withdrawn from the programme.',
        'All disputes will be resolved through the appropriate grievance procedures.',
        'This agreement is governed by South African law.',
        'Both parties acknowledge that they have read and understood this agreement.'
    ];
    
    foreach ($agreementTerms as $term) {
        $pdf->Cell(5, 5, chr(149), 0, 0);
        $pdf->MultiCell(0, 5, $term);
        $pdf->Ln(1);
    }
    $pdf->Ln(8);
    
    // SIGNATURES section (exactly like template)
    $pdf->SetFont('Arial', 'B', 12);
    $pdf->Cell(0, 8, 'SIGNATURES', 0, 1);
    $pdf->Ln(8);
    
    $pdf->SetFont('Arial', '', 10);
    
    // Learner signature line (matches template layout)
    $pdf->Cell(90, 8, '', 'B', 0); // Signature line
    $pdf->Cell(20, 8, '', 0, 0);
    $pdf->Cell(70, 8, date('d F Y'), 'B', 1, 'C'); // Date
    $pdf->Cell(90, 4, 'Learner (Signature)', 0, 0);
    $pdf->Cell(20, 4, '', 0, 0);
    $pdf->Cell(70, 4, 'Date', 0, 1, 'C');
    $pdf->Ln(10);
    
    // Training Provider signature line
    $pdf->Cell(90, 8, '', 'B', 0); // Signature line
    $pdf->Cell(20, 8, '', 0, 0);
    $pdf->Cell(70, 8, date('d F Y'), 'B', 1, 'C'); // Date
    $pdf->Cell(90, 4, 'Training Provider (Signature)', 0, 0);
    $pdf->Cell(20, 4, '', 0, 0);
    $pdf->Cell(70, 4, 'Date', 0, 1, 'C');
    $pdf->Ln(10);
    
    // Witness signature section
    $pdf->SetFont('Arial', 'B', 11);
    $pdf->Cell(0, 8, 'Witnesses', 0, 1);
    $pdf->Ln(5);
    
    $pdf->SetFont('Arial', '', 10);
    // Witness signature line
    $pdf->Cell(90, 8, '', 'B', 0); // Signature line
    $pdf->Cell(20, 8, '', 0, 0);
    $pdf->Cell(70, 8, date('d F Y'), 'B', 1, 'C'); // Date
    $pdf->Cell(90, 4, 'Witness Signature', 0, 0);
    $pdf->Cell(20, 4, '', 0, 0);
    $pdf->Cell(70, 4, 'Date', 0, 1, 'C');
    $pdf->Ln(5);
    
    // Agreement number
    $pdf->SetFont('Arial', 'B', 10);
    $pdf->Cell(0, 6, 'Agreement No: ' . ($data['LearnerID'] ?? 'N/A') . '-' . date('Y'), 0, 1);
    $pdf->Ln(10);
    
    // Add new page for ANNEXURE B (POPI)
    $pdf->AddPage();
    
    // ANNEXURE B
    $pdf->SetFont('Arial', 'B', 14);
    $pdf->Cell(0, 10, 'ANNEXURE B', 0, 1, 'C');
    $pdf->Ln(5);
    
    $pdf->SetFont('Arial', 'B', 16);
    $pdf->Cell(0, 10, 'POPI', 0, 1, 'C');
    $pdf->Ln(8);
    
    $pdf->SetFont('Arial', 'B', 12);
    $pdf->Cell(0, 8, 'PROTECTION OF INFORMATION ACT, 4 OF 2013 (POPI)', 0, 1, 'C');
    $pdf->Ln(8);
    
    // POPI declaration text (from template)
    $pdf->SetFont('Arial', '', 10);
    $pdf->Cell(0, 6, 'I, ' . ($data['Name'] ?? 'N/A') . ' ' . ($data['Surname'] ?? 'N/A') . ' with ID NO ' . ($data['IDNumber'] ?? 'N/A'), 0, 1);
    $pdf->Ln(3);
    
    $popi_text = [
        'consent to sharing my personal information strictly for reporting to the relevant authorities.',
        'understand that third parties will have access to my personal information.',
        'understand that my personal information, with the required consent and/or information, will be processed and/or stored securely for the purpose for which it was collected.',
        'confirm that all my personal information supplied to the Services for the purposes of recruitment for training and operational reasons is accurate, up-to-date, is not misleading and that it is complete in all respects.',
        'will advise of any changes to my Personal Information should any of these details change.',
        'understand that my information may be used for statistical reporting and monitoring purposes.',
        'consent to the use of my information for certification and qualification verification purposes.',
        'understand my rights under the Protection of Personal Information Act.',
        'acknowledge that I may withdraw my consent at any time by providing written notice.',
        'understand that withdrawal of consent may affect my participation in the programme.'
    ];
    
    foreach ($popi_text as $text) {
        $pdf->Cell(5, 6, chr(149), 0, 0);
        $pdf->MultiCell(0, 6, $text);
        $pdf->Ln(2);
    }
    
    $pdf->Ln(10);
    
    // Signature section for POPI
    $pdf->SetFont('Arial', '', 10);
    $pdf->Cell(0, 6, 'Name And Surname : ' . ($data['Name'] ?? 'N/A') . '    ' . ($data['Surname'] ?? 'N/A'), 0, 1);
    $pdf->Ln(3);
    $pdf->Cell(0, 6, 'Date :   ' . date('d F Y'), 0, 1);
    $pdf->Ln(8);
    
    $pdf->Cell(90, 8, '', 'B', 0); // Signature line
    $pdf->Cell(0, 8, '', 0, 1);
    $pdf->Cell(90, 4, 'Signature', 0, 1);
}

// Create simple text-based PDF (fallback)
function createSimpleTextPdf($pdf, $content) {
    $pdf->SetFont('Arial', '', 10);
    
    // Split content into lines and add to PDF
    $lines = explode("\n", $content);
    foreach ($lines as $line) {
        if (strlen(trim($line)) > 0) {
            // Handle long lines
            if (strlen($line) > 80) {
                $words = explode(' ', $line);
                $currentLine = '';
                foreach ($words as $word) {
                    if (strlen($currentLine . ' ' . $word) > 80) {
                        if (!empty($currentLine)) {
                            $pdf->Cell(0, 6, trim($currentLine), 0, 1);
                            $currentLine = $word;
                        } else {
                            $pdf->Cell(0, 6, $word, 0, 1);
                        }
                    } else {
                        $currentLine .= ' ' . $word;
                    }
                }
                if (!empty($currentLine)) {
                    $pdf->Cell(0, 6, trim($currentLine), 0, 1);
                }
            } else {
                $pdf->Cell(0, 6, $line, 0, 1);
            }
        } else {
            $pdf->Ln(3);
        }
    }
}

// Extract text content from DOCX file
function extractTextFromDocx($docxPath) {
    try {
        if (!file_exists($docxPath)) {
            return '';
        }
        
        $zip = new ZipArchive();
        if ($zip->open($docxPath) === TRUE) {
            $content = $zip->getFromName('word/document.xml');
            $zip->close();
            
            if ($content !== false) {
                // Remove XML tags and get text content
                $content = preg_replace('/<[^>]+>/', ' ', $content);
                $content = html_entity_decode($content);
                $content = preg_replace('/\s+/', ' ', $content);
                return trim($content);
            }
        }
        
        return '';
    } catch (Exception $e) {
        log_message("Error extracting text from DOCX: " . $e->getMessage());
        return '';
    }
}

// Function to validate DOCX file
function isValidDocx($file_path) {
    if (!file_exists($file_path)) {
        return false;
    }
    $zip = new ZipArchive();
    if ($zip->open($file_path) !== true) {
        return false;
    }
    $is_valid = $zip->locateName('word/document.xml') !== false;
    $zip->close();
    return $is_valid;
}

// Function to scan and list available templates
function scanAvailableTemplates($specific_path = null) {
    $template_base_paths = [
        'mobile/agreement/templates/',
        'agreement/templates/',
        'templates/',
        'forms/',
        '../templates/',
        './'
    ];
    
    $available_templates = [];
    $paths_to_scan = $specific_path ? [$specific_path] : $template_base_paths;
    
    foreach ($paths_to_scan as $path) {
        if (is_dir($path)) {
            $files = glob($path . "*.{docx,doc}", GLOB_BRACE);
            foreach ($files as $file) {
                if (isValidDocx($file)) {
                    $filename = basename($file);
                    $template_name = pathinfo($filename, PATHINFO_FILENAME);
                    $available_templates[$template_name] = $file;
                    log_message("Found valid template: $template_name at $file");
                } else {
                    log_message("Invalid DOCX file: $file");
                }
            }
        } else {
            log_message("Directory not found: $path");
        }
    }
    
    if (empty($available_templates) && $specific_path) {
        log_message("No valid templates found in specific path: $specific_path");
    }
    
    return $available_templates;
}

// Function to get SETA forms
function getSETAForms($seta_name) {
    $seta_form_mappings = [
        'AGRISETA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement'],
        'BANKSETA' => ['Construction_Application', 'Learner_Agreement'],
        'CATHSSETA' => ['Safety_Training_Form', 'Learner_Agreement'],
        'CETA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement', 'NEW_SKILLS_PROGRAMME_APPLICATION_FORM'],
        'CHIETA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement'],
        'ETDPSETA' => ['Construction_Application', 'Learner_Agreement'],
        'EWSETA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement'],
        'FASSET' => ['Construction_Application', 'Learner_Agreement'],
        'FOODBEV' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement'],
        'FP&M SETA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement'],
        'HWSETA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement'],
        'INSETA' => ['Construction_Application', 'Learner_Agreement'],
        'LGSETA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement'],
        'MERSETA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement'],
        'MICT SETA' => ['Construction_Application', 'Learner_Agreement'],
        'MQA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement'],
        'PSETA' => ['Construction_Application', 'Learner_Agreement'],
        'SASSETA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement'],
        'SERVICES SETA' => ['Construction_Application', 'Learner_Agreement'],
        'TETA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement'],
        'W&RSETA' => ['Construction_Application', 'Safety_Training_Form', 'Learner_Agreement']
    ];
    return isset($seta_form_mappings[$seta_name]) ? $seta_form_mappings[$seta_name] : ['Learner_Agreement'];
}

// Function to get first clock_in date for a learner
function getFirstClockInDate($conn, $learner_id) {
    $first_clock_in = 'N/A';
    $stmt = $conn->prepare("SELECT MIN(clock_in) as first_clock_in FROM attendance WHERE LearnerID = ? AND clock_in IS NOT NULL");
    if ($stmt) {
        $stmt->bind_param("i", $learner_id);
        if ($stmt->execute()) {
            $result = $stmt->get_result();
            if ($row = $result->fetch_assoc()) {
                $first_clock_in = $row['first_clock_in'] ?? 'N/A';
            }
        }
        $stmt->close();
    }
    return $first_clock_in;
}

// Function to get pathway dates
function getPathwayDates($conn, $project_id) {
    $pathway_start_dates = [];
    $pathway_end_dates = [];
    
    $stmt = $conn->prepare("SELECT pathway_start_dates, pathway_end_dates FROM project WHERE project_id = ?");
    if ($stmt) {
        $stmt->bind_param("i", $project_id);
        $result = $stmt->execute() ? $stmt->get_result() : null;
        if ($result && $row = $result->fetch_assoc()) {
            $pathway_start_dates_str = $row['pathway_start_dates'] ?? '';
            $pathway_end_dates_str = $row['pathway_end_dates'] ?? '';
            $pathway_start_dates = !empty($pathway_start_dates_str) ? array_filter(array_map('trim', explode(',', $pathway_start_dates_str))) : [];
            $pathway_end_dates = !empty($pathway_end_dates_str) ? array_filter(array_map('trim', explode(',', $pathway_end_dates_str))) : [];
        }
        $stmt->close();
    } else {
        log_message("Error preparing pathway dates query for project_id=$project_id: " . $conn->error);
    }
    
    return [
        'start_dates' => $pathway_start_dates,
        'end_dates' => $pathway_end_dates
    ];
}

// Function to get unit standards
function getUnitStandards($conn, $qualification_id) {
    $unit_standards = [];
    $stmt = $conn->prepare("
        SELECT unitstandard_id, unit_standard_name, credits
        FROM unitstandard
        WHERE qualification_id = ?
        ORDER BY unitstandard_id
        LIMIT 10
    ");
    if ($stmt) {
        $stmt->bind_param("s", $qualification_id);
        $result = $stmt->execute() ? $stmt->get_result() : null;
        if ($result) {
            while ($row = $result->fetch_assoc()) {
                $unit_standards[] = [
                    'id' => $row['unitstandard_id'],
                    'title' => $row['unit_standard_name'],
                    'credits' => $row['credits'] ?? 'N/A',
                    's_type' => 'N/A' // Will be updated with qualification type from JSON
                ];
            }
        }
        $stmt->close();
    } else {
        log_message("Error preparing unit standards query for qualification_id=$qualification_id: " . $conn->error);
    }
    return $unit_standards;
}

// Function to generate forms
function generateForms($conn, $forms_list, $learner_data, $output_dir, $pathway_dates = []) {
    global $signature_base_paths, $default_signature_path;
    $generated_forms = [];
    $template_base_paths = [
        'mobile/agreement/templates/',
        'agreement/templates/',
        'templates/',
        'forms/',
        '../templates/',
        './'
    ];
    
    foreach ($forms_list as $form_name) {
        try {
            $form_template_path = null;
            $possible_extensions = ['.docx', '.doc'];
            
            foreach ($template_base_paths as $base_path) {
                foreach ($possible_extensions as $ext) {
                    $test_path = $base_path . $form_name . $ext;
                    if (file_exists($test_path)) {
                        $form_template_path = $test_path;
                        break 2;
                    }
                }
            }
            
            if ($form_template_path && file_exists($form_template_path)) {
                if (!isValidDocx($form_template_path)) {
                    log_message("Template is not a valid DOCX file: $form_template_path");
                    continue;
                }
                log_message("Using template: $form_template_path");
                $template = new TemplateProcessor($form_template_path);
                
                // Select the correct pathway from p.project_pathway based on site.project_pathway
                $pathway_data = isset($learner_data['project_pathway']) ? json_decode($learner_data['project_pathway'], true) : [];
                $site_pathway_name = $learner_data['pathway_name'] ?? 'Short Skills Programme';
                $selected_pathway = null;
                
                if (is_array($pathway_data) && $site_pathway_name !== null) {
                    foreach ($pathway_data as $pathway) {
                        if (isset($pathway['name']) && trim(strtolower($pathway['name'])) === trim(strtolower($site_pathway_name))) {
                            $selected_pathway = $pathway;
                            break;
                        }
                    }
                }
                
                // Fallback to first pathway or default values
                if (!$selected_pathway && !empty($pathway_data)) {
                    $selected_pathway = $pathway_data[0];
                    log_message("No matching pathway found for pathway_name=$site_pathway_name, using first pathway");
                }
                
                // Extract fields from selected pathway or use defaults
                $pathway_name = $selected_pathway['name'] ?? 'Short Skills Programme';
                $qualification_name = $selected_pathway['qual_types'][0]['qualification']['name'] ?? '91782 - Plumber';
                $employment_status = $selected_pathway['qual_types'][0]['qualification']['employment_status'] ?? 'Unemployed 18.2';
                
                // Override learner_data with JSON-derived values
                $learner_data['qualification_name'] = $qualification_name;
                $learner_data['employment_status'] = $employment_status;
                
                // First, try to extract unit standards from JSON project_pathway
                $json_unit_standards = [];
                $pathway_data = null;
                $qual_type = 'N/A'; // Default qualification type
                
                if (isset($learner_data['project_pathway']) && !empty($learner_data['project_pathway'])) {
                    $pathway_data = json_decode($learner_data['project_pathway'], true);
                    log_message("Form - Pathway data: " . json_encode($pathway_data));
                    
                    // Extract qual_type from the pathway data
                    if (isset($pathway_data[0]['qual_types'][0]['qual_type'])) {
                        $qual_type = $pathway_data[0]['qual_types'][0]['qual_type'];
                        log_message("Form - Extracted qual_type from JSON: " . $qual_type);
                    } else {
                        log_message("Form - No qual_type found in JSON data");
                    }
                    
                    if (is_array($pathway_data) && isset($pathway_data[0]['qual_types'])) {
                        foreach ($pathway_data[0]['qual_types'] as $qual_type_entry) {
                            if (isset($qual_type_entry['qualification']['unitStandards'])) {
                                $json_unit_standards = array_merge($json_unit_standards, $qual_type_entry['qualification']['unitStandards']);
                                log_message("Form - Found " . count($qual_type_entry['qualification']['unitStandards']) . " unit standards in JSON");
                            } else {
                                log_message("Form - No unitStandards found in qualification");
                            }
                        }
                    } else {
                        log_message("Form - No qual_types found in pathway data");
                    }
                } else {
                    log_message("Form - No project_pathway data found");
                }
                
                // Use JSON unit standards if available, otherwise use database unit standards
                if (!empty($json_unit_standards)) {
                    log_message("Form - Found " . count($json_unit_standards) . " unit standards in JSON data with qualification type: " . $qual_type);
                    
                    // Get unit standard IDs from JSON data
                    $json_unit_ids = array_column($json_unit_standards, 'id');
                    $json_unit_ids = array_filter($json_unit_ids, function($id) { return !empty($id) && $id !== 'N/A'; });
                    
                    // Fetch credits from database for JSON unit standards
                    $db_credits = [];
                    if (!empty($json_unit_ids)) {
                        $placeholders = str_repeat('?,', count($json_unit_ids) - 1) . '?';
                        $stmt = $conn->prepare("SELECT unitstandard_id, credits FROM unitstandard WHERE unitstandard_id IN ($placeholders)");
                        if ($stmt) {
                            $stmt->bind_param(str_repeat('s', count($json_unit_ids)), ...$json_unit_ids);
                            if ($stmt->execute()) {
                                $result = $stmt->get_result();
                                while ($row = $result->fetch_assoc()) {
                                    $db_credits[$row['unitstandard_id']] = $row['credits'];
                                }
                            }
                            $stmt->close();
                        }
                    }
                    
                    $unit_standards = [];
                    foreach ($json_unit_standards as $index => $us) {
                        $unit_id = $us['id'] ?? 'N/A';
                        $credits = $us['credits'] ?? $us['credit'] ?? ($db_credits[$unit_id] ?? 'N/A');
                        
                        $unit_standards[] = [
                            'id' => $unit_id,
                            'title' => $us['name'] ?? 'N/A',
                            'credits' => $credits,
                            's_type' => $qual_type
                        ];
                        log_message("Form - Unit Standard " . ($index + 1) . ": " . $unit_id . " - " . ($us['name'] ?? 'N/A') . " - Credits: " . $credits . " - Type: " . $qual_type);
                    }
                } else {
                    log_message("Form - No unit standards found in JSON data, using database unit standards with qualification type: " . $qual_type);
                    // Get unit standards from database as fallback
                    $unit_standards = getUnitStandards($conn, $learner_data['qualification_id']);
                    
                    // Update unit standards with qualification type from JSON
                    foreach ($unit_standards as &$us) {
                        $us['s_type'] = $qual_type;
                    }
                }
                
                // Replace placeholders for NEW_SKILLS_PROGRAMME_APPLICATION_FORM
                if ($form_name === 'NEW_SKILLS_PROGRAMME_APPLICATION_FORM') {
                    // Process ID digits - handle "0" values properly
                    $id_number = $learner_data['IDNumber'] ?? '';
                    for ($i = 1; $i <= 13; $i++) {
                        // Get digit from database result first
                        $digit_value = $learner_data["id_digit_$i"] ?? '';
                        
                        // If empty, try to extract from the full ID number
                        if ($digit_value === '' || $digit_value === null) {
                            $digit_value = substr($id_number, $i - 1, 1);
                        }
                        
                        // If still empty, default to '0'
                        if ($digit_value === '' || $digit_value === null) {
                            $digit_value = '0';
                        }
                        
                        // Debug: Log the actual values being set
                        error_log("Setting id_digit_$i = '$digit_value' for ID: $id_number (from DB: " . ($learner_data["id_digit_$i"] ?? 'null') . ")");
                        
                        // Force PhpWord to treat "0" as a valid value
                        // PhpWord skips "0" values, so we need to work around this
                        if ($digit_value === '0') {
                            // Use a non-empty string that represents zero
                            $template->setValue("id_digit_$i", 'ZERO');
                        } else {
                            $template->setValue("id_digit_$i", $digit_value);
                        }
                    }
                    $template->setValue('Date_of_Birth', $learner_data['id_derived_dob'] ?? 'N/A');
                    $template->setValue('Gender_Male', $learner_data['gender'] === 'Male' ? 'X' : '');
                    $template->setValue('Gender_Female', $learner_data['gender'] === 'Female' ? 'X' : '');
                    $template->setValue('Citizen_Yes', $learner_data['is_south_african_citizen'] === 'Yes' ? 'X' : '');
                    $template->setValue('Citizen_No', $learner_data['is_south_african_citizen'] === 'No' ? 'X' : '');
                    $template->setValue('Title', $learner_data['title'] ?? 'N/A');
                    $template->setValue('employment_status', $employment_status);
                    // Add unit standards using cloneRow for dynamic generation
                    if (!empty($unit_standards)) {
                        try {
                            // Clone the row for each unit standard
                            $template->cloneRow('unit_standard_id', count($unit_standards));
                            
                            // Set values for each unit standard
                            for ($i = 0; $i < count($unit_standards); $i++) {
                                $template->setValue("unit_standard_id#" . ($i + 1), $unit_standards[$i]['id'] ?? 'N/A');
                                $template->setValue("unit_standard_title#" . ($i + 1), $unit_standards[$i]['title'] ?? 'N/A');
                                $template->setValue("unit_standard_credits#" . ($i + 1), $unit_standards[$i]['credits'] ?? 'N/A');
                                $template->setValue("unit_standard_type#" . ($i + 1), $unit_standards[$i]['s_type'] ?? 'N/A');
                            }
                        } catch (Exception $e) {
                            // Fallback to simple placeholder replacement if cloneRow fails
                            for ($i = 0; $i < min(10, count($unit_standards)); $i++) {
                                $index = $i + 1;
                                $template->setValue("unit_standard_{$index}_id", $unit_standards[$i]['id'] ?? 'N/A');
                                $template->setValue("unit_standard_{$index}_title", $unit_standards[$i]['title'] ?? 'N/A');
                                $template->setValue("unit_standard_{$index}_credits", $unit_standards[$i]['credits'] ?? 'N/A');
                                $template->setValue("unit_standard_{$index}_type", $unit_standards[$i]['s_type'] ?? 'N/A');
                            }
                        }
                    } else {
                        // If no unit standards, set default values
                        try {
                            $template->setValue('unit_standard_id', 'N/A');
                            $template->setValue('unit_standard_title', 'N/A');
                            $template->setValue('unit_standard_credits', 'N/A');
                            $template->setValue('unit_standard_type', 'N/A');
                        } catch (Exception $e) {
                            // Fallback for numbered placeholders
                            for ($i = 1; $i <= 10; $i++) {
                                $template->setValue("unit_standard_{$i}_id", 'N/A');
                                $template->setValue("unit_standard_{$i}_title", 'N/A');
                                $template->setValue("unit_standard_{$i}_credits", 'N/A');
                                $template->setValue("unit_standard_{$i}_type", 'N/A');
                            }
                        }
                    }
                    // Set dynamic values for form fields from learnerdetails table
                    $race = strtolower(trim($learner_data['Race'] ?? ''));
                    $template->setValue('Race_African', $race === 'african' ? 'X' : '');
                    $template->setValue('Race_Coloured', $race === 'coloured' ? 'X' : '');
                    $template->setValue('Race_Indian', $race === 'indian' ? 'X' : '');
                    $template->setValue('Race_White', $race === 'white' ? 'X' : '');
                    
                    $disability = strtolower($learner_data['Disability'] ?? '');
                    if ($disability === 'none' || $disability === 'no' || empty($disability)) {
                        $template->setValue('Disability_No', 'X');
                        $template->setValue('Disability_Yes', '');
                        $template->setValue('Disability_Specify', 'N/A');
                    } else {
                        $template->setValue('Disability_No', '');
                        $template->setValue('Disability_Yes', 'X');
                        $template->setValue('Disability_Specify', $learner_data['Disability'] ?? 'N/A');
                    }
                    
                    $template->setValue('Postal_Address', $learner_data['full_address'] ?? 'N/A');
                    $template->setValue('Physical_Address', $learner_data['full_address'] ?? 'N/A');
                    $template->setValue('Postal_Code', $learner_data['PostalCode'] ?? 'N/A');
                    $template->setValue('Physical_Code', $learner_data['PostalCode'] ?? 'N/A');
                    $template->setValue('Municipality', $learner_data['Municipality'] ?? 'N/A');
                    $template->setValue('Home_Tel', 'N/A');
                    $template->setValue('Alternative_Contact', $learner_data['KinName'] ?? 'N/A');
                    $template->setValue('Alternative_Tel', $learner_data['KinContact'] ?? 'N/A');
                    $template->setValue('Alternative_Email', $learner_data['Email'] ?? 'N/A');
                    $template->setValue('Employer_Name', $learner_data['client_name'] ?? 'N/A');
                    $template->setValue('Employer_SDL', 'N/A');
                    $template->setValue('Employer_Address', $learner_data['client_address'] ?? 'N/A');
                    $template->setValue('Employer_Postal', $learner_data['client_address'] ?? 'N/A');
                    $template->setValue('Employer_Postal_Code', $learner_data['client_postal_code'] ?? 'N/A');
                    $template->setValue('Employer_Physical_Code', $learner_data['client_postal_code'] ?? 'N/A');
                    $template->setValue('Employer_Contact', $learner_data['client_name'] ?? 'N/A');
                    $template->setValue('Employer_Tel', $learner_data['client_phone'] ?? 'N/A');
                    $template->setValue('Employer_Cell', $learner_data['client_phone'] ?? 'N/A');
                    $template->setValue('Employer_Email', $learner_data['client_email'] ?? 'N/A');
                    // Get first clock_in date for this learner
                    $first_clock_in = getFirstClockInDate($conn, $learner_data['LearnerID']);
                    $template->setValue('Employment_Start', $first_clock_in);
                    $template->setValue('Assessor_Name', 'N/A');
                    $template->setValue('Assessor_Surname', 'N/A');
                    $template->setValue('Assessor_ID', 'N/A');
                    $template->setValue('Assessor_Registration', 'N/A');
                    $template->setValue('Assessor_End_Date', 'N/A');
                }
                
                // Common placeholders for all forms
                $template->setValue('Name', $learner_data['Name'] ?? 'N/A');
                $template->setValue('Surname', $learner_data['Surname'] ?? 'N/A');
                $template->setValue('IDNumber', $learner_data['IDNumber'] ?? 'N/A');
                $template->setValue('PhoneNumber', $learner_data['PhoneNumber'] ?? 'N/A');
                $template->setValue('qualification_name', $learner_data['qualification_name'] ?? 'N/A');
                $template->setValue('qualification_id', $learner_data['qualification_id'] ?? 'N/A');
                $template->setValue('pathway_name', $pathway_name);
                $template->setValue('sdp_name', $learner_data['sdp_name'] ?? 'N/A');
                $template->setValue('learner_initials', $learner_data['learner_initials'] ?? 'N/A');
                // Use first clock date if available, otherwise current date
                $date_to_use = $learner_data['first_clock_date'] ?? date('Y-m-d');
                $formatted_date = date('d F Y', strtotime($date_to_use));
                $template->setValue('Date', $formatted_date);
                $template->setValue('qa_body_name', $learner_data['qa_body_name'] ?? 'N/A');
                $template->setValue('accreditation_number', $learner_data['accreditation_number'] ?? 'N/A');
                $template->setValue('total_credits', $learner_data['total_credits'] ?? 'N/A');
                $template->setValue('nqf_level', $learner_data['nqf_level'] ?? 'N/A');
                
                // Add pathway dates
                if (!empty($pathway_dates['start_dates'])) {
                    $template->setValue('pathway_start_date', $pathway_dates['start_dates'][0] ?? 'TBD');
                    $template->setValue('selected_pathway_start_date', $pathway_dates['start_dates'][0] ?? 'TBD');
                    $template->setValue('all_start_dates', implode(', ', $pathway_dates['start_dates']));
                } else {
                    $template->setValue('pathway_start_date', 'TBD');
                    $template->setValue('selected_pathway_start_date', 'TBD');
                    $template->setValue('all_start_dates', 'TBD');
                }
                
                if (!empty($pathway_dates['end_dates'])) {
                    $template->setValue('pathway_end_date', $pathway_dates['end_dates'][0] ?? 'TBD');
                    $template->setValue('selected_pathway_end_date', $pathway_dates['end_dates'][0] ?? 'TBD');
                    $template->setValue('all_end_dates', implode(', ', $pathway_dates['end_dates']));
                } else {
                    $template->setValue('pathway_end_date', 'TBD');
                    $template->setValue('selected_pathway_end_date', 'TBD');
                    $template->setValue('all_end_dates', 'TBD');
                }
                
                // Calculate pathway duration in months
                $selected_pathway_duration = 'N/A';
                if (!empty($pathway_dates['start_dates']) && !empty($pathway_dates['end_dates'])) {
                    $start_date = $pathway_dates['start_dates'][0];
                    $end_date = $pathway_dates['end_dates'][0];
                    
                    if ($start_date !== 'TBD' && $end_date !== 'TBD') {
                        try {
                            $start = new DateTime($start_date);
                            $end = new DateTime($end_date);
                            $interval = $start->diff($end);
                            $months = ($interval->y * 12) + $interval->m;
                            if ($interval->d > 0) $months++; // Round up if there are remaining days
                            $selected_pathway_duration = $months;
                        } catch (Exception $e) {
                            log_message("Error calculating pathway duration: " . $e->getMessage());
                            $selected_pathway_duration = 'N/A';
                        }
                    }
                }
                $template->setValue('selected_pathway_duration', $selected_pathway_duration);
                
                // Add employer/client information
                $template->setValue('Employer_Contact', $learner_data['client_name'] ?? 'N/A');
                $template->setValue('Employer_Cell', $learner_data['client_phone'] ?? 'N/A');
                $template->setValue('Employer_Email', $learner_data['client_email'] ?? 'N/A');
                $template->setValue('Employer_Address', $learner_data['client_address'] ?? 'N/A');
                $template->setValue('Employer_Postal', $learner_data['client_address'] ?? 'N/A');
                $template->setValue('Employer_Physical_Code', $learner_data['client_postal_code'] ?? 'N/A');
                $template->setValue('Employer_Postal_Code', $learner_data['client_postal_code'] ?? 'N/A');
                
                // Add signatures
                $learner_signature_path = find_signature_path($learner_data['signaturePath'], $signature_base_paths);
                if ($learner_signature_path) {
                    $template->setImageValue('learner_signature', [
                        'src' => $learner_signature_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                } elseif (file_exists($default_signature_path)) {
                    $template->setImageValue('learner_signature', [
                        'src' => $default_signature_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("Default learner signature used: $default_signature_path");
                } else {
                    $template->setValue('learner_signature', 'N/A');
                    log_message("Default signature missing: $default_signature_path");
                }
                
                // Add SDP signature
                $sdp_signature_base_paths = [
                    '/home/ezxcmacd/public_html/tesing.mtltechnical.co.za/mobile/uploads/',
                    '/home/ezxcmacd/public_html/tesing.mtltechnical.co.za/uploads/',
                    'mobile/uploads/',
                    'uploads/',
                    './'
                ];
                log_message("Form - Looking for SDP signature_image: " . ($learner_data['signature_image'] ?? 'null'));
                $sdp_signature_path = find_signature_path($learner_data['signature_image'], $sdp_signature_base_paths);
                if ($sdp_signature_path) {
                    $template->setImageValue('sdp_signature_image', [
                        'src' => $sdp_signature_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("SDP signature added to form: $sdp_signature_path");
                } else {
                    $template->setValue('sdp_signature_image', 'N/A');
                    log_message("No SDP signature found for form, signature_image: " . ($learner_data['signature_image'] ?? 'null'));
                    // Debug: Check what files exist in the directories
                    foreach ($sdp_signature_base_paths as $base_path) {
                        $full_path = $base_path . ($learner_data['signature_image'] ?? '');
                        log_message("Form - Checked path: $full_path - exists: " . (file_exists($full_path) ? 'yes' : 'no'));
                    }
                }
                
                // Save form
                $safe_id = preg_replace('/[^a-zA-Z0-9]/', '_', $learner_data['IDNumber'] ?? 'unknown_' . $learner_data['LearnerID']);
                $form_file = $output_dir . $safe_id . "_{$form_name}.docx";
                $template->saveAs($form_file);
                
                // Post-process the document to replace "ZERO" back to "0"
                if (file_exists($form_file)) {
                    $zip = new ZipArchive();
                    if ($zip->open($form_file) === TRUE) {
                        // Get the document.xml content
                        $document_xml = $zip->getFromName('word/document.xml');
                        if ($document_xml !== false) {
                            // Replace "ZERO" with "0" in the document content
                            $document_xml = str_replace('ZERO', '0', $document_xml);
                            $zip->addFromString('word/document.xml', $document_xml);
                        }
                        $zip->close();
                        log_message("Post-processed document to replace ZERO with 0: $form_file");
                    }
                }
                
                if (file_exists($form_file)) {
                    $generated_forms[] = $form_file;
                    log_message("Form generated: $form_file");
                    
                    // Convert form to PDF (if enabled)
                    global $ENABLE_PDF_CONVERSION, $FORCE_PDF_ONLY;
                    if ($ENABLE_PDF_CONVERSION) {
                        $form_pdf_file = str_replace('.docx', '.pdf', $form_file);
                        if (convertDocxToPdf($form_file, $form_pdf_file)) {
                            $generated_forms[] = $form_pdf_file;
                            log_message("Form PDF generated: $form_pdf_file");
                            
                            // If force PDF only, remove DOCX file
                            if ($FORCE_PDF_ONLY && file_exists($form_file)) {
                                unlink($form_file);
                                // Remove DOCX from generated forms array
                                $generated_forms = array_filter($generated_forms, function($file) use ($form_file) {
                                    return $file !== $form_file;
                                });
                                log_message("Form DOCX file removed (PDF only mode): $form_file");
                            }
                        } else {
                            log_message("Failed to convert form to PDF: $form_name for LearnerID: {$learner_data['LearnerID']}");
                        }
                    } else {
                        log_message("PDF conversion disabled for forms - only generating DOCX");
                    }
                    
                } else {
                    log_message("Failed to generate form: $form_name for LearnerID: {$learner_data['LearnerID']}");
                }
            } else {
                log_message("Form template not found for: $form_name");
                foreach ($template_base_paths as $base_path) {
                    foreach ($possible_extensions as $ext) {
                        log_message("Searched: " . $base_path . $form_name . $ext);
                    }
                }
                $available_templates = scanAvailableTemplates('mobile/agreement/templates/');
                log_message("Available templates in mobile/agreement/templates/: " . implode(', ', array_keys($available_templates)));
            }
        } catch (Exception $e) {
            log_message("Error generating form $form_name: " . $e->getMessage());
        }
    }
    
    return $generated_forms;
}

// Verify main template existence
$template_path = 'agreement/Cleaned_Updated_Agreement_V4.docx';
if (!file_exists($template_path)) {
    log_message("Main template file missing: $template_path");
    sendErrorResponse("Main template file missing.", 404);
}
if (!isValidDocx($template_path)) {
    log_message("Main template is not a valid DOCX file: $template_path");
    sendErrorResponse("Main template is not a valid DOCX file.", 400);
}

// Set up output directory
$output_dir = 'agreement/today/';
if (!is_dir($output_dir)) {
    mkdir($output_dir, 0755, true);
    chmod($output_dir, 0755);
}
if (!is_writable($output_dir)) {
    log_message("Output directory is not writable: $output_dir");
    sendErrorResponse("Output directory is not writable.", 500);
}

// Check if LearnerID or IDNumbers is provided (support both GET and POST)
$LearnerID = $_GET['LearnerID'] ?? $_POST['LearnerID'] ?? null;
$IDNumbers = $_GET['IDNumbers'] ?? $_POST['IDNumbers'] ?? null;

// Handle JSON input for bulk processing
if (empty($LearnerID) && empty($IDNumbers)) {
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    if (strpos($contentType, 'application/json') !== false) {
        $json = file_get_contents('php://input');
        $jsonData = json_decode($json, true);
        if ($jsonData) {
            $LearnerID = $jsonData['LearnerID'] ?? null;
            $IDNumbers = $jsonData['IDNumbers'] ?? $jsonData['learner_ids'] ?? null;
        }
    }
}

if ($LearnerID && is_numeric($LearnerID)) {
    // Single learner processing
    $sql = "
    SELECT 
        ld.LearnerID, 
        ld.Name, 
        ld.Surname, 
        ld.IDNumber, 
        SUBSTRING(ld.IDNumber, 1, 1) AS id_digit_1,
        SUBSTRING(ld.IDNumber, 2, 1) AS id_digit_2,
        SUBSTRING(ld.IDNumber, 3, 1) AS id_digit_3,
        SUBSTRING(ld.IDNumber, 4, 1) AS id_digit_4,
        SUBSTRING(ld.IDNumber, 5, 1) AS id_digit_5,
        SUBSTRING(ld.IDNumber, 6, 1) AS id_digit_6,
        SUBSTRING(ld.IDNumber, 7, 1) AS id_digit_7,
        SUBSTRING(ld.IDNumber, 8, 1) AS id_digit_8,
        SUBSTRING(ld.IDNumber, 9, 1) AS id_digit_9,
        SUBSTRING(ld.IDNumber, 10, 1) AS id_digit_10,
        SUBSTRING(ld.IDNumber, 11, 1) AS id_digit_11,
        SUBSTRING(ld.IDNumber, 12, 1) AS id_digit_12,
        SUBSTRING(ld.IDNumber, 13, 1) AS id_digit_13,
        CASE 
            WHEN CAST(SUBSTRING(ld.IDNumber, 1, 2) AS UNSIGNED) <= 25 
            THEN CONCAT('20', SUBSTRING(ld.IDNumber, 1, 2), '/', SUBSTRING(ld.IDNumber, 3, 2), '/', SUBSTRING(ld.IDNumber, 5, 2))
            ELSE CONCAT('19', SUBSTRING(ld.IDNumber, 1, 2), '/', SUBSTRING(ld.IDNumber, 3, 2), '/', SUBSTRING(ld.IDNumber, 5, 2))
        END AS id_derived_dob,
        CASE 
            WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 0 AND 4999 THEN 'Female'
            WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 5000 AND 9999 THEN 'Male'
            ELSE 'Unknown'
        END AS gender,
        CASE 
            WHEN SUBSTRING(ld.IDNumber, 11, 1) = '0' THEN 'Yes'
            WHEN SUBSTRING(ld.IDNumber, 11, 1) = '1' THEN 'No'
            ELSE 'Unknown'
        END AS is_south_african_citizen,
        CASE 
            WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 0 AND 4999 THEN 'Ms.'
            WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 5000 AND 9999 THEN 'Mr.'
            ELSE 'Unknown'
        END AS title,
        ld.signature AS signaturePath,
        ld.learner_initials,
        ld.PhoneNumber,
        (SELECT MIN(DATE(clock_date)) FROM learner_clocking WHERE LearnerID = ld.LearnerID) AS first_clock_date, 
        p.project_pathway,
        site.project_pathway AS pathway_name,
        p.Project_name, 
        p.Project_funder,
        p.project_id,
        p.Start_date, 
        p.End_date, 
        s.sdp_name, 
        s.sdp_logo, 
        q.qualification_id as qualification_id,
        q.name as qualification_name,
        q.credits as total_credits,
        q.level as nqf_level,
        s.signature_image,
        qa.qa_body_name,
        qa.accreditation_number,
        COALESCE(cl.client_name, 'N/A') AS client_name,
        COALESCE(cl.phone, 'N/A') AS client_phone,
        COALESCE(cl.email, 'N/A') AS client_email,
        COALESCE(CONCAT(cl.client_address, ', ', cl.city), 'N/A') AS client_address,
        COALESCE(cl.postal_code, 'N/A') AS client_postal_code,
        COALESCE(ld.Race, 'N/A') AS Race,
        COALESCE(ld.Disability, 'N/A') AS Disability,
        COALESCE(CONCAT(ld.AddressLine1, ', ', ld.AddressLine2, ', ', ld.AddressLine3), 'N/A') AS full_address,
        COALESCE(ld.PostalCode, 'N/A') AS PostalCode,
        COALESCE(ld.KinName, 'N/A') AS KinName,
        COALESCE(ld.KinContact, 'N/A') AS KinContact,
        COALESCE(ld.Email, 'N/A') AS Email,
        COALESCE(site.Municipality, 'N/A') AS Municipality,
        (
            SELECT 
                CASE 
                    WHEN ld2.Name LIKE '% %' THEN 
                        CONCAT(LEFT(ld2.Name, 1), SUBSTRING(ld2.Name, LOCATE(' ', ld2.Name) + 1, 1))
                    ELSE 
                        LEFT(ld2.Name, 1)
                END
            FROM learnerdetails ld2 
            JOIN class c2 ON ld2.classID = c2.classID 
            WHERE c2.classID = c.classID 
            AND ld2.signature IS NOT NULL
            AND ld2.LearnerID != ld.LearnerID
            ORDER BY RAND()
            LIMIT 1
        ) AS witness_initials,
        (
            SELECT ld2.signature
            FROM learnerdetails ld2 
            JOIN class c2 ON ld2.classID = c2.classID 
            WHERE c2.classID = c.classID 
            AND ld2.signature IS NOT NULL
            AND ld2.LearnerID != ld.LearnerID
            ORDER BY RAND()
            LIMIT 1
        ) AS witnessSignaturePath
    FROM learnerdetails ld
    JOIN class c ON ld.classID = c.classID
    JOIN sites site ON c.siteID = site.siteID
    JOIN qualification q ON q.qualification_id = site.qualification_id
    JOIN project p ON p.project_id = site.project_id
    LEFT JOIN sdp s ON p.sdp_name = s.sdp_name
    LEFT JOIN client cl ON cl.client_name = p.client_name
    LEFT JOIN qa_details qa ON qa.project_id = p.project_id 
    LEFT JOIN learningpathway lp ON lp.pathway_id = qa.pathway_id
    AND qa.qualification_id = q.qualification_id
    AND TRIM(LOWER(lp.name)) = TRIM(LOWER(site.Project_pathway))
    WHERE ld.LearnerID = ?";

    try {
        log_message("Executing query for LearnerID: $LearnerID");
        log_message("SQL Query: $sql");
        
        // Debug: Test if the query can be prepared
        if (!$stmt = $conn->prepare($sql)) {
            log_message("SQL Prepare Error: " . $conn->error);
            sendErrorResponse("Database query preparation failed: " . $conn->error, 500);
        }

        // Debug: Check each table individually
        $debug_queries = [
            "SELECT * FROM learnerdetails WHERE LearnerID = $LearnerID",
            "SELECT * FROM class WHERE classID = (SELECT classID FROM learnerdetails WHERE LearnerID = $LearnerID)",
            "SELECT * FROM sites WHERE siteID = (SELECT siteID FROM class WHERE classID = (SELECT classID FROM learnerdetails WHERE LearnerID = $LearnerID))",
            "SELECT * FROM qualification WHERE qualification_id = (SELECT qualification_id FROM sites WHERE siteID = (SELECT siteID FROM class WHERE classID = (SELECT classID FROM learnerdetails WHERE LearnerID = $LearnerID)))",
            "SELECT * FROM project WHERE project_id = (SELECT project_id FROM sites WHERE siteID = (SELECT siteID FROM class WHERE classID = (SELECT classID FROM learnerdetails WHERE LearnerID = $LearnerID)))"
        ];

        foreach ($debug_queries as $index => $debug_sql) {
            $debug_result = $conn->query($debug_sql);
            $row_count = $debug_result ? $debug_result->num_rows : 0;
            log_message("Debug Query " . ($index + 1) . ": $debug_sql");
            log_message("Debug Query " . ($index + 1) . " returned $row_count rows");
            if ($row_count > 0) {
                $debug_data = $debug_result->fetch_assoc();
                log_message("Debug Query " . ($index + 1) . " data: " . json_encode($debug_data));
            }
        }

        if (!$stmt = $conn->prepare($sql)) {
            log_message("SQL Error: " . $conn->error . " | Query: $sql");
            sendErrorResponse("SQL Error: " . $conn->error, 500);
        }

        $stmt->bind_param('i', $LearnerID);
        if (!$stmt->execute()) {
            log_message("SQL Execution Error: " . $stmt->error . " | Query: $sql | LearnerID: $LearnerID");
            sendErrorResponse("Failed to execute database query", 500);
        }

        $result = $stmt->get_result();
        log_message("Query returned " . $result->num_rows . " rows for LearnerID: $LearnerID");
        if ($result->num_rows === 0) {
            log_message("No data found for LearnerID: $LearnerID, attempting fallback query");

            // Fallback query with LEFT JOINs
            $fallback_sql = "
            SELECT 
                ld.LearnerID, 
                ld.Name, 
                ld.Surname, 
                ld.IDNumber, 
                SUBSTRING(ld.IDNumber, 1, 1) AS id_digit_1,
                SUBSTRING(ld.IDNumber, 2, 1) AS id_digit_2,
                SUBSTRING(ld.IDNumber, 3, 1) AS id_digit_3,
                SUBSTRING(ld.IDNumber, 4, 1) AS id_digit_4,
                SUBSTRING(ld.IDNumber, 5, 1) AS id_digit_5,
                SUBSTRING(ld.IDNumber, 6, 1) AS id_digit_6,
                SUBSTRING(ld.IDNumber, 7, 1) AS id_digit_7,
                SUBSTRING(ld.IDNumber, 8, 1) AS id_digit_8,
                SUBSTRING(ld.IDNumber, 9, 1) AS id_digit_9,
                SUBSTRING(ld.IDNumber, 10, 1) AS id_digit_10,
                SUBSTRING(ld.IDNumber, 11, 1) AS id_digit_11,
                SUBSTRING(ld.IDNumber, 12, 1) AS id_digit_12,
                SUBSTRING(ld.IDNumber, 13, 1) AS id_digit_13,
                CASE 
                    WHEN CAST(SUBSTRING(ld.IDNumber, 1, 2) AS UNSIGNED) <= 25 
                    THEN CONCAT('20', SUBSTRING(ld.IDNumber, 1, 2), '/', SUBSTRING(ld.IDNumber, 3, 2), '/', SUBSTRING(ld.IDNumber, 5, 2))
                    ELSE CONCAT('19', SUBSTRING(ld.IDNumber, 1, 2), '/', SUBSTRING(ld.IDNumber, 3, 2), '/', SUBSTRING(ld.IDNumber, 5, 2))
                END AS id_derived_dob,
                CASE 
                    WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 0 AND 4999 THEN 'Female'
                    WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 5000 AND 9999 THEN 'Male'
                    ELSE 'Unknown'
                END AS gender,
                CASE 
                    WHEN SUBSTRING(ld.IDNumber, 11, 1) = '0' THEN 'Yes'
                    WHEN SUBSTRING(ld.IDNumber, 11, 1) = '1' THEN 'No'
                    ELSE 'Unknown'
                END AS is_south_african_citizen,
                CASE 
                    WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 0 AND 4999 THEN 'Ms.'
                    WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 5000 AND 9999 THEN 'Mr.'
                    ELSE 'Unknown'
                END AS title,
                ld.signature AS signaturePath,
                ld.learner_initials,
                ld.PhoneNumber, 
                p.project_pathway,
                site.project_pathway AS pathway_name,
                p.Project_name, 
                p.Project_funder,
                p.project_id,
                p.Start_date, 
                p.End_date, 
                s.sdp_name, 
                s.sdp_logo, 
                q.qualification_id as qualification_id,
                q.name as qualification_name,
                q.credits as total_credits,
                q.level as nqf_level,
                s.signature_image,
                qa.qa_body_name,
                qa.accreditation_number
            FROM learnerdetails ld
            LEFT JOIN class c ON ld.classID = c.classID
            LEFT JOIN sites site ON c.siteID = site.siteID
            LEFT JOIN qualification q ON q.qualification_id = site.qualification_id
            LEFT JOIN project p ON p.project_id = site.project_id
            LEFT JOIN sdp s ON p.sdp_name = s.sdp_name
            LEFT JOIN qa_details qa ON qa.project_id = p.project_id 
            LEFT JOIN learningpathway lp ON lp.pathway_id = qa.pathway_id
            AND qa.qualification_id = q.qualification_id
            AND TRIM(LOWER(lp.name)) = TRIM(LOWER(site.Project_pathway))
            WHERE ld.LearnerID = ?";

            log_message("Executing fallback query for LearnerID: $LearnerID");
            log_message("Fallback SQL Query: $fallback_sql");
            if (!$stmt = $conn->prepare($fallback_sql)) {
                log_message("SQL Error (fallback): " . $conn->error . " | Query: $fallback_sql");
                sendErrorResponse("SQL Error (fallback): " . $conn->error, 500);
            }

            $stmt->bind_param('i', $LearnerID);
            if (!$stmt->execute()) {
                log_message("SQL Execution Error (fallback): " . $stmt->error . " | Query: $fallback_sql | LearnerID: $LearnerID");
                sendErrorResponse("Failed to execute fallback database query", 500);
            }

            $result = $stmt->get_result();
            log_message("Fallback query returned " . $result->num_rows . " rows for LearnerID: $LearnerID");
            if ($result->num_rows === 0) {
                log_message("No data found in fallback query for LearnerID: $LearnerID");
                sendErrorResponse("No data found for LearnerID: $LearnerID", 404);
            }

            $data = $result->fetch_assoc();
            // Populate default values for missing fields
            $data['pathway_name'] = $data['pathway_name'] ?? 'Short Skills Programme';
            $data['qualification_id'] = $data['qualification_id'] ?? '91782';
            $data['qualification_name'] = $data['qualification_name'] ?? '91782 - Plumber';
            $data['total_credits'] = $data['total_credits'] ?? '120';
            $data['nqf_level'] = $data['nqf_level'] ?? 'NQF Level 4';
            $data['sdp_name'] = $data['sdp_name'] ?? 'Job Creation Programme (JCP)';
            $data['qa_body_name'] = $data['qa_body_name'] ?? 'CETA';
            $data['accreditation_number'] = $data['accreditation_number'] ?? 'ACC/12345';
            $data['project_id'] = $data['project_id'] ?? '72';
            $data['project_pathway'] = $data['project_pathway'] ?? '[{"id":"4","name":"Short Skills Programme","qual_types":[{"qual_type":"Occupational","qualification":{"id":"91782","name":"91782 - Plumber","employment_status":"Unemployed 18.2"}}]}]';
            log_message("Fallback data: " . json_encode($data));
            $learners = [$data];
        } else {
            $data = $result->fetch_assoc();
            log_message("Data fetched: " . json_encode($data));
            $learners = [$data];
        }
    } catch (Exception $e) {
        log_message("Database error: " . $e->getMessage());
        sendErrorResponse("Database error: " . $e->getMessage(), 500);
    }
} elseif ($IDNumbers) {
    // Multiple learner processing
    $idNumbersArray = array_filter(array_map('trim', explode(',', $IDNumbers)));
    if (empty($idNumbersArray)) {
        sendErrorResponse('Invalid or missing IDNumbers parameter', 400);
    }

    $placeholders = implode(',', array_fill(0, count($idNumbersArray), '?'));
    $sql = "
    SELECT 
        ld.LearnerID, 
        ld.Name, 
        ld.Surname, 
        ld.IDNumber, 
        SUBSTRING(ld.IDNumber, 1, 1) AS id_digit_1,
        SUBSTRING(ld.IDNumber, 2, 1) AS id_digit_2,
        SUBSTRING(ld.IDNumber, 3, 1) AS id_digit_3,
        SUBSTRING(ld.IDNumber, 4, 1) AS id_digit_4,
        SUBSTRING(ld.IDNumber, 5, 1) AS id_digit_5,
        SUBSTRING(ld.IDNumber, 6, 1) AS id_digit_6,
        SUBSTRING(ld.IDNumber, 7, 1) AS id_digit_7,
        SUBSTRING(ld.IDNumber, 8, 1) AS id_digit_8,
        SUBSTRING(ld.IDNumber, 9, 1) AS id_digit_9,
        SUBSTRING(ld.IDNumber, 10, 1) AS id_digit_10,
        SUBSTRING(ld.IDNumber, 11, 1) AS id_digit_11,
        SUBSTRING(ld.IDNumber, 12, 1) AS id_digit_12,
        SUBSTRING(ld.IDNumber, 13, 1) AS id_digit_13,
        CASE 
            WHEN CAST(SUBSTRING(ld.IDNumber, 1, 2) AS UNSIGNED) <= 25 
            THEN CONCAT('20', SUBSTRING(ld.IDNumber, 1, 2), '/', SUBSTRING(ld.IDNumber, 3, 2), '/', SUBSTRING(ld.IDNumber, 5, 2))
            ELSE CONCAT('19', SUBSTRING(ld.IDNumber, 1, 2), '/', SUBSTRING(ld.IDNumber, 3, 2), '/', SUBSTRING(ld.IDNumber, 5, 2))
        END AS id_derived_dob,
        CASE 
            WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 0 AND 4999 THEN 'Female'
            WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 5000 AND 9999 THEN 'Male'
            ELSE 'Unknown'
        END AS gender,
        CASE 
            WHEN SUBSTRING(ld.IDNumber, 11, 1) = '0' THEN 'Yes'
            WHEN SUBSTRING(ld.IDNumber, 11, 1) = '1' THEN 'No'
            ELSE 'Unknown'
        END AS is_south_african_citizen,
        CASE 
            WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 0 AND 4999 THEN 'Ms.'
            WHEN CAST(SUBSTRING(ld.IDNumber, 7, 4) AS UNSIGNED) BETWEEN 5000 AND 9999 THEN 'Mr.'
            ELSE 'Unknown'
        END AS title,
        ld.signature AS signaturePath,
        ld.learner_initials,
        ld.PhoneNumber,
        (SELECT MIN(DATE(clock_date)) FROM learner_clocking WHERE LearnerID = ld.LearnerID) AS first_clock_date, 
        p.project_pathway,
        site.project_pathway AS pathway_name,
        p.Project_name, 
        p.Project_funder,
        p.project_id,
        p.Start_date, 
        p.End_date, 
        s.sdp_name, 
        s.sdp_logo, 
        q.qualification_id as qualification_id,
        q.name as qualification_name,
        q.credits as total_credits,
        q.level as nqf_level,
        s.signature_image,
        qa.qa_body_name,
        qa.accreditation_number,
        COALESCE(cl.client_name, 'N/A') AS client_name,
        COALESCE(cl.phone, 'N/A') AS client_phone,
        COALESCE(cl.email, 'N/A') AS client_email,
        COALESCE(CONCAT(cl.client_address, ', ', cl.city), 'N/A') AS client_address,
        COALESCE(cl.postal_code, 'N/A') AS client_postal_code,
        COALESCE(ld.Race, 'N/A') AS Race,
        COALESCE(ld.Disability, 'N/A') AS Disability,
        COALESCE(CONCAT(ld.AddressLine1, ', ', ld.AddressLine2, ', ', ld.AddressLine3), 'N/A') AS full_address,
        COALESCE(ld.PostalCode, 'N/A') AS PostalCode,
        COALESCE(ld.KinName, 'N/A') AS KinName,
        COALESCE(ld.KinContact, 'N/A') AS KinContact,
        COALESCE(ld.Email, 'N/A') AS Email,
        COALESCE(site.Municipality, 'N/A') AS Municipality,
        (
            SELECT 
                CASE 
                    WHEN ld2.Name LIKE '% %' THEN 
                        CONCAT(LEFT(ld2.Name, 1), SUBSTRING(ld2.Name, LOCATE(' ', ld2.Name) + 1, 1))
                    ELSE 
                        LEFT(ld2.Name, 1)
                END
            FROM learnerdetails ld2 
            JOIN class c2 ON ld2.classID = c2.classID 
            WHERE c2.classID = c.classID 
            AND ld2.signature IS NOT NULL
            AND ld2.LearnerID != ld.LearnerID
            ORDER BY RAND()
            LIMIT 1
        ) AS witness_initials,
        (
            SELECT ld2.signature
            FROM learnerdetails ld2 
            JOIN class c2 ON ld2.classID = c2.classID 
            WHERE c2.classID = c.classID 
            AND ld2.signature IS NOT NULL
            AND ld2.LearnerID != ld.LearnerID
            ORDER BY RAND()
            LIMIT 1
        ) AS witnessSignaturePath
    FROM learnerdetails ld
    JOIN class c ON ld.classID = c.classID
    JOIN sites site ON c.siteID = site.siteID
    JOIN qualification q ON q.qualification_id = site.qualification_id
    JOIN project p ON p.project_id = site.project_id
    LEFT JOIN sdp s ON p.sdp_name = s.sdp_name
    LEFT JOIN client cl ON cl.client_name = p.client_name
    LEFT JOIN qa_details qa ON qa.project_id = p.project_id 
    LEFT JOIN learningpathway lp ON lp.pathway_id = qa.pathway_id
    AND qa.qualification_id = q.qualification_id
    AND TRIM(LOWER(lp.name)) = TRIM(LOWER(site.Project_pathway))
    WHERE ld.IDNumber IN ($placeholders)";

    try {
        log_message("Executing query for IDNumbers: $IDNumbers");
        log_message("SQL Query: $sql");
        
        // Debug: Test if the query can be prepared
        if (!$stmt = $conn->prepare($sql)) {
            log_message("SQL Prepare Error: " . $conn->error);
            sendErrorResponse("Database query preparation failed: " . $conn->error, 500);
        }

        $stmt->bind_param(str_repeat('s', count($idNumbersArray)), ...$idNumbersArray);
        if (!$stmt->execute()) {
            log_message("SQL Execution Error: " . $stmt->error . " | Query: $sql | IDNumbers: $IDNumbers");
            sendErrorResponse("Failed to execute database query", 500);
        }

        $result = $stmt->get_result();
        log_message("Query returned " . $result->num_rows . " rows for IDNumbers: $IDNumbers");
        $learners = $result->fetch_all(MYSQLI_ASSOC);
        if (empty($learners)) {
            log_message("No data found for IDNumbers: $IDNumbers");
            sendErrorResponse("No data found for provided IDNumbers", 404);
        }
        log_message("Data fetched: " . json_encode($learners));
    } catch (Exception $e) {
        log_message("Database error: " . $e->getMessage());
        sendErrorResponse("Database error: " . $e->getMessage(), 500);
    }
} else {
    sendErrorResponse('Missing LearnerID or IDNumbers parameter', 400);
}

log_message("Found " . count($learners) . " learners");

// Test PDF conversion methods
$pdfMethods = testPdfConversionMethods();

// Log available templates
$available_templates = scanAvailableTemplates();
log_message("Available templates found: " . count($available_templates));
foreach ($available_templates as $name => $path) {
    log_message("Template: $name -> $path");
}

$generatedFiles = [];
$skipped = 0;
$batch_size = 100;

for ($i = 0; $i < count($learners); $i += $batch_size) {
    $batch = array_slice($learners, $i, $batch_size);
    foreach ($batch as $data) {
        log_message("Processing LearnerID: {$data['LearnerID']} - {$data['Name']} {$data['Surname']}");
        
        // Set global learner data for PDF generation
        global $current_learner_data;
        $current_learner_data = $data;
        
        // Create individual learner folder
        $safe_id = preg_replace('/[^a-zA-Z0-9]/', '_', $data['IDNumber'] ?? 'unknown_' . $data['LearnerID']);
        $learner_dir = $output_dir . $safe_id . '/';
        if (!is_dir($learner_dir)) {
            mkdir($learner_dir, 0755, true);
            chmod($learner_dir, 0755);
        }
        
        try {
            // Get pathway dates
            $pathway_dates = getPathwayDates($conn, $data['project_id']);
            log_message("Pathway dates for project {$data['project_id']}: Start dates: " . implode(', ', $pathway_dates['start_dates']) . " | End dates: " . implode(', ', $pathway_dates['end_dates']));
            
            // Select the correct pathway from p.project_pathway based on site.project_pathway
            $pathway_data = isset($data['project_pathway']) ? json_decode($data['project_pathway'], true) : [];
            $site_pathway_name = $data['pathway_name'] ?? 'Short Skills Programme';
            $selected_pathway = null;
            
            if (is_array($pathway_data) && $site_pathway_name !== null) {
                foreach ($pathway_data as $pathway) {
                    if (isset($pathway['name']) && trim(strtolower($pathway['name'])) === trim(strtolower($site_pathway_name))) {
                        $selected_pathway = $pathway;
                        break;
                    }
                }
            }
            
            // Fallback to first pathway or default values
            if (!$selected_pathway && !empty($pathway_data)) {
                $selected_pathway = $pathway_data[0];
                log_message("No matching pathway found for pathway_name=$site_pathway_name, using first pathway");
            }
            
            // Extract fields from selected pathway or use defaults
            $pathway_name = $selected_pathway['name'] ?? 'Short Skills Programme';
            $qualification_name = $selected_pathway['qual_types'][0]['qualification']['name'] ?? '91782 - Plumber';
            $employment_status = $selected_pathway['qual_types'][0]['qualification']['employment_status'] ?? 'Unemployed 18.2';
            
            // Override learner_data with JSON-derived values
            $data['qualification_name'] = $qualification_name;
            $data['employment_status'] = $employment_status;
            
            // First, try to extract unit standards from JSON project_pathway
            $json_unit_standards = [];
            $pathway_data = null;
            $qual_type = 'N/A'; // Default qualification type
            
            if (isset($data['project_pathway']) && !empty($data['project_pathway'])) {
                $pathway_data = json_decode($data['project_pathway'], true);
                log_message("Pathway data: " . json_encode($pathway_data));
                
                // Extract qual_type from the pathway data
                if (isset($pathway_data[0]['qual_types'][0]['qual_type'])) {
                    $qual_type = $pathway_data[0]['qual_types'][0]['qual_type'];
                    log_message("Extracted qual_type from JSON: " . $qual_type);
                } else {
                    log_message("No qual_type found in JSON data");
                }
                
                if (is_array($pathway_data) && isset($pathway_data[0]['qual_types'])) {
                    foreach ($pathway_data[0]['qual_types'] as $qual_type_entry) {
                        if (isset($qual_type_entry['qualification']['unitStandards'])) {
                            $json_unit_standards = array_merge($json_unit_standards, $qual_type_entry['qualification']['unitStandards']);
                            log_message("Found " . count($qual_type_entry['qualification']['unitStandards']) . " unit standards in JSON");
                        } else {
                            log_message("No unitStandards found in qualification");
                        }
                    }
                } else {
                    log_message("No qual_types found in pathway data");
                }
            } else {
                log_message("No project_pathway data found");
            }
            
            // Use JSON unit standards if available, otherwise use database unit standards
            if (!empty($json_unit_standards)) {
                log_message("Found " . count($json_unit_standards) . " unit standards in JSON data with qualification type: " . $qual_type);
                
                // Get unit standard IDs from JSON data
                $json_unit_ids = array_column($json_unit_standards, 'id');
                $json_unit_ids = array_filter($json_unit_ids, function($id) { return !empty($id) && $id !== 'N/A'; });
                
                // Fetch credits from database for JSON unit standards
                $db_credits = [];
                if (!empty($json_unit_ids)) {
                    $placeholders = str_repeat('?,', count($json_unit_ids) - 1) . '?';
                    $stmt = $conn->prepare("SELECT unitstandard_id, credits FROM unitstandard WHERE unitstandard_id IN ($placeholders)");
                    if ($stmt) {
                        $stmt->bind_param(str_repeat('s', count($json_unit_ids)), ...$json_unit_ids);
                        if ($stmt->execute()) {
                            $result = $stmt->get_result();
                            while ($row = $result->fetch_assoc()) {
                                $db_credits[$row['unitstandard_id']] = $row['credits'];
                            }
                        }
                        $stmt->close();
                    }
                }
                
                $unit_standards = [];
                foreach ($json_unit_standards as $index => $us) {
                    $unit_id = $us['id'] ?? 'N/A';
                    $credits = $us['credits'] ?? $us['credit'] ?? ($db_credits[$unit_id] ?? 'N/A');
                    
                    $unit_standards[] = [
                        'id' => $unit_id,
                        'title' => $us['name'] ?? 'N/A',
                        'credits' => $credits,
                        's_type' => $qual_type
                    ];
                    log_message("Unit Standard " . ($index + 1) . ": " . $unit_id . " - " . ($us['name'] ?? 'N/A') . " - Credits: " . $credits . " - Type: " . $qual_type);
                }
            } else {
                log_message("No unit standards found in JSON data, using database unit standards with qualification type: " . $qual_type);
                // Get unit standards from database as fallback
                $unit_standards = getUnitStandards($conn, $data['qualification_id']);
                
                // Update unit standards with qualification type from JSON
                foreach ($unit_standards as &$us) {
                    $us['s_type'] = $qual_type;
                }
            }
            
            // Generate Agreement
            $template = new TemplateProcessor($template_path);

            // Replace text placeholders
            $template->setValue('Name', $data['Name'] ?? 'N/A');
            $template->setValue('Surname', $data['Surname'] ?? 'N/A');
            $template->setValue('IDNumber', $data['IDNumber'] ?? 'N/A');
            $template->setValue('PhoneNumber', $data['PhoneNumber'] ?? 'N/A');
            $template->setValue('qualification_name', $data['qualification_name'] ?? '91782 - Plumber');
            $template->setValue('qualification_id', $data['qualification_id'] ?? '91782');
            $template->setValue('pathway_name', $pathway_name);
            $template->setValue('sdp_name', $data['sdp_name'] ?? 'N/A');
            $template->setValue('learner_initials', $data['learner_initials'] ?? 'N/A');
            // Use first clock date if available, otherwise current date
            $date_to_use = $data['first_clock_date'] ?? date('Y-m-d');
            $formatted_date = date('d F Y', strtotime($date_to_use));
            $template->setValue('Date', $formatted_date);
            $template->setValue('witness_initials', $data['witness_initials'] ?? 'N/A');
            $template->setValue('qa_body_name', $data['qa_body_name'] ?? 'N/A');
            $template->setValue('accreditation_number', $data['accreditation_number'] ?? 'N/A');
            
            // Get first clock_in date for this learner
            $first_clock_in = getFirstClockInDate($conn, $data['LearnerID']);
            $template->setValue('Employment_Start', $first_clock_in);
            
            // Add unit standards using cloneRow for dynamic generation
            if (!empty($unit_standards)) {
                try {
                    // Clone the row for each unit standard
                    $template->cloneRow('unit_standard_id', count($unit_standards));
                    
                    // Set values for each unit standard
                    for ($i = 0; $i < count($unit_standards); $i++) {
                        $template->setValue("unit_standard_id#" . ($i + 1), $unit_standards[$i]['id'] ?? 'N/A');
                        $template->setValue("unit_standard_title#" . ($i + 1), $unit_standards[$i]['title'] ?? 'N/A');
                        $template->setValue("unit_standard_credits#" . ($i + 1), $unit_standards[$i]['credits'] ?? 'N/A');
                        $template->setValue("unit_standard_type#" . ($i + 1), $unit_standards[$i]['s_type'] ?? 'N/A');
                    }
                } catch (Exception $e) {
                    // Fallback to simple placeholder replacement if cloneRow fails
                    log_message("cloneRow failed, using fallback method: " . $e->getMessage());
                    for ($i = 0; $i < min(10, count($unit_standards)); $i++) {
                        $index = $i + 1;
                        $template->setValue("unit_standard_{$index}_id", $unit_standards[$i]['id'] ?? 'N/A');
                        $template->setValue("unit_standard_{$index}_title", $unit_standards[$i]['title'] ?? 'N/A');
                        $template->setValue("unit_standard_{$index}_credits", $unit_standards[$i]['credits'] ?? 'N/A');
                        $template->setValue("unit_standard_{$index}_type", $unit_standards[$i]['s_type'] ?? 'N/A');
                    }
                }
            } else {
                // If no unit standards, set default values
                try {
                    $template->setValue('unit_standard_id', 'N/A');
                    $template->setValue('unit_standard_title', 'N/A');
                    $template->setValue('unit_standard_credits', 'N/A');
                    $template->setValue('unit_standard_type', 'N/A');
                } catch (Exception $e) {
                    // Fallback for numbered placeholders
                    for ($i = 1; $i <= 10; $i++) {
                        $template->setValue("unit_standard_{$i}_id", 'N/A');
                        $template->setValue("unit_standard_{$i}_title", 'N/A');
                        $template->setValue("unit_standard_{$i}_credits", 'N/A');
                        $template->setValue("unit_standard_{$i}_type", 'N/A');
                    }
                }
            }
            
            // Add pathway dates
            if (!empty($pathway_dates['start_dates'])) {
                $template->setValue('pathway_start_date', $pathway_dates['start_dates'][0] ?? 'TBD');
                $template->setValue('selected_pathway_start_date', $pathway_dates['start_dates'][0] ?? 'TBD');
                $template->setValue('all_start_dates', implode(', ', $pathway_dates['start_dates']));
                for ($j = 0; $j < count($pathway_dates['start_dates']); $j++) {
                    $template->setValue('pathway_start_date_' . ($j + 1), $pathway_dates['start_dates'][$j] ?? 'TBD');
                }
            } else {
                $template->setValue('pathway_start_date', 'TBD');
                $template->setValue('selected_pathway_start_date', 'TBD');
                $template->setValue('all_start_dates', 'TBD');
            }
            
            if (!empty($pathway_dates['end_dates'])) {
                $template->setValue('pathway_end_date', $pathway_dates['end_dates'][0] ?? 'TBD');
                $template->setValue('selected_pathway_end_date', $pathway_dates['end_dates'][0] ?? 'TBD');
                $template->setValue('all_end_dates', implode(', ', $pathway_dates['end_dates']));
                for ($j = 0; $j < count($pathway_dates['end_dates']); $j++) {
                    $template->setValue('pathway_end_date_' . ($j + 1), $pathway_dates['end_dates'][$j] ?? 'TBD');
                }
            } else {
                $template->setValue('pathway_end_date', 'TBD');
                $template->setValue('selected_pathway_end_date', 'TBD');
                $template->setValue('all_end_dates', 'TBD');
            }
            
            // Calculate pathway duration in months
            $selected_pathway_duration = 'N/A';
            if (!empty($pathway_dates['start_dates']) && !empty($pathway_dates['end_dates'])) {
                $start_date = $pathway_dates['start_dates'][0];
                $end_date = $pathway_dates['end_dates'][0];
                
                if ($start_date !== 'TBD' && $end_date !== 'TBD') {
                    try {
                        $start = new DateTime($start_date);
                        $end = new DateTime($end_date);
                        $interval = $start->diff($end);
                        $months = ($interval->y * 12) + $interval->m;
                        if ($interval->d > 0) $months++; // Round up if there are remaining days
                        $selected_pathway_duration = $months;
                        log_message("Calculated pathway duration: $months months (from $start_date to $end_date)");
                    } catch (Exception $e) {
                        log_message("Error calculating pathway duration: " . $e->getMessage());
                        $selected_pathway_duration = 'N/A';
                    }
                }
            }
            $template->setValue('selected_pathway_duration', $selected_pathway_duration);
            
            // Add employer/client information
            $template->setValue('Employer_Contact', $data['client_name'] ?? 'N/A');
            $template->setValue('Employer_Cell', $data['client_phone'] ?? 'N/A');
            $template->setValue('Employer_Email', $data['client_email'] ?? 'N/A');
            $template->setValue('Employer_Address', $data['client_address'] ?? 'N/A');
            $template->setValue('Employer_Postal', $data['client_address'] ?? 'N/A');
            $template->setValue('Employer_Physical_Code', $data['client_postal_code'] ?? 'N/A');
            $template->setValue('Employer_Postal_Code', $data['client_postal_code'] ?? 'N/A');

            // Add signatures
            $learner_signature_path = find_signature_path($data['signaturePath'], $signature_base_paths);
            if ($learner_signature_path) {
                $template->setImageValue('learner_signature', [
                    'src' => $learner_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
                log_message("Learner signature added: $learner_signature_path");
            } elseif (file_exists($default_signature_path)) {
                $template->setImageValue('learner_signature', [
                    'src' => $default_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
                log_message("Default learner signature used: $default_signature_path");
            } else {
                $template->setValue('learner_signature', 'N/A');
                log_message("Default signature missing: $default_signature_path");
            }

            // Create SDP signature base paths similar to learner signature paths
            $sdp_signature_base_paths = [
                'mobile/uploads/',
                'uploads/',
                './'
            ];
            log_message("Looking for SDP signature_image: " . ($data['signature_image'] ?? 'null'));
            log_message("SDP signature search paths: " . implode(', ', $sdp_signature_base_paths));
            $sdp_signature_path = find_signature_path($data['signature_image'], $sdp_signature_base_paths);
            if ($sdp_signature_path) {
                $template->setImageValue('sdp_signature_image', [
                    'src' => $sdp_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
                log_message("SDP signature added: $sdp_signature_path");
            } else {
                $template->setValue('sdp_signature_image', 'N/A');
                log_message("No SDP signature found for signature_image: " . ($data['signature_image'] ?? 'null'));
                // Debug: Check what files exist in the directories
                foreach ($sdp_signature_base_paths as $base_path) {
                    $full_path = $base_path . ($data['signature_image'] ?? '');
                    log_message("Checked path: $full_path - exists: " . (file_exists($full_path) ? 'yes' : 'no'));
                }
            }

            $witness_signature_path = find_signature_path($data['witnessSignaturePath'], $signature_base_paths);
            if ($witness_signature_path) {
                $template->setImageValue('witness_signature', [
                    'src' => $witness_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
                log_message("Witness signature added: $witness_signature_path");
            } else {
                $template->setValue('witness_signature', 'N/A');
                log_message("No witness signature found");
            }

            // Save agreement document
            $docxFile = $learner_dir . $safe_id . "_Agreement.docx";
            $template->saveAs($docxFile);
            
            // Post-process the document to replace "ZERO" back to "0"
            if (file_exists($docxFile)) {
                $zip = new ZipArchive();
                if ($zip->open($docxFile) === TRUE) {
                    // Get the document.xml content
                    $document_xml = $zip->getFromName('word/document.xml');
                    if ($document_xml !== false) {
                        // Replace "ZERO" with "0" in the document content
                        $document_xml = str_replace('ZERO', '0', $document_xml);
                        $zip->addFromString('word/document.xml', $document_xml);
                    }
                    $zip->close();
                    log_message("Post-processed agreement document to replace ZERO with 0: $docxFile");
                }
            }

            if (file_exists($docxFile)) {
                $generatedFiles[] = $docxFile;
                log_message("Agreement generated: $docxFile");
                
                // Convert to PDF (if enabled)
                if ($ENABLE_PDF_CONVERSION) {
                    $pdfFile = $learner_dir . $safe_id . "_Agreement.pdf";
                    if (convertDocxToPdf($docxFile, $pdfFile)) {
                        $generatedFiles[] = $pdfFile;
                        log_message("Agreement PDF generated: $pdfFile");
                        
                        // If force PDF only, remove DOCX file
                        if ($FORCE_PDF_ONLY && file_exists($docxFile)) {
                            unlink($docxFile);
                            // Remove DOCX from generated files array
                            $generatedFiles = array_filter($generatedFiles, function($file) use ($docxFile) {
                                return $file !== $docxFile;
                            });
                            log_message("DOCX file removed (PDF only mode): $docxFile");
                        }
                    } else {
                        log_message("Failed to convert agreement to PDF for LearnerID: {$data['LearnerID']}");
                    }
                } else {
                    log_message("PDF conversion disabled - only generating DOCX");
                }
                
            } else {
                log_message("Failed to generate agreement for LearnerID: {$data['LearnerID']}");
                $skipped++;
            }

            // Determine required forms based on funder and qa_body_namelank
        
            $project_funder = $data['Project_funder'] ?? '';
            $qa_body_name = $data['qa_body_name'] ?? '';
            $required_forms = [];

            if (in_array($project_funder, $SETAS)) {
                log_message("Project funder is SETA (self-funded): $project_funder");
                $required_forms = getSETAForms($project_funder);
            } else {
                log_message("Project funder is external: $project_funder");
                if (in_array($qa_body_name, $SETAS)) {
                    log_message("qa_body_name is SETA: $qa_body_name");
                    $required_forms = getSETAForms($qa_body_name);
                } else {
                    log_message("qa_body_name is not a SETA: $qa_body_name. Using default forms.");
                    $required_forms = ['Learner_Agreement'];
                }
            }

            // Generate required forms
            if (!empty($required_forms)) {
                log_message("Generating forms for LearnerID {$data['LearnerID']}: " . implode(', ', $required_forms));
                $form_files = generateForms($conn, $required_forms, $data, $learner_dir, $pathway_dates);
                $generatedFiles = array_merge($generatedFiles, $form_files);
            } else {
                log_message("No additional forms required for LearnerID: {$data['LearnerID']}");
            }

        } catch (Exception $e) {
            $skipped++;
            log_message("Error processing LearnerID {$data['LearnerID']}: " . $e->getMessage());
        }
    }
    unset($batch);
}

// Output handling
if (!empty($generatedFiles)) {
    if (count($learners) === 1) {
        // Single learner: serve the agreement file directly
        $docxFile = $generatedFiles[0];
        header('Content-Description: File Transfer');
        header('Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document');
        header('Content-Disposition: attachment; filename="' . basename($docxFile) . '"');
        header('Content-Transfer-Encoding: binary');
        header('Expires: 0');
        header('Cache-Control: must-revalidate');
        header('Pragma: public');
        header('Content-Length: ' . filesize($docxFile));
        readfile($docxFile);
    } else {
        // Multiple learners: create ZIP file
        try {
            $zip = new ZipArchive();
            $zipFileName = $output_dir . "Project_Agreements_" . date('Ymd_His') . ".zip";

            if ($zip->open($zipFileName, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== TRUE) {
                log_message("Failed to open ZIP archive: $zipFileName");
                sendErrorResponse("Failed to create ZIP file.", 500);
            }

            foreach ($generatedFiles as $file) {
                if (file_exists($file)) {
                    $relativePath = str_replace($output_dir, '', $file);
                    $zip->addFile($file, $relativePath);
                } else {
                    log_message("ZIP error: File not found: $file");
                }
            }
            $zip->close();

            if (file_exists($zipFileName)) {
                log_message("ZIP file created: $zipFileName");
                header('Content-Type: application/zip');
                header('Content-Disposition: attachment; filename="' . basename($zipFileName) . '"');
                readfile($zipFileName);
                exit;
            } else {
                log_message("Failed to create ZIP file: $zipFileName");
                sendErrorResponse("Failed to create ZIP file.", 500);
            }
        } catch (Exception $e) {
            log_message("ZIP creation error: " . $e->getMessage());
            sendErrorResponse("Error creating ZIP file: " . $e->getMessage(), 500);
        }
    }
} else {
    log_message("No files generated for processing");
    sendErrorResponse("No files were generated.", 500);
}


$stmt->close();
$conn->close();
exit;
?>