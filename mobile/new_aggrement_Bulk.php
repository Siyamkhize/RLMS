<?php

require_once __DIR__ . '/../security_functions.php';
use PhpOffice\PhpWord\TemplateProcessor;
require 'vendor/autoload.php';

// Include PDF converter helper
require_once __DIR__ . '/../pdf_converter_libreoffice.php';

// Include PDF storage helper for permanent PDF storage
require_once __DIR__ . '/../pdf_storage_helper.php';

ini_set('memory_limit', '1024M');
set_time_limit(900); // 15 minutes for large downloads

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

// Helper: case-insensitive lookup of canonical SETA name used as key in getSETAForms() mapping
// (defined ONCE, outside any loop, to avoid PHP "Cannot redeclare function" errors)
$SETA_UPPER_TO_CANONICAL = [
    'AGRISETA' => 'AGRISETA', 'BANKSETA' => 'BANKSETA', 'CATHSSETA' => 'CATHSSETA',
    'CETA' => 'CETA', 'CHIETA' => 'CHIETA', 'ETDPSETA' => 'ETDPSETA', 'EWSETA' => 'EWSETA',
    'FASSET' => 'FASSET', 'FOODBEV' => 'FOODBEV', 'FP&M SETA' => 'FP&M SETA',
    'HWSETA' => 'HWSETA', 'INSETA' => 'INSETA', 'LGSETA' => 'LGSETA',
    'MERSETA' => 'MERSETA', 'MICT SETA' => 'MICT SETA', 'MQA' => 'MQA',
    'PSETA' => 'PSETA', 'SASSETA' => 'SASSETA', 'SERVICES SETA' => 'SERVICES SETA',
    'TETA' => 'TETA', 'W&RSETA' => 'W&RSETA'
];

// Helper: try repeatedly to convert a DOCX -> PDF until EITHER we have a valid PDF
// OR we exhaust max_attempts. Uses exponential back-off. This guarantees "wait for PDF"
// behaviour requested by user: each form gets multiple chances + slowdowns for slow/AV Windows.
// PHASE 1 ENHANCEMENT: Added PDF header verification to ensure 100% PDF files
function convertToPdfWithRetries($docxPath, $outputDir, $maxAttempts = 8) {
    $attempts = 0;
    $lastErr = 'no attempt made';
    $backoffMs = 800; // 0.8s initial, then x2 each failed attempt (was 400ms)
    while ($attempts < $maxAttempts) {
        $attempts++;
        if ($attempts > 1) {
            // Between retries: kill any lingering soffice (clears profile lock)
            if (function_exists('exec')) {
                if (DIRECTORY_SEPARATOR === '\\') {
                    @exec('taskkill /F /IM soffice.exe /T 2>NUL');
                    @exec('taskkill /F /IM soffice.bin /T 2>NUL');
                } else {
                    @exec('pkill -9 -f soffice 2>/dev/null; pkill -9 -f libreoffice 2>/dev/null');
                }
            }
            usleep($backoffMs * 1000);
            $backoffMs = min($backoffMs * 2, 8000); // cap at 8s (was 5s)
        }
        log_message("PDF conversion attempt $attempts/$maxAttempts for: " . basename($docxPath));
        try {
            $pdf = convertDocxToPdfLibreOffice($docxPath, $outputDir);
        } catch (Throwable $e) {
            $lastErr = 'exception: ' . $e->getMessage();
            $pdf = false;
        }
        
        // ✅ PHASE 1 ENHANCEMENT: Verify PDF file validity with header check
        if ($pdf && file_exists($pdf)) {
            $fileSize = filesize($pdf);
            
            // Check if PDF is valid (>22 bytes and has PDF header)
            if ($fileSize > 22) {
                $handle = @fopen($pdf, 'r');
                if ($handle) {
                    $header = fread($handle, 4);
                    fclose($handle);
                    
                    // PDF files start with %PDF
                    if (substr($header, 0, 4) === '%PDF') {
                        // FINAL STABILITY CHECK: Re-verify after a short sleep that the PDF is
                        // still valid (antivirus on Windows can truncate/lock files right after creation)
                        usleep(300000); // 0.3s grace period
                        clearstatcache(true, $pdf);
                        
                        if (file_exists($pdf) && filesize($pdf) > 22) {
                            log_message("✅ PDF conversion SUCCESS on attempt $attempts: $pdf ({$fileSize}B) - Header verified");
                            return $pdf;
                        } else {
                            log_message("⚠️ PDF appeared valid but failed post-stability check, retrying...");
                        }
                    } else {
                        log_message("⚠️ PDF header invalid (got: '" . bin2hex($header) . "' expected: '%PDF'), retrying...");
                        $lastErr = 'invalid PDF header';
                    }
                } else {
                    log_message("⚠️ Could not open PDF for header verification, retrying...");
                    $lastErr = 'cannot open PDF file';
                }
            } else {
                log_message("⚠️ PDF file too small ({$fileSize}B), retrying...");
                $lastErr = "PDF file size only {$fileSize} bytes";
            }
        } else {
            $lastErr = 'convertDocxToPdfLibreOffice returned ' . ($pdf === false ? 'false' : 'invalid/empty PDF at ' . var_export($pdf, true));
        }
    }
    
    log_message("❌ PDF conversion FAILED after $attempts attempts for " . basename($docxPath) . ". Last error: $lastErr");
    
    // ✅ PHASE 1 FALLBACK: Copy DOCX as-is with clear label if conversion failed
    // This ensures user gets the document even if PDF conversion fails
    $fallbackPath = $outputDir . '/' . basename($docxPath, '.docx') . '_CONVERSION_FAILED.docx';
    if (file_exists($docxPath) && @copy($docxPath, $fallbackPath)) {
        log_message("⚠️ FALLBACK: Copied DOCX to output as conversion failed: " . basename($fallbackPath));
        log_message("⚠️ User should manually convert this file or investigate conversion issues");
        return $fallbackPath; // Return DOCX path so it's included in ZIP
    }
    
    log_message("❌ CRITICAL: Both PDF conversion AND fallback DOCX copy failed for " . basename($docxPath));
    return false;
}

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

// Add initial debug log
error_log("Script started - LearnerID: " . ($_GET['LearnerID'] ?? 'not provided'));
error_log("All GET parameters: " . print_r($_GET, true));
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

// Response headers set contextually per branch (JSON for API errors, file download for documents)

function log_message($message) {
    global $log_file;
    file_put_contents($log_file, date('Y-m-d H:i:s') . " - $message\n", FILE_APPEND);
}

// Helper function to send error responses
function sendErrorResponse($message, $statusCode = 500) {
    header('Content-Type: application/json');
    http_response_code($statusCode);
    echo json_encode(['error' => $message]);
    exit;
}


// Signature path finder
$signature_base_paths = [
    'signatures/',
    'mobile/signatures/',
    '/',
    'mobile/'
];
$default_signature_path = 'mobile/signatures/';

// Helper function to find signature image in multiple possible locations
function findSignatureImage($signatureFilename, $learnerID = null, $signatureType = 'learner') {
    if (empty($signatureFilename)) {
        return null;
    }
    
    // Strip URL prefix if present (e.g., "rlms.mtltechnical.co.za/mobile/signatures/file.png")
    $cleanFilename = preg_replace('#^https?://[^/]+/#', '', $signatureFilename);
    $cleanFilename = preg_replace('#^[^/]+\.(com|co\.za|net|org)/#', '', $cleanFilename);
    
    // Take the filename exactly as it is from database
    $exactFilename = basename($cleanFilename);
    
    $possiblePaths = [];
    
    if ($signatureType === 'sdp') {
        // SDP signature paths - handle both /Uploads/sdp/ and other formats
        $possiblePaths = [
            $signatureFilename,
            $cleanFilename,
            // Remove leading slash and try
            ltrim($signatureFilename, '/'),
            ltrim($cleanFilename, '/'),
            // Try with Uploads/sdp/ folder
            "Uploads/sdp/" . $exactFilename,
            "../Uploads/sdp/" . $exactFilename,
            "uploads/sdp/" . $exactFilename,
            "../uploads/sdp/" . $exactFilename,
            // Try without sdp subfolder
            "Uploads/" . $exactFilename,
            "../Uploads/" . $exactFilename,
            "uploads/" . $exactFilename,
            "../uploads/" . $exactFilename,
            "mobile/Uploads/sdp/" . $exactFilename,
            "../mobile/Uploads/sdp/" . $exactFilename,
            "mobile/uploads/sdp/" . $exactFilename,
            "../mobile/uploads/sdp/" . $exactFilename,
            "mobile/Uploads/" . $exactFilename,
            "../mobile/Uploads/" . $exactFilename,
            "mobile/uploads/" . $exactFilename,
            "../mobile/uploads/" . $exactFilename,
            "assets/img/" . $exactFilename,
            "../assets/img/" . $exactFilename,
            $exactFilename,
            "../" . $exactFilename,
            __DIR__ . "/" . $exactFilename,
            __DIR__ . "/../" . $exactFilename,
            __DIR__ . "/Uploads/sdp/" . $exactFilename,
            __DIR__ . "/../Uploads/sdp/" . $exactFilename
        ];
    } elseif ($signatureType === 'client' || $signatureType === 'client_witness') {
        // Client signature paths - stored in /Uploads/signature/ or /uploads/signatures/ folder
        $possiblePaths = [
            $signatureFilename,
            $cleanFilename,
            // Check both /uploads/signatures/ (new location) and /Uploads/signature/ (legacy)
            "uploads/signatures/" . $exactFilename,
            "../uploads/signatures/" . $exactFilename,
            "mobile/uploads/signatures/" . $exactFilename,
            "../mobile/uploads/signatures/" . $exactFilename,
            "Uploads/signature/" . $exactFilename,
            "../Uploads/signature/" . $exactFilename,
            "uploads/signature/" . $exactFilename,
            "../uploads/signature/" . $exactFilename,
            "mobile/Uploads/signature/" . $exactFilename,
            "../mobile/Uploads/signature/" . $exactFilename,
            "mobile/uploads/signature/" . $exactFilename,
            "../mobile/uploads/signature/" . $exactFilename,
            "Uploads/" . $exactFilename,
            "../Uploads/" . $exactFilename,
            "uploads/" . $exactFilename,
            "../uploads/" . $exactFilename,
            $exactFilename,
            "../" . $exactFilename,
            __DIR__ . "/" . $exactFilename,
            __DIR__ . "/../" . $exactFilename,
            __DIR__ . "/uploads/signatures/" . $exactFilename,
            __DIR__ . "/../uploads/signatures/" . $exactFilename,
            __DIR__ . "/Uploads/signature/" . $exactFilename,
            __DIR__ . "/../Uploads/signature/" . $exactFilename
        ];
    } else {
        // Learner and witness signature paths
        // Search for the exact filename in all possible folders
        $possiblePaths = [
            // Try as-is from database
            $signatureFilename,
            $cleanFilename,
            // Search in signatures folders
            "signatures/" . $exactFilename,
            "../signatures/" . $exactFilename,
            "mobile/signatures/" . $exactFilename,
            "../mobile/signatures/" . $exactFilename,
            // Search in learnerImages folders
            "learnerImages/" . $exactFilename,
            "../learnerImages/" . $exactFilename,
            "mobile/learnerImages/" . $exactFilename,
            "../mobile/learnerImages/" . $exactFilename,
            // Search in uploads folders
            "uploads/" . $exactFilename,
            "../uploads/" . $exactFilename,
            "mobile/uploads/" . $exactFilename,
            "../mobile/uploads/" . $exactFilename,
            "Uploads/" . $exactFilename,
            "../Uploads/" . $exactFilename,
            "mobile/Uploads/" . $exactFilename,
            "../mobile/Uploads/" . $exactFilename,
            // Search in root/current directory
            $exactFilename,
            "../" . $exactFilename,
            "mobile/" . $exactFilename,
            "../mobile/" . $exactFilename,
            // Absolute paths
            __DIR__ . "/" . $exactFilename,
            __DIR__ . "/../" . $exactFilename,
            __DIR__ . "/signatures/" . $exactFilename,
            __DIR__ . "/../signatures/" . $exactFilename,
            __DIR__ . "/learnerImages/" . $exactFilename,
            __DIR__ . "/../learnerImages/" . $exactFilename
        ];
    }
    
    // Check each path
    $checkedPaths = [];
    foreach ($possiblePaths as $path) {
        $checkedPaths[] = $path;
        if (file_exists($path)) {
            // Log successful path resolution for debugging
            if ($signatureType === 'sdp') {
                error_log("SDP Signature found: Database value='$signatureFilename', Resolved path='$path'");
            } else {
                error_log("Learner/Witness Signature found: Database value='$signatureFilename', Resolved path='$path', Type='$signatureType'");
            }
            return $path;
        }
    }
    
    // Log all checked paths if not found
    error_log("Signature NOT found for '$signatureFilename' (Type: $signatureType). Checked paths: " . implode(', ', array_slice($checkedPaths, 0, 10)));
    
    return null;
}

