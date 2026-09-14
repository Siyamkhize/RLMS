<?php
use PhpOffice\PhpWord\TemplateProcessor;
require 'vendor/autoload.php';

// Increase resource limits to handle large datasets
ini_set('memory_limit', '1024M');
set_time_limit(600);
error_reporting(E_ALL);
ini_set('log_errors', 1);

// Ensure the log directory exists
$log_dir = 'agreement/today';
if (!is_dir($log_dir)) {
    if (!mkdir($log_dir, 0755, true)) {
        die(json_encode(['error' => 'Failed to create log directory']));
    }
}

$log_file = $log_dir . '/bulk_log_' . date('Ymd_His') . '.log';
ini_set('error_log', $log_file);

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

// Temporary fix for testing - force LearnerID if not provided
if (empty($_GET['LearnerID']) && !empty($_SERVER['QUERY_STRING']) && strpos($_SERVER['QUERY_STRING'], 'LearnerID=') !== false) {
    parse_str($_SERVER['QUERY_STRING'], $_GET);
}

// Initial debug logging
log_message("Script started - LearnerID: " . ($_GET['LearnerID'] ?? 'not provided'));
log_message("All GET parameters: " . print_r($_GET, true));
log_message("Request method: " . ($_SERVER['REQUEST_METHOD'] ?? 'CLI'));
log_message("Query string: " . ($_SERVER['QUERY_STRING'] ?? 'none'));

// Test database connection
try {
    if (!$conn) {
        throw new Exception("Database connection is null");
    }
    if ($conn->connect_error) {
        throw new Exception("Database connection failed: " . $conn->connect_error);
    }
    log_message("Database connection successful");
} catch (Exception $e) {
    log_message("Database connection error: " . $e->getMessage());
    sendErrorResponse("Database connection failed: " . $e->getMessage(), 500);
}

// Set response headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

