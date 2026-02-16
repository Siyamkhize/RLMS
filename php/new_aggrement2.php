<?php
use PhpOffice\PhpWord\TemplateProcessor;
require 'vendor/autoload.php';

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
        // Client signature paths - stored in /Uploads/signature/ folder
        $possiblePaths = [
            $signatureFilename,
            $cleanFilename,
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

// Function to get SETA forms
function getSETAForms($seta_name, $pathway_name = '') {
    // Use only forms that exist in the templates directory
    $seta_form_mappings = [
        'AGRISETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'BANKSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'CATHSSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'CETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'CHIETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'ETDPSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'EWSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'FASSET' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'FOODBEV' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'FP&M SETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'HWSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'INSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'LGSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'MERSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'MICT SETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'MQA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'PSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'SASSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'SERVICES SETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'TETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form'],
        'W&RSETA' => ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM', 'skills_registration_form']
    ];
    
    // Check if it's CETA and Learnership - return ONLY the 3 learnership forms
    if ($seta_name === 'CETA' && !empty($pathway_name)) {
        $pathway_lower = strtolower(trim($pathway_name));
        // Check if it's a Learnership (not Short Skills Programme)
        if (strpos($pathway_lower, 'learnership') !== false || 
            ($pathway_lower !== 'short skills programme' && $pathway_lower !== 'short skills' && $pathway_lower !== 'skills programme')) {
            log_message("CETA Learnership detected for pathway: $pathway_name. Returning ONLY the 3 learnership forms.");
            // Return ONLY the three CETA learnership forms
            return [
                'Learnership-Agreement-v130314',
                'Learnership-Application-Form-v01',
                'Learner_Contract_of_Employment_Template'
            ];
        } else {
            log_message("CETA Short Skills Programme detected for pathway: $pathway_name. Using standard forms.");
        }
    }
    
    // For all other cases, return the standard forms
    $forms = isset($seta_form_mappings[$seta_name]) ? $seta_form_mappings[$seta_name] : ['NEW_SKILLS_PROGRAMME_APPLICATION_FORM'];
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
                for ($i = 1; $i <= 13; $i++) {
                    $digit_value = $learner_data["assessor_id_digit_$i"] ?? '';
                    
                    if ($digit_value === '' || $digit_value === null) {
                        $digit_value = substr($assessor_id_number, $i - 1, 1);
                    }
                    
                    if ($digit_value === '' || $digit_value === null) {
                        $digit_value = '0';
                    }
                    
                    // PhpWord workaround: treat "0" as "ZERO" to prevent it from being skipped
                    if ($digit_value === '0') {
                        $template->setValue("assessor_id_digit_$i", 'ZERO');
                    } else {
                        $template->setValue("assessor_id_digit_$i", $digit_value);
                    }
                }
                
                // 3️⃣ Assessor Number (31 placeholders: full + 30 character breakdown)
                $assessor_number = $learner_data['assessor_number'] ?? '';
                $template->setValue('Assessor_Number', $assessor_number !== '' ? $assessor_number : 'N/A');
                
                // Character-by-character breakdown (assessor_number_char_1 to assessor_number_char_30)
                for ($i = 1; $i <= 30; $i++) {
                    $char_value = $learner_data["assessor_number_char_$i"] ?? '';
                    
                    if ($char_value === '' || $char_value === null) {
                        $char_value = substr($assessor_number, $i - 1, 1);
                    }
                    
                    if ($char_value === '' || $char_value === null) {
                        $char_value = ' ';
                    }
                    
                    // PhpWord workaround: treat "0" as "ZERO" to prevent it from being skipped
                    if ($char_value === '0') {
                        $template->setValue("assessor_number_char_$i", 'ZERO');
                    } else {
                        $template->setValue("assessor_number_char_$i", $char_value);
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
                for ($i = 1; $i <= 10; $i++) {
                    $char_value = $learner_data["assessor_expiry_char_$i"] ?? '';
                    
                    if ($char_value === '' || $char_value === null) {
                        $char_value = substr($expiry_formatted, $i - 1, 1);
                    }
                    
                    if ($char_value === '' || $char_value === null) {
                        $char_value = '0';
                    }
                    
                    // PhpWord workaround: treat "0" as "ZERO" to prevent it from being skipped
                    if ($char_value === '0') {
                        $template->setValue("assessor_expiry_char_$i", 'ZERO');
                    } else {
                        $template->setValue("assessor_expiry_char_$i", $char_value);
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

// Set up output directory
$output_dir = __DIR__ . '/agreement/today/';
if (!is_dir($output_dir)) {
    mkdir($output_dir, 0755, true);
    chmod($output_dir, 0755);
}
if (!is_writable($output_dir)) {
    log_message("Output directory is not writable: $output_dir");
    sendErrorResponse("Output directory is not writable.", 500);
}

// Check if LearnerID or IDNumbers is provided
$LearnerID = $_GET['LearnerID'] ?? null;
$IDNumbers = $_GET['IDNumbers'] ?? null;

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
        COALESCE(cl.client_name, 'N/A') AS client_name,
        COALESCE(cl.contract_no, 'N/A') AS client_phone,
        COALESCE(cl.phone, cl.contract_no, 'N/A') AS client_cell,
        COALESCE(cl.contact_number, cl.phone, 'N/A') AS contact_number,
        COALESCE(cl.contact_person, 'N/A') AS contact_person,
        COALESCE(cl.email, 'N/A') AS client_email,
        COALESCE(cl.client_address, 'N/A') AS client_address,
        COALESCE(cl.city, 'N/A') AS client_city,
        COALESCE(cl.postal_code, 'N/A') AS client_postal_code,
        cl.signature AS client_signature,
        cl.client_initials AS client_initials,
        cl.client_witness_signature AS client_witness_signature,
        cl.clent_witness_initials AS client_witness_initials,
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
                qa.qa_body_name,COALESCE(cl.client_name, 'N/A') AS client_name,
        COALESCE(cl.contract_no, 'N/A') AS client_phone,
        COALESCE(cl.phone, cl.contract_no, 'N/A') AS client_cell,
        COALESCE(cl.contact_number, cl.phone, 'N/A') AS contact_number,
        COALESCE(cl.contact_person, 'N/A') AS contact_person,
        COALESCE(cl.email, 'N/A') AS client_email,
        COALESCE(cl.client_address, 'N/A') AS client_address,
        COALESCE(cl.city, 'N/A') AS client_city,
        COALESCE(cl.postal_code, 'N/A') AS client_postal_code,
        cl.signature AS client_signature,
        cl.client_initials AS client_initials,
        cl.client_witness_signature AS client_witness_signature,
        cl.clent_witness_initials AS client_witness_initials,
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
            LEFT JOIN client cl ON cl.client_name = p.client_name
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
        COALESCE(cl.client_name, 'N/A') AS client_name,
        COALESCE(cl.contract_no, 'N/A') AS client_phone,
        COALESCE(cl.phone, cl.contract_no, 'N/A') AS client_cell,
        COALESCE(cl.contact_number, cl.phone, 'N/A') AS contact_number,
        COALESCE(cl.contact_person, 'N/A') AS contact_person,
        COALESCE(cl.email, 'N/A') AS client_email,
        COALESCE(cl.client_address, 'N/A') AS client_address,
        COALESCE(cl.city, 'N/A') AS client_city,
        COALESCE(cl.postal_code, 'N/A') AS client_postal_code,
        cl.signature AS client_signature,
        cl.client_initials AS client_initials,
        cl.client_witness_signature AS client_witness_signature,
        cl.clent_witness_initials AS client_witness_initials,
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
    LEFT JOIN facilitator f ON f.role = 'Assessor' AND FIND_IN_SET(c.classID, f.classID) > 0
    LEFT JOIN (
        SELECT LearnerID, MAX(signature) AS signature
        FROM learner_clocking
        WHERE NULLIF(TRIM(signature), '') IS NOT NULL
        GROUP BY LearnerID
    ) lc_sig ON lc_sig.LearnerID = ld.LearnerID
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
            for ($i = 1; $i <= 13; $i++) {
                $digit_value = $data["assessor_id_digit_$i"] ?? '';
                
                if ($digit_value === '' || $digit_value === null) {
                    $digit_value = substr($assessor_id_number, $i - 1, 1);
                }
                
                if ($digit_value === '' || $digit_value === null) {
                    $digit_value = '0';
                }
                
                if ($digit_value === '0') {
                    $digit_value = '0';
                }
                
                $template->setValue("assessor_id_digit_$i", $digit_value);
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
                
                
            } else {
                log_message("Failed to generate agreement for LearnerID: {$data['LearnerID']}");
                $skipped++;
            }

            // Determine required forms based on funder and qa_body_namelank
        
            $project_funder = $data['Project_funder'] ?? '';
            $qa_body_name = $data['qa_body_name'] ?? '';
            $pathway_name = $data['pathway_name'] ?? '';
            $required_forms = [];

            if (in_array($project_funder, $SETAS)) {
                log_message("Project funder is SETA (self-funded): $project_funder");
                $required_forms = getSETAForms($project_funder, $pathway_name);
            } else {
                log_message("Project funder is external: $project_funder");
                if (in_array($qa_body_name, $SETAS)) {
                    log_message("qa_body_name is SETA: $qa_body_name");
                    $required_forms = getSETAForms($qa_body_name, $pathway_name);
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
log_message("Total files in generatedFiles array: " . count($generatedFiles));
log_message("Generated files: " . json_encode($generatedFiles));
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
?>    un
set($batch);
}

// Output handling
if (!empty($generatedFiles)) {
    if (count($learners) === 1) {
        // Single learner: serve the agreement file directly or ZIP if multiple files
        if (count($generatedFiles) === 1) {
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
            // Multiple files for single learner: create ZIP
            try {
                $zip = new ZipArchive();
                $learner_data = $learners[0];
                $safe_id = preg_replace('/[^a-zA-Z0-9]/', '_', $learner_data['IDNumber'] ?? 'learner');
                $zipFileName = $output_dir . $safe_id . "_Documents_" . date('Ymd_His') . ".zip";

                if ($zip->open($zipFileName, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== TRUE) {
                    log_message("Failed to open ZIP archive: $zipFileName");
                    sendErrorResponse("Failed to create ZIP file.", 500);
                }

                foreach ($generatedFiles as $file) {
                    if (file_exists($file)) {
                        $zip->addFile($file, basename($file));
                    } else {
                        log_message("ZIP error: File not found: $file");
                    }
                }
                $zip->close();

                if (file_exists($zipFileName)) {
                    log_message("ZIP file created: $zipFileName");
                    header('Content-Type: application/zip');
                    header('Content-Disposition: attachment; filename="' . basename($zipFileName) . '"');
                    header('Content-Length: ' . filesize($zipFileName));
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

$conn->close();
exit;
?>