// Function to validate DOCX file
function isValidDocx($file_path) {
    if (!file_exists($file_path)) {
        return false;
    }
    
    // Check file extension
    $extension = strtolower(pathinfo($file_path, PATHINFO_EXTENSION));
    
    // For .doc files, just check if file exists and is readable
    if ($extension === 'doc') {
        return is_readable($file_path);
    }
    
    // For .docx files, validate ZIP structure
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

// Function to copy file to Desktop
function copyToDesktop($source_file, $desktop_dir, $desktop_enabled) {
    if ($desktop_enabled && file_exists($source_file)) {
        $desktop_file = $desktop_dir . basename($source_file);
        if (copy($source_file, $desktop_file)) {
            log_message("Desktop copy saved: $desktop_file");
            return true;
        } else {
            log_message("Failed to copy to Desktop: $desktop_file");
            return false;
        }
    }
    return false;
}

// Function to get SETA forms
function getSETAForms($seta_name, $pathway_name = '') {
    // Use only forms that exist in the templates directory
    // DoL EEA1 Form is now included for ALL SETAs
    $seta_form_mappings = [
        'AGRISETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'BANKSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'CATHSSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'CETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'CHIETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'ETDPSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'EWSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'FASSET' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'FOODBEV' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'FP&M SETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'HWSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'INSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'LGSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'MERSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'MICT SETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'MQA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'PSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'SASSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'SERVICES SETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'TETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form'],
        'W&RSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form', 'DoL EEA1 Form']
    ];
    
    // Check if it's CETA and Learnership - return ONLY the learnership forms + DoL EEA1 Form
    if ($seta_name === 'CETA' && !empty($pathway_name)) {
        $pathway_lower = strtolower(trim($pathway_name));
        // Check if it's a Learnership (not Short Skills Programme)
        if (strpos($pathway_lower, 'learnership') !== false || 
            ($pathway_lower !== 'short skills programme' && $pathway_lower !== 'short skills' && $pathway_lower !== 'skills programme')) {
            log_message("CETA Learnership detected for pathway: $pathway_name. Returning learnership forms + DoL EEA1 Form.");
            // Return the CETA learnership forms + DoL EEA1 Form
            return [
                'Learnership-Agreement-v130314',
                'Learnership-Application-Form-v01',
                'Learner_Contract_of_Employment_Template',
                'DoL EEA1 Form'
            ];
        } else {
            log_message("CETA Short Skills Programme detected for pathway: $pathway_name. Using standard forms.");
        }
    }
    
    // For all other cases, return the standard forms (including DoL EEA1 Form)
    $forms = isset($seta_form_mappings[$seta_name]) ? $seta_form_mappings[$seta_name] : ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'DoL EEA1 Form'];
    return $forms;
}

