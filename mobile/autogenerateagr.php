<?php
error_reporting(E_ALL);
ini_set('display_errors', 1); // Disable in production
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error.log');

include 'connection.php';
require_once 'vendor/autoload.php';

use PhpOffice\PhpWord\TemplateProcessor;

error_log("autogenerateagr.php started at " . date('Y-m-d H:i:s'));

// Define paths


$templatePath = __DIR__ . '/agreement/Cleaned_Updated_Agreement_V3.docx';
$outputDir = __DIR__ . '/agreement/';
$zipFileName = 'learner_agreements_' . date('Ymd_His') . '.zip';
$zipFilePath = $outputDir . $zipFileName;
$baseUrl = 'http://rlms.rlms.co.za/mobile/';

// Validate dependencies
if (!file_exists('vendor/autoload.php')) {
    sendErrorResponse("PHPWord autoloader not found. Run 'composer require phpoffice/phpword'.", 500);
}
if (!class_exists('ZipArchive')) {
    sendErrorResponse("ZipArchive extension is not enabled.", 500);
}

// Ensure output directory exists and is writable
if (!file_exists($outputDir)) {
    mkdir($outputDir, 0777, true);
    error_log("Created output directory: $outputDir");
}
if (!is_writable($outputDir)) {
    sendErrorResponse("Output directory '$outputDir' is not writable", 500);
}

function sendErrorResponse($message, $statusCode = 500) {
    http_response_code($statusCode);
    header('Content-Type: text/plain');
    echo "Error: $message";
    error_log("Error in agreement.php: $message");
    exit;
}

if (!file_exists($templatePath)) {
    sendErrorResponse("Template file '$templatePath' not found", 404);
}

if (!$conn) {
    sendErrorResponse("Database connection failed", 500);
}

// Fetch learners
$sql = "
    SELECT 
        ld.LearnerID, 
        ld.Name, 
        ld.Surname, 
        ld.IDNumber, 
        lc.signature AS signaturePath,
        ld.learner_initials,
        ld.PhoneNumber, 
        p.Project_pathway,
        p.Project_name, 
        p.Start_date, 
        p.End_date, 
        s.sdp_name, 
        s.sdp_logo, 
        s.signature_image,
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
            WHERE c2.classID = 6 
            AND ld2.signature IS NOT NULL
            ORDER BY RAND()
            LIMIT 1
        ) AS witness_initials,
        (
            SELECT ld2.signature
            FROM learnerdetails ld2 
            JOIN class c2 ON ld2.classID = c2.classID 
            WHERE c2.classID = 6 
            AND ld2.signature IS NOT NULL
            ORDER BY RAND()
            LIMIT 1
        ) AS witnessSignaturePath
    FROM learnerdetails ld
    JOIN class c ON ld.classID = c.classID
    JOIN learner_clocking lc ON ld.learnerID = lc.learnerID
    JOIN sites site ON c.siteID = site.siteID
    JOIN project p ON p.project_id = site.project_id
    LEFT JOIN sdp s ON p.sdp_name = s.sdp_name
    WHERE p.project_name = 'ZDM CONSTRUCTION ROADWORKS'";
$stmt = $conn->prepare($sql);
if (!$stmt) {
    sendErrorResponse('Failed to prepare query: ' . $conn->error);
}

if (!$stmt->execute()) {
    sendErrorResponse('Failed to execute query: ' . $stmt->error);
}

$result = $stmt->get_result();
error_log("Query returned {$result->num_rows} rows");
if ($result->num_rows === 0) {
    sendErrorResponse('No learners found for project ZDM CONSTRUCTION ROADWORKS', 404);
}

$generatedCount = 0;
$skippedCount = 0;
$filesToZip = [];