function log_message($message) {
    global $log_file;
    if (is_writable(dirname($log_file))) {
        file_put_contents($log_file, date('Y-m-d H:i:s') . " - $message\n", FILE_APPEND);
    } else {
        error_log("Cannot write to log file: $log_file");
    }
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

function find_signature_path($signature, $base_paths) {
    if (empty($signature)) {
        log_message("Empty signature provided");
        return false;
    }
    foreach ($base_paths as $path) {
        $full_path = $path . $signature;
        if (file_exists($full_path) && @getimagesize($full_path)) {
            log_message("Found valid signature: $full_path");
            return $full_path;
        }
    }
    log_message("Signature not found: $signature");
    return false;
}

// Function to validate DOCX file
function isValidDocx($file_path) {
    if (!file_exists($file_path)) {
        log_message("DOCX file does not exist: $file_path");
        return false;
    }
    $zip = new ZipArchive();
    if ($zip->open($file_path) !== true) {
        log_message("Failed to open DOCX as ZIP: $file_path");
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
    try {
        $stmt = $conn->prepare("SELECT MIN(clock_in) as first_clock_in FROM attendance WHERE LearnerID = ? AND clock_in IS NOT NULL");
        if (!$stmt) {
            log_message("Error preparing first clock_in query: " . $conn->error);
            return $first_clock_in;
        }
        $stmt->bind_param("i", $learner_id);
        if ($stmt->execute()) {
            $result = $stmt->get_result();
            if ($row = $result->fetch_assoc()) {
                $first_clock_in = $row['first_clock_in'] ?? 'N/A';
            }
        } else {
            log_message("Error executing first clock_in query: " . $stmt->error);
        }
        $stmt->close();
    } catch (Exception $e) {
        log_message("Error in getFirstClockInDate: " . $e->getMessage());
    }
    return $first_clock_in;
}

// Function to get pathway dates
function getPathwayDates($conn, $project_id) {
    $pathway_start_dates = [];
    $pathway_end_dates = [];
    
    try {
        $stmt = $conn->prepare("SELECT pathway_start_dates, pathway_end_dates FROM project WHERE project_id = ?");
        if (!$stmt) {
            log_message("Error preparing pathway dates query: " . $conn->error);
            return ['start_dates' => [], 'end_dates' => []];
        }
        $stmt->bind_param("i", $project_id);
        if ($stmt->execute()) {
            $result = $stmt->get_result();
            if ($row = $result->fetch_assoc()) {
                $pathway_start_dates_str = $row['pathway_start_dates'] ?? '';
                $pathway_end_dates_str = $row['pathway_end_dates'] ?? '';
                $pathway_start_dates = !empty($pathway_start_dates_str) ? array_filter(array_map('trim', explode(',', $pathway_start_dates_str))) : [];
                $pathway_end_dates = !empty($pathway_end_dates_str) ? array_filter(array_map('trim', explode(',', $pathway_end_dates_str))) : [];
            }
        } else {
            log_message("Error executing pathway dates query: " . $stmt->error);
        }
        $stmt->close();
    } catch (Exception $e) {
        log_message("Error in getPathwayDates: " . $e->getMessage());
    }
    
    return [
        'start_dates' => $pathway_start_dates,
        'end_dates' => $pathway_end_dates
    ];
}

// Function to get unit standards
function getUnitStandards($conn, $qualification_id) {
    $unit_standards = [];
    try {
        $stmt = $conn->prepare("
            SELECT unitstandard_id, unit_standard_name, credits
            FROM unitstandard
            WHERE qualification_id = ?
            ORDER BY unitstandard_id
            LIMIT 10
        ");
        if (!$stmt) {
            log_message("Error preparing unit standards query: " . $conn->error);
            return $unit_standards;
        }
        $stmt->bind_param("s", $qualification_id);
        if ($stmt->execute()) {
            $result = $stmt->get_result();
            while ($row = $result->fetch_assoc()) {
                $unit_standards[] = [
                    'id' => $row['unitstandard_id'],
                    'title' => $row['unit_standard_name'],
                    'credits' => $row['credits'] ?? 'N/A',
                    's_type' => 'N/A'
                ];
            }
        } else {
            log_message("Error executing unit standards query: " . $stmt->error);
        }
        $stmt->close();
    } catch (Exception $e) {
        log_message("Error in getUnitStandards: " . $e->getMessage());
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
            
            if (!$form_template_path || !isValidDocx($form_template_path)) {
                log_message("Valid template not found for form: $form_name");
                continue;
            }
            
            log_message("Using template: $form_template_path");
            $template = new TemplateProcessor($form_template_path);
            
            // Select pathway
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
            
            if (!$selected_pathway && !empty($pathway_data)) {
                $selected_pathway = $pathway_data[0];
                log_message("No matching pathway found for pathway_name=$site_pathway_name, using first pathway");
            }
            
            $pathway_name = $selected_pathway['name'] ?? 'Short Skills Programme';
            $qualification_name = $selected_pathway['qual_types'][0]['qualification']['name'] ?? '91782 - Plumber';
            $employment_status = $selected_pathway['qual_types'][0]['qualification']['employment_status'] ?? 'Unemployed 18.2';
            
            $learner_data['qualification_name'] = $qualification_name;
            $learner_data['employment_status'] = $employment_status;
            
            // Extract unit standards
            $json_unit_standards = [];
            $qual_type = 'N/A';
            
            if (isset($learner_data['project_pathway']) && !empty($learner_data['project_pathway'])) {
                $pathway_data = json_decode($learner_data['project_pathway'], true);
                if (isset($pathway_data[0]['qual_types'][0]['qual_type'])) {
                    $qual_type = $pathway_data[0]['qual_types'][0]['qual_type'];
                    log_message("Form - Extracted qual_type: $qual_type");
                }
                if (is_array($pathway_data) && isset($pathway_data[0]['qual_types'])) {
                    foreach ($pathway_data[0]['qual_types'] as $qual_type_entry) {
                        if (isset($qual_type_entry['qualification']['unitStandards'])) {
                            $json_unit_standards = array_merge($json_unit_standards, $qual_type_entry['qualification']['unitStandards']);
                        }
                    }
                }
            }
            
            if (!empty($json_unit_standards)) {
                $json_unit_ids = array_filter(array_column($json_unit_standards, 'id'), function($id) { return !empty($id) && $id !== 'N/A'; });
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
                }
            } else {
                $unit_standards = getUnitStandards($conn, $learner_data['qualification_id']);
                foreach ($unit_standards as &$us) {
                    $us['s_type'] = $qual_type;
                }
            }
            
            // Replace placeholders for NEW_SKILLS_PROGRAMME_APPLICATION_FORM
            if ($form_name === 'NEW_SKILLS_PROGRAMME_APPLICATION_FORM') {
                $id_number = $learner_data['IDNumber'] ?? '';
                for ($i = 1; $i <= 13; $i++) {
                    $digit_value = $learner_data["id_digit_$i"] ?? substr($id_number, $i - 1, 1) ?? '0';
                    $template->setValue("id_digit_$i", $digit_value === '0' ? 'ZERO' : $digit_value);
                    log_message("Setting id_digit_$i = '$digit_value'");
                }
                $template->setValue('Date_of_Birth', $learner_data['id_derived_dob'] ?? 'N/A');
                $template->setValue('Gender_Male', $learner_data['gender'] === 'Male' ? 'X' : '');
                $template->setValue('Gender_Female', $learner_data['gender'] === 'Female' ? 'X' : '');
                $template->setValue('Citizen_Yes', $learner_data['is_south_african_citizen'] === 'Yes' ? 'X' : '');
                $template->setValue('Citizen_No', $learner_data['is_south_african_citizen'] === 'No' ? 'X' : '');
                $template->setValue('Title', $learner_data['title'] ?? 'N/A');
                $template->setValue('employment_status', $employment_status);
                
                if (!empty($unit_standards)) {
                    try {
                        $template->cloneRow('unit_standard_id', count($unit_standards));
                        for ($i = 0; $i < count($unit_standards); $i++) {
                            $template->setValue("unit_standard_id#" . ($i + 1), $unit_standards[$i]['id'] ?? 'N/A');
                            $template->setValue("unit_standard_title#" . ($i + 1), $unit_standards[$i]['title'] ?? 'N/A');
                            $template->setValue("unit_standard_credits#" . ($i + 1), $unit_standards[$i]['credits'] ?? 'N/A');
                            $template->setValue("unit_standard_type#" . ($i + 1), $unit_standards[$i]['s_type'] ?? 'N/A');
                        }
                    } catch (Exception $e) {
                        log_message("cloneRow failed for $form_name: " . $e->getMessage());
                        for ($i = 0; $i < min(10, count($unit_standards)); $i++) {
                            $index = $i + 1;
                            $template->setValue("unit_standard_{$index}_id", $unit_standards[$i]['id'] ?? 'N/A');
                            $template->setValue("unit_standard_{$index}_title", $unit_standards[$i]['title'] ?? 'N/A');
                            $template->setValue("unit_standard_{$index}_credits", $unit_standards[$i]['credits'] ?? 'N/A');
                            $template->setValue("unit_standard_{$index}_type", $unit_standards[$i]['s_type'] ?? 'N/A');
                        }
                    }
                } else {
                    for ($i = 1; $i <= 10; $i++) {
                        $template->setValue("unit_standard_{$i}_id", 'N/A');
                        $template->setValue("unit_standard_{$i}_title", 'N/A');
                        $template->setValue("unit_standard_{$i}_credits", 'N/A');
                        $template->setValue("unit_standard_{$i}_type", 'N/A');
                    }
                }
                
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
                $template->setValue('Employment_Start', getFirstClockInDate($conn, $learner_data['LearnerID']));
                $template->setValue('Assessor_Name', 'N/A');
                $template->setValue('Assessor_Surname', 'N/A');
                $template->setValue('Assessor_ID', 'N/A');
                $template->setValue('Assessor_Registration', 'N/A');
                $template->setValue('Assessor_End_Date', 'N/A');
            }
            
            // Common placeholders
            $template->setValue('Name', $learner_data['Name'] ?? 'N/A');
            $template->setValue('Surname', $learner_data['Surname'] ?? 'N/A');
            $template->setValue('IDNumber', $learner_data['IDNumber'] ?? 'N/A');
            $template->setValue('PhoneNumber', $learner_data['PhoneNumber'] ?? 'N/A');
            $template->setValue('qualification_name', $learner_data['qualification_name'] ?? 'N/A');
            $template->setValue('qualification_id', $learner_data['qualification_id'] ?? 'N/A');
            $template->setValue('pathway_name', $pathway_name);
            $template->setValue('sdp_name', $learner_data['sdp_name'] ?? 'N/A');
            $template->setValue('learner_initials', $learner_data['learner_initials'] ?? 'N/A');
            $date_to_use = $learner_data['first_clock_date'] ?? date('Y-m-d');
            $template->setValue('Date', date('d F Y', strtotime($date_to_use)));
            $template->setValue('qa_body_name', $learner_data['qa_body_name'] ?? 'N/A');
            $template->setValue('accreditation_number', $learner_data['accreditation_number'] ?? 'N/A');
            $template->setValue('total_credits', $learner_data['total_credits'] ?? 'N/A');
            $template->setValue('nqf_level', $learner_data['nqf_level'] ?? 'N/A');
            
            // Pathway dates
            $template->setValue('pathway_start_date', $pathway_dates['start_dates'][0] ?? 'TBD');
            $template->setValue('selected_pathway_start_date', $pathway_dates['start_dates'][0] ?? 'TBD');
            $template->setValue('all_start_dates', implode(', ', $pathway_dates['start_dates']) ?: 'TBD');
            $template->setValue('pathway_end_date', $pathway_dates['end_dates'][0] ?? 'TBD');
            $template->setValue('selected_pathway_end_date', $pathway_dates['end_dates'][0] ?? 'TBD');
            $template->setValue('all_end_dates', implode(', ', $pathway_dates['end_dates']) ?: 'TBD');
            
            // Pathway duration
            $selected_pathway_duration = 'N/A';
            if (!empty($pathway_dates['start_dates']) && !empty($pathway_dates['end_dates'])) {
                $start_date = $pathway_dates['start_dates'][0];
                $end_date = $pathway_dates['end_dates'][0];
                if ($start_date !== 'TBD' && $end_date !== 'TBD') {
                    try {
                        $start = new DateTime($start_date);
                        $end = new DateTime($end_date);
                        $interval = $start->diff($end);
                        $months = ($interval->y * 12) + $interval->m + ($interval->d > 0 ? 1 : 0);
                        $selected_pathway_duration = $months;
                    } catch (Exception $e) {
                        log_message("Error calculating pathway duration: " . $e->getMessage());
                    }
                }
            }
            $template->setValue('selected_pathway_duration', $selected_pathway_duration);
            
            // Employer information
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
            } else {
                $template->setValue('learner_signature', 'N/A');
            }
            
            // Save form
            $safe_id = preg_replace('/[^a-zA-Z0-9]/', '_', $learner_data['IDNumber'] ?? 'unknown_' . $learner_data['LearnerID']);
            $form_file = $output_dir . $safe_id . "_{$form_name}.docx";
            $template->saveAs($form_file);
            
            // Post-process to replace ZERO with 0
            if (file_exists($form_file)) {
                $zip = new ZipArchive();
                if ($zip->open($form_file) === TRUE) {
                    $document_xml = $zip->getFromName('word/document.xml');
                    if ($document_xml !== false) {
                        $document_xml = str_replace('ZERO', '0', $document_xml);
                        $zip->addFromString('word/document.xml', $document_xml);
                    }
                    $zip->close();
                }
                $generated_forms[] = $form_file;
                log_message("Form generated: $form_file");
            } else {
                log_message("Failed to generate form: $form_name for LearnerID: {$learner_data['LearnerID']}");
            }
        } catch (Exception $e) {
            log_message("Error generating form $form_name: " . $e->getMessage());
        }
    }
    
    return $generated_forms;
}