// Function to get first clock_in date for a learner
function getFirstClockInDate($conn, $learner_id) {
    $first_clock_in = 'N/A';
    $stmt = $conn->prepare("SELECT MIN(clock_date) as first_clock_in FROM learner_clocking WHERE LearnerID = ? AND clock_date IS NOT NULL");
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
                
                // Process ID digits for ALL forms - handle "0" values properly
                $id_number = $learner_data['IDNumber'] ?? '';
                for ($id_digit = 1; $id_digit <= 13; $id_digit++) {
                    // Get digit from database result first
                    $digit_value = $learner_data["id_digit_$id_digit"] ?? '';
                    
                    // If empty, try to extract from the full ID number
                    if ($digit_value === '' || $digit_value === null) {
                        $digit_value = substr($id_number, $id_digit - 1, 1);
                    }
                    
                    // If still empty, default to '0'
                    if ($digit_value === '' || $digit_value === null) {
                        $digit_value = '0';
                    }
                    
                    // Debug: Log the actual values being set
                    error_log("Setting id_digit_$id_digit = '$digit_value' for ID: $id_number (from DB: " . ($learner_data["id_digit_$id_digit"] ?? 'null') . ")");
                    
                    // Force PhpWord to treat "0" as a valid value
                    // PhpWord skips "0" values, so we need to work around this
                    if ($digit_value === '0') {
                        // Use a non-empty string that represents zero
                        $template->setValue("id_digit_$id_digit", 'ZERO');
                    } else {
                        $template->setValue("id_digit_$id_digit", $digit_value);
                    }
                }
                
                // Set common demographic placeholders for ALL forms
                $template->setValue('Date_of_Birth', $learner_data['id_derived_dob'] ?? 'N/A');
                $template->setValue('Gender_Male', $learner_data['gender'] === 'Male' ? 'X' : '');
                $template->setValue('Gender_Female', $learner_data['gender'] === 'Female' ? 'X' : '');
                $template->setValue('Gender', $learner_data['gender'] ?? 'N/A');
                $template->setValue('Citizen_Yes', $learner_data['is_south_african_citizen'] === 'Yes' ? 'X' : '');
                $template->setValue('Citizen_No', $learner_data['is_south_african_citizen'] === 'No' ? 'X' : '');
                $template->setValue('Title', $learner_data['title'] ?? 'N/A');
                $template->setValue('employment_status', $employment_status);
                
                // Set race placeholders for ALL forms
                $race = strtolower(trim($learner_data['Race'] ?? ''));
                $template->setValue('Race_African', $race === 'african' ? 'X' : '');
                $template->setValue('Race_Coloured', $race === 'coloured' ? 'X' : '');
                $template->setValue('Race_Indian', $race === 'indian' ? 'X' : '');
                $template->setValue('Race_White', $race === 'white' ? 'X' : '');
                $template->setValue('Race', $learner_data['Race'] ?? 'N/A');
                
                // Set disability placeholders for ALL forms
                $disability = strtolower($learner_data['Disability'] ?? '');
                if ($disability === 'none' || $disability === 'no' || empty($disability)) {
                    $template->setValue('Disability_No', 'X');
                    $template->setValue('Disability_Yes', '');
                    $template->setValue('Disability_Specify', 'N/A');
                    $template->setValue('Disability', 'N/A');
                } else {
                    $template->setValue('Disability_No', '');
                    $template->setValue('Disability_Yes', 'X');
                    $template->setValue('Disability_Specify', $learner_data['Disability'] ?? 'N/A');
                    $template->setValue('Disability', $learner_data['Disability'] ?? 'N/A');
                }
                
                // Set address placeholders for ALL forms
                $template->setValue('Postal_Address', $learner_data['full_address'] ?? 'N/A');
                $template->setValue('Physical_Address', $learner_data['full_address'] ?? 'N/A');
                $template->setValue('Postal_Code', $learner_data['PostalCode'] ?? 'N/A');
                $template->setValue('Physical_Code', $learner_data['PostalCode'] ?? 'N/A');
                $template->setValue('Municipality', $learner_data['Municipality'] ?? 'N/A');
                $template->setValue('Home_Tel', 'N/A');
                $template->setValue('Alternative_Contact', $learner_data['KinName'] ?? 'N/A');
                $template->setValue('Alternative_Tel', $learner_data['KinContact'] ?? 'N/A');
                $template->setValue('Alternative_Email', $learner_data['Email'] ?? 'N/A');
                
                // Set school information for ALL forms
                $template->setValue('SchoolName', $learner_data['SchoolName'] ?? 'N/A');
                $template->setValue('SchoolLocation', $learner_data['SchoolLocation'] ?? 'N/A');
                $template->setValue('SchoolCompletion', $learner_data['SchoolCompletion'] ?? 'N/A');
                $template->setValue('SchoolGrade', $learner_data['SchoolGrade'] ?? 'N/A');
                
                // Replace placeholders for NEW_SKILLS_PROGRAMME_APPLICATION_FORM
                if ($form_name === 'NEW_SKILLS_PROGRAMME_APPLICATION_FORM') {
                    // Set employment status checkboxes
                    $employment_status_lower = strtolower($employment_status);
                    $template->setValue('Employed_Learner', (strpos($employment_status_lower, 'employed') !== false && strpos($employment_status_lower, 'unemployed') === false) ? 'X' : '');
                    $template->setValue('Unemployed_Learner', (strpos($employment_status_lower, 'unemployed') !== false) ? 'X' : '');
                    
                    // Set funding type checkboxes (CETA DG Funded vs Industry Funded)
                    // Assuming CETA DG Funded is the default unless specified otherwise
                    $template->setValue('CETA_DG_Funded', 'X'); // Default to CETA DG Funded
                    $template->setValue('Industry_Funded', ''); // Empty for now, can be set based on project data if available
                    
                    // Add unit standards using cloneRow for dynamic generation
                    if (!empty($unit_standards)) {
                        try {
                            // Clone the row for each unit standard
                            $template->cloneRow('unit_standard_id', count($unit_standards));
                            
                            // Set values for each unit standard
                            for ($f_us = 0; $f_us < count($unit_standards); $f_us++) {
                                $template->setValue("unit_standard_id#" . ($f_us + 1), $unit_standards[$f_us]['id'] ?? 'N/A');
                                $template->setValue("unit_standard_title#" . ($f_us + 1), $unit_standards[$f_us]['title'] ?? 'N/A');
                                $template->setValue("unit_standard_credits#" . ($f_us + 1), $unit_standards[$f_us]['credits'] ?? 'N/A');
                                $template->setValue("unit_standard_type#" . ($f_us + 1), $unit_standards[$f_us]['s_type'] ?? 'N/A');
                            }
                        } catch (Exception $e) {
                            // Fallback to simple placeholder replacement if cloneRow fails
                            for ($f_usfb = 0; $f_usfb < min(10, count($unit_standards)); $f_usfb++) {
                                $index = $f_usfb + 1;
                                $template->setValue("unit_standard_{$index}_id", $unit_standards[$f_usfb]['id'] ?? 'N/A');
                                $template->setValue("unit_standard_{$index}_title", $unit_standards[$f_usfb]['title'] ?? 'N/A');
                                $template->setValue("unit_standard_{$index}_credits", $unit_standards[$f_usfb]['credits'] ?? 'N/A');
                                $template->setValue("unit_standard_{$index}_type", $unit_standards[$f_usfb]['s_type'] ?? 'N/A');
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
                            for ($f_usdef = 1; $f_usdef <= 10; $f_usdef++) {
                                $template->setValue("unit_standard_{$f_usdef}_id", 'N/A');
                                $template->setValue("unit_standard_{$f_usdef}_title", 'N/A');
                                $template->setValue("unit_standard_{$f_usdef}_credits", 'N/A');
                                $template->setValue("unit_standard_{$f_usdef}_type", 'N/A');
                            }
                        }
                    }
                    
                    // Additional placeholders specific to NEW_SKILLS_PROGRAMME_APPLICATION_FORM
                    $template->setValue('Employer_Name', $learner_data['client_name'] ?? 'N/A');
                    $template->setValue('Employer_SDL', 'N/A');
                    // Get first clock_in date for this learner
                    $first_clock_in = getFirstClockInDate($conn, $learner_data['LearnerID']);
                    $template->setValue('Employment_Start', $first_clock_in);
                    // Assessor fields will be set in the common placeholders section below
                }
                
                // Common placeholders for all forms
                $template->setValue('Name', $learner_data['Name'] ?? 'N/A');
                $template->setValue('Surname', $learner_data['Surname'] ?? 'N/A');
                $template->setValue('IDNumber', $learner_data['IDNumber'] ?? 'N/A');
                $template->setValue('PhoneNumber', $learner_data['PhoneNumber'] ?? 'N/A');
                $template->setValue('qualification_name', $learner_data['qualification_name'] ?? 'N/A');
                $template->setValue('qualification_id', $learner_data['qualification_id'] ?? 'N/A');
                $template->setValue('pathway_name', $pathway_name);
                
                // Extract and set stipend amount for the selected pathway
                $stipend_amount = 'N/A';
                $stipend_type = 'N/A';
                if (!empty($learner_data['pathway_stipends']) && !empty($learner_data['project_pathway'])) {
                    $pathway_stipends_array = array_filter(array_map('trim', explode(',', $learner_data['pathway_stipends'])));
                    $pathway_stipend_types_array = !empty($learner_data['pathway_stipend_types']) ? array_filter(array_map('trim', explode(',', $learner_data['pathway_stipend_types']))) : [];
                    $pathway_data_decoded = json_decode($learner_data['project_pathway'], true);
                    
                    if (is_array($pathway_data_decoded)) {
                        // Find the index of the matching pathway
                        $pathway_index = 0;
                        foreach ($pathway_data_decoded as $index => $pathway_item) {
                            if (isset($pathway_item['name']) && trim(strtolower($pathway_item['name'])) === trim(strtolower($pathway_name))) {
                                $pathway_index = $index;
                                break;
                            }
                        }
                        
                        // Get the stipend amount for this pathway
                        if (isset($pathway_stipends_array[$pathway_index])) {
                            $stipend_amount = 'R' . number_format((float)$pathway_stipends_array[$pathway_index], 2);
                        }
                        
                        // Get the stipend type for this pathway
                        if (isset($pathway_stipend_types_array[$pathway_index])) {
                            $stipend_type = ucfirst($pathway_stipend_types_array[$pathway_index]);
                        }
                        
                        log_message("Stipend for pathway '$pathway_name' (index $pathway_index): Amount=$stipend_amount, Type=$stipend_type");
                    }
                }
                $template->setValue('stipend_amount', $stipend_amount);
                $template->setValue('amount', $stipend_amount);
                $template->setValue('stipend_type', $stipend_type);
                
                $template->setValue('sdp_name', $learner_data['sdp_name'] ?? 'N/A');
                $template->setValue('sdp_initials', $learner_data['sdp_initials'] ?? 'N/A');
                // Note: sdp_witness_signature is set as IMAGE below, not as text
                $template->setValue('sdp_witness_initials', $learner_data['sdp_witness_initials'] ?? 'N/A');
                $template->setValue('sdp_contact_person', $learner_data['contact_person'] ?? 'N/A');
                $template->setValue('sdp_contact_number', $learner_data['contact_number'] ?? 'N/A');
                $template->setValue('sdp_city', $learner_data['city'] ?? 'N/A');
                $template->setValue('sdp_postal_code', $learner_data['postal_code'] ?? 'N/A');
                $template->setValue('sdp_physical_address', $learner_data['sdp_physical_address'] ?? 'N/A');
                $template->setValue('sdp_email', $learner_data['sdp_email'] ?? 'N/A');
                $template->setValue('learner_initials', $learner_data['learner_initials'] ?? 'N/A');
                $template->setValue('witness_initials', $learner_data['witness_initials'] ?? 'N/A');
                // Note: signaturePath and witness_signature are set as IMAGES below, not as text
                // Use first clock date if available, otherwise current date
                $date_to_use = $learner_data['first_clock_date'] ?? date('Y-m-d');
                $formatted_date = date('d F Y', strtotime($date_to_use));
                $template->setValue('Date', $formatted_date);
                $template->setValue('qa_body_name', $learner_data['qa_body_name'] ?? 'N/A');
                $template->setValue('accreditation_number', $learner_data['accreditation_number'] ?? 'N/A');
                $template->setValue('skill_programme_id', $learner_data['skill_programme_id'] ?? 'N/A');
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
                $template->setValue('Employer_Cell', $learner_data['client_cell'] ?? $learner_data['client_phone'] ?? 'N/A');
                $template->setValue('Employer_Phone', $learner_data['client_phone'] ?? 'N/A');
                $template->setValue('Contact_Number', $learner_data['contact_number'] ?? 'N/A');
                $template->setValue('Contact_Person', $learner_data['contact_person'] ?? 'N/A');
                $template->setValue('Employer_Email', $learner_data['client_email'] ?? 'N/A');
                $template->setValue('Employer_Address', $learner_data['client_address'] ?? 'N/A');
                $template->setValue('Employer_City', $learner_data['client_city'] ?? 'N/A');
                $template->setValue('Employer_Postal', $learner_data['client_address'] ?? 'N/A');
                $template->setValue('Employer_Physical_Code', $learner_data['client_postal_code'] ?? 'N/A');
                $template->setValue('Employer_Postal_Code', $learner_data['client_postal_code'] ?? 'N/A');
                
                // ========================================
                // ASSESSOR INFORMATION - 67 Placeholders
                // ========================================
                
                // 1️⃣ Basic Information (8 placeholders)
                $template->setValue('Assessor_Name', $learner_data['assessor_firstName'] ?? 'N/A');
                $template->setValue('Assessor_Surname', $learner_data['assessor_lastName'] ?? 'N/A');
                $template->setValue('Assessor_Full_Name', $learner_data['assessor_fullName'] ?? 'N/A');
                $template->setValue('Assessor_ID', $learner_data['assessor_id_number'] ?? 'N/A');
                $template->setValue('Assessor_IDNumber', $learner_data['assessor_id_number'] ?? 'N/A');
                $template->setValue('Assessor_Email', $learner_data['assessor_email'] ?? 'N/A');
                $template->setValue('Assessor_Phone', $learner_data['assessor_phone'] ?? 'N/A');
                $template->setValue('Assessor_Contact', $learner_data['assessor_phone'] ?? 'N/A');
                
                // Legacy field names (for backward compatibility)
                $template->setValue('Assessor_FirstName', $learner_data['assessor_firstName'] ?? 'N/A');
                $template->setValue('Assessor_LastName', $learner_data['assessor_lastName'] ?? 'N/A');
                $template->setValue('Assessor_FullName', $learner_data['assessor_fullName'] ?? 'N/A');
                $template->setValue('Assessor_Role', $learner_data['assessor_role'] ?? 'N/A');
                $template->setValue('Assessor_ID_Number', $learner_data['assessor_id_number'] ?? 'N/A');
                
                // 2️⃣ Assessor ID Digits (13 placeholders: assessor_id_digit_1 to assessor_id_digit_13)
                $assessor_id_number = $learner_data['assessor_id_number'] ?? '';
                for ($f_aid = 1; $f_aid <= 13; $f_aid++) {
                    $digit_value = $learner_data["assessor_id_digit_$f_aid"] ?? '';
                    
                    if ($digit_value === '' || $digit_value === null) {
                        $digit_value = substr($assessor_id_number, $f_aid - 1, 1);
                    }
                    
                    if ($digit_value === '' || $digit_value === null) {
                        $digit_value = '0';
                    }
                    
                    // PhpWord workaround: treat "0" as "ZERO" to prevent it from being skipped
                    if ($digit_value === '0') {
                        $template->setValue("assessor_id_digit_$f_aid", 'ZERO');
                    } else {
                        $template->setValue("assessor_id_digit_$f_aid", $digit_value);
                    }
                }
                
                // 3️⃣ Assessor Number (31 placeholders: full + 30 character breakdown)
                $assessor_number = $learner_data['assessor_number'] ?? '';
                $template->setValue('Assessor_Number', $assessor_number !== '' ? $assessor_number : 'N/A');
                
                // Character-by-character breakdown (assessor_number_char_1 to assessor_number_char_30)
                for ($f_anum = 1; $f_anum <= 30; $f_anum++) {
                    $char_value = $learner_data["assessor_number_char_$f_anum"] ?? '';
                    
                    if ($char_value === '' || $char_value === null) {
                        $char_value = substr($assessor_number, $f_anum - 1, 1);
                    }
                    
                    if ($char_value === '' || $char_value === null) {
                        $char_value = ' ';
                    }
                    
                    // PhpWord workaround: treat "0" as "ZERO" to prevent it from being skipped
                    if ($char_value === '0') {
                        $template->setValue("assessor_number_char_$f_anum", 'ZERO');
                    } else {
                        $template->setValue("assessor_number_char_$f_anum", $char_value);
                    }
                }
                
                // 4️⃣ Registration (removed - not needed)
                $template->setValue('Assessor_Registration', 'N/A');
                $template->setValue('Assessor_Registration_Number', 'N/A');
                
                // 5️⃣ Expiry Date (13 placeholders: 3 full dates + 10 character breakdown)
                $assessor_expiry_date = $learner_data['assessor_expiry_date'] ?? '';
                
                // Full date formats
                $template->setValue('Assessor_End_Date', $assessor_expiry_date !== '' ? $assessor_expiry_date : 'N/A');
                $template->setValue('Assessor_Expiry_Date', $assessor_expiry_date !== '' ? $assessor_expiry_date : 'N/A');
                $template->setValue('assessor_expiry_date', $assessor_expiry_date !== '' ? $assessor_expiry_date : 'N/A');
                
                // Character-by-character breakdown for DD/MM/YYYY format (assessor_expiry_char_1 to assessor_expiry_char_10)
                // Convert date to DD/MM/YYYY format if needed
                $expiry_formatted = '';
                if ($assessor_expiry_date !== '' && $assessor_expiry_date !== 'N/A') {
                    try {
                        $date_obj = new DateTime($assessor_expiry_date);
                        $expiry_formatted = $date_obj->format('d/m/Y'); // DD/MM/YYYY
                    } catch (Exception $e) {
                        $expiry_formatted = $assessor_expiry_date;
                    }
                } else {
                    $expiry_formatted = '  /  /    '; // 10 spaces for empty date
                }
                
                // Remove slashes for character extraction (DDMMYYYY = 8 chars, but we need 10 with slashes)
                for ($f_aexp = 1; $f_aexp <= 10; $f_aexp++) {
                    $char_value = $learner_data["assessor_expiry_char_$f_aexp"] ?? '';
                    
                    if ($char_value === '' || $char_value === null) {
                        $char_value = substr($expiry_formatted, $f_aexp - 1, 1);
                    }
                    
                    if ($char_value === '' || $char_value === null) {
                        $char_value = '0';
                    }
                    
                    // PhpWord workaround: treat "0" as "ZERO" to prevent it from being skipped
                    if ($char_value === '0') {
                        $template->setValue("assessor_expiry_char_$f_aexp", 'ZERO');
                    } else {
                        $template->setValue("assessor_expiry_char_$f_aexp", $char_value);
                    }
                }
                
                // ========================================
                // END OF ASSESSOR PLACEHOLDERS (67 total)
                // ========================================
                
                // Add learner signature image
                log_message("Learner signature from DB: " . ($learner_data['signaturePath'] ?? 'NULL'));
                $learner_signature_path = findSignatureImage(
                    $learner_data['signaturePath'], 
                    $learner_data['LearnerID'], 
                    'learner'
                );
                log_message("Resolved learner signature path: " . ($learner_signature_path ?? 'NULL'));
                if ($learner_signature_path) {
                    $template->setImageValue('learner_signature', [
                        'src' => $learner_signature_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("Learner signature image added: $learner_signature_path");
                } else {
                    $template->setValue('learner_signature', 'N/A');
                    log_message("No learner signature found: " . ($learner_data['signaturePath'] ?? 'null'));
                }
                
                // Add witness signature image (use actual witness_signature field, fallback to random classmate)
                $witness_sig_field = $learner_data['witness_signature'] ?? $learner_data['witnessSignaturePath'] ?? null;
                $witness_signature_path = findSignatureImage(
                    $witness_sig_field, 
                    null, // Don't use learner's own ID for witness signature
                    'witness'
                );
                if ($witness_signature_path) {
                    $template->setImageValue('witness_signature', [
                        'src' => $witness_signature_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("Witness signature image added: $witness_signature_path (from field: $witness_sig_field)");
                } else {
                    $template->setValue('witness_signature', 'N/A');
                    log_message("No witness signature found: witness_signature=" . ($learner_data['witness_signature'] ?? 'null') . ", witnessSignaturePath=" . ($learner_data['witnessSignaturePath'] ?? 'null'));
                }
                
                // Add SDP signature image
                log_message("Form - Looking for SDP signature_image: " . ($learner_data['signature_image'] ?? 'null'));
                $sdp_signature_path = findSignatureImage(
                    $learner_data['signature_image'], 
                    null, 
                    'sdp'
                );
                if ($sdp_signature_path) {
                    $template->setImageValue('sdp_signature_image', [
                        'src' => $sdp_signature_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("SDP signature image added to form: $sdp_signature_path");
                } else {
                    $template->setValue('sdp_signature_image', 'N/A');
                    log_message("No SDP signature found for form, signature_image: " . ($learner_data['signature_image'] ?? 'null'));
                }
                
                // SDP initials are TEXT, not images - already set above as text placeholder
                // No need to process as image
                log_message("Form - SDP initials (text): " . ($learner_data['sdp_initials'] ?? 'N/A'));
                
                // Add SDP witness signature image
                log_message("Form - Looking for SDP witness signature: " . ($learner_data['sdp_witness_signature'] ?? 'null'));
                $sdp_witness_signature_path = findSignatureImage(
                    $learner_data['sdp_witness_signature'], 
                    null, 
                    'sdp'
                );
                if ($sdp_witness_signature_path) {
                    $template->setImageValue('sdp_witness_signature_image', [
                        'src' => $sdp_witness_signature_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("SDP witness signature image added to form: $sdp_witness_signature_path");
                } else {
                    $template->setValue('sdp_witness_signature_image', 'N/A');
                    log_message("No SDP witness signature found for form");
                }
                
                // SDP witness initials are TEXT, not images - already set above as text placeholder
                // No need to process as image
                log_message("Form - SDP witness initials (text): " . ($learner_data['sdp_witness_initials'] ?? 'N/A'));
                
                // Add client signature image
                log_message("Form - Looking for client signature: " . ($learner_data['client_signature'] ?? 'null'));
                $client_signature_path = findSignatureImage(
                    $learner_data['client_signature'], 
                    null, 
                    'client'
                );
                if ($client_signature_path) {
                    $template->setImageValue('client_signature', [
                        'src' => $client_signature_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("Client signature image added to form: $client_signature_path");
                } else {
                    $template->setValue('client_signature', 'N/A');
                    log_message("No client signature found for form");
                }
                
                // Add client initials image
                log_message("Form - Looking for client initials: " . ($learner_data['client_initials'] ?? 'null'));
                $client_initials_path = findSignatureImage(
                    $learner_data['client_initials'], 
                    null, 
                    'client'
                );
                if ($client_initials_path) {
                    $template->setImageValue('client_initials', [
                        'src' => $client_initials_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("Client initials image added to form: $client_initials_path");
                } else {
                    $template->setValue('client_initials', 'N/A');
                    log_message("No client initials found for form");
                }
                
                // Add client witness signature image
                log_message("Form - Looking for client witness signature: " . ($learner_data['client_witness_signature'] ?? 'null'));
                $client_witness_signature_path = findSignatureImage(
                    $learner_data['client_witness_signature'], 
                    null, 
                    'client_witness'
                );
                if ($client_witness_signature_path) {
                    $template->setImageValue('client_witness_signature', [
                        'src' => $client_witness_signature_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("Client witness signature image added to form: $client_witness_signature_path");
                } else {
                    $template->setValue('client_witness_signature', 'N/A');
                    log_message("No client witness signature found for form");
                }
                
                // Add client witness initials image
                log_message("Form - Looking for client witness initials: " . ($learner_data['client_witness_initials'] ?? 'null'));
                $client_witness_initials_path = findSignatureImage(
                    $learner_data['client_witness_initials'], 
                    null, 
                    'client_witness'
                );
                if ($client_witness_initials_path) {
                    $template->setImageValue('client_witness_initials', [
                        'src' => $client_witness_initials_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("Client witness initials image added to form: $client_witness_initials_path");
                } else {
                    $template->setValue('client_witness_initials', 'N/A');
                    log_message("No client witness initials found for form");
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
$template_path = __DIR__ . '/agreement/Cleaned_Updated_Agreement_jcp.docx';
if (!file_exists($template_path)) {
    log_message("Main template file missing: $template_path");
    sendErrorResponse("Main template file missing.", 404);
}
if (!isValidDocx($template_path)) {
    log_message("Main template is not a valid DOCX file: $template_path");
    sendErrorResponse("Main template is not a valid DOCX file.", 400);
}

// Set up output directory (server location)
$output_dir = __DIR__ . '/agreement/today/';
if (!is_dir($output_dir)) {
    mkdir($output_dir, 0755, true);
    chmod($output_dir, 0755);
}
if (!is_writable($output_dir)) {
    log_message("Output directory is not writable: $output_dir");
    sendErrorResponse("Output directory is not writable.", 500);
}

// Set up Desktop directory (local copy)
// Get user's home directory and create Desktop path
$home_dir = getenv('USERPROFILE') ?: getenv('HOME'); // Windows or Linux/Mac
$desktop_dir = $home_dir . DIRECTORY_SEPARATOR . 'Desktop' . DIRECTORY_SEPARATOR . 'RLMS_Documents' . DIRECTORY_SEPARATOR;
if (!is_dir($desktop_dir)) {
    mkdir($desktop_dir, 0755, true);
    log_message("Created Desktop directory: $desktop_dir");
}
$desktop_enabled = is_dir($desktop_dir) && is_writable($desktop_dir);
if ($desktop_enabled) {
    log_message("Desktop save enabled: $desktop_dir");
} else {
    log_message("Desktop save disabled - directory not writable or doesn't exist");
}

// Check if LearnerID or IDNumbers is provided (support both GET and POST)
$LearnerID = $_REQUEST['LearnerID'] ?? null;
$IDNumbers = $_REQUEST['IDNumbers'] ?? null;

// Handle chunked processing for large downloads
$isChunkedRequest = isset($_REQUEST['chunk_mode']) && $_REQUEST['chunk_mode'] === '1';
$chunkNumber = isset($_REQUEST['chunk_number']) ? (int)$_REQUEST['chunk_number'] : 1;
$chunkSize = isset($_REQUEST['chunk_size']) ? (int)$_REQUEST['chunk_size'] : 50;

// Batched bulk processor passes global chunk number + session id for unique ZIP naming
$batchChunkNumber = isset($_REQUEST['batch_chunk_number']) ? (int)$_REQUEST['batch_chunk_number'] : 0;
$batchTotalChunks = isset($_REQUEST['batch_total_chunks']) ? (int)$_REQUEST['batch_total_chunks'] : 0;
$batchSessionId = isset($_REQUEST['batch_session_id']) ? preg_replace('/[^a-zA-Z0-9_]/', '', $_REQUEST['batch_session_id']) : '';
$isBatchedDownload = ($batchChunkNumber > 0 && $batchTotalChunks > 0 && $batchSessionId !== '');

if ($isChunkedRequest && $IDNumbers) {
    // Process IDNumbers in chunks
    $idNumbersArray = array_filter(array_map('trim', explode(',', $IDNumbers)));
    $totalLearners = count($idNumbersArray);
    $totalChunks = ceil($totalLearners / $chunkSize);
    
    // Calculate chunk boundaries
    $startIndex = ($chunkNumber - 1) * $chunkSize;
    $endIndex = min($startIndex + $chunkSize, $totalLearners);
    $chunkIdNumbers = array_slice($idNumbersArray, $startIndex, $chunkSize);
    
    log_message("Processing chunk $chunkNumber of $totalChunks (learners $startIndex to $endIndex of $totalLearners)");
    
    // Override IDNumbers with chunk data
    $IDNumbers = implode(',', $chunkIdNumbers);
    
    // Set special output directory for chunks
    $output_dir = 'agreement/today/chunk_' . $chunkNumber . '_' . date('Ymd_His') . '/';
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
        COALESCE(NULLIF(TRIM(ld.signature), ''), lc_sig.signature, '') AS signaturePath,
        CONCAT(UPPER(LEFT(ld.Name,1)), UPPER(LEFT(ld.Surname,1))) AS learner_initials,
        ld.witness_signature,
        ld.witness_initials,
        ld.PhoneNumber,
        (SELECT MIN(DATE(clock_date)) FROM learner_clocking WHERE LearnerID = ld.LearnerID) AS first_clock_date, 
        p.project_pathway,
        p.pathway_stipends,
        p.pathway_stipend_types,
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
        s.sdp_initials,
        s.sdp_witness_signature,
        s.sdp_witness_initials,
        s.contact_person,
        s.contact_number,
        s.city,
        s.postal_code,
        s.p_address AS sdp_physical_address,
        s.email AS sdp_email,
        qa.qa_body_name,
        qa.accreditation_number,
        qa.skill_programme_id,
        COALESCE(emp.employer_name, 'N/A') AS client_name,
        COALESCE(emp.contact_tel_number, 'N/A') AS client_phone,
        COALESCE(emp.contact_cell_number, emp.contact_tel_number, 'N/A') AS client_cell,
        COALESCE(emp.contact_cell_number, 'N/A') AS contact_number,
        COALESCE(CONCAT(emp.contact_person_name, ' ', emp.contact_person_surname), 'N/A') AS contact_person,
        COALESCE(emp.contact_email, 'N/A') AS client_email,
        COALESCE(emp.physical_address_line1, 'N/A') AS client_address,
        COALESCE(emp.physical_city, 'N/A') AS client_city,
        COALESCE(emp.physical_postal_code, 'N/A') AS client_postal_code,
        emp.provider_signature AS client_signature,
        emp.provider_initials AS client_initials,
        emp.witness_signature AS client_witness_signature,
        emp.witness_initials AS client_witness_initials,
        COALESCE(f.firstName, 'N/A') AS assessor_firstName,
        COALESCE(f.lastName, 'N/A') AS assessor_lastName,
        COALESCE(CONCAT(f.firstName, ' ', f.lastName), 'N/A') AS assessor_fullName,
        COALESCE(f.role, 'N/A') AS assessor_role,
        COALESCE(LPAD(f.assessorNo, 8, '0'), 'N/A') AS assessor_number,
        COALESCE(LPAD(f.f_IDNumber, 13, '0'), 'N/A') AS assessor_id_number,
        COALESCE(f.email, 'N/A') AS assessor_email,
        COALESCE(f.phoneNumber, 'N/A') AS assessor_phone,
        COALESCE(f.assessorExpiryDate, 'N/A') AS assessor_expiry_date,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 1, 1), '0') AS assessor_id_digit_1,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 2, 1), '0') AS assessor_id_digit_2,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 3, 1), '0') AS assessor_id_digit_3,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 4, 1), '0') AS assessor_id_digit_4,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 5, 1), '0') AS assessor_id_digit_5,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 6, 1), '0') AS assessor_id_digit_6,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 7, 1), '0') AS assessor_id_digit_7,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 8, 1), '0') AS assessor_id_digit_8,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 9, 1), '0') AS assessor_id_digit_9,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 10, 1), '0') AS assessor_id_digit_10,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 11, 1), '0') AS assessor_id_digit_11,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 12, 1), '0') AS assessor_id_digit_12,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 13, 1), '0') AS assessor_id_digit_13,
        COALESCE(ld.Race, 'N/A') AS Race,
        COALESCE(ld.Disability, 'N/A') AS Disability,
        COALESCE(CONCAT(ld.AddressLine1, ', ', ld.AddressLine2, ', ', ld.AddressLine3), 'N/A') AS full_address,
        COALESCE(ld.PostalCode, 'N/A') AS PostalCode,
        COALESCE(ld.KinName, 'N/A') AS KinName,
        COALESCE(ld.KinContact, 'N/A') AS KinContact,
        COALESCE(ld.Email, 'N/A') AS Email,
        COALESCE(site.Municipality, 'N/A') AS Municipality,
        COALESCE(ld.SchoolName, 'N/A') AS SchoolName,
        COALESCE(ld.SchoolLocation, 'N/A') AS SchoolLocation,
        COALESCE(ld.SchoolCompletion, 'N/A') AS SchoolCompletion,
        COALESCE(ld.SchoolGrade, 'N/A') AS SchoolGrade,
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
            LEFT JOIN class c2 ON ld2.classID = c2.classID 
            WHERE c2.classID = c.classID 
            AND ld2.signature IS NOT NULL
            AND ld2.LearnerID != ld.LearnerID
            ORDER BY RAND()
            LIMIT 1
        ) AS witnessSignaturePath
    FROM learnerdetails ld
    LEFT JOIN class c ON ld.classID = c.classID
    LEFT JOIN sites site ON c.siteID = site.siteID
    LEFT JOIN qualification q ON q.qualification_id = site.qualification_id
    LEFT JOIN project p ON p.project_id = site.project_id
    LEFT JOIN sdp s ON p.sdp_name = s.sdp_name
    LEFT JOIN sdp_provider_projects spp ON spp.project_id = p.project_id
    LEFT JOIN sdp_provider_details emp ON emp.id = spp.sdp_provider_id
    LEFT JOIN qa_details qa ON qa.project_id = p.project_id 
    LEFT JOIN learningpathway lp ON lp.pathway_id = qa.pathway_id
    AND qa.qualification_id = q.qualification_id
    AND TRIM(LOWER(lp.name)) = TRIM(LOWER(site.Project_pathway))
    LEFT JOIN facilitator f ON f.role = 'Assessor' AND FIND_IN_SET(c.classID, f.classID) > 0
    LEFT JOIN (
        SELECT LearnerID, MAX(signature) AS signature
        FROM learner_clocking
        WHERE NULLIF(TRIM(signature), '') IS NOT NULL
        GROUP BY LearnerID
    ) lc_sig ON lc_sig.LearnerID = ld.LearnerID
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
                COALESCE(NULLIF(TRIM(ld.signature), ''), lc_sig.signature, '') AS signaturePath,
                CONCAT(UPPER(LEFT(ld.Name,1)), UPPER(LEFT(ld.Surname,1))) AS learner_initials,
        ld.witness_signature,
        ld.witness_initials,
        ld.PhoneNumber, 
                p.project_pathway,
                p.pathway_stipends,
                p.pathway_stipend_types,
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
                s.sdp_initials,
                s.sdp_witness_signature,
                s.sdp_witness_initials,
                s.contact_person,
                s.contact_number,
                s.city,
                s.postal_code,
        s.p_address AS sdp_physical_address,
        s.email AS sdp_email,
                qa.qa_body_name,COALESCE(emp.employer_name, 'N/A') AS client_name,
        COALESCE(emp.contact_tel_number, 'N/A') AS client_phone,
        COALESCE(emp.contact_cell_number, emp.contact_tel_number, 'N/A') AS client_cell,
        COALESCE(emp.contact_cell_number, 'N/A') AS contact_number,
        COALESCE(CONCAT(emp.contact_person_name, ' ', emp.contact_person_surname), 'N/A') AS contact_person,
        COALESCE(emp.contact_email, 'N/A') AS client_email,
        COALESCE(emp.physical_address_line1, 'N/A') AS client_address,
        COALESCE(emp.physical_city, 'N/A') AS client_city,
        COALESCE(emp.physical_postal_code, 'N/A') AS client_postal_code,
        emp.provider_signature AS client_signature,
        emp.provider_initials AS client_initials,
        emp.witness_signature AS client_witness_signature,
        emp.witness_initials AS client_witness_initials,
        COALESCE(f.firstName, 'N/A') AS assessor_firstName,
        COALESCE(f.lastName, 'N/A') AS assessor_lastName,
        COALESCE(CONCAT(f.firstName, ' ', f.lastName), 'N/A') AS assessor_fullName,
        COALESCE(f.role, 'N/A') AS assessor_role,
        COALESCE(LPAD(f.assessorNo, 8, '0'), 'N/A') AS assessor_number,
        COALESCE(LPAD(f.f_IDNumber, 13, '0'), 'N/A') AS assessor_id_number,
        COALESCE(f.email, 'N/A') AS assessor_email,
        COALESCE(f.phoneNumber, 'N/A') AS assessor_phone,
        COALESCE(f.assessorExpiryDate, 'N/A') AS assessor_expiry_date,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 1, 1), '0') AS assessor_id_digit_1,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 2, 1), '0') AS assessor_id_digit_2,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 3, 1), '0') AS assessor_id_digit_3,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 4, 1), '0') AS assessor_id_digit_4,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 5, 1), '0') AS assessor_id_digit_5,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 6, 1), '0') AS assessor_id_digit_6,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 7, 1), '0') AS assessor_id_digit_7,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 8, 1), '0') AS assessor_id_digit_8,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 9, 1), '0') AS assessor_id_digit_9,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 10, 1), '0') AS assessor_id_digit_10,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 11, 1), '0') AS assessor_id_digit_11,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 12, 1), '0') AS assessor_id_digit_12,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 13, 1), '0') AS assessor_id_digit_13,
                qa.accreditation_number
            FROM learnerdetails ld
            LEFT JOIN class c ON ld.classID = c.classID
            LEFT JOIN sites site ON c.siteID = site.siteID
            LEFT JOIN qualification q ON q.qualification_id = site.qualification_id
            LEFT JOIN project p ON p.project_id = site.project_id
            LEFT JOIN sdp s ON p.sdp_name = s.sdp_name
            LEFT JOIN sdp_provider_projects spp ON spp.project_id = p.project_id
    LEFT JOIN sdp_provider_details emp ON emp.id = spp.sdp_provider_id
            LEFT JOIN qa_details qa ON qa.project_id = p.project_id 
            LEFT JOIN learningpathway lp ON lp.pathway_id = qa.pathway_id
            AND qa.qualification_id = q.qualification_id
            AND TRIM(LOWER(lp.name)) = TRIM(LOWER(site.Project_pathway))
            LEFT JOIN facilitator f ON f.role = 'Assessor' AND FIND_IN_SET(c.classID, f.classID) > 0
            LEFT JOIN (
                SELECT LearnerID, MAX(signature) AS signature
                FROM learner_clocking
                WHERE NULLIF(TRIM(signature), '') IS NOT NULL
                GROUP BY LearnerID
            ) lc_sig ON lc_sig.LearnerID = ld.LearnerID
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
            $data['pathway_name'] = $data['pathway_name'] ?? ' ';
            $data['qualification_id'] = $data['qualification_id'] ?? ' ';
            $data['qualification_name'] = $data['qualification_name'] ?? ' ';
            $data['total_credits'] = $data['total_credits'] ?? ' ';
            $data['nqf_level'] = $data['nqf_level'] ?? ' ';
            $data['sdp_name'] = $data['sdp_name'] ?? ' ';
            $data['qa_body_name'] = $data['qa_body_name'] ?? ' ';
            $data['accreditation_number'] = $data['accreditation_number'] ?? ' ';
            $data['skill_programme_id'] = $data['skill_programme_id'] ?? ' ';
            $data['project_id'] = $data['project_id'] ?? ' ';
            $data['project_pathway'] = $data['project_pathway'] ?? ' ';
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
    SELECT DISTINCT
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
        COALESCE(
            NULLIF(TRIM(ld.signature), ''),
            (SELECT MAX(signature) 
             FROM learner_clocking 
             WHERE LearnerID = ld.LearnerID 
               AND NULLIF(TRIM(signature), '') IS NOT NULL),
            ''
        ) AS signaturePath,
        CONCAT(UPPER(LEFT(ld.Name,1)), UPPER(LEFT(ld.Surname,1))) AS learner_initials,
        ld.witness_signature,
        ld.witness_initials,
        ld.PhoneNumber,
        (SELECT MIN(DATE(clock_date)) FROM learner_clocking WHERE LearnerID = ld.LearnerID) AS first_clock_date, 
        p.project_pathway,
        p.pathway_stipends,
        p.pathway_stipend_types,
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
        s.sdp_initials,
        s.sdp_witness_signature,
        s.sdp_witness_initials,
        s.contact_person,
        s.contact_number,
        s.city,
        s.postal_code,
        s.p_address AS sdp_physical_address,
        s.email AS sdp_email,
        qa.qa_body_name,
        qa.accreditation_number,
        qa.skill_programme_id,
        COALESCE(emp.employer_name, 'N/A') AS client_name,
        COALESCE(emp.contact_tel_number, 'N/A') AS client_phone,
        COALESCE(emp.contact_cell_number, emp.contact_tel_number, 'N/A') AS client_cell,
        COALESCE(emp.contact_cell_number, 'N/A') AS contact_number,
        COALESCE(CONCAT(emp.contact_person_name, ' ', emp.contact_person_surname), 'N/A') AS contact_person,
        COALESCE(emp.contact_email, 'N/A') AS client_email,
        COALESCE(emp.physical_address_line1, 'N/A') AS client_address,
        COALESCE(emp.physical_city, 'N/A') AS client_city,
        COALESCE(emp.physical_postal_code, 'N/A') AS client_postal_code,
        emp.provider_signature AS client_signature,
        emp.provider_initials AS client_initials,
        emp.witness_signature AS client_witness_signature,
        emp.witness_initials AS client_witness_initials,
        COALESCE(f.firstName, 'N/A') AS assessor_firstName,
        COALESCE(f.lastName, 'N/A') AS assessor_lastName,
        COALESCE(CONCAT(f.firstName, ' ', f.lastName), 'N/A') AS assessor_fullName,
        COALESCE(f.role, 'N/A') AS assessor_role,
        COALESCE(LPAD(f.assessorNo, 8, '0'), 'N/A') AS assessor_number,
        COALESCE(LPAD(f.f_IDNumber, 13, '0'), 'N/A') AS assessor_id_number,
        COALESCE(f.email, 'N/A') AS assessor_email,
        COALESCE(f.phoneNumber, 'N/A') AS assessor_phone,
        COALESCE(f.assessorExpiryDate, 'N/A') AS assessor_expiry_date,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 1, 1), '0') AS assessor_id_digit_1,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 2, 1), '0') AS assessor_id_digit_2,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 3, 1), '0') AS assessor_id_digit_3,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 4, 1), '0') AS assessor_id_digit_4,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 5, 1), '0') AS assessor_id_digit_5,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 6, 1), '0') AS assessor_id_digit_6,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 7, 1), '0') AS assessor_id_digit_7,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 8, 1), '0') AS assessor_id_digit_8,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 9, 1), '0') AS assessor_id_digit_9,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 10, 1), '0') AS assessor_id_digit_10,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 11, 1), '0') AS assessor_id_digit_11,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 12, 1), '0') AS assessor_id_digit_12,
        COALESCE(SUBSTRING(LPAD(f.f_IDNumber, 13, '0'), 13, 1), '0') AS assessor_id_digit_13,
        COALESCE(ld.Race, 'N/A') AS Race,
        COALESCE(ld.Disability, 'N/A') AS Disability,
        COALESCE(CONCAT(ld.AddressLine1, ', ', ld.AddressLine2, ', ', ld.AddressLine3), 'N/A') AS full_address,
        COALESCE(ld.PostalCode, 'N/A') AS PostalCode,
        COALESCE(ld.KinName, 'N/A') AS KinName,
        COALESCE(ld.KinContact, 'N/A') AS KinContact,
        COALESCE(ld.Email, 'N/A') AS Email,
        COALESCE(site.Municipality, 'N/A') AS Municipality,
        COALESCE(ld.SchoolName, 'N/A') AS SchoolName,
        COALESCE(ld.SchoolLocation, 'N/A') AS SchoolLocation,
        COALESCE(ld.SchoolCompletion, 'N/A') AS SchoolCompletion,
        COALESCE(ld.SchoolGrade, 'N/A') AS SchoolGrade,
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
    LEFT JOIN class c ON ld.classID = c.classID
    LEFT JOIN sites site ON c.siteID = site.siteID
    LEFT JOIN qualification q ON q.qualification_id = site.qualification_id
    LEFT JOIN project p ON p.project_id = site.project_id
    LEFT JOIN sdp s ON p.sdp_name = s.sdp_name
    LEFT JOIN sdp_provider_projects spp ON spp.project_id = p.project_id
    LEFT JOIN sdp_provider_details emp ON emp.id = spp.sdp_provider_id
    LEFT JOIN qa_details qa ON qa.project_id = p.project_id 
    LEFT JOIN learningpathway lp ON lp.pathway_id = qa.pathway_id
    AND qa.qualification_id = q.qualification_id
    AND TRIM(LOWER(lp.name)) = TRIM(LOWER(site.Project_pathway))
    LEFT JOIN facilitator f ON f.role = 'Assessor' AND FIND_IN_SET(c.classID, f.classID) > 0
    LEFT JOIN (
        SELECT LearnerID, MAX(signature) AS signature
        FROM learner_clocking
        WHERE NULLIF(TRIM(signature), '') IS NOT NULL
        GROUP BY LearnerID
    ) lc_sig ON lc_sig.LearnerID = ld.LearnerID
    WHERE ld.IDNumber IN ($placeholders)
    GROUP BY ld.LearnerID, ld.IDNumber
    ORDER BY ld.LearnerID";

    try {
        log_message("Executing query for IDNumbers: $IDNumbers (expecting " . count($idNumbersArray) . " unique results)");
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
        
        // Populate default values for learners with missing data (CRITICAL FIX FOR 53 LEARNERS)
        foreach ($learners as &$learner) {
            $learnerID = $learner['LearnerID'] ?? 'Unknown';
            $missingFields = [];
            
            // Check and populate missing fields with "N/A" or defaults
            if (empty($learner['pathway_name']) || $learner['pathway_name'] === null) {
                $learner['pathway_name'] = 'Short Skills Programme';
                $missingFields[] = 'pathway_name';
            }
            if (empty($learner['qualification_id']) || $learner['qualification_id'] === null) {
                $learner['qualification_id'] = 'N/A';
                $missingFields[] = 'qualification_id';
            }
            if (empty($learner['qualification_name']) || $learner['qualification_name'] === null) {
                $learner['qualification_name'] = 'Not Assigned';
                $missingFields[] = 'qualification_name';
            }
            if (empty($learner['total_credits']) || $learner['total_credits'] === null) {
                $learner['total_credits'] = 'N/A';
                $missingFields[] = 'total_credits';
            }
            if (empty($learner['nqf_level']) || $learner['nqf_level'] === null) {
                $learner['nqf_level'] = 'N/A';
                $missingFields[] = 'nqf_level';
            }
            if (empty($learner['sdp_name']) || $learner['sdp_name'] === null) {
                $learner['sdp_name'] = 'N/A';
                $missingFields[] = 'sdp_name';
            }
            if (empty($learner['qa_body_name']) || $learner['qa_body_name'] === null) {
                $learner['qa_body_name'] = 'N/A';
                $missingFields[] = 'qa_body_name';
            }
            if (empty($learner['accreditation_number']) || $learner['accreditation_number'] === null) {
                $learner['accreditation_number'] = 'N/A';
                $missingFields[] = 'accreditation_number';
            }
            if (empty($learner['skill_programme_id']) || $learner['skill_programme_id'] === null) {
                $learner['skill_programme_id'] = 'N/A';
                $missingFields[] = 'skill_programme_id';
            }
            if (empty($learner['project_id']) || $learner['project_id'] === null) {
                $learner['project_id'] = 'N/A';
                $missingFields[] = 'project_id';
            }
            if (empty($learner['Project_name']) || $learner['Project_name'] === null) {
                $learner['Project_name'] = 'Not Assigned';
                $missingFields[] = 'Project_name';
            }
            if (empty($learner['project_pathway']) || $learner['project_pathway'] === null) {
                // Create minimal JSON structure for missing project pathway
                $learner['project_pathway'] = json_encode([[
                    'name' => 'Short Skills Programme',
                    'qual_types' => [[
                        'qual_type' => 'Skills Programme',
                        'qualification' => [
                            'name' => 'Not Assigned',
                            'employment_status' => 'Unemployed 18.2',
                            'unitStandards' => []
                        ]
                    ]]
                ]]);
                $missingFields[] = 'project_pathway';
            }
            
            // Log if learner had missing fields (for debugging)
            if (!empty($missingFields)) {
                log_message("Learner $learnerID had missing fields (populated with defaults): " . implode(', ', $missingFields));
            }
        }
        unset($learner); // Break reference
        
        log_message("Data fetched and enriched: " . count($learners) . " learners ready for PDF generation");
    } catch (Exception $e) {
        log_message("Database error: " . $e->getMessage());
        sendErrorResponse("Database error: " . $e->getMessage(), 500);
    }
} else {
    sendErrorResponse('Missing LearnerID or IDNumbers parameter', 400);
}