$zip = new ZipArchive();
if ($zip->open($zipFilePath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
    sendErrorResponse("Cannot create ZIP file: $zipFilePath");
}

while ($row = $result->fetch_assoc()) {
    $LearnerID = $row['LearnerID'];
    $outputPath = $outputDir . "learner_agreement_$LearnerID.docx";

    if (file_exists($outputPath)) {
        error_log("Document already exists for LearnerID $LearnerID: $outputPath, skipping");
        $skippedCount++;
        continue;
    }

    $requiredFields = [
        'Name' => $row['Name'],
        'Surname' => $row['Surname'],
        'IDNumber' => $row['IDNumber'],
        'PhoneNumber' => $row['PhoneNumber'],
        'signaturePath' => $row['signaturePath'],
        'learner_initials' => $row['learner_initials'],
        'witnessSignaturePath' => $row['witnessSignaturePath'],
        'witness_initials' => $row['witness_initials']
    ];

    $allFieldsFilled = true;
    foreach ($requiredFields as $fieldName => $value) {
        if (is_null($value) || trim($value) === '') {
            error_log("Skipping LearnerID $LearnerID: Required field '$fieldName' is missing");
            $allFieldsFilled = false;
            break;
        }
    }

    if (!$allFieldsFilled) {
        continue;
    }

    $learnerSignaturePath = __DIR__ . 'mobile/' . $row['signaturePath'];
    $witnessSignaturePath = __DIR__ . 'mobile/signatures/' . $row['witnessSignaturePath'];

    error_log("Learner signature path: $learnerSignaturePath");
    error_log("Witness signature path: $witnessSignaturePath");

    $learnerSignatureData = @file_get_contents($learnerSignaturePath);
    if ($learnerSignatureData === false) {
        error_log("Cannot access learner signature: $learnerSignaturePath");
        continue;
    }
    $witnessSignatureData = @file_get_contents($witnessSignaturePath);
    if ($witnessSignatureData === false) {
        error_log("Cannot access witness signature: $witnessSignaturePath");
        continue;
    }

    try {
        $templateProcessor = new TemplateProcessor($templatePath);
    } catch (Exception $e) {
        error_log("Failed to load template for LearnerID $LearnerID: " . $e->getMessage());
        continue;
    }

    $replacements = [
        '${Name}' => htmlspecialchars($row['Name']),
        '${Surname}' => htmlspecialchars($row['Surname']),
        '${IDNumber}' => htmlspecialchars($row['IDNumber']),
        '${PhoneNumber}' => htmlspecialchars($row['PhoneNumber']),
        '${Date}' => date('Y-m-d'),
        '${Project_name}' => htmlspecialchars($row['Project_name'] ?? 'N/A'),
        '${Start_date}' => htmlspecialchars($row['Start_date'] ?? 'N/A'),
        '${End_date}' => htmlspecialchars($row['End_date'] ?? 'N/A'),
        '${sdp_name}' => htmlspecialchars($row['sdp_name'] ?? 'N/A'),
        '${sdp_logo}' => htmlspecialchars($row['sdp_logo'] ?? 'N/A'),
        '${learner_initials}' => htmlspecialchars($row['learner_initials']),
        '${witness_initials}' => htmlspecialchars($row['witness_initials']),
        '${qualification_name}' => htmlspecialchars('Construction Roadworks'),
        '${qualification_id}' => htmlspecialchars('24173'),
        '${pathway_name}' => htmlspecialchars($row['pathway_name'] ?? 'N/A'),
        '${Project_pathway}' => htmlspecialchars($row['Project_pathway'] ?? 'N/A'),
        '${signature_image}' => htmlspecialchars($row['signature_image'] ?? 'N/A'),
    ];

    foreach ($replacements as $placeholder => $value) {
        $templateProcessor->setValue($placeholder, $value);
    }

    try {
        $templateProcessor->setImageValue('learner_signature', [
            'src' => $learnerSignaturePath,
            'width' => 100,
            'height' => 50,
        ]);
    } catch (Exception $e) {
        error_log("Failed to set learner signature for LearnerID $LearnerID: " . $e->getMessage());
        $templateProcessor->setValue('learner_signature', 'Signature not available');
    }

    try {
        $templateProcessor->setImageValue('witness_signature', [
            'src' => $witnessSignaturePath,
            'width' => 100,
            'height' => 50,
        ]);
    } catch (Exception $e) {
        error_log("Failed to set witness signature for LearnerID $LearnerID: " . $e->getMessage());
        $templateProcessor->setValue('witness_signature', 'Signature not available');
    }

    try {
        $templateProcessor->saveAs($outputPath);
        if (file_exists($outputPath)) {
            error_log("Document saved for LearnerID $LearnerID: $outputPath");
            $generatedCount++;
            $zip->addFile($outputPath, "learner_agreement_$LearnerID.docx");
            $filesToZip[] = $outputPath;
        } else {
            error_log("Failed to verify saved document for LearnerID $LearnerID");
        }
    } catch (Exception $e) {
        error_log("Failed to save document for LearnerID $LearnerID: " . $e->getMessage());
    }
}

$stmt->close();
$zip->close();

foreach ($filesToZip as $file) {
    if (file_exists($file)) {
        unlink($file);
        error_log("Deleted individual file: $file");
    }
}

if (file_exists($zipFilePath) && $generatedCount > 0) {
    $downloadUrl = $baseUrl . 'agreement/' . $zipFileName;
    header('Content-Type: text/plain');
    echo "Generated $generatedCount agreements, skipped $skippedCount. Download: $downloadUrl";
    error_log("Generated $generatedCount agreements, ZIP: $zipFilePath, URL: $downloadUrl");
} else {
    header('Content-Type: text/plain');
    echo "Generated $generatedCount agreements, skipped $skippedCount. No files to download.";
    error_log("Generated $generatedCount agreements, skipped $skippedCount. No ZIP created.");
}

exit;