// Verify main template
$template_path = 'agreement/Cleaned_Updated_Agreement_V4.docx';
if (!file_exists($template_path) || !isValidDocx($template_path)) {
    log_message("Main template issue: $template_path");
    sendErrorResponse("Main template file missing or invalid.", 404);
}

// Set up output directory
$output_dir = 'agreement/today/';
if (!is_dir($output_dir)) {
    if (!mkdir($output_dir, 0755, true)) {
        log_message("Failed to create output directory: $output_dir");
        sendErrorResponse("Failed to create output directory.", 500);
    }
}
if (!is_writable($output_dir)) {
    log_message("Output directory not writable: $output_dir");
    sendErrorResponse("Output directory is not writable.", 500);
}

// Validate input parameters
$LearnerID = $_GET['LearnerID'] ?? null;
$IDNumbers = $_GET['IDNumbers'] ?? null;

if (empty($LearnerID) && empty($IDNumbers)) {
    sendErrorResponse('Missing LearnerID or IDNumbers parameter', 400);
}
if ($LearnerID && !is_numeric($LearnerID)) {
    sendErrorResponse('Invalid LearnerID', 400);
}
if ($IDNumbers && !preg_match('/^[0-9,]+$/', $IDNumbers)) {
    sendErrorResponse('Invalid IDNumbers format', 400);
}

