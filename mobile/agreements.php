<?php
require 'vendor/autoload.php';
use PhpOffice\PhpWord\TemplateProcessor;

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
ini_set('memory_limit', '512M');
set_time_limit(300);

include('../connection.php');

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

$log_file = 'agreement/today/bulk_log_' . date('Ymd_His') . '.log';
ini_set('log_errors', 1);
ini_set('error_log', $log_file);

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
        'mobile/agreement/templates/', // Prioritized for NEW_SKILLS_PROGRAMME_APPLICATION_FORM
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
        SELECT us_code, us_title, credit_value, s_type
        FROM unit_standards
        WHERE qualification_id = ?
        ORDER BY us_code
        LIMIT 10
    ");
    if ($stmt) {
        $stmt->bind_param("s", $qualification_id);
        $result = $stmt->execute() ? $stmt->get_result() : null;
        if ($result) {
            while ($row = $result->fetch_assoc()) {
                $unit_standards[] = [
                    'id' => $row['us_code'],
                    'title' => $row['us_title'],
                    'credits' => $row['credit_value'] ?? 'N/A',
                    's_type' => $row['s_type'] ?? 'N/A'
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
        'mobile/agreement/templates/', // Prioritize this path
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
                $site_pathway_name = $learner_data['pathway_name'] ?? null;
                $selected_pathway = null;
                
                if (is_array($pathway_data) && $site_pathway_name !== null) {
                    foreach ($pathway_data as $pathway) {
                        if (isset($pathway['name']) && $pathway['name'] === $site_pathway_name) {
                            $selected_pathway = $pathway;
                            break;
                        }
                    }
                }
                
                // Fallback to first pathway if no match found
                if (!$selected_pathway && !empty($pathway_data)) {
                    $selected_pathway = $pathway_data[0];
                    log_message("No matching pathway found for pathway_name=$site_pathway_name, using first pathway");
                }
                
                // Extract fields from selected pathway
                $pathway_name = $selected_pathway['name'] ?? 'Short Skills Programme';
                $employment_status = $selected_pathway['qual_types'][0]['qualification']['employment_status'] ?? 'N/A';
                
                // Get unit standards from database
                $unit_standards = getUnitStandards($conn, $learner_data['qualification_id']);
                
                // Replace placeholders for NEW_SKILLS_PROGRAMME_APPLICATION_FORM
                if ($form_name === 'NEW_SKILLS_PROGRAMME_APPLICATION_FORM') {
                    // ID Number digits
                    for ($i = 1; $i <= 13; $i++) {
                        $template->setValue("id_digit_$i", $learner_data["id_digit_$i"] ?? 'N/A');
                    }
                    $template->setValue('Date_of_Birth', $learner_data['id_derived_dob'] ?? 'N/A');
                    $template->setValue('Gender_Male', $learner_data['gender'] === 'Male' ? 'X' : '');
                    $template->setValue('Gender_Female', $learner_data['gender'] === 'Female' ? 'X' : '');
                    $template->setValue('Citizen_Yes', $learner_data['is_south_african_citizen'] === 'Yes' ? 'X' : '');
                    $template->setValue('Citizen_No', $learner_data['is_south_african_citizen'] === 'No' ? 'X' : '');
                    $template->setValue('Title', $learner_data['title'] ?? 'N/A');
                    $template->setValue('employment_status', $employment_status);
                    // Unit Standards
                    if (!empty($unit_standards)) {
                        for ($i = 0; $i < min(10, count($unit_standards)); $i++) {
                            $index = $i + 1;
                            $template->setValue("unit_standard_{$index}_id", $unit_standards[$i]['id'] ?? 'N/A');
                            $template->setValue("unit_standard_{$index}_title", $unit_standards[$i]['title'] ?? 'N/A');
                            $template->setValue("unit_standard_{$index}_credits", $unit_standards[$i]['credits'] ?? 'N/A');
                            $template->setValue("unit_standard_{$index}_s_type", $unit_standards[$i]['s_type'] ?? 'N/A');
                        }
                        // Clear unused unit standard placeholders
                        for ($i = count($unit_standards) + 1; $i <= 10; $i++) {
                            $template->setValue("unit_standard_{$i}_id", 'N/A');
                            $template->setValue("unit_standard_{$i}_title", 'N/A');
                            $template->setValue("unit_standard_{$i}_credits", 'N/A');
                            $template->setValue("unit_standard_{$i}_s_type", 'N/A');
                        }
                    } else {
                        // Clear all unit standard placeholders if no data
                        for ($i = 1; $i <= 10; $i++) {
                            $template->setValue("unit_standard_{$i}_id", 'N/A');
                            $template->setValue("unit_standard_{$i}_title", 'N/A');
                            $template->setValue("unit_standard_{$i}_credits", 'N/A');
                            $template->setValue("unit_standard_{$i}_s_type", 'N/A');
                        }
                    }
                    $template->setValue('Race_African', 'X'); // Placeholder, as race is not in query
                    $template->setValue('Race_Coloured', '');
                    $template->setValue('Race_Indian', '');
                    $template->setValue('Race_White', '');
                    $template->setValue('Disability_No', 'X'); // Placeholder
                    $template->setValue('Disability_Yes', '');
                    $template->setValue('Disability_Specify', 'N/A');
                    $template->setValue('Postal_Address', 'PO Box 123, Pretoria, 0001'); // Placeholder
                    $template->setValue('Physical_Address', '456 Main Street, Pretoria, 0001'); // Placeholder
                    $template->setValue('Postal_Code', '0001'); // Placeholder
                    $template->setValue('Physical_Code', '0001'); // Placeholder
                    $template->setValue('Municipality', 'City of Tshwane'); // Placeholder
                    $template->setValue('Home_Tel', '0123456789'); // Placeholder
                    $template->setValue('Alternative_Contact', 'Jane Doe'); // Placeholder
                    $template->setValue('Alternative_Tel', '0839876543'); // Placeholder
                    $template->setValue('Alternative_Email', 'jane.doe@email.com'); // Placeholder
                    $template->setValue('Employer_Name', 'BuildCorp Ltd'); // Placeholder
                    $template->setValue('Employer_SDL', 'SDL789123'); // Placeholder
                    $template->setValue('Employer_Address', '789 Industry Road, Johannesburg, 2000'); // Placeholder
                    $template->setValue('Employer_Postal', 'PO Box 456, Johannesburg, 2000'); // Placeholder
                    $template->setValue('Employer_Postal_Code', '2000'); // Placeholder
                    $template->setValue('Employer_Physical_Code', '2000'); // Placeholder
                    $template->setValue('Employer_Contact', 'Sarah Brown'); // Placeholder
                    $template->setValue('Employer_Tel', '0112345678'); // Placeholder
                    $template->setValue('Employer_Cell', '0845678901'); // Placeholder
                    $template->setValue('Employer_Email', 'sarah.brown@buildcorp.com'); // Placeholder
                    $template->setValue('Employment_Start', '2023/03/01'); // Placeholder
                    $template->setValue('Assessor_Name', 'Jane Elizabeth Smith'); // Placeholder
                    $template->setValue('Assessor_Surname', 'Smith'); // Placeholder
                    $template->setValue('Assessor_ID', '7809125678901'); // Placeholder
                    $template->setValue('Assessor_Registration', 'ASS/456/2025'); // Placeholder
                    $template->setValue('Assessor_End_Date', '2027/12/31'); // Placeholder
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
                $template->setValue('Date', date('d F Y'));
                $template->setValue('qa_body_name', $learner_data['qa_body_name'] ?? 'N/A');
                $template->setValue('accreditation_number', $learner_data['accreditation_number'] ?? 'N/A');
                $template->setValue('total_credits', $learner_data['total_credits'] ?? 'N/A');
                $template->setValue('nqf_level', $learner_data['nqf_level'] ?? 'N/A');
                
                // Add pathway dates
                if (!empty($pathway_dates['start_dates'])) {
                    $template->setValue('pathway_start_date', $pathway_dates['start_dates'][0] ?? 'TBD');
                    $template->setValue('all_start_dates', implode(', ', $pathway_dates['start_dates']));
                } else {
                    $template->setValue('pathway_start_date', 'TBD');
                    $template->setValue('all_start_dates', 'TBD');
                }
                
                if (!empty($pathway_dates['end_dates'])) {
                    $template->setValue('pathway_end_date', $pathway_dates['end_dates'][0] ?? 'TBD');
                    $template->setValue('all_end_dates', implode(', ', $pathway_dates['end_dates']));
                } else {
                    $template->setValue('pathway_end_date', 'TBD');
                    $template->setValue('all_end_dates', 'TBD');
                }
                
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
                
                // Save form
                $safe_id = preg_replace('/[^a-zA-Z0-9]/', '_', $learner_data['IDNumber'] ?? 'unknown_' . $learner_data['LearnerID']);
                $form_file = $output_dir . $safe_id . "_{$form_name}.docx";
                $template->saveAs($form_file);
                
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
        qa.accreditation_number,
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
    LEFT JOIN qa_details qa ON qa.project_id = p.project_id 
        JOIN learningpathway lp on lp.pathway_id=qa.pathway_id
    AND qa.qualification_id = q.qualification_id
    AND lp.name= site.Project_pathway
    WHERE ld.LearnerID = ?";

    try {
        if (!$stmt = $conn->prepare($sql)) {
            log_message("SQL Error: " . $conn->error);
            sendErrorResponse("SQL Error: " . $conn->error, 500);
        }

        $stmt->bind_param('i', $LearnerID);
        if (!$stmt->execute()) {
            log_message("SQL Execution Error: " . $stmt->error);
            sendErrorResponse("Failed to execute database query", 500);
        }

        $result = $stmt->get_result();
        if ($result->num_rows === 0) {
            log_message("No data found for LearnerID: $LearnerID");
            sendErrorResponse("No data found for LearnerID: $LearnerID", 404);
        }

        $data = $result->fetch_assoc();
        $learners = [$data];
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
    LEFT JOIN qa_details qa ON qa.project_id = p.project_id 
       JOIN learningpathway lp on lp.pathway_id=qa.pathway_id
    AND qa.qualification_id = q.qualification_id
    AND lp.name= site.Project_pathway
    WHERE ld.IDNumber IN ($placeholders)";

    try {
        if (!$stmt = $conn->prepare($sql)) {
            log_message("SQL Error: " . $conn->error);
            sendErrorResponse("SQL Error: " . $conn->error, 500);
        }

        $stmt->bind_param(str_repeat('s', count($idNumbersArray)), ...$idNumbersArray);
        if (!$stmt->execute()) {
            log_message("SQL Execution Error: " . $stmt->error);
            sendErrorResponse("Failed to execute database query", 500);
        }

        $result = $stmt->get_result();
        $learners = $result->fetch_all(MYSQLI_ASSOC);
        if (empty($learners)) {
            log_message("No data found for IDNumbers: $IDNumbers");
            sendErrorResponse("No data found for provided IDNumbers", 404);
        }
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
            $site_pathway_name = $data['pathway_name'] ?? null;
            $selected_pathway = null;
            
            if (is_array($pathway_data) && $site_pathway_name !== null) {
                foreach ($pathway_data as $pathway) {
                    if (isset($pathway['name']) && $pathway['name'] === $site_pathway_name) {
                        $selected_pathway = $pathway;
                        break;
                    }
                }
            }
            
            // Fallback to first pathway if no match found
            if (!$selected_pathway && !empty($pathway_data)) {
                $selected_pathway = $pathway_data[0];
                log_message("No matching pathway found for pathway_name=$site_pathway_name, using first pathway");
            }
            
            // Extract fields from selected pathway
            $pathway_name = $selected_pathway['name'] ?? 'Short Skills Programme';
            $employment_status = $selected_pathway['qual_types'][0]['qualification']['employment_status'] ?? 'N/A';
            
            // Get unit standards
            $unit_standards = getUnitStandards($conn, $data['qualification_id']);
            
            // Generate Agreement
            $template = new TemplateProcessor($template_path);

            // Replace text placeholders
            $template->setValue('Name', $data['Name'] ?? 'N/A');
            $template->setValue('Surname', $data['Surname'] ?? 'N/A');
            $template->setValue('IDNumber', $data['IDNumber'] ?? 'N/A');
            $template->setValue('PhoneNumber', $data['PhoneNumber'] ?? 'N/A');
            $template->setValue('qualification_name', $data['qualification_name'] ?? 'Construction Roadworks');
            $template->setValue('qualification_id', $data['qualification_id'] ?? '24173');
            $template->setValue('pathway_name', $pathway_name);
            $template->setValue('sdp_name', $data['sdp_name'] ?? 'N/A');
            $template->setValue('learner_initials', $data['learner_initials'] ?? 'N/A');
            $template->setValue('Date', date('d F Y'));
            $template->setValue('witness_initials', $data['witness_initials'] ?? 'N/A');
            $template->setValue('qa_body_name', $data['qa_body_name'] ?? 'N/A');
            $template->setValue('accreditation_number', $data['accreditation_number'] ?? 'N/A');
            
            // Add pathway dates
            if (!empty($pathway_dates['start_dates'])) {
                $template->setValue('pathway_start_date', $pathway_dates['start_dates'][0] ?? 'TBD');
                $template->setValue('all_start_dates', implode(', ', $pathway_dates['start_dates']));
                for ($j = 0; $j < count($pathway_dates['start_dates']); $j++) {
                    $template->setValue('pathway_start_date_' . ($j + 1), $pathway_dates['start_dates'][$j] ?? 'TBD');
                }
            } else {
                $template->setValue('pathway_start_date', 'TBD');
                $template->setValue('all_start_dates', 'TBD');
            }
            
            if (!empty($pathway_dates['end_dates'])) {
                $template->setValue('pathway_end_date', $pathway_dates['end_dates'][0] ?? 'TBD');
                $template->setValue('all_end_dates', implode(', ', $pathway_dates['end_dates']));
                for ($j = 0; $j < count($pathway_dates['end_dates']); $j++) {
                    $template->setValue('pathway_end_date_' . ($j + 1), $pathway_dates['end_dates'][$j] ?? 'TBD');
                }
            } else {
                $template->setValue('pathway_end_date', 'TBD');
                $template->setValue('all_end_dates', 'TBD');
            }

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

            $sdp_signature_path = find_signature_path($data['signature_image'], ['signatures/']);
            if ($sdp_signature_path) {
                $template->setImageValue('sdp_signature_image', [
                    'src' => $sdp_signature_path,
                    'width' => 100,
                    'height' => 50
                ]);
                log_message("SDP signature added: $sdp_signature_path");
            } else {
                $template->setValue('sdp_signature_image', 'N/A');
                log_message("No SDP signature found");
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

            if (file_exists($docxFile)) {
                $generatedFiles[] = $docxFile;
                log_message("Agreement generated: $docxFile");
            } else {
                log_message("Failed to generate agreement for LearnerID: {$data['LearnerID']}");
                $skipped++;
            }

            // Determine required forms based on funder and qa_body_name
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