log_message("Found " . count($learners) . " learners");

// Log available templates
$available_templates = scanAvailableTemplates();
log_message("Available templates found: " . count($available_templates));
foreach ($available_templates as $name => $path) {
    log_message("Template: $name -> $path");
}

$generatedFiles = [];
$skipped = 0;
$batch_size = 1000;
$processedCount = 0; // Track how many learners we actually process

for ($i = 0; $i < count($learners); $i += $batch_size) {
    $batch = array_slice($learners, $i, $batch_size);
    foreach ($batch as $data) {
        $processedCount++;
        log_message("=== PROCESSING LEARNER $processedCount/" . count($learners) . " ===");
        log_message("LearnerID: {$data['LearnerID']} - IDNumber: {$data['IDNumber']} - Name: {$data['Name']} {$data['Surname']}");

        
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
            
            // Extract and set stipend amount for the selected pathway
            $stipend_amount = 'N/A';
            $stipend_type = 'N/A';
            if (!empty($data['pathway_stipends']) && !empty($data['project_pathway'])) {
                $pathway_stipends_array = array_filter(array_map('trim', explode(',', $data['pathway_stipends'])));
                $pathway_stipend_types_array = !empty($data['pathway_stipend_types']) ? array_filter(array_map('trim', explode(',', $data['pathway_stipend_types']))) : [];
                $pathway_data_decoded = json_decode($data['project_pathway'], true);
                
                if (is_array($pathway_data_decoded)) {
                    // Find the index of the matching pathway
                    $pathway_index = 0;
                    foreach ($pathway_data_decoded as $index => $pathway_item) {
                        if (isset($pathway_item['name']) && trim(strtolower($pathway_item['name'])) === trim(strtolower($pathway_name))) {
                            $pathway_index = $index;
                            break;
                        }
                    }
                    
                    // Get the stipend amount for this pathway
                    if (isset($pathway_stipends_array[$pathway_index])) {
                        $stipend_amount = 'R' . number_format((float)$pathway_stipends_array[$pathway_index], 2);
                    }
                    
                    // Get the stipend type for this pathway
                    if (isset($pathway_stipend_types_array[$pathway_index])) {
                        $stipend_type = ucfirst($pathway_stipend_types_array[$pathway_index]);
                    }
                    
                    log_message("Bulk - Stipend for pathway '$pathway_name' (index $pathway_index): Amount=$stipend_amount, Type=$stipend_type");
                }
            }
            $template->setValue('stipend_amount', $stipend_amount);
            $template->setValue('amount', $stipend_amount);
            $template->setValue('stipend_type', $stipend_type);
            
            $template->setValue('sdp_name', $data['sdp_name'] ?? 'N/A');
            $template->setValue('sdp_initials', $data['sdp_initials'] ?? 'N/A');
            // Note: sdp_witness_signature is set as IMAGE below, not as text
            $template->setValue('sdp_witness_initials', $data['sdp_witness_initials'] ?? 'N/A');
            $template->setValue('sdp_contact_person', $data['contact_person'] ?? 'N/A');
            $template->setValue('sdp_contact_number', $data['contact_number'] ?? 'N/A');
            $template->setValue('sdp_city', $data['city'] ?? 'N/A');
            $template->setValue('sdp_postal_code', $data['postal_code'] ?? 'N/A');
            $template->setValue('sdp_physical_address', $data['sdp_physical_address'] ?? 'N/A');
            $template->setValue('sdp_email', $data['sdp_email'] ?? 'N/A');
            $template->setValue('learner_initials', $data['learner_initials'] ?? 'N/A');
            $template->setValue('witness_initials', $data['witness_initials'] ?? 'N/A');
            // Note: signaturePath and witness_signature are set as IMAGES below, not as text
            // Use first clock date if available, otherwise current date
            $date_to_use = $data['first_clock_date'] ?? date('Y-m-d');
            $formatted_date = date('d F Y', strtotime($date_to_use));
            $template->setValue('Date', $formatted_date);
            $template->setValue('qa_body_name', $data['qa_body_name'] ?? 'N/A');
            $template->setValue('accreditation_number', $data['accreditation_number'] ?? 'N/A');
            $template->setValue('skill_programme_id', $data['skill_programme_id'] ?? 'N/A');
            
            // Get first clock_in date for this learner
            $first_clock_in = getFirstClockInDate($conn, $data['LearnerID']);
            $template->setValue('Employment_Start', $first_clock_in);
            
            // Set demographic placeholders for learner agreement
            $template->setValue('Date_of_Birth', $data['id_derived_dob'] ?? 'N/A');
            $template->setValue('Gender', $data['gender'] ?? 'N/A');
            $template->setValue('Race', $data['Race'] ?? 'N/A');
            $disability = strtolower($data['Disability'] ?? '');
            if ($disability === 'none' || $disability === 'no' || empty($disability)) {
                $template->setValue('Disability', 'N/A');
            } else {
                $template->setValue('Disability', $data['Disability'] ?? 'N/A');
            }
            
            // Set address placeholders for learner agreement
            $template->setValue('Physical_Address', $data['full_address'] ?? 'N/A');
            $template->setValue('Physical_Code', $data['PostalCode'] ?? 'N/A');
            $template->setValue('Alternative_Contact', $data['KinName'] ?? 'N/A');
            $template->setValue('Alternative_Tel', $data['KinContact'] ?? 'N/A');
            $template->setValue('Alternative_Email', $data['Email'] ?? 'N/A');
            
            // Set school information for learner agreement
            $template->setValue('SchoolName', $data['SchoolName'] ?? 'N/A');
            $template->setValue('SchoolLocation', $data['SchoolLocation'] ?? 'N/A');
            $template->setValue('SchoolCompletion', $data['SchoolCompletion'] ?? 'N/A');
            $template->setValue('SchoolGrade', $data['SchoolGrade'] ?? 'N/A');
            
            // Add unit standards using cloneRow for dynamic generation
            if (!empty($unit_standards)) {
                try {
                    // Clone the row for each unit standard
                    $template->cloneRow('unit_standard_id', count($unit_standards));
                    
                    // Set values for each unit standard
                    for ($us_idx = 0; $us_idx < count($unit_standards); $us_idx++) {
                        $template->setValue("unit_standard_id#" . ($us_idx + 1), $unit_standards[$us_idx]['id'] ?? 'N/A');
                        $template->setValue("unit_standard_title#" . ($us_idx + 1), $unit_standards[$us_idx]['title'] ?? 'N/A');
                        $template->setValue("unit_standard_credits#" . ($us_idx + 1), $unit_standards[$us_idx]['credits'] ?? 'N/A');
                        $template->setValue("unit_standard_type#" . ($us_idx + 1), $unit_standards[$us_idx]['s_type'] ?? 'N/A');
                    }
                } catch (Exception $e) {
                    // Fallback to simple placeholder replacement if cloneRow fails
                    log_message("cloneRow failed, using fallback method: " . $e->getMessage());
                    for ($us_idx = 0; $us_idx < min(10, count($unit_standards)); $us_idx++) {
                        $index = $us_idx + 1;
                        $template->setValue("unit_standard_{$index}_id", $unit_standards[$us_idx]['id'] ?? 'N/A');
                        $template->setValue("unit_standard_{$index}_title", $unit_standards[$us_idx]['title'] ?? 'N/A');
                        $template->setValue("unit_standard_{$index}_credits", $unit_standards[$us_idx]['credits'] ?? 'N/A');
                        $template->setValue("unit_standard_{$index}_type", $unit_standards[$us_idx]['s_type'] ?? 'N/A');
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
                    for ($us_n = 1; $us_n <= 10; $us_n++) {
                        $template->setValue("unit_standard_{$us_n}_id", 'N/A');
                        $template->setValue("unit_standard_{$us_n}_title", 'N/A');
                        $template->setValue("unit_standard_{$us_n}_credits", 'N/A');
                        $template->setValue("unit_standard_{$us_n}_type", 'N/A');
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
            $template->setValue('Employer_Cell', $data['client_cell'] ?? $data['client_phone'] ?? 'N/A');
            $template->setValue('Employer_Phone', $data['client_phone'] ?? 'N/A');
            $template->setValue('Contact_Number', $data['contact_number'] ?? 'N/A');
            $template->setValue('Contact_Person', $data['contact_person'] ?? 'N/A');
            $template->setValue('Employer_Email', $data['client_email'] ?? 'N/A');
            $template->setValue('Employer_Address', $data['client_address'] ?? 'N/A');
            $template->setValue('Employer_City', $data['client_city'] ?? 'N/A');
            $template->setValue('Employer_Postal', $data['client_address'] ?? 'N/A');
            $template->setValue('Employer_Physical_Code', $data['client_postal_code'] ?? 'N/A');
            $template->setValue('Employer_Postal_Code', $data['client_postal_code'] ?? 'N/A');

            // Add assessor information
            $template->setValue('Assessor_Name', $data['assessor_firstName'] ?? 'N/A');
            $template->setValue('Assessor_Surname', $data['assessor_lastName'] ?? 'N/A');
            $template->setValue('Assessor_FirstName', $data['assessor_firstName'] ?? 'N/A');
            $template->setValue('Assessor_LastName', $data['assessor_lastName'] ?? 'N/A');
            $template->setValue('Assessor_Full_Name', $data['assessor_fullName'] ?? 'N/A');
            $template->setValue('Assessor_FullName', $data['assessor_fullName'] ?? 'N/A');
            $template->setValue('Assessor_Role', $data['assessor_role'] ?? 'N/A');
            $template->setValue('Assessor_Number', $data['assessor_number'] ?? 'N/A');
            $template->setValue('Assessor_ID_Number', $data['assessor_id_number'] ?? 'N/A');
            $template->setValue('Assessor_ID', $data['assessor_id_number'] ?? 'N/A');

            // Process assessor ID digits
            $assessor_id_number = $data['assessor_id_number'] ?? '';
            for ($aid_digit = 1; $aid_digit <= 13; $aid_digit++) {
                $digit_value = $data["assessor_id_digit_$aid_digit"] ?? '';
                
                if ($digit_value === '' || $digit_value === null) {
                    $digit_value = substr($assessor_id_number, $aid_digit - 1, 1);
                }
                
                if ($digit_value === '' || $digit_value === null) {
                    $digit_value = '0';
                }
                
                if ($digit_value === '0') {
                    $digit_value = '0';
                }
                
                $template->setValue("assessor_id_digit_$aid_digit", $digit_value);
            }

            // Add learner signature image
            $learner_signature_path = findSignatureImage(
                $data['signaturePath'], 
                $data['LearnerID'], 
                'learner'
            );
            if ($learner_signature_path) {
                $template->setImageValue('learner_signature', [
                    'src' => $learner_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
                log_message("Learner signature image added: $learner_signature_path");
            } else {
                $template->setValue('learner_signature', 'N/A');
                log_message("No learner signature found: " . ($data['signaturePath'] ?? 'null'));
            }

            // Add witness signature image (use actual witness_signature field, fallback to random classmate)
            $witness_sig_field = $data['witness_signature'] ?? $data['witnessSignaturePath'] ?? null;
            $witness_signature_path = findSignatureImage(
                $witness_sig_field, 
                null, // Don't use learner's own ID for witness signature
                'witness'
            );
            if ($witness_signature_path) {
                $template->setImageValue('witness_signature', [
                    'src' => $witness_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
                log_message("Witness signature image added: $witness_signature_path (from field: $witness_sig_field)");
            } else {
                $template->setValue('witness_signature', 'N/A');
                log_message("No witness signature found: witness_signature=" . ($data['witness_signature'] ?? 'null') . ", witnessSignaturePath=" . ($data['witnessSignaturePath'] ?? 'null'));
            }

            // Add SDP signature image
            log_message("Looking for SDP signature_image: " . ($data['signature_image'] ?? 'null'));
            $sdp_signature_path = findSignatureImage(
                $data['signature_image'], 
                null, 
                'sdp'
            );
            if ($sdp_signature_path) {
                $template->setImageValue('sdp_signature_image', [
                    'src' => $sdp_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
                log_message("SDP signature image added: $sdp_signature_path");
            } else {
                $template->setValue('sdp_signature_image', 'N/A');
                log_message("No SDP signature found for signature_image: " . ($data['signature_image'] ?? 'null'));
            }

            // Add SDP witness signature image
            log_message("Looking for SDP witness signature: " . ($data['sdp_witness_signature'] ?? 'null'));
            $sdp_witness_signature_path = findSignatureImage(
                $data['sdp_witness_signature'], 
                null, 
                'sdp'
            );
            if ($sdp_witness_signature_path) {
                $template->setImageValue('sdp_witness_signature_image', [
                    'src' => $sdp_witness_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
                log_message("SDP witness signature image added: $sdp_witness_signature_path");
            } else {
                $template->setValue('sdp_witness_signature_image', 'N/A');
                log_message("No SDP witness signature found");
            }

            // Add client signature image
            log_message("Looking for client signature: " . ($data['client_signature'] ?? 'null'));
            $client_signature_path = findSignatureImage(
                $data['client_signature'], 
                null, 
                'client'
            );
            if ($client_signature_path) {
                $template->setImageValue('client_signature', [
                    'src' => $client_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
                log_message("Client signature image added: $client_signature_path");
            } else {
                $template->setValue('client_signature', 'N/A');
                log_message("No client signature found");
            }
            
            // Add client initials image
            log_message("Looking for client initials: " . ($data['client_initials'] ?? 'null'));
            $client_initials_path = findSignatureImage(
                $data['client_initials'], 
                null, 
                'client'
            );
            if ($client_initials_path) {
                $template->setImageValue('client_initials', [
                    'src' => $client_initials_path,
                    'width' => 30,
                    'height' => 20
                ]);
                log_message("Client initials image added: $client_initials_path");
            } else {
                $template->setValue('client_initials', 'N/A');
                log_message("No client initials found");
            }
            
            // Add client witness signature image
            log_message("Looking for client witness signature: " . ($data['client_witness_signature'] ?? 'null'));
            $client_witness_signature_path = findSignatureImage(
                $data['client_witness_signature'], 
                null, 
                'client_witness'
            );
            if ($client_witness_signature_path) {
                $template->setImageValue('client_witness_signature', [
                    'src' => $client_witness_signature_path,
                    'width' => 20,
                    'height' => 30
                ]);
                log_message("Client witness signature image added: $client_witness_signature_path");
            } else {
                $template->setValue('client_witness_signature', 'N/A');
                log_message("No client witness signature found");
            }
            
            // Add client witness initials image
            log_message("Looking for client witness initials: " . ($data['client_witness_initials'] ?? 'null'));
            $client_witness_initials_path = findSignatureImage(
                $data['client_witness_initials'], 
                null, 
                'client_witness'
            );
            if ($client_witness_initials_path) {
                $template->setImageValue('client_witness_initials', [
                    'src' => $client_witness_initials_path,
                    'width' => 30,
                    'height' => 20
                ]);
                log_message("Client witness initials image added: $client_witness_initials_path");
            } else {
                $template->setValue('client_witness_initials', 'N/A');
                log_message("No client witness initials found");
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
                
                // Copy to Desktop if enabled
                copyToDesktop($docxFile, $desktop_dir, $desktop_enabled);
                
            } else {
                log_message("Failed to generate agreement for LearnerID: {$data['LearnerID']}");
                $skipped++;
            }

            // Determine required forms based on funder and qa_body_name
            // Use CASE-INSENSITIVE + TRIMMED comparison (project memory rules) because DB values can be mixed-case or padded
            global $SETAS, $SETA_UPPER_TO_CANONICAL;
            $project_funder = trim($data['Project_funder'] ?? '');
            $qa_body_name = trim($data['qa_body_name'] ?? '');
            $pathway_name = trim($data['pathway_name'] ?? '');
            $required_forms = [];

            // Normalize SETA list to uppercase for case-insensitive in_array lookup
            $SETAS_UPPER = array_map('strtoupper', $SETAS);
            $funder_upper = strtoupper($project_funder);
            $qa_upper = strtoupper($qa_body_name);

            if (!empty($project_funder) && in_array($funder_upper, $SETAS_UPPER, true)) {
                log_message("Project funder is SETA (self-funded): $project_funder");
                $seta_canonical = $SETA_UPPER_TO_CANONICAL[$funder_upper] ?? $project_funder;
                $required_forms = getSETAForms($seta_canonical, $pathway_name);
            } elseif (!empty($qa_body_name) && in_array($qa_upper, $SETAS_UPPER, true)) {
                log_message("qa_body_name is SETA: $qa_body_name");
                $seta_canonical = $SETA_UPPER_TO_CANONICAL[$qa_upper] ?? $qa_body_name;
                $required_forms = getSETAForms($seta_canonical, $pathway_name);
            } else {
                // Neither funder nor QA-body matched a SETA explicitly.
                // FALLBACK: Still generate the 3 standard SETA forms (the default fallback from getSETAForms).
                // Before, we incorrectly returned ['Learner_Agreement'] = 1 item, causing only 2 docs total
                // (agreement + 1 form) even though the standard default is 3 SETA forms.
                log_message("No explicit SETA match for funder='$project_funder' / qa_body='$qa_body_name'. Falling back to 3 standard SETA forms + Learner_Agreement template.");
                $required_forms = [
                    'NEW_SKILLS_PROGRAMME_APPLICATION_FORM',
                    'skills_registration_form',
                    'DoL EEA1 Form',
                    'Learner_Agreement'
                ];
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
log_message("Total files in generatedFiles array: " . count($generatedFiles));
log_message("Generated files: " . json_encode($generatedFiles));
$forceZip = isset($_GET['force_zip']) && $_GET['force_zip'] == '1';
if (!empty($generatedFiles)) {
    // ============================================================
    // PDF CONVERSION WITH LENIENT FALLBACK:
    // - Try hard to convert every DOCX -> PDF (up to 8 retries each)
    // - On success: include the PDF in the download
    // - On failure: include the ORIGINAL DOCX so the user still gets the document
    // - Cancel ONLY if ZERO files were produced (total failure)
    // ============================================================
    // Option: add ?strict_pdf=1 to force the old "cancel if any fail" behaviour
    $strictPdfMode = isset($_GET['strict_pdf']) && $_GET['strict_pdf'] === '1';

    // Step A: Try to convert ALL generated DOCX -> PDF first (with retries)
    $strictFails = [];
    $strictFailsDocxFallback = []; // DOCX files to include as fallback
    $strictPdfMap = [];
    foreach ($generatedFiles as $gfile) {
        if (!file_exists($gfile)) {
            $strictFails[] = basename($gfile) . ' (generated file missing from disk)';
            continue;
        }
        $gext = strtolower(pathinfo($gfile, PATHINFO_EXTENSION));
        if ($gext !== 'docx') {
            // already-pdf / non-docx files pass through
            $strictPdfMap[] = $gfile;
            continue;
        }
        $gotPdf = convertToPdfWithRetries($gfile, $output_dir, 8);
        if ($gotPdf && file_exists($gotPdf) && filesize($gotPdf) > 22) {
            $strictPdfMap[] = $gotPdf;
        } else {
            $strictFails[] = basename($gfile) . ' (PDF conversion failed after 8 retries — DOCX included as fallback)';
            $strictFailsDocxFallback[] = $gfile; // Keep DOCX for fallback inclusion
            log_message("PDF FAIL (lenient): PDF conversion failed for $gfile, will include DOCX instead");
        }
    }
    // Step A.5: Settle pass - wait up to 3s for all PDFs to be stable on disk
    for ($settle = 1; $settle <= 6; $settle++) {
        $allOk = true;
        foreach ($strictPdfMap as $pf) {
            if (!file_exists($pf) || filesize($pf) <= 22) {
                $allOk = false;
                clearstatcache(true, $pf);
            }
        }
        if ($allOk) break;
        usleep(500000);
    }
    // Step A.6: Strict vs Lenient handling
    $strictInputCount = count($generatedFiles);
    $strictPdfCount = count($strictPdfMap);
    $hasAnyOutput = ($strictPdfCount + count($strictFailsDocxFallback)) > 0;

    if ($strictPdfMode && (!empty($strictFails) || $strictPdfCount !== $strictInputCount)) {
        // STRICT MODE ONLY (not default): Cancel entirely if any conversion failed
        foreach ($strictPdfMap as $pp) { @unlink($pp); }
        $msg = "Download CANCELLED — not all documents are PDFs yet (strict mode).\n";
        $msg .= "Progress: $strictPdfCount / $strictInputCount documents successfully converted to PDF.\n";
        if (!empty($strictFails)) {
            $msg .= "Failed forms:\n  - " . implode("\n  - ", $strictFails) . "\n";
        }
        $msg .= "\nTip: Confirm LibreOffice is installed at C:\\Program Files\\LibreOffice\\program\\soffice.exe\n";
        $msg .= "       and try again in 10 seconds (Windows Defender may have been scanning files).\n";
        $msg .= "Log file: $log_file";
        log_message("STRICT PDF MODE: Download aborted -> " . str_replace("\n", " | ", $msg));
        sendErrorResponse($msg, 500);
        exit;
    }

    // LENIENT MODE (default): proceed with download even if some PDFs failed.
    // Include PDFs for successful conversions + DOCX as fallback for failed ones,
    // plus a WARNING.txt explaining what happened.
    if (!$hasAnyOutput) {
        // Catastrophic failure — zero files produced at all
        $msg = "Download FAILED — no documents could be generated.\n";
        $msg .= "Log file: $log_file";
        log_message("COMPLETE FAILURE: No output files generated -> " . str_replace("\n", " | ", $msg));
        sendErrorResponse($msg, 500);
        exit;
    }

    // Build a WARNING.txt readme if there were any partial failures
    $warningFilePath = null;
    if (!empty($strictFails)) {
        $warningContent = "========================================\n";
        $warningContent .= "PARTIAL PDF CONVERSION WARNING\n";
        $warningContent .= "========================================\n\n";
        $warningContent .= "Date: " . date('Y-m-d H:i:s') . "\n";
        $warningContent .= "Successfully converted to PDF: $strictPdfCount / $strictInputCount\n\n";
        if (!empty($strictFails)) {
            $warningContent .= "The following files could NOT be converted to PDF.\n";
            $warningContent .= "The original DOCX file is included instead — you can open\n";
            $warningContent .= "it in Microsoft Word or LibreOffice and use File > Save As PDF:\n\n";
            foreach ($strictFails as $fail) {
                $warningContent .= "  - $fail\n";
            }
        }
        $warningContent .= "\n========================================\n";
        $warningContent .= "TIPS TO FIX PDF CONVERSION:\n";
        $warningContent .= "========================================\n";
        $warningContent .= "1. Try again in 15 seconds (Windows Defender may be scanning files)\n";
        $warningContent .= "2. Ensure LibreOffice is installed at:\n";
        $warningContent .= "   C:\\Program Files\\LibreOffice\\program\\soffice.exe\n";
        $warningContent .= "3. Close any open LibreOffice / Word windows before downloading\n";
        $warningContent .= "4. For strict PDF-only mode, add ?strict_pdf=1 to the URL\n\n";
        $warningContent .= "Log file: $log_file\n";

        $warningFilePath = $output_dir . '_CONVERSION_WARNING_' . date('Ymd_His') . '.txt';
        file_put_contents($warningFilePath, $warningContent);
        log_message("Partial conversion: Wrote warning readme to $warningFilePath with " . count($strictFails) . " failure notes");
    }

    // Final package: PDFs + DOCX fallbacks + warning (if any)
    $finalFilesToPackage = $strictPdfMap;
    if (!empty($strictFailsDocxFallback)) {
        $finalFilesToPackage = array_merge($finalFilesToPackage, $strictFailsDocxFallback);
    }
    if ($warningFilePath && file_exists($warningFilePath)) {
        $finalFilesToPackage[] = $warningFilePath;
    }
    log_message("LENIENT MODE OK: Packaging " . count($finalFilesToPackage) . " files total ("
        . count($strictPdfMap) . " PDFs, "
        . count($strictFailsDocxFallback) . " DOCX fallbacks, "
        . ($warningFilePath ? "1 warning readme" : "0 warnings") . ")");
    
    // ========================================================================
    // STORE PDFs PERMANENTLY for single-learner downloads (CRITICAL FIX)
    // PDFs must be stored in mobile/agreement/pdfs/{LearnerID}/ for lister
    // ========================================================================
    if (count($learners) === 1 && !empty($strictPdfMap)) {
        log_message("SINGLE LEARNER: Storing " . count($strictPdfMap) . " PDFs permanently for lister...");
        
        foreach ($strictPdfMap as $pdfFile) {
            if (!file_exists($pdfFile)) continue;
            
            $filename = basename($pdfFile);
            // Extract learner ID and document type from filename: {LearnerID}_{DocumentType}.pdf
            if (preg_match('/^(\d+)_(.+)\.pdf$/', $filename, $matches)) {
                $learnerID = $matches[1];
                $documentType = str_replace('_', ' ', $matches[2]);
                
                // Get learner details from database
                $learnerStmt = $conn->prepare("
                    SELECT ld.Name as firstname, ld.Surname as surname, p.project_id 
                    FROM learnerdetails ld
                    JOIN class c ON ld.classID = c.classID
                    JOIN sites s ON c.siteID = s.siteID
                    LEFT JOIN project p ON s.project_id = p.project_id
                    WHERE ld.IDNumber = ? 
                    LIMIT 1
                ");
                $learnerStmt->bind_param('s', $learnerID);
                $learnerStmt->execute();
                $learnerResult = $learnerStmt->get_result();
                
                if ($learnerRow = $learnerResult->fetch_assoc()) {
                    $learnerName = trim($learnerRow['firstname'] . ' ' . $learnerRow['surname']);
                    $projectId = $learnerRow['project_id'];
                    
                    // Store PDF permanently using helper function
                    $storeResult = storePdfPermanently(
                        $conn,
                        $pdfFile,
                        $learnerID,
                        $learnerName,
                        $projectId,
                        $documentType,
                        date('Y'),
                        date('m')
                    );
                    
                    if ($storeResult['success']) {
                        log_message("SINGLE LEARNER: PDF stored permanently: " . $storeResult['stored_path'] . " (Type: $documentType)");
                    } else {
                        log_message("SINGLE LEARNER: Failed to store PDF: " . $storeResult['error']);
                    }
                }
                $learnerStmt->close();
            }
        }
        
        log_message("SINGLE LEARNER: PDF storage complete - " . count($strictPdfMap) . " PDFs stored for lister");
    }
    // ========================================================================
    
    // Single-learner single-file shortcut: send raw file directly ONLY if
    // exactly 1 output file AND it's a pure PDF (no DOCX fallbacks, no warnings)
    if (count($learners) === 1 && count($finalFilesToPackage) === 1
        && empty($strictFailsDocxFallback) && empty($warningFilePath) && !$forceZip) {
        $ext = strtolower(pathinfo($finalFilesToPackage[0], PATHINFO_EXTENSION));
        if ($ext === 'pdf') {
            $singleFile = $finalFilesToPackage[0];
            while (ob_get_level()) { ob_end_clean(); }
            header('Content-Description: File Transfer');
            header('Content-Type: application/pdf');
            header('Content-Disposition: attachment; filename="' . basename($singleFile) . '"');
            header('Content-Transfer-Encoding: binary');
            header('Expires: 0');
            header('Cache-Control: must-revalidate');
            header('Pragma: public');
            header('Content-Length: ' . filesize($singleFile));
            readfile($singleFile);
            exit;
        }
    }
    if (count($learners) === 1) {
        try {
            $zip = new ZipArchive();
            $learner_data = $learners[0];
            $safe_id = preg_replace('/[^a-zA-Z0-9]/', '_', $learner_data['IDNumber'] ?? 'learner');
            $zipFileName = $output_dir . $safe_id . "_Documents_" . date('Ymd_His') . ".zip";
            if ($zip->open($zipFileName, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== TRUE) {
                sendErrorResponse("Failed to create ZIP file.", 500);
            }
            // Use finalFilesToPackage: PDFs (converted) + DOCX (fallback) + warning readme
            $filesToAdd = $finalFilesToPackage;
            $docxFilesToCleanup = [];

            log_message("Single-learner ZIP: packaging " . count($filesToAdd) . " files ("
                . count($strictPdfMap) . " PDFs, "
                . count($strictFailsDocxFallback) . " DOCX fallbacks)");

            // Add files to ZIP
            foreach ($filesToAdd as $file) {
                if (file_exists($file)) {
                    $zip->addFile($file, basename($file));
                }
            }
            $zip->close();
            if (file_exists($zipFileName)) {
                while (ob_get_level()) { ob_end_clean(); }
                header('Content-Type: application/zip');
                header('Content-Disposition: attachment; filename="' . basename($zipFileName) . '"');
                header('Content-Length: ' . filesize($zipFileName));
                header('Cache-Control: no-cache, no-store, must-revalidate');
                header('Pragma: no-cache');
                header('Expires: 0');
                readfile($zipFileName);
                exit;
            } else {
                sendErrorResponse("Failed to create ZIP file.", 500);
            }
        } catch (Exception $e) {
            sendErrorResponse("Error creating ZIP file: " . $e->getMessage(), 500);
        }
    } else {
        // ================================================================
        // MULTIPLE LEARNERS: CHUNKED ZIP
        // ================================================================
        // Batched mode (from disk_space_optimized_bulk_processor_batched.php):
        //   - One ZIP per request with global chunk number in filename
        //   - All learners in the request go into that single ZIP (no master wrapper)
        // Normal mode:
        //   - Split into sub-chunks, wrap in master ZIP
        // ================================================================
        try {
            $chunkSize = $isBatchedDownload ? PHP_INT_MAX : 10;
            $docxFilesToCleanup = [];
            $storedPdfInfo = [];

            // ---- Step 1: Build storedPdfInfo for database (unchanged) ----
            foreach ($strictPdfMap as $pdfFile) {
                if (!file_exists($pdfFile)) continue;
                $filename = basename($pdfFile);
                if (preg_match('/^(\d+)_(.+)\.pdf$/', $filename, $matches)) {
                    $storedPdfInfo[] = [
                        'pdf_path' => $pdfFile,
                        'learner_id' => $matches[1],
                        'filename' => $filename,
                        'document_type' => str_replace('_', ' ', $matches[2])
                    ];
                }
            }

            // ---- Step 2: Group files by Learner ID + root-level files ----
            $filesPerLearner = []; // [learnerID => [[diskPath, zipInnerPath], ...]]
            $rootLevelFiles = [];  // files that don't belong to any learner (warning readme etc.)

            foreach ($finalFilesToPackage as $file) {
                if (!file_exists($file)) {
                    log_message("CHUNKED ZIP: File not found on disk, skipping: $file");
                    continue;
                }
                $filename = basename($file);

                // Warning readme -> goes to root of master zip (NOT in any chunk zip)
                if ($warningFilePath && $file === $warningFilePath) {
                    $rootLevelFiles[] = [$file, $filename];
                    log_message("CHUNKED ZIP: Root-level file -> $filename");
                    continue;
                }

                // Extract Learner ID from filename pattern: {LearnerID}_{anything}.{ext}
                if (preg_match('/^(\d+)_/', $filename, $matches)) {
                    $learnerID = $matches[1];
                    if (!isset($filesPerLearner[$learnerID])) {
                        $filesPerLearner[$learnerID] = [];
                    }
                    $zipInner = $learnerID . '/' . $filename;
                    $filesPerLearner[$learnerID][] = [$file, $zipInner];
                } else {
                    // Unrecognized pattern -> treat as root-level inside master zip
                    $rootLevelFiles[] = [$file, $filename];
                    log_message("CHUNKED ZIP: No LearnerID pattern in '$filename' -> root level");
                }
            }

            // ---- Step 3: Build a deterministic ordered list of Learner IDs ----
            // Prefer the order from $learners (database order), then append extras
            $orderedLearnerIDs = [];
            foreach ($learners as $l) {
                $id = strval($l['IDNumber'] ?? $l['LearnerID'] ?? '');
                if ($id !== '' && isset($filesPerLearner[$id]) && !in_array($id, $orderedLearnerIDs, true)) {
                    $orderedLearnerIDs[] = $id;
                }
            }
            // Append any remaining IDs we found in filenames but not in $learners
            foreach (array_keys($filesPerLearner) as $id) {
                if (!in_array($id, $orderedLearnerIDs, true)) {
                    $orderedLearnerIDs[] = $id;
                }
            }

            $totalLearners = count($orderedLearnerIDs);
            $totalChunks = (int)ceil(max(1, $totalLearners) / $chunkSize);

            log_message("=== CHUNKED ZIP CREATION STARTING ===");
            log_message("CHUNKED ZIP: $totalLearners learners -> $totalChunks chunks of up to $chunkSize learners");
            log_message("CHUNKED ZIP: Learner IDs to process: " . implode(', ', $orderedLearnerIDs));
            log_message("CHUNKED ZIP: " . count($filesPerLearner) . " learner IDs found in filenames, "
                . count($rootLevelFiles) . " root-level files");

            // ---- Step 4: Create per-chunk ZIPs (each = up to 10 learner folders) ----
            $chunkZipPaths = [];
            $nowTs = date('Ymd_His');

            for ($chunkIdx = 0; $chunkIdx < $totalChunks; $chunkIdx++) {
                $chunkNumber = $chunkIdx + 1;
                $chunkLearnerIDs = array_slice($orderedLearnerIDs, $chunkIdx * $chunkSize, $chunkSize);
                if (empty($chunkLearnerIDs)) {
                    continue;
                }

                $chunkZipName = $isBatchedDownload
                    ? sprintf(
                        'Project_Agreements_Chunk_%02d_of_%02d_%s.zip',
                        $batchChunkNumber,
                        $batchTotalChunks,
                        $batchSessionId
                    )
                    : sprintf(
                        'Project_Agreements_Chunk_%02d_of_%02d_%s.zip',
                        $chunkNumber,
                        $totalChunks,
                        $nowTs
                    );
                $chunkZipPath = $output_dir . $chunkZipName;

                $chunkZip = new ZipArchive();
                if ($chunkZip->open($chunkZipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== TRUE) {
                    log_message("CHUNKED ZIP: Failed to create chunk zip: $chunkZipPath");
                    sendErrorResponse("Failed to create chunk ZIP file $chunkZipName.", 500);
                }

                $chunkFileCount = 0;
                $chunkLearnerList = [];
                foreach ($chunkLearnerIDs as $lid) {
                    if (!isset($filesPerLearner[$lid])) {
                        continue;
                    }
                    $chunkLearnerList[] = $lid;
                    foreach ($filesPerLearner[$lid] as $entry) {
                        list($diskPath, $zipInner) = $entry;
                        if (file_exists($diskPath)) {
                            // ✅ PHASE 1 ENHANCEMENT: Verify PDF files before adding to ZIP
                            $ext = strtolower(pathinfo($diskPath, PATHINFO_EXTENSION));
                            
                            if ($ext === 'pdf') {
                                // Verify PDF header to ensure it's a valid PDF
                                $handle = @fopen($diskPath, 'r');
                                if ($handle) {
                                    $header = fread($handle, 4);
                                    fclose($handle);
                                    
                                    if (substr($header, 0, 4) !== '%PDF') {
                                        log_message("⚠️ WARNING: File has .pdf extension but invalid PDF header: " . basename($diskPath));
                                        log_message("⚠️ Attempting reconversion from DOCX...");
                                        
                                        // Try to find and reconvert the source DOCX
                                        $docxPath = str_replace('.pdf', '.docx', $diskPath);
                                        if (file_exists($docxPath)) {
                                            $reconvertedPdf = convertToPdfWithRetries($docxPath, dirname($diskPath), 3); // 3 attempts max for reconversion
                                            if ($reconvertedPdf && file_exists($reconvertedPdf)) {
                                                log_message("✅ Reconversion successful, using new PDF");
                                                $diskPath = $reconvertedPdf; // Use the reconverted PDF
                                            } else {
                                                log_message("❌ Reconversion failed, adding original (possibly corrupt) file");
                                            }
                                        } else {
                                            log_message("❌ Source DOCX not found for reconversion: " . basename($docxPath));
                                        }
                                    } else {
                                        log_message("✅ PDF header verified for: " . basename($diskPath));
                                    }
                                } else {
                                    log_message("⚠️ Could not open PDF for header verification: " . basename($diskPath));
                                }
                            } else if ($ext === 'docx') {
                                // DOCX file detected - this means conversion failed completely
                                log_message("⚠️ DOCX file being added to ZIP (PDF conversion failed): " . basename($diskPath));
                            }
                            
                            $chunkZip->addFile($diskPath, $zipInner);
                            $chunkFileCount++;
                        }
                    }
                }

                // Add a tiny manifest text inside the chunk for user clarity
                $manifestText = "Project Agreements - Chunk $chunkNumber / $totalChunks\n";
                $manifestText .= "Generated: " . date('Y-m-d H:i:s') . "\n";
                $manifestText .= "Learners in this chunk (" . count($chunkLearnerList) . "):\n  - "
                    . implode("\n  - ", $chunkLearnerList) . "\n";
                $chunkZip->addFromString('_THIS_CHUNK_manifest.txt', $manifestText);

                $chunkZip->close();
                if (!file_exists($chunkZipPath) || filesize($chunkZipPath) === 0) {
                    log_message("CHUNKED ZIP: Chunk zip empty or missing: $chunkZipPath");
                    sendErrorResponse("Failed to write chunk ZIP $chunkZipName.", 500);
                }

                $chunkZipPaths[] = $chunkZipPath;
                log_message("CHUNKED ZIP: Created chunk $chunkNumber/$totalChunks -> $chunkZipName"
                    . " (" . count($chunkLearnerList) . " learners, $chunkFileCount files, "
                    . filesize($chunkZipPath) . " bytes)");
            }

            if (empty($chunkZipPaths)) {
                log_message("CHUNKED ZIP: No chunk zips were produced");
                sendErrorResponse("No chunk ZIP files could be created.", 500);
            }

            // Batched mode: send the single chunk ZIP directly (no master wrapper)
            if ($isBatchedDownload && count($chunkZipPaths) === 1) {
                $zipToSend = $chunkZipPaths[0];

                if (session_status() === PHP_SESSION_NONE) {
                    session_start();
                }
                if (!isset($_SESSION['chunk_downloads'])) {
                    $_SESSION['chunk_downloads'] = [];
                }
                if (!isset($_SESSION['chunk_downloads'][$batchSessionId])) {
                    $_SESSION['chunk_downloads'][$batchSessionId] = [];
                }
                $_SESSION['chunk_downloads'][$batchSessionId][$batchChunkNumber] = $zipToSend;

                log_message("BATCHED ZIP: Registered chunk $batchChunkNumber/$batchTotalChunks -> " . basename($zipToSend));

                if (!empty($storedPdfInfo)) {
                    log_message("BATCHED ZIP: Storing " . count($storedPdfInfo) . " PDFs permanently on server...");
                    foreach ($storedPdfInfo as $pdfInfo) {
                        $learnerStmt = $conn->prepare("
                            SELECT ld.Name as firstname, ld.Surname as surname, p.project_id 
                            FROM learnerdetails ld
                            JOIN class c ON ld.classID = c.classID
                            JOIN sites s ON c.siteID = s.siteID
                            LEFT JOIN project p ON s.project_id = p.project_id
                            WHERE ld.IDNumber = ? 
                            LIMIT 1
                        ");
                        $learnerStmt->bind_param('s', $pdfInfo['learner_id']);
                        $learnerStmt->execute();
                        $learnerResult = $learnerStmt->get_result();

                        if ($learnerRow = $learnerResult->fetch_assoc()) {
                            $learnerName = trim($learnerRow['firstname'] . ' ' . $learnerRow['surname']);
                            $projectId = $learnerRow['project_id'];
                            $documentType = isset($pdfInfo['document_type']) ? $pdfInfo['document_type'] : 'Agreement';
                            storePdfPermanently(
                                $conn,
                                $pdfInfo['pdf_path'],
                                $pdfInfo['learner_id'],
                                $learnerName,
                                $projectId,
                                $documentType,
                                date('Y'),
                                date('m')
                            );
                        }
                        $learnerStmt->close();
                    }
                }

                if (!empty($docxFilesToCleanup)) {
                    cleanupDocxFiles($docxFilesToCleanup);
                }

                copyToDesktop($zipToSend, $desktop_dir, $desktop_enabled);

                while (ob_get_level()) { ob_end_clean(); }
                header('Content-Type: application/zip');
                header('Content-Disposition: attachment; filename="' . basename($zipToSend) . '"');
                header('Content-Length: ' . filesize($zipToSend));
                header('Cache-Control: no-cache, no-store, must-revalidate');
                header('Pragma: no-cache');
                header('Expires: 0');
                readfile($zipToSend);
                exit;
            }

            // ---- Step 5: Create MASTER ZIP containing all chunk ZIPs ----
            $masterZipName = "Project_Agreements_AllChunks_{$nowTs}.zip";
            $masterZipPath = $output_dir . $masterZipName;

            $masterZip = new ZipArchive();
            if ($masterZip->open($masterZipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== TRUE) {
                log_message("CHUNKED ZIP: Failed to open master archive: $masterZipPath");
                sendErrorResponse("Failed to create master ZIP file.", 500);
            }

            // Add each chunk ZIP to the master
            foreach ($chunkZipPaths as $czp) {
                $masterZip->addFile($czp, basename($czp));
            }

            // Add root-level files (conversion warning readme etc.) to master root
            foreach ($rootLevelFiles as $rfe) {
                list($diskPath, $zipInner) = $rfe;
                if (file_exists($diskPath)) {
                    $masterZip->addFile($diskPath, $zipInner);
                }
            }

            // Master-level manifest
            $masterManifest = "Project Agreements - CHUNKED DOWNLOAD\n";
            $masterManifest .= "Generated: " . date('Y-m-d H:i:s') . "\n";
            $masterManifest .= "Total learners: $totalLearners\n";
            $masterManifest .= "Chunk size: $chunkSize learners per chunk ZIP\n";
            $masterManifest .= "Total chunks: $totalChunks\n\n";
            $masterManifest .= "Chunk ZIP contents:\n";
            for ($i = 0; $i < count($chunkZipPaths); $i++) {
                $chunkNo = $i + 1;
                $learnerSlice = array_slice($orderedLearnerIDs, $i * $chunkSize, $chunkSize);
                $masterManifest .= "  Chunk $chunkNo/$totalChunks  -> " . basename($chunkZipPaths[$i])
                    . "  (" . count($learnerSlice) . " learners: "
                    . implode(', ', $learnerSlice) . ")\n";
            }
            if (!empty($strictFails)) {
                $masterManifest .= "\nPartial PDF conversion warnings:\n  - "
                    . implode("\n  - ", array_slice($strictFails, 0, 20));
                if (count($strictFails) > 20) {
                    $masterManifest .= "\n  (... and " . (count($strictFails) - 20) . " more. See the warning TXT file)\n";
                }
            }
            $masterZip->addFromString('_MASTER_manifest.txt', $masterManifest);

            $masterZip->close();

            if (!file_exists($masterZipPath) || filesize($masterZipPath) === 0) {
                log_message("CHUNKED ZIP: Master zip missing or empty: $masterZipPath");
                sendErrorResponse("Failed to create master ZIP.", 500);
            }

            log_message("CHUNKED ZIP: MASTER ZIP OK -> $masterZipPath ("
                . count($chunkZipPaths) . " chunks, " . filesize($masterZipPath) . " bytes total)");

            // ---- Step 6: Store PDFs permanently on server (original logic, unchanged) ----
            if (!empty($storedPdfInfo)) {
                log_message("CHUNKED ZIP: Storing " . count($storedPdfInfo) . " PDFs permanently on server...");
                foreach ($storedPdfInfo as $pdfInfo) {
                    $learnerStmt = $conn->prepare("
                        SELECT ld.Name as firstname, ld.Surname as surname, p.project_id 
                        FROM learnerdetails ld
                        JOIN class c ON ld.classID = c.classID
                        JOIN sites s ON c.siteID = s.siteID
                        LEFT JOIN project p ON s.project_id = p.project_id
                        WHERE ld.IDNumber = ? 
                        LIMIT 1
                    ");
                    $learnerStmt->bind_param('s', $pdfInfo['learner_id']);
                    $learnerStmt->execute();
                    $learnerResult = $learnerStmt->get_result();
                    
                    if ($learnerRow = $learnerResult->fetch_assoc()) {
                        $learnerName = trim($learnerRow['firstname'] . ' ' . $learnerRow['surname']);
                        $projectId = $learnerRow['project_id'];
                        $documentType = isset($pdfInfo['document_type']) ? $pdfInfo['document_type'] : 'Agreement';
                        $storeResult = storePdfPermanently(
                            $conn,
                            $pdfInfo['pdf_path'],
                            $pdfInfo['learner_id'],
                            $learnerName,
                            $projectId,
                            $documentType,
                            date('Y'),
                            date('m')
                        );
                        if ($storeResult['success']) {
                            log_message("PDF stored permanently: " . $storeResult['stored_path'] . " (Type: $documentType)");
                        } else {
                            log_message("Failed to store PDF permanently: " . $storeResult['error']);
                        }
                    }
                    $learnerStmt->close();
                }
                log_message("CHUNKED ZIP: PDF storage complete - " . count($storedPdfInfo) . " PDFs");
            }

            // ---- Step 7: Cleanup + send the master zip to the user ----
            if (!empty($docxFilesToCleanup)) {
                cleanupDocxFiles($docxFilesToCleanup);
            }

            copyToDesktop($masterZipPath, $desktop_dir, $desktop_enabled);

            while (ob_get_level()) { ob_end_clean(); }
            header('Content-Type: application/zip');
            header('Content-Disposition: attachment; filename="' . basename($masterZipPath) . '"');
            header('Content-Length: ' . filesize($masterZipPath));
            header('Cache-Control: no-cache, no-store, must-revalidate');
            header('Pragma: no-cache');
            header('Expires: 0');
            readfile($masterZipPath);
            exit;

        } catch (Exception $e) {
            log_message("CHUNKED ZIP: Exception -> " . $e->getMessage());
            sendErrorResponse("Error creating chunked ZIP files: " . $e->getMessage(), 500);
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