// SQL query for learner data
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
        q.qualification_id,
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
    WHERE ";

try {
    if ($LearnerID) {
        $sql .= "ld.LearnerID = ?";
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            log_message("SQL Prepare Error (LearnerID): " . $conn->error);
            sendErrorResponse("Database query preparation failed: " . $conn->error, 500);
        }
        $stmt->bind_param('i', $LearnerID);
    } else {
        $idNumbersArray = array_filter(array_map('trim', explode(',', $IDNumbers)));
        if (empty($idNumbersArray)) {
            sendErrorResponse('No valid IDNumbers provided', 400);
        }
        $placeholders = implode(',', array_fill(0, count($idNumbersArray), '?'));
        $sql .= "ld.IDNumber IN ($placeholders)";
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            log_message("SQL Prepare Error (IDNumbers): " . $conn->error);
            sendErrorResponse("Database query preparation failed: " . $conn->error, 500);
        }
        $stmt->bind_param(str_repeat('s', count($idNumbersArray)), ...$idNumbersArray);
    }
    
    log_message("Executing SQL: $sql");
    if (!$stmt->execute()) {
        log_message("SQL Execution Error: " . $stmt->error);
        sendErrorResponse("Failed to execute database query: " . $stmt->error, 500);
    }
    
    $result = $stmt->get_result();
    log_message("Query returned " . $result->num_rows . " rows");
    if ($result->num_rows === 0) {
        log_message("No data found for input parameters");
        sendErrorResponse("No data found for provided parameters", 404);
    }
    
    $learners = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
} catch (Exception $e) {
    log_message("Database error: " . $e->getMessage());
    sendErrorResponse("Database error: " . $e->getMessage(), 500);
}

