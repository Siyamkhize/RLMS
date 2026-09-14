<?php
require 'vendor/autoload.php';
use PhpOffice\PhpWord\TemplateProcessor;
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Include database connection
include('../connection.php');

// SQL Query
$sql = "SELECT DISTINCT
    ld.LearnerID, 
    ld.Name AS learner_name, 
    ld.Surname AS learner_surname, 
    ld.IDNumber, 
    ld.PhoneNumber, 
    lc.signature AS learner_signature, 
    c.classID, 
    p.Project_pathway, 
    p.Project_name, 
    p.Start_date, 
    p.End_date, 
    s.sdp_name, 
    s.sdp_logo, 
    s.signature_image AS sdp_signature_image, 
    COALESCE(ps.pathway_name, 'Skills Programme') AS pathway_name, 
    COALESCE(q.qualification_name, 'Contraction Roadworks') AS qualification_name, 
    COALESCE(aq.qualification_id, q.qualification_id, '24173') AS qualification_id,
    
    -- Learner Initials
    CONCAT(
        CASE 
            WHEN LOCATE(' ', ld.Name) > 0 THEN 
                CONCAT(
                    UPPER(SUBSTRING(ld.Name, 1, 1)), 
                    UPPER(SUBSTRING(SUBSTRING_INDEX(ld.Name, ' ', -1), 1, 1)),
                    '.'
                )
            ELSE 
                CONCAT(UPPER(SUBSTRING(ld.Name, 1, 1)), '.')
        END,
        UPPER(SUBSTRING(ld.Surname, 1, 1)), '.'
    ) AS learner_initials,
    
    -- Random witness details using correlated subquery
    (
        SELECT CONCAT(
            CASE 
                WHEN LOCATE(' ', w.Name) > 0 THEN 
                    CONCAT(
                        UPPER(SUBSTRING(w.Name, 1, 1)), 
                        UPPER(SUBSTRING(SUBSTRING_INDEX(w.Name, ' ', -1), 1, 1)),
                        '.'
                    )
                ELSE 
                    CONCAT(UPPER(SUBSTRING(w.Name, 1, 1)), '.')
            END,
            UPPER(SUBSTRING(w.Surname, 1, 1)), '.'
        )
        FROM learnerdetails w
        WHERE w.classID = 6 AND w.signature IS NOT NULL
        ORDER BY RAND()
        LIMIT 1
    ) AS witness_initials,
    
    (
        SELECT w.signature
        FROM learnerdetails w
        WHERE w.classID = 6 AND w.signature IS NOT NULL
        ORDER BY RAND()
        LIMIT 1
    ) AS witness_signature

FROM 
    learnerdetails ld
LEFT JOIN
    learner_clocking lc ON lc.LearnerID = ld.LearnerID
JOIN 
    class c ON ld.classID = c.classID
JOIN 
    sites site ON c.siteID = site.siteID
JOIN 
    project p ON site.project_id = p.project_id
LEFT JOIN 
    sdp s ON p.sdp_name = s.sdp_name
LEFT JOIN 
    pathway_selection ps ON ps.project_id = p.project_id
LEFT JOIN 
    qualification_selection q ON q.pathway_id = ps.pathway_id
LEFT JOIN 
    qualification aq ON aq.name = q.qualification_name

WHERE 
     ld.LearnerID = 868

GROUP BY 
    ld.LearnerID

ORDER BY 
    ld.LearnerID";

if (!$stmt = $conn->prepare($sql)) {
    die("SQL Error: " . $conn->error);
}

$stmt->execute();
$result = $stmt->get_result();
$learners = $result->fetch_all(MYSQLI_ASSOC);

// Array to store generated DOCX files for zipping
$generatedFiles = [];


