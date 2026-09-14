<?php
require 'vendor/autoload.php';
use PhpOffice\PhpWord\TemplateProcessor;

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
ini_set('memory_limit', '512M');
set_time_limit(300);

include('../connection.php');

// Set response headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

$log_file = 'agreement/today/bulk_log_' . date('Ymd_His') . '.log';
ini_set('log_errors', 1);
ini_set('error_log', $log_file);

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
    '/home/ezxcmacd/public_html/rlms.rlms.co.za/signatures/',
    '/home/ezxcmacd/public_html/rlms.rlms.co.za/mobile/signatures/',
    '/home/ezxcmacd/public_html/rlms.rlms.co.za/',
    '/home/ezxcmacd/public_html/rlms.rlms.co.za/mobile/'
];
$default_signature_path = '/home/ezxcmacd/public_html/rlms.rlms.co.za/mobile/agreement/signature_11_1728641462.png';

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

// Verify template existence
$template_path = 'agreement/Cleaned_Updated_Agreement_V4.docx';
if (!file_exists($template_path)) {
    log_message("Template file missing: $template_path");
    sendErrorResponse("Template file missing.", 404);
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

// Get LearnerID from the request
$LearnerID = $_GET['LearnerID'] ?? null;
if (!$LearnerID || !is_numeric($LearnerID)) {
    sendErrorResponse('Invalid or missing LearnerID parameter', 400);
}

// SQL Query for a single learner
$sql = "SELECT 
        ld.LearnerID, 
        ld.Name, 
        ld.Surname, 
        ld.IDNumber, 
        ld.signature AS signaturePath,
        ld.learner_initials,
        ld.PhoneNumber, 
        COALESCE(site.Project_pathway, 'Short Skills Programme') AS Project_pathway,
        COALESCE(p.Project_name, 'N/A') AS Project_name, 
        COALESCE(p.Start_date, 'N/A') AS Start_date, 
        COALESCE(p.End_date, 'N/A') AS End_date, 
        COALESCE(s.sdp_name, 'N/A') AS sdp_name, 
        COALESCE(s.sdp_logo, 'N/A') AS sdp_logo, 
        COALESCE(q.qualification_id, '24173') AS qualification_id,
        COALESCE(q.name, 'Construction Roadworks') AS qualification_name,
        COALESCE(s.signature_image, 'N/A') AS signature_image,
        ld.witness_initials AS witness_initials,
        ld.witness_signature AS witnessSignaturePath
    FROM learnerdetails ld
    LEFT JOIN class c ON ld.classID = c.classID
    LEFT JOIN sites site ON c.siteID = site.siteID
    LEFT JOIN qualification q ON q.qualification_id = site.qualification_id
    LEFT JOIN project p ON p.project_id = site.project_id
    LEFT JOIN sdp s ON p.sdp_name = s.sdp_name
    WHERE ld.LearnerID =
 ?";

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
} catch (Exception $e) {
    log_message("Database error: " . $e->getMessage());
    sendErrorResponse("Database error: " . $e->getMessage(), 500);
}

log_message("Processing LearnerID: {$data['LearnerID']} - {$data['Name']} {$data['Surname']}");

try {
    $template = new TemplateProcessor($template_path);

    // Replace text placeholders (unchanged from original)
    $template->setValue('Name', $data['Name'] ?? 'N/A');
    $template->setValue('Surname', $data['Surname'] ?? 'N/A');
    $template->setValue('IDNumber', $data['IDNumber'] ?? 'N/A');
    $template->setValue('PhoneNumber', $data['PhoneNumber'] ?? 'N/A');
    $template->setValue('qualification_name', 'Contruction Roadwords');
    $template->setValue('qualification_id', '24173');
    $template->setValue('pathway_name', $data['Project_pathway'] ?? 'Short Skills Programme');
    $template->setValue('sdp_name', $data['sdp_name'] ?? 'N/A');
    $template->setValue('learner_initials', $data['learner_initials'] ?? 'N/A');
    $template->setValue('Date', '06 February 2025');
    $template->setValue('witness_initials', $data['witness_initials'] ?? 'N/A');

    // Learner signature
    $learner_signature_path = find_signature_path($data['signaturePath'], $signature_base_paths);
    if ($learner_signature_path) {
        $template->setImageValue('learner_signature', [
            'src' => $learner_signature_path,
            'width' => 100,
            'height' => 50
        ]);
        log_message("Learner signature added: $learner_signature_path");
    } else {
        if (file_exists($default_signature_path)) {
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
    }

    // SDP signature
    $sdp_signature_path = find_signature_path($data['signature_image'], ['signatures/']);
    if ($sdp_signature_path) {
        $template->setImageValue('sdp_signature_image', [
            'src' => $sdp_signature_path,
            'width' => 100,
            'height' => 50
        ]);
        log_message("SDP signature added: $sdp_signature_path");
    } else {
        log_message("No SDP signature found");
    }

    // Witness signature
    $witness_signature_path = find_signature_path($data['witnessSignaturePath'], ['signatures/']);
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

    // Save document
    $safe_id = preg_replace('/[^a-zA-Z0-9]/', '_', $data['IDNumber'] ?? 'unknown_' . $data['LearnerID']);
    $docxFile = $output_dir . $safe_id . "_Agreement.docx";
    $template->saveAs($docxFile);

    if (!file_exists($docxFile)) {
        log_message("Failed to generate document for LearnerID: {$data['LearnerID']}");
        sendErrorResponse("Failed to generate agreement document", 500);
    }

    log_message("Document generated: $docxFile");

    // Serve the generated document for download
    header('Content-Description: File Transfer');
    header('Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    header('Content-Disposition: attachment; filename="' . basename($docxFile) . '"');
    header('Content-Transfer-Encoding: binary');
    header('Expires: 0');
    header('Cache-Control: must-revalidate');
    header('Pragma: public');
    header('Content-Length: ' . filesize($docxFile));
    readfile($docxFile);

    // Optional: Delete the generated file after serving
    // unlink($docxFile);

} catch (Exception $e) {
    log_message("Error processing LearnerID {$data['LearnerID']}: " . $e->getMessage());
    sendErrorResponse("Error processing document: " . $e->getMessage(), 500);
}

$stmt->close();
$conn->close();
exit;
?>