$generatedFiles = [];
$skipped = 0;
$batch_size = 100;

for ($i = 0; $i < count($learners); $i += $batch_size) {
    $batch = array_slice($learners, $i, $batch_size);
    foreach ($batch as $data) {
        log_message("Processing LearnerID: {$data['LearnerID']} - {$data['Name']} {$data['Surname']}");
        
        $safe_id = preg_replace('/[^a-zA-Z0-9]/', '_', $data['IDNumber'] ?? 'unknown_' . $data['LearnerID']);
        $learner_dir = $output_dir . $safe_id . '/';
        if (!is_dir($learner_dir)) {
            if (!mkdir($learner_dir, 0755, true)) {
                log_message("Failed to create learner directory: $learner_dir");
                $skipped++;
                continue;
            }
        }
        
        try {
            $pathway_dates = getPathwayDates($conn, $data['project_id']);
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
            
            if (!$selected_pathway && !empty($pathway_data)) {
                $selected_pathway = $pathway_data[0];
            }
            
            $pathway_name = $selected_pathway['name'] ?? 'Short Skills Programme';
            $qualification_name = $selected_pathway['qual_types'][0]['qualification']['name'] ?? '91782 - Plumber';
            $employment_status = $selected_pathway['qual_types'][0]['qualification']['employment_status'] ?? 'Unemployed 18.2';
            
            $data['qualification_name'] = $qualification_name;
            $data['employment_status'] = $employment_status;
            
            $json_unit_standards = [];
            $qual_type = 'N/A';
            if (isset($data['project_pathway']) && !empty($data['project_pathway'])) {
                $pathway_data = json_decode($data['project_pathway'], true);
                if (isset($pathway_data[0]['qual_types'][0]['qual_type'])) {
                    $qual_type = $pathway_data[0]['qual_types'][0]['qual_type'];
                }
                if (is_array($pathway_data) && isset($pathway_data[0]['qual_types'])) {
                    foreach ($pathway_data[0]['qual_types'] as $qual_type_entry) {
                        if (isset($qual_type_entry['qualification']['unitStandards'])) {
                            $json_unit_standards = array_merge($json_unit_standards, $qual_type_entry['qualification']['unitStandards']);
                        }
                    }
                }
            }
            
            if (!empty($json_unit_standards)) {
                $json_unit_ids = array_filter(array_column($json_unit_standards, 'id'), function($id) { return !empty($id) && $id !== 'N/A'; });
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
                }
            } else {
                $unit_standards = getUnitStandards($conn, $data['qualification_id']);
                foreach ($unit_standards as &$us) {
                    $us['s_type'] = $qual_type;
                }
            }
            
            $template = new TemplateProcessor($template_path);
            $template->setValue('Name', $data['Name'] ?? 'N/A');
            $template->setValue('Surname', $data['Surname'] ?? 'N/A');
            $template->setValue('IDNumber', $data['IDNumber'] ?? 'N/A');
            $template->setValue('PhoneNumber', $data['PhoneNumber'] ?? 'N/A');
            $template->setValue('qualification_name', $data['qualification_name'] ?? '91782 - Plumber');
            $template->setValue('qualification_id', $data['qualification_id'] ?? '91782');
            $template->setValue('pathway_name', $pathway_name);
            $template->setValue('sdp_name', $data['sdp_name'] ?? 'N/A');
            $template->setValue('learner_initials', $data['learner_initials'] ?? 'N/A');
            $date_to_use = $data['first_clock_date'] ?? date('Y-m-d');
            $template->setValue('Date', date('d F Y', strtotime($date_to_use)));
            $template->setValue('witness_initials', $data['witness_initials'] ?? 'N/A');
            $template->setValue('qa_body_name', $data['qa_body_name'] ?? 'N/A');
            $template->setValue('accreditation_number', $data['accreditation_number'] ?? 'N/A');
            $template->setValue('Employment_Start', getFirstClockInDate($conn, $data['LearnerID']));
            
            if (!empty($unit_standards)) {
                try {
                    $template->cloneRow('unit_standard_id', count($unit_standards));
                    for ($i = 0; $i < count($unit_standards); $i++) {
                        $template->setValue("unit_standard_id#" . ($i + 1), $unit_standards[$i]['id'] ?? 'N/A');
                        $template->setValue("unit_standard_title#" . ($i + 1), $unit_standards[$i]['title'] ?? 'N/A');
                        $template->setValue("unit_standard_credits#" . ($i + 1), $unit_standards[$i]['credits'] ?? 'N/A');
                        $template->setValue("unit_standard_type#" . ($i + 1), $unit_standards[$i]['s_type'] ?? 'N/A');
                    }
                } catch (Exception $e) {
                    log_message("cloneRow failed: " . $e->getMessage());
                    for ($i = 0; $i < min(10, count($unit_standards)); $i++) {
                        $index = $i + 1;
                        $template->setValue("unit_standard_{$index}_id", $unit_standards[$i]['id'] ?? 'N/A');
                        $template->setValue("unit_standard_{$index}_title", $unit_standards[$i]['title'] ?? 'N/A');
                        $template->setValue("unit_standard_{$index}_credits", $unit_standards[$i]['credits'] ?? 'N/A');
                        $template->setValue("unit_standard_{$index}_type", $unit_standards[$i]['s_type'] ?? 'N/A');
                    }
                }
            } else {
                for ($i = 1; $i <= 10; $i++) {
                    $template->setValue("unit_standard_{$i}_id", 'N/A');
                    $template->setValue("unit_standard_{$i}_title", 'N/A');
                    $template->setValue("unit_standard_{$i}_credits", 'N/A');
                    $template->setValue("unit_standard_{$i}_type", 'N/A');
                }
            }
            
            $template->setValue('pathway_start_date', $pathway_dates['start_dates'][0] ?? 'TBD');
            $template->setValue('selected_pathway_start_date', $pathway_dates['start_dates'][0] ?? 'TBD');
            $template->setValue('all_start_dates', implode(', ', $pathway_dates['start_dates']) ?: 'TBD');
            $template->setValue('pathway_end_date', $pathway_dates['end_dates'][0] ?? 'TBD');
            $template->setValue('selected_pathway_end_date', $pathway_dates['end_dates'][0] ?? 'TBD');
            $template->setValue('all_end_dates', implode(', ', $pathway_dates['end_dates']) ?: 'TBD');
            
            $selected_pathway_duration = 'N/A';
            if (!empty($pathway_dates['start_dates']) && !empty($pathway_dates['end_dates'])) {
                $start_date = $pathway_dates['start_dates'][0];
                $end_date = $pathway_dates['end_dates'][0];
                if ($start_date !== 'TBD' && $end_date !== 'TBD') {
                    try {
                        $start = new DateTime($start_date);
                        $end = new DateTime($end_date);
                        $interval = $start->diff($end);
                        $months = ($interval->y * 12) + $interval->m + ($interval->d > 0 ? 1 : 0);
                        $selected_pathway_duration = $months;
                    } catch (Exception $e) {
                        log_message("Error calculating pathway duration: " . $e->getMessage());
                    }
                }
            }
            $template->setValue('selected_pathway_duration', $selected_pathway_duration);
            
            $template->setValue('Employer_Contact', $data['client_name'] ?? 'N/A');
            $template->setValue('Employer_Cell', $data['client_phone'] ?? 'N/A');
            $template->setValue('Employer_Email', $data['client_email'] ?? 'N/A');
            $template->setValue('Employer_Address', $data['client_address'] ?? 'N/A');
            $template->setValue('Employer_Postal', $data['client_address'] ?? 'N/A');
            $template->setValue('Employer_Physical_Code', $data['client_postal_code'] ?? 'N/A');
            $template->setValue('Employer_Postal_Code', $data['client_postal_code'] ?? 'N/A');
            
            $learner_signature_path = find_signature_path($data['signaturePath'], $signature_base_paths);
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
            } else {
                $template->setValue('learner_signature', 'N/A');
            }
            
            $sdp_signature_path = find_signature_path($data['signature_image'], ['signatures/']);
            if ($sdp_signature_path) {
                $template->setImageValue('sdp_signature_image', [
                    'src' => $sdp_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
            } else {
                $template->setValue('sdp_signature_image', 'N/A');
            }
            
            $witness_signature_path = find_signature_path($data['witnessSignaturePath'], $signature_base_paths);
            if ($witness_signature_path) {
                $template->setImageValue('witness_signature', [
                    'src' => $witness_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
            } else {
                $template->setValue('witness_signature', 'N/A');
            }
            
            $docxFile = $learner_dir . $safe_id . "_Agreement.docx";
            $template->saveAs($docxFile);
            
            if (file_exists($docxFile)) {
                $zip = new ZipArchive();
                if ($zip->open($docxFile) === TRUE) {
                    $document_xml = $zip->getFromName('word/document.xml');
                    if ($document_xml !== false) {
                        $document_xml = str_replace('ZERO', '0', $document_xml);
                        $zip->addFromString('word/document.xml', $document_xml);
                    }
                    $zip->close();
                }
                $generatedFiles[] = $docxFile;
                log_message("Agreement generated: $docxFile");
            } else {
                log_message("Failed to generate agreement: $docxFile");
                $skipped++;
            }
            
            $project_funder = $data['Project_funder'] ?? '';
            $qa_body_name = $data['qa_body_name'] ?? '';
            $required_forms = in_array($project_funder, $SETAS) ? getSETAForms($project_funder) : (in_array($qa_body_name, $SETAS) ? getSETAForms($qa_body_name) : ['Learner_Agreement']);
            
            if (!empty($required_forms)) {
                $form_files = generateForms($conn, $required_forms, $data, $learner_dir, $pathway_dates);
                $generatedFiles = array_merge($generatedFiles, $form_files);
            }
        } catch (Exception $e) {
            log_message("Error processing LearnerID {$data['LearnerID']}: " . $e->getMessage());
            $skipped++;
        }
    }
    unset($batch);
}

// Output handling
if (!empty($generatedFiles)) {
    if (count($learners) === 1) {
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
                }
            }
            $zip->close();
            
            if (file_exists($zipFileName)) {
                header('Content-Type: application/zip');
                header('Content-Disposition: attachment; filename="' . basename($zipFileName) . '"');
                readfile($zipFileName);
            } else {
                sendErrorResponse("Failed to create ZIP file.", 500);
            }
        } catch (Exception $e) {
            log_message("ZIP creation error: " . $e->getMessage());
            sendErrorResponse("Error creating ZIP file: " . $e->getMessage(), 500);
        }
    }
} else {
    log_message("No files generated");
    sendErrorResponse("No files were generated.", 500);
}

$conn->close();
exit;
?>