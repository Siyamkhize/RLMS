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
$default_signature_path = 'mobile/agreement/signature_11_1728641462.png';

// Helper function to find signature image in multiple possible locations
function findSignatureImage($signatureFilename, $learnerID = null, $signatureType = 'learner') {
    if (empty($signatureFilename)) {
        return null;
    }
    
    $possiblePaths = [];
    
    if ($signatureType === 'sdp') {
        // SDP signature paths - handle both direct filename and path variations
        $baseFilename = basename($signatureFilename);
        $possiblePaths = [
            // Try the path as stored in database first
            $signatureFilename,
            // If database has "uploads/sdp_signature.png", try "mobile/uploads/sdp_signature.png"
            str_replace('uploads/', 'mobile/uploads/', $signatureFilename),
            // Try with just the filename
            "mobile/uploads/" . $baseFilename,
            "uploads/" . $baseFilename,
            "mobile/Uploads/" . $baseFilename,
            "assets/img/" . $baseFilename,
            "./" . $baseFilename,
            $baseFilename
        ];
    } else {
        // Learner and witness signature paths
        $possiblePaths = [
            $signatureFilename, // Direct path as stored in database
            "signatures/" . basename($signatureFilename),
            "mobile/signatures/" . basename($signatureFilename),
            "mobile/learnerImages/" . basename($signatureFilename),
            basename($signatureFilename),
            "mobile/" . basename($signatureFilename),
            "uploads/" . basename($signatureFilename),
            "uploads/" . $signatureFilename,
            "mobile/uploads/" . basename($signatureFilename),
            "mobile/uploads/" . $signatureFilename,
            "mobile/Uploads/" . basename($signatureFilename),
            "mobile/Uploads/" . $signatureFilename
        ];
        
        // Add learner-specific paths if learnerID is provided
        if ($learnerID) {
            $learnerPaths = [
                "mobile/signatures/learner{$learnerID}_" . basename($signatureFilename),
                "mobile/signatures/learner{$learnerID}_signature_" . basename($signatureFilename),
                "signatures/learner{$learnerID}_" . basename($signatureFilename),
                "signatures/learner{$learnerID}_signature_" . basename($signatureFilename)
            ];
            $possiblePaths = array_merge($learnerPaths, $possiblePaths);
        }
    }
    
    // Check each path
    foreach ($possiblePaths as $path) {
        if (file_exists($path)) {
            // Verify it's a valid image
            if (@getimagesize($path)) {
                // Log successful path resolution for debugging
                if ($signatureType === 'sdp') {
                    error_log("SDP Signature found: Database value='$signatureFilename', Resolved path='$path'");
                }
                return $path;
            }
        }
    }
    
    return null;
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
                $template->setValue('Employer_Cell', $learner_data['client_phone'] ?? 'N/A');
                $template->setValue('Employer_Email', $learner_data['client_email'] ?? 'N/A');
                $template->setValue('Employer_Address', $learner_data['client_address'] ?? 'N/A');
                $template->setValue('Employer_Postal', $learner_data['client_address'] ?? 'N/A');
                $template->setValue('Employer_Physical_Code', $learner_data['client_postal_code'] ?? 'N/A');
                $template->setValue('Employer_Postal_Code', $learner_data['client_postal_code'] ?? 'N/A');
                
                // Add learner signature image
                $learner_signature_path = findSignatureImage(
                    $learner_data['signaturePath'], 
                    $learner_data['LearnerID'], 
                    'learner'
                );
                if ($learner_signature_path) {
                    $template->setImageValue('learner_signature', [
                        'src' => $learner_signature_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("Learner signature image added: $learner_signature_path");
                } elseif (file_exists($default_signature_path)) {
                    $template->setImageValue('learner_signature', [
                        'src' => $default_signature_path,
                        'width' => 100,
                        'height' => 50
                    ]);
                    log_message("Default learner signature used: $default_signature_path");
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
        ld.signature AS signaturePath,
        ld.learner_initials,
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
            } elseif (file_exists($default_signature_path)) {
                $template->setImageValue('learner_signature', [
                    'src' => $default_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
                log_message("Default learner signature used: $default_signature_path");
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