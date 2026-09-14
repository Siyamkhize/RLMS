<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

include 'connection.php';
require_once 'vendor/autoload.php'; // Include PHPWord library

use PhpOffice\PhpWord\TemplateProcessor;

// Set response headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Connect to the database
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Get the classID from GET parameters
$classID = isset($_GET['classID']) ? $_GET['classID'] : '';

if ($classID) {
    $sql = "SELECT Name, Surname, IDNumber FROM learnerdetails WHERE classID = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $classID);
    $stmt->execute();
    $result = $stmt->get_result();
} else {
    echo json_encode([
        'status' => 'error',
        'message' => "No classID provided",
    ]);
    exit;
}

// Fetch learners
$learners = [];
if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $learners[] = $row;
    }
} else {
    echo json_encode([
        'status' => 'error',
        'message' => "No learners found for classID: $classID",
    ]);
    exit;
}

// Path to the template document
$templatePath = "learningMeterial/class_template.docx";

try {
    $templateProcessor = new TemplateProcessor($templatePath);
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Error loading template: ' . $e->getMessage(),
    ]);
    exit;
}

// Clone rows in the table for each learner
$templateProcessor->cloneRow('NAME', count($learners));

// Populate the rows with learners' data
foreach ($learners as $index => $learner) {
    $rowIndex = $index + 1; // PhpWord rows are 1-based
    $templateProcessor->setValue("NAME#$rowIndex", htmlspecialchars($learner['Name']));
    $templateProcessor->setValue("SURNAME#$rowIndex", htmlspecialchars($learner['Surname']));
    $templateProcessor->setValue("ID#$rowIndex", htmlspecialchars($learner['IDNumber']));

    // Leave these placeholders empty (null) for now
    $templateProcessor->setValue("SIGNATURE#$rowIndex", "");
    $templateProcessor->setValue("CONDITION#$rowIndex", "");
    $templateProcessor->setValue("QUANTITY#$rowIndex", "");
}

// Ensure the 'generated_documents' directory exists
if (!file_exists('generated_documents')) {
    mkdir('generated_documents', 0777, true);
}

// Save the populated Word document
$docName = "class_{$classID}_generated.docx";
$docPath = "generated_documents/$docName";

try {
    $templateProcessor->saveAs($docPath);
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Error saving the document: ' . $e->getMessage(),
    ]);
    exit;
}

// Return the document path as a response
echo json_encode([
    'status' => 'success',
    'message' => 'Document generated successfully',
    'docPath' => $docPath,
]);

// Close the database connection
$conn->close();