if ($learners) {
    foreach ($learners as $data) {
        echo "Processing LearnerID: {$data['LearnerID']} - {$data['learner_name']} {$data['learner_surname']}<br>";
        
        $template = new TemplateProcessor('agreement/Cleaned_Updated_Agreement_V3.docx');
        
        // Replace text placeholders
        $template->setValue('Name', $data['learner_name']);
        $template->setValue('Surname', $data['learner_surname']);
        $template->setValue('IDNumber', $data['IDNumber']);
        $template->setValue('PhoneNumber', $data['PhoneNumber']);
        $template->setValue('qualification_name', $data['qualification_name']);
        $template->setValue('qualification_id', $data['qualification_id']);
        $template->setValue('pathway_name', $data['pathway_name']);
        $template->setValue('sdp_name', $data['sdp_name']);
        $template->setValue('learner_initials', $data['learner_initials']);
        $template->setValue('Date', ' 06 February 2025');
        
$basePaths = [
    '/home/ezxcmacd/public_html/rlms.rlms.co.za/signatures/', // Primary signatures path
    '/home/ezxcmacd/public_html/rlms.rlms.co.za/mobile/signatures/', // Mobile signatures path
    '/home/ezxcmacd/public_html/rlms.rlms.co.za/', // Root path
    '/home/ezxcmacd/public_html/rlms.rlms.co.za/mobile/' // Mobile root path
];

$defaultSignaturePath = '/home/ezxcmacd/public_html/rlms.rlms.co.za/mobile/agreement/signature_11_1728641462.png'; // Default signature image

// Handle learner signature with multiple absolute paths
if (!empty($data['learner_signature'])) {
    $signatureFound = false;
    $signaturePath = '';

    // Iterate through each base path
    foreach ($basePaths as $basePath) {
        $signaturePath = $basePath . $data['learner_signature'];
        echo "LearnerID: {$data['LearnerID']} - Checking signature path: $signaturePath<br>";

        if (file_exists($signaturePath)) {
            $template->setImageValue('learner_signature', [
                'src' => $signaturePath,
                'width' => 100,
                'height' => 50
            ]);
            echo "Signature found and added for {$data['learner_name']} {$data['learner_surname']} at $signaturePath<br>";
            $signatureFound = true;
            break; // Exit loop once file is found
        } else {
            echo "Signature not found at: $signaturePath<br>";
        }
    }

    // If no signature was found in any path
    if (!$signatureFound) {
        echo "Signature file not found in any path for {$data['learner_name']} {$data['learner_surname']}<br>";
        $template->setValue('learner_signature', 'N/A');
    }
} else {
    echo "No signature in database for {$data['learner_name']} {$data['learner_surname']}, using default signature<br>";
    if (file_exists($defaultSignaturePath)) {
        $template->setImageValue('learner_signature', [
            'src' => $defaultSignaturePath,
            'width' => 100,
            'height' => 50
        ]);
        echo "Default signature added for {$data['learner_name']} {$data['learner_surname']} at $defaultSignaturePath<br>";
    } else {
        echo "Default signature file not found at: $defaultSignaturePath<br>";
        $template->setValue('learner_signature', 'N/A');
    }
}

        // Handle SDP signature with absolute path
        if (!empty($data['sdp_signature_image'])) {
            $sdpSignaturePath = 'signatures/'. $data['sdp_signature_image'];
            echo "Checking SDP signature path: $sdpSignaturePath<br>";
            if (file_exists($sdpSignaturePath)) {
                $template->setImageValue('sdp_signature_image', [
                    'src' => $sdpSignaturePath,
                    'width' => 100,
                    'height' => 50
                ]);
            } else {
                echo "SDP signature file not found: $sdpSignaturePath<br>";
            }
        }

        // Handle witness signature with absolute path
        if (!empty($data['witness_signature'])) {
            $witnessSignaturePath = 'signatures/'. $data['witness_signature'];
            echo "Checking witness signature path: $witnessSignaturePath<br>";
            if (file_exists($witnessSignaturePath)) {
                $template->setImageValue('witness_signature', [
                    'src' => $witnessSignaturePath,
                    'width' => 100,
                    'height' => 50
                ]);
            } else {
                echo "Witness signature file not found: $witnessSignaturePath<br>";
            }
        }
        
        // Handle witness initials
        if (!empty($data['witness_initials'])) {
            $template->setValue('witness_initials', $data['witness_initials']);
        }
        
        // Save as DOCX
        $docxFile = "agreement/today/{$data['IDNumber']}_Agreement.docx";
        $template->saveAs($docxFile);
        
        // Add DOCX to array for zipping
        if (file_exists($docxFile)) {
            $generatedFiles[] = $docxFile;
            echo "Document generated for {$data['learner_name']} {$data['learner_surname']}: <a href='$docxFile'>Download</a><br>";
        } else {
            echo "Failed to generate document for {$data['learner_name']} {$data['learner_surname']}<br>";
        }
    }

    // Create ZIP file containing all DOCX files
    if (!empty($generatedFiles)) {
        $zip = new ZipArchive();
        $zipFileName = "agreement/today/Class".$data['classID']."_Agreements_" . date('Ymd_His') . ".zip";
        
        if ($zip->open($zipFileName, ZipArchive::CREATE | ZipArchive::OVERWRITE) === TRUE) {
            foreach ($generatedFiles as $file) {
                $zip->addFile($file, basename($file));
            }
            $zip->close();
            
            echo "<br>All documents have been zipped: <a href='$zipFileName'>Download ZIP</a>";
        } else {
            echo "Failed to create ZIP file";
        }
    }
} else {
    echo "No data found for class ID 47.";
}

$stmt->close();
$conn->close();
?>