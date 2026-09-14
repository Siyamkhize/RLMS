<?php

/**
 * Direct Agreement PDF Generator
 * Uses the new PdfConverter class to generate PDFs directly from web context.
 */

require_once __DIR__ . '/../PdfConverter.php';
require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/../connection.php';

use PhpOffice\PhpWord\TemplateProcessor;

// Increase limits
set_time_limit(300);
ini_set('memory_limit', '512M');

// Get LearnerID
$learnerID = isset($_GET['LearnerID']) ? intval($_GET['LearnerID']) : null;

if (!$learnerID) {
    die("Error: LearnerID is required. Example: generate_agreement_pdfs.php?LearnerID=868");
}

try {
    echo "<h1>Generating Agreement PDF for Learner #$learnerID</h1>";
    
    // 1. Fetch learner data (Simplified version)
    $sql = "SELECT ld.* FROM learnerdetails ld WHERE ld.LearnerID = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $learner = $stmt->get_result()->fetch_assoc();

    if (!$learner) {
        throw new Exception("Learner not found with ID: $learnerID");
    }

    echo "<p>✓ Found learner: " . $learner['Name'] . " " . $learner['Surname'] . "</p>";

    // 2. Prepare Directories
    $tempDir = __DIR__ . '/agreement/today/' . $learner['IDNumber'];
    if (!is_dir($tempDir)) {
        mkdir($tempDir, 0777, true);
    }

    // 3. Create simple test DOCX (for now) - until we have the real template
    echo "<p>Creating test DOCX...</p>";
    $phpWord = new \PhpOffice\PhpWord\PhpWord();
    $section = $phpWord->addSection();
    $section->addText("LEARNER AGREEMENT", ['bold' => true, 'size' => 18]);
    $section->addTextBreak(2);
    $section->addText("Learner Name: " . $learner['Name'] . " " . $learner['Surname']);
    $section->addText("ID Number: " . $learner['IDNumber']);
    $section->addText("Date: " . date('d F Y'));
    
    $docxPath = $tempDir . '/Agreement_' . $learner['IDNumber'] . '.docx';
    $objWriter = \PhpOffice\PhpWord\IOFactory::createWriter($phpWord, 'Word2007');
    $objWriter->save($docxPath);

    echo "<p>✓ DOCX created: " . basename($docxPath) . "</p>";

    // 4. Convert to PDF using PdfConverter
    echo "<p>Converting to PDF (this may take a few seconds)...</p>";
    
    $converter = new PdfConverter($tempDir . '/pdf_input', $tempDir . '/pdf_output');
    $result = $converter->convertDocxToPdf($docxPath);

    if ($result['success']) {
        $pdfPath = $result['pdf_file'];
        $pdfFileName = basename($pdfPath);
        echo "<h2 style='color:green;'>✓ SUCCESS!</h2>";
        echo "<p>PDF generated successfully!</p>";
        echo "<p><a href='agreement/today/" . $learner['IDNumber'] . "/pdf_output/$pdfFileName' target='_blank' style='background: #28a745; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-size: 18px;'>📄 Download PDF Agreement</a></p>";
    } else {
        throw new Exception("PDF Conversion failed: " . $result['error']);
    }

} catch (Exception $e) {
    echo "<div style='color:red; padding:20px; border:1px solid red; background:#fff5f5;'>";
    echo "<h2>Error!</h2>";
    echo "<p><strong>Error:</strong> " . $e->getMessage() . "</p>";
    echo "</div>";
    error_log("Direct PDF Generation Error: " . $e->getMessage());